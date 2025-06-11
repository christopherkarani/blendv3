import Foundation
import stellarsdk

/// Core networking service for Soroban smart contract operations
/// Handles all RPC calls, contract invocations, and transaction submission
@MainActor
class NetworkService: ObservableObject {
    
    // MARK: - Properties
    
    private let stellarSDK: StellarSDK
    private let sorobanServer: SorobanServer
    private let network: Network
    
    // MARK: - Initialization
    
    init(network: Network = .testnet) {
        self.network = network
        self.stellarSDK = StellarSDK(withHorizonUrl: network.horizonUrl)
        self.sorobanServer = SorobanServer(endpoint: network.sorobanRpcUrl)
    }
    
    // MARK: - Account Operations
    
    /// Load account details from the network
    func loadAccount(accountId: String) async throws -> AccountResponse {
        return try await withCheckedThrowingContinuation { continuation in
            stellarSDK.accounts.getAccountDetails(accountId: accountId) { response in
                switch response {
                case .success(let accountResponse):
                    continuation.resume(returning: accountResponse)
                case .failure(let error):
                    continuation.resume(throwing: NetworkError.horizonError(error))
                }
            }
        }
    }
    
    // MARK: - Contract Data Operations
    
    /// Get contract data from Soroban
    func getContractData(contractAddress: String, key: SCVal, durability: ContractDataDurability = .persistent) async throws -> LedgerEntryResult {
        let request = GetLedgerEntriesRequest()
        let contractDataKey = LedgerKey.contractData(
            contractAddress: contractAddress,
            key: key,
            durability: durability
        )
        request.keys = [contractDataKey]
        
        return try await withCheckedThrowingContinuation { continuation in
            sorobanServer.getLedgerEntries(request: request) { response in
                switch response {
                case .success(let result):
                    guard let entry = result.entries.first else {
                        continuation.resume(throwing: NetworkError.contractDataNotFound)
                        return
                    }
                    continuation.resume(returning: entry)
                case .failure(let error):
                    continuation.resume(throwing: NetworkError.sorobanError(error))
                }
            }
        }
    }
    
    // MARK: - Contract Invocation
    
    /// Simulate a contract method invocation
    func simulateTransaction(transaction: Transaction) async throws -> SimulateTransactionResponse {
        let request = SimulateTransactionRequest(transaction: transaction)
        
        return try await withCheckedThrowingContinuation { continuation in
            sorobanServer.simulateTransaction(simulateTransactionRequest: request) { response in
                switch response {
                case .success(let simulationResponse):
                    continuation.resume(returning: simulationResponse)
                case .failure(let error):
                    continuation.resume(throwing: NetworkError.simulationError(error))
                }
            }
        }
    }
    
    /// Invoke a contract method (simulate + submit)
    func invokeContract(
        contractAddress: String,
        method: String,
        args: [SCVal],
        sourceAccount: KeyPair,
        fee: UInt32? = nil
    ) async throws -> SubmitTransactionResponse {
        
        // Load source account
        let account = try await loadAccount(accountId: sourceAccount.accountId)
        
        // Build invoke operation
        let operation = try InvokeContractOperation(
            sourceAccountId: sourceAccount.accountId,
            contractAddress: contractAddress,
            functionName: method,
            functionArguments: args
        )
        
        // Build transaction
        var transaction = try Transaction(
            sourceAccount: account,
            operations: [operation],
            memo: Memo.none
        )
        
        // Simulate to get resource requirements
        let simulationResponse = try await simulateTransaction(transaction: transaction)
        
        // Update transaction with simulation results
        if let transactionData = simulationResponse.transactionData {
            transaction.setSorobanTransactionData(sorobanData: transactionData)
        }
        
        // Set fee if provided or use simulation result
        let transactionFee = fee ?? simulationResponse.minResourceFee
        transaction.fee = transactionFee
        
        // Sign transaction
        try transaction.sign(keyPair: sourceAccount, network: network)
        
        // Submit transaction
        return try await submitTransaction(transaction: transaction)
    }
    
    // MARK: - Transaction Submission
    
    /// Submit a signed transaction to the network
    func submitTransaction(transaction: Transaction) async throws -> SubmitTransactionResponse {
        return try await withCheckedThrowingContinuation { continuation in
            sorobanServer.submitTransaction(transaction: transaction) { response in
                switch response {
                case .success(let submitResponse):
                    continuation.resume(returning: submitResponse)
                case .failure(let error):
                    continuation.resume(throwing: NetworkError.submissionError(error))
                }
            }
        }
    }
    
    // MARK: - Event Retrieval
    
    /// Get contract events
    func getEvents(
        contractAddress: String? = nil,
        topics: [String] = [],
        startLedger: UInt32? = nil,
        endLedger: UInt32? = nil
    ) async throws -> GetEventsResponse {
        
        let request = GetEventsRequest()
        
        if let contractAddress = contractAddress {
            let eventFilter = EventFilter()
            eventFilter.contractIds = [contractAddress]
            if !topics.isEmpty {
                eventFilter.topics = [topics]
            }
            request.filters = [eventFilter]
        }
        
        if let startLedger = startLedger {
            request.startLedger = startLedger
        }
        
        if let endLedger = endLedger {
            request.endLedger = endLedger
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            sorobanServer.getEvents(request: request) { response in
                switch response {
                case .success(let eventsResponse):
                    continuation.resume(returning: eventsResponse)
                case .failure(let error):
                    continuation.resume(throwing: NetworkError.eventsError(error))
                }
            }
        }
    }
    
    // MARK: - Network Information
    
    /// Get latest ledger information
    func getLatestLedger() async throws -> GetLatestLedgerResponse {
        return try await withCheckedThrowingContinuation { continuation in
            sorobanServer.getLatestLedger { response in
                switch response {
                case .success(let ledgerResponse):
                    continuation.resume(returning: ledgerResponse)
                case .failure(let error):
                    continuation.resume(throwing: NetworkError.ledgerError(error))
                }
            }
        }
    }
}

// MARK: - Network Configuration Extension

extension Network {
    var horizonUrl: String {
        switch self {
        case .testnet:
            return "https://horizon-testnet.stellar.org"
        case .public:
            return "https://horizon.stellar.org"
        default:
            return "https://horizon-testnet.stellar.org"
        }
    }
    
    var sorobanRpcUrl: String {
        switch self {
        case .testnet:
            return "https://soroban-testnet.stellar.org"
        case .public:
            return "https://soroban-mainnet.stellar.org"
        default:
            return "https://soroban-testnet.stellar.org"
        }
    }
}

// MARK: - Error Types

enum NetworkError: Error, LocalizedError {
    case horizonError(HorizonRequestError)
    case sorobanError(SorobanRpcRequestError)
    case simulationError(SorobanRpcRequestError)
    case submissionError(SorobanRpcRequestError)
    case eventsError(SorobanRpcRequestError)
    case ledgerError(SorobanRpcRequestError)
    case contractDataNotFound
    case invalidResponse
    case accountNotFound
    
    var errorDescription: String? {
        switch self {
        case .horizonError(let error):
            return "Horizon error: \(error.localizedDescription)"
        case .sorobanError(let error):
            return "Soroban RPC error: \(error.localizedDescription)"
        case .simulationError(let error):
            return "Transaction simulation failed: \(error.localizedDescription)"
        case .submissionError(let error):
            return "Transaction submission failed: \(error.localizedDescription)"
        case .eventsError(let error):
            return "Events retrieval failed: \(error.localizedDescription)"
        case .ledgerError(let error):
            return "Ledger retrieval failed: \(error.localizedDescription)"
        case .contractDataNotFound:
            return "Contract data not found"
        case .invalidResponse:
            return "Invalid response received"
        case .accountNotFound:
            return "Account not found"
        }
    }
}