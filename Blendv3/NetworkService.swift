import Foundation
import Combine
import StellarSDK

// MARK: - Network Service Protocol
protocol NetworkServiceProtocol {
    func invokeContract(contractId: String, method: String, args: [SCVal]) -> AnyPublisher<InvokeContractResponse, NetworkError>
    func simulateTransaction(transaction: Transaction) -> AnyPublisher<SimulateTransactionResponse, NetworkError>
    func getContractData(contractId: String, key: SCVal) -> AnyPublisher<GetContractDataResponse, NetworkError>
    func submitTransaction(transaction: Transaction) -> AnyPublisher<SubmitTransactionResponse, NetworkError>
    func getEvents(contractId: String, startLedger: UInt32?, limit: Int?) -> AnyPublisher<GetEventsResponse, NetworkError>
    func getLedgerEntries(keys: [String]) -> AnyPublisher<GetLedgerEntriesResponse, NetworkError>
}

// MARK: - Network Error
enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(String)
    case networkError(Error)
    case sorobanError(String)
    case simulationFailed(String)
    case transactionFailed(String)
    case retryLimitExceeded
    case unauthorized
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .sorobanError(let message):
            return "Soroban error: \(message)"
        case .simulationFailed(let message):
            return "Transaction simulation failed: \(message)"
        case .transactionFailed(let message):
            return "Transaction submission failed: \(message)"
        case .retryLimitExceeded:
            return "Retry limit exceeded"
        case .unauthorized:
            return "Unauthorized"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

// MARK: - Response Types
struct InvokeContractResponse {
    let transactionHash: String?
    let result: SCVal?
    let events: [DiagnosticEvent]
    let cost: TransactionCost?
}

struct SimulateTransactionResponse {
    let results: [SimulateHostFunctionResult]
    let cost: TransactionCost?
    let events: [DiagnosticEvent]
    let latestLedger: UInt32
}

struct GetContractDataResponse {
    let key: SCVal
    let value: SCVal?
    let liveUntilLedgerSeq: UInt32?
}

struct SubmitTransactionResponse {
    let transactionHash: String
    let status: TransactionStatus
    let ledger: UInt32
}

struct GetEventsResponse {
    let events: [ContractEvent]
    let latestLedger: UInt32
}

struct GetLedgerEntriesResponse {
    let entries: [LedgerEntry]
    let latestLedger: UInt32
}

// MARK: - Supporting Types
struct TransactionCost {
    let cpuInstructions: UInt64
    let memoryBytes: UInt64
    let storageBytes: UInt64
}

struct DiagnosticEvent {
    let type: String
    let contractId: String?
    let topics: [SCVal]
    let data: SCVal
}

struct SimulateHostFunctionResult {
    let auth: [SorobanAuthorizationEntry]
    let xdr: String
}

struct ContractEvent {
    let contractId: String
    let ledger: UInt32
    let topics: [SCVal]
    let data: SCVal
}

struct LedgerEntry {
    let key: String
    let xdr: String
    let lastModifiedLedgerSeq: UInt32
}

enum TransactionStatus {
    case pending
    case success
    case failed(String)
}

// MARK: - Network Service Implementation
final class NetworkService: NetworkServiceProtocol {
    
    // MARK: - Properties
    private let sorobanServer: SorobanServer
    private let horizonServer: AccountService
    private let networkPassphrase: String
    private let retryConfig: RetryConfiguration
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    struct Configuration {
        let sorobanURL: String
        let horizonURL: String
        let networkPassphrase: String
        let retryConfig: RetryConfiguration
        
        static let testnet = Configuration(
            sorobanURL: "https://soroban-testnet.stellar.org",
            horizonURL: "https://horizon-testnet.stellar.org",
            networkPassphrase: Network.testnet.networkId,
            retryConfig: .default
        )
        
        static let mainnet = Configuration(
            sorobanURL: "https://soroban.stellar.org",
            horizonURL: "https://horizon.stellar.org",
            networkPassphrase: Network.public.networkId,
            retryConfig: .default
        )
    }
    
    struct RetryConfiguration {
        let maxAttempts: Int
        let baseDelay: TimeInterval
        let maxDelay: TimeInterval
        
        static let `default` = RetryConfiguration(
            maxAttempts: 3,
            baseDelay: 1.0,
            maxDelay: 10.0
        )
    }
    
    // MARK: - Initialization
    init(configuration: Configuration = .testnet) {
        self.sorobanServer = SorobanServer(endpoint: configuration.sorobanURL)
        self.horizonServer = AccountService(baseURL: configuration.horizonURL)
        self.networkPassphrase = configuration.networkPassphrase
        self.retryConfig = configuration.retryConfig
    }
    
    // MARK: - Public Methods
    
    func invokeContract(contractId: String, method: String, args: [SCVal]) -> AnyPublisher<InvokeContractResponse, NetworkError> {
        Future<InvokeContractResponse, NetworkError> { [weak self] promise in
            guard let self = self else { return }
            
            Task {
                do {
                    // Build the invocation
                    let invokeFunction = InvokeHostFunctionOp.invokeContract(
                        contractAddress: try SCAddress(contractId: contractId),
                        functionName: method,
                        functionArguments: args
                    )
                    
                    // Create transaction with the invoke operation
                    let operation = try Operation.invokeHostFunction(invokeFunction)
                    
                    // For now, we'll simulate the transaction
                    // In a real implementation, this would need an account and proper signing
                    promise(.failure(.sorobanError("Contract invocation requires account setup")))
                    
                } catch {
                    promise(.failure(.networkError(error)))
                }
            }
        }
        .retry(retryConfig.maxAttempts) { error in
            self.shouldRetry(error: error)
        }
        .eraseToAnyPublisher()
    }
    
    func simulateTransaction(transaction: Transaction) -> AnyPublisher<SimulateTransactionResponse, NetworkError> {
        Future<SimulateTransactionResponse, NetworkError> { [weak self] promise in
            guard let self = self else { return }
            
            Task {
                do {
                    let response = try await self.sorobanServer.simulateTransaction(
                        simulateTxRequest: SimulateTransactionRequest(transaction: transaction)
                    )
                    
                    switch response {
                    case .success(let simulateResponse):
                        let result = SimulateTransactionResponse(
                            results: simulateResponse.results ?? [],
                            cost: self.mapTransactionCost(simulateResponse.cost),
                            events: simulateResponse.events?.map { self.mapDiagnosticEvent($0) } ?? [],
                            latestLedger: simulateResponse.latestLedger
                        )
                        promise(.success(result))
                        
                    case .failure(let error):
                        promise(.failure(.simulationFailed(error.localizedDescription)))
                    }
                } catch {
                    promise(.failure(.networkError(error)))
                }
            }
        }
        .retry(retryConfig.maxAttempts) { error in
            self.shouldRetry(error: error)
        }
        .eraseToAnyPublisher()
    }
    
    func getContractData(contractId: String, key: SCVal) -> AnyPublisher<GetContractDataResponse, NetworkError> {
        Future<GetContractDataResponse, NetworkError> { [weak self] promise in
            guard let self = self else { return }
            
            Task {
                do {
                    // Create contract data key
                    let contractAddress = try SCAddress(contractId: contractId)
                    let contractDataKey = SCVal.ledgerKeyContractData(
                        contract: contractAddress,
                        key: key,
                        durability: .persistent
                    )
                    
                    // Convert to base64 for the request
                    let keyXDR = try contractDataKey.xdrEncoded()
                    let keyBase64 = keyXDR.base64EncodedString()
                    
                    // Get ledger entries
                    let response = try await self.sorobanServer.getLedgerEntries(
                        getLedgerEntriesRequest: GetLedgerEntriesRequest(keys: [keyBase64])
                    )
                    
                    switch response {
                    case .success(let entriesResponse):
                        if let entry = entriesResponse.entries?.first,
                           let data = try? LedgerEntryData(xdr: entry.xdr) {
                            let result = GetContractDataResponse(
                                key: key,
                                value: data.contractData?.val,
                                liveUntilLedgerSeq: entry.liveUntilLedgerSeq
                            )
                            promise(.success(result))
                        } else {
                            let result = GetContractDataResponse(
                                key: key,
                                value: nil,
                                liveUntilLedgerSeq: nil
                            )
                            promise(.success(result))
                        }
                        
                    case .failure(let error):
                        promise(.failure(.sorobanError(error.localizedDescription)))
                    }
                } catch {
                    promise(.failure(.networkError(error)))
                }
            }
        }
        .retry(retryConfig.maxAttempts) { error in
            self.shouldRetry(error: error)
        }
        .eraseToAnyPublisher()
    }
    
    func submitTransaction(transaction: Transaction) -> AnyPublisher<SubmitTransactionResponse, NetworkError> {
        Future<SubmitTransactionResponse, NetworkError> { [weak self] promise in
            guard let self = self else { return }
            
            Task {
                do {
                    let response = try await self.sorobanServer.sendTransaction(
                        sendTxRequest: SendTransactionRequest(transaction: transaction)
                    )
                    
                    switch response {
                    case .success(let sendResponse):
                        let status: TransactionStatus
                        switch sendResponse.status {
                        case .pending:
                            status = .pending
                        case .success:
                            status = .success
                        case .error(let message):
                            status = .failed(message)
                        default:
                            status = .pending
                        }
                        
                        let result = SubmitTransactionResponse(
                            transactionHash: sendResponse.hash,
                            status: status,
                            ledger: sendResponse.latestLedger ?? 0
                        )
                        promise(.success(result))
                        
                    case .failure(let error):
                        promise(.failure(.transactionFailed(error.localizedDescription)))
                    }
                } catch {
                    promise(.failure(.networkError(error)))
                }
            }
        }
        .retry(retryConfig.maxAttempts) { error in
            self.shouldRetry(error: error)
        }
        .eraseToAnyPublisher()
    }
    
    func getEvents(contractId: String, startLedger: UInt32? = nil, limit: Int? = nil) -> AnyPublisher<GetEventsResponse, NetworkError> {
        Future<GetEventsResponse, NetworkError> { [weak self] promise in
            guard let self = self else { return }
            
            Task {
                do {
                    let filters = [EventFilter(
                        contractIds: [contractId],
                        topics: nil,
                        type: nil
                    )]
                    
                    let request = GetEventsRequest(
                        startLedger: startLedger,
                        filters: filters,
                        pagination: limit.map { PaginationOptions(limit: $0) }
                    )
                    
                    let response = try await self.sorobanServer.getEvents(getEventsRequest: request)
                    
                    switch response {
                    case .success(let eventsResponse):
                        let events = eventsResponse.events?.map { event in
                            ContractEvent(
                                contractId: event.contractId,
                                ledger: event.ledger,
                                topics: event.topic.map { try? SCVal(xdr: $0) }.compactMap { $0 },
                                data: (try? SCVal(xdr: event.value.xdr)) ?? SCVal.void
                            )
                        } ?? []
                        
                        let result = GetEventsResponse(
                            events: events,
                            latestLedger: eventsResponse.latestLedger
                        )
                        promise(.success(result))
                        
                    case .failure(let error):
                        promise(.failure(.sorobanError(error.localizedDescription)))
                    }
                } catch {
                    promise(.failure(.networkError(error)))
                }
            }
        }
        .retry(retryConfig.maxAttempts) { error in
            self.shouldRetry(error: error)
        }
        .eraseToAnyPublisher()
    }
    
    func getLedgerEntries(keys: [String]) -> AnyPublisher<GetLedgerEntriesResponse, NetworkError> {
        Future<GetLedgerEntriesResponse, NetworkError> { [weak self] promise in
            guard let self = self else { return }
            
            Task {
                do {
                    let response = try await self.sorobanServer.getLedgerEntries(
                        getLedgerEntriesRequest: GetLedgerEntriesRequest(keys: keys)
                    )
                    
                    switch response {
                    case .success(let entriesResponse):
                        let entries = entriesResponse.entries?.map { entry in
                            LedgerEntry(
                                key: entry.key,
                                xdr: entry.xdr,
                                lastModifiedLedgerSeq: entry.lastModifiedLedgerSeq ?? 0
                            )
                        } ?? []
                        
                        let result = GetLedgerEntriesResponse(
                            entries: entries,
                            latestLedger: entriesResponse.latestLedger
                        )
                        promise(.success(result))
                        
                    case .failure(let error):
                        promise(.failure(.sorobanError(error.localizedDescription)))
                    }
                } catch {
                    promise(.failure(.networkError(error)))
                }
            }
        }
        .retry(retryConfig.maxAttempts) { error in
            self.shouldRetry(error: error)
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func shouldRetry(error: NetworkError) -> Bool {
        switch error {
        case .networkError, .serverError:
            return true
        case .retryLimitExceeded, .unauthorized:
            return false
        default:
            return false
        }
    }
    
    private func mapTransactionCost(_ cost: TransactionCost?) -> TransactionCost? {
        guard let cost = cost else { return nil }
        return TransactionCost(
            cpuInstructions: cost.cpuInsns,
            memoryBytes: cost.memBytes,
            storageBytes: 0 // Add if available in response
        )
    }
    
    private func mapDiagnosticEvent(_ event: DiagnosticEvent) -> DiagnosticEvent {
        DiagnosticEvent(
            type: event.event.type ?? "unknown",
            contractId: event.event.contractId,
            topics: event.event.body.v0?.topics.map { try? SCVal(xdr: $0) }.compactMap { $0 } ?? [],
            data: (try? SCVal(xdr: event.event.body.v0?.data ?? "")) ?? SCVal.void
        )
    }
}

// MARK: - Retry Extension
extension Publisher {
    func retry<T: Scheduler>(
        _ retries: Int,
        on scheduler: T = DispatchQueue.global(),
        condition: @escaping (Failure) -> Bool
    ) -> AnyPublisher<Output, Failure> {
        self.catch { error -> AnyPublisher<Output, Failure> in
            guard condition(error), retries > 0 else {
                return Fail(error: error).eraseToAnyPublisher()
            }
            
            return Just(())
                .delay(for: .seconds(1), scheduler: scheduler)
                .flatMap { _ -> AnyPublisher<Output, Failure> in
                    self.retry(retries - 1, on: scheduler, condition: condition)
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}