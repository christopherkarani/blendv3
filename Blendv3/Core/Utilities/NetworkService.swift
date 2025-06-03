//
//  NetworkService.swift
//  Blendv3
//
//  Enhanced network service with Soroban RPC support
//

import Foundation
import Combine
import stellarsdk

/// Enhanced network service for Stellar/Soroban RPC calls with connection pooling
public final class NetworkService: BlendNetworkServiceProtocol {
    
    // MARK: - Properties
    
    private let configuration: ConfigurationServiceProtocol
    private let session: URLSession
    private let baseURL: URL
    
    // Connection state
    private var connectionState: ConnectionState = .disconnected
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    
    // Request interceptors
    private var requestInterceptors: [(URLRequest) -> URLRequest] = []
    private var responseInterceptors: [(Data, URLResponse) -> Void] = []
    
    // MARK: - Initialization
    
    public init(configuration: ConfigurationServiceProtocol) {
        self.configuration = configuration
        
        // Configure URLSession with connection pooling
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.getTimeoutConfiguration().networkTimeout
        config.timeoutIntervalForResource = configuration.getTimeoutConfiguration().networkTimeout * 2
        config.httpMaximumConnectionsPerHost = 6 // Connection pooling
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: config)
        self.baseURL = URL(string: configuration.rpcEndpoint)!
        
        setupDefaultInterceptors()
        BlendLogger.info("NetworkService initialized with endpoint: \(configuration.rpcEndpoint)", category: BlendLogger.network)
    }
    
    // MARK: - NetworkServiceProtocol
    
    public func initialize() async throws {
        BlendLogger.info("Initializing network service", category: BlendLogger.network)
        
        // Test connection
        let testResult = await checkConnectivity()
        guard testResult == .connected else {
            throw BlendError.network(.connectionFailed)
        }
        
        connectionState = .connected
        connectionStateSubject.send(.connected)
        
        BlendLogger.info("Network service initialized successfully", category: BlendLogger.network)
    }
    
    public func getAccount(accountId: String) async throws -> Account {
        BlendLogger.debug("Fetching account: \(accountId)", category: BlendLogger.network)
        
        let sdk = StellarSDK(withHorizonUrl: configuration.rpcEndpoint)
        
        return try await withCheckedThrowingContinuation { continuation in
            sdk.accounts.getAccountDetails(accountId: accountId) { response in
                switch response {
                case .success(let details):
                    // Convert AccountResponse to Account
                    do {
                        let account = try Account(accountId: details.accountId, 
                                             sequenceNumber: details.sequenceNumber)
                        continuation.resume(returning: account)
                    } catch {
                        BlendLogger.error("Failed to create Account from response", error: error, category: BlendLogger.network)
                        continuation.resume(throwing: BlendError.network(.serverError))
                    }
                case .failure(let error):
                    BlendLogger.error("Failed to fetch account", error: error, category: BlendLogger.network)
                    continuation.resume(throwing: BlendError.network(.serverError))
                }
            }
        }
    }
    
    public func submitTransaction(_ transaction: Transaction) async throws -> TransactionResponse {
        BlendLogger.info("Submitting transaction", category: BlendLogger.network)
        
        let sdk = StellarSDK(withHorizonUrl: configuration.rpcEndpoint)
        
        return try await withCheckedThrowingContinuation { continuation in
            sdk.transactions.submitTransaction(transaction: transaction) { response in
                switch response {
                case .success(let result):
                    BlendLogger.info("Transaction submitted successfully: \(result.transactionHash ?? "unknown")", category: BlendLogger.network)
                    continuation.resume(returning: result)
                case .failure(let error):
                    BlendLogger.error("Transaction submission failed", error: error, category: BlendLogger.network)
                    continuation.resume(throwing: BlendError.transaction(.failed))
                @unknown default:
                    BlendLogger.error("Unknown response type in transaction submission", category: BlendLogger.network)
                    continuation.resume(throwing: BlendError.transaction(.failed))
                }
            }
        }
    }
    
    public func invokeContractFunction(
        contractId: String,
        functionName: String,
        args: [SCValXDR]
    ) async throws -> SCValXDR {
        BlendLogger.debug("Invoking contract function: \(functionName) on \(contractId)", category: BlendLogger.network)
        
        // Create invoke contract operation
        let contractAddress = try SCAddressXDR(contractId: contractId)
        let invokeArgs = InvokeContractArgsXDR(
            contractAddress: contractAddress,
            functionName: functionName,
            args: args
        )
        
        // Simulate the transaction first
        let operation = try InvokeHostFunctionOperation(
            hostFunction: .invokeContract(invokeArgs),
            sourceAccountId: nil
        )
        
        let simulationResult = try await simulateOperation(operation)
        
        // Parse the result
        guard let result = simulationResult.result else {
            throw BlendError.validation(.invalidResponse)
        }
        
        return result
    }
    
    public func simulateOperation(_ operation: stellarsdk.Operation) async throws -> SimulationResult {
        BlendLogger.debug("Simulating operation", category: BlendLogger.network)
        
        let request = try SimulateTransactionRequest(
            transaction: try createSimulationTransaction(operation),
            resourceConfig: ResourceConfig()
        )
        
        let response = try await performSorobanRPC("simulateTransaction", params: request)
        
        // Parse simulation response
        let simulationResponse = try JSONDecoder().decode(SimulateTransactionResponse.self, from: response)
        
        if let error = simulationResponse.error {
            BlendLogger.error("Simulation failed: \(error)", category: BlendLogger.network)
            throw BlendError.transaction(.failed)
        }
        
        // Parse the first result XDR string to SCValXDR
        let resultVal: SCValXDR? = simulationResponse.results?.first.flatMap { xdrString in
            try? SCValXDR(xdr: xdrString)
        }
        
        return SimulationResult(
            result: resultVal,
            cost: simulationResponse.cost ?? 0,
            footprint: simulationResponse.footprint
        )
    }
    
    public func getLedgerEntries(keys: [String]) async throws -> [String: Any] {
        BlendLogger.debug("Getting ledger entries for \(keys.count) keys", category: BlendLogger.network)
        
        // Create a request structure for getLedgerEntries RPC call
        struct GetLedgerEntriesParams: Encodable {
            let keys: [String]
        }
        
        let params = GetLedgerEntriesParams(keys: keys)
        let response = try await performSorobanRPC("getLedgerEntries", params: params)
        
        // Parse the response
        struct GetLedgerEntriesResponse: Decodable {
            let entries: [[String: String]]?
            let error: String?
        }
        
        let ledgerResponse = try JSONDecoder().decode(GetLedgerEntriesResponse.self, from: response)
        
        if let error = ledgerResponse.error {
            BlendLogger.error("Get ledger entries failed: \(error)", category: BlendLogger.network)
            throw BlendError.network(.serverError)
        }
        
        guard let entries = ledgerResponse.entries else {
            BlendLogger.warning("No entries returned from getLedgerEntries", category: BlendLogger.network)
            return [:]
        }
        
        // Process entries into the expected format
        var result: [String: Any] = [:]
        
        for entry in entries {
            if let key = entry["key"], let xdr = entry["xdr"] {
                // Parse XDR into a usable format
                // Note: Implementation depends on what format is expected by callers
                result[key] = xdr
            }
        }
        
        BlendLogger.debug("Got \(result.count) ledger entries", category: BlendLogger.network)
        return result
    }
    
    // MARK: - Connection Management
    
    public func checkConnectivity() async -> ConnectionState {
        BlendLogger.debug("Checking connectivity", category: BlendLogger.network)
        
        do {
            // Try a simple RPC call
            let request = try createSorobanRPCRequest(method: "getHealth", params: EmptyParams())
            let _ = try await performRequest(request)
            
            connectionState = .connected
            connectionStateSubject.send(.connected)
            return .connected
        } catch {
            BlendLogger.warning("Connectivity check failed: \(error.localizedDescription)", category: BlendLogger.network)
            connectionState = .disconnected
            connectionStateSubject.send(.disconnected)
            return .disconnected
        }
    }
    
    // MARK: - Request Interceptors
    
    public func addRequestInterceptor(_ interceptor: @escaping (URLRequest) -> URLRequest) {
        requestInterceptors.append(interceptor)
    }
    
    public func addResponseInterceptor(_ interceptor: @escaping (Data, URLResponse) -> Void) {
        responseInterceptors.append(interceptor)
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultInterceptors() {
        // Request logging interceptor
        addRequestInterceptor { request in
            BlendLogger.debug("→ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")", category: BlendLogger.network)
            if let body = request.httpBody {
                BlendLogger.debug("→ Body: \(body.count) bytes", category: BlendLogger.network)
            }
            return request
        }
        
        // Response logging interceptor
        addResponseInterceptor { data, response in
            if let httpResponse = response as? HTTPURLResponse {
                BlendLogger.debug("← \(httpResponse.statusCode) \(data.count) bytes", category: BlendLogger.network)
            }
        }
    }
    
    private func createSorobanRPCRequest<T: Encodable>(method: String, params: T) throws -> URLRequest {
        let rpcRequest = SorobanRPCRequest(
            jsonrpc: "2.0",
            id: UUID().uuidString,
            method: method,
            params: params
        )
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BlendProtocol/2.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(rpcRequest)
        
        // Apply request interceptors
        return requestInterceptors.reduce(request) { $1($0) }
    }
    
    private func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            
            // Apply response interceptors
            responseInterceptors.forEach { $0(data, response) }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BlendError.network(.serverError)
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw BlendError.network(.serverError)
            }
            
            return data
        } catch {
            BlendLogger.error("Network request failed", error: error, category: BlendLogger.network)
            throw BlendError.network(.connectionFailed)
        }
    }
    
    private func performSorobanRPC<T: Encodable>(_ method: String, params: T) async throws -> Data {
        let request = try createSorobanRPCRequest(method: method, params: params)
        return try await performRequest(request)
    }
    
    private func createSimulationTransaction(_ operation: stellarsdk.Operation) throws -> Transaction {
        // Create a dummy transaction for simulation
        let dummyAccount = try Account(
            accountId: "GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWHF",
            sequenceNumber: 0
        )
        
        return try Transaction(
            sourceAccount: dummyAccount,
            operations: [operation],
            memo: Memo.none,
            timeBounds: nil,
            maxOperationFee: 100_000
        )
    }
}

// MARK: - Supporting Types

public enum ConnectionState {
    case connected
    case disconnected
    case connecting
}

struct SorobanRPCRequest<T: Encodable>: Encodable {
    let jsonrpc: String
    let id: String
    let method: String
    let params: T
}

struct EmptyParams: Encodable {}

struct SimulateTransactionRequest: Encodable {
    let transaction: String // Base64 encoded XDR transaction
    let resourceConfig: ResourceConfig
    
    init(transaction: Transaction, resourceConfig: ResourceConfig = ResourceConfig()) throws {
        // Encode transaction to XDR and then to base64
        // encodedEnvelope() already returns a base64 encoded string
        self.transaction = try transaction.encodedEnvelope()
        self.resourceConfig = resourceConfig
    }
}

struct ResourceConfig: Encodable {
    let instructionLeeway: UInt32 = 3000000
}

struct SimulateTransactionResponse: Decodable {
    let error: String?
    let results: [String]? // XDR strings that need to be decoded to SCValXDR
    let cost: Int64?
    let footprint: String?
}

public struct SimulationResult {
    public let result: SCValXDR?
    public let cost: Int64
    public let footprint: String?
}

// MARK: - NetworkServiceProtocol Extension

extension NetworkService {
    public func simulateOperation(_ operation: Data) async throws -> Data {
        // Legacy method for compatibility
        BlendLogger.warning("Using legacy simulateOperation method", category: BlendLogger.network)
        return operation
    }
    
    public func getLedgerEntries(_ keys: [String]) async throws -> [Data] {
        BlendLogger.debug("Fetching \(keys.count) ledger entries", category: BlendLogger.network)
        
        let request = GetLedgerEntriesRequest(keys: keys)
        let response = try await performSorobanRPC("getLedgerEntries", params: request)
        
        let ledgerResponse = try JSONDecoder().decode(GetLedgerEntriesResponse.self, from: response)
        return ledgerResponse.entries?.map { Data(base64Encoded: $0.xdr) ?? Data() } ?? []
    }
}

struct GetLedgerEntriesRequest: Encodable {
    let keys: [String]
}

struct GetLedgerEntriesResponse: Decodable {
    let entries: [LedgerEntry]?
    
    struct LedgerEntry: Decodable {
        let xdr: String
    }
} 

