//
//  NetworkService.swift
//  Blendv3
//
//  Enhanced network service with SorobanClient support
//

import Foundation
import Combine
import stellarsdk

/// Enum representing the result of a simulation: success or failure.
public enum SimulationStatus<Success> {
    case success(SimulationResult<Success>)
    case failure(NetworkSimulationError)
}

/// Enum representing detailed simulation/network errors.
public enum NetworkSimulationError: Error, Sendable {
    case transactionFailed(String)
    case connectionFailed(String)
    case invalidResponse(String)
    case unknown(String)
}

/// Configuration for NetworkService operations
public struct NetworkServiceConfig: Sendable {
    public let networkType: BlendConstants.NetworkType
    public let timeoutConfiguration: TimeoutConfiguration
    public let retryConfiguration: RetryConfiguration
    
    public init(
        networkType: BlendConstants.NetworkType = .testnet,
        timeoutConfiguration: TimeoutConfiguration = TimeoutConfiguration(),
        retryConfiguration: RetryConfiguration = RetryConfiguration()
    ) {
        self.networkType = networkType
        self.timeoutConfiguration = timeoutConfiguration
        self.retryConfiguration = retryConfiguration
    }
    
    /// Get the appropriate RPC endpoint for the network type
    public var rpcEndpoint: String {
        return BlendConstants.RPC.url(for: networkType)
    }
}

/// Enhanced network service for Stellar/Soroban contract interactions using SorobanClient.
/// Provides methods for account retrieval, contract invocation, simulation, ledger queries,
/// and network connection management.
@MainActor
public final class NetworkService: NetworkServiceProtocol {
    
    // MARK: - Initialization & Configuration
    
    private let config: NetworkServiceConfig
    private let session: URLSession
    private let baseURL: URL
    
    private let sorobanClientCache = SorobanClientCacheActor()
    private let sorobanServer: SorobanServer
    private let transactionSimulator: SorobanTransactionSimulator
    
    private var connectionState: ConnectionState = .disconnected
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    
    private var requestInterceptors: [(URLRequest) -> URLRequest] = []
    private var responseInterceptors: [(Data, URLResponse) -> Void] = []
    
    private let keyPair: KeyPair
    
    /// Initializes the NetworkService with configuration.
    /// Configures URLSession with connection pooling and sets up interceptors.
    public init(config: NetworkServiceConfig = NetworkServiceConfig(), keyPair: KeyPair) {
        self.config = config
        self.keyPair = keyPair
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeoutConfiguration.networkTimeout
        sessionConfig.timeoutIntervalForResource = config.timeoutConfiguration.networkTimeout * 2
        sessionConfig.httpMaximumConnectionsPerHost = 6
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: sessionConfig)
        self.baseURL = URL(string: config.rpcEndpoint)!
        
        // Initialize Soroban server and transaction simulator
        self.sorobanServer = SorobanServer(endpoint: config.rpcEndpoint)
        let debugLogger = DebugLogger(subsystem: "com.blendv3.network", category: "TransactionSimulator")
        self.transactionSimulator = SorobanTransactionSimulator(debugLogger: debugLogger)
        
        setupDefaultInterceptors()
        BlendLogger.info("NetworkService initialized with endpoint: \(config.rpcEndpoint)", category: BlendLogger.network)
    }
    

    
    // MARK: - NetworkServiceProtocol Conformance
    
    /// Initializes the network service by checking connectivity.
    /// - Throws: `BlendError.network(.connectionFailed)` if connectivity check fails.
    public func initialize() async throws {
        BlendLogger.info("Initializing network service", category: BlendLogger.network)
        
        let testResult = await checkConnectivity()
        guard testResult == .connected else {
            BlendLogger.error("Failed to initialize network service: Connection failed", category: BlendLogger.network)
            throw BlendError.network(.connectionFailed)
        }
        
        connectionState = .connected
        connectionStateSubject.send(.connected)
        BlendLogger.info("Network service initialized successfully", category: BlendLogger.network)
    }
    
    /// Fetches Stellar account details by account ID.
    /// - Parameter accountId: Stellar account ID to fetch.
    /// - Returns: An `Account` object representing the account.
    /// - Throws: `BlendError.network(.serverError)` on failure.
    public func getAccount(accountId: String) async throws -> Account {
        let sdk = StellarSDK(withHorizonUrl: config.rpcEndpoint)
        
        return try await withCheckedThrowingContinuation { continuation in
            sdk.accounts.getAccountDetails(accountId: accountId) { response in
                switch response {
                case .success(let details):
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
    
    /// Invokes a contract function using SorobanClient.
    /// - Parameters:
    ///   - contractId: Contract ID to invoke.
    ///   - functionName: Function name to call.
    ///   - args: Function arguments as SCValXDR array.
    ///   - force: Whether to force execution for read-only calls.
    /// - Returns: Result of the contract invocation as SCValXDR.
    /// - Throws: `BlendError.transaction(.failed)` or `BlendError.validation(.invalidResponse)` on failure.
    public func invokeContractFunction(
        contractId: String,
        functionName: String,
        args: [SCValXDR],
        force: Bool = false
    ) async throws -> SCValXDR {
        do {
            let client = try await getSorobanClient(contractId: contractId, sourceKeyPair: self.keyPair)
            let result = try await client.invokeMethod(name: functionName, args: args, force: force)
            return result
            
        } catch let error as SorobanClientError {
            BlendLogger.error("Contract function invocation failed: \(functionName)", error: error, category: BlendLogger.network)
            throw BlendError.transaction(.failed)
        } catch {
            BlendLogger.error("Contract function invocation failed with unexpected error: \(functionName)", error: error, category: BlendLogger.network)
            throw BlendError.validation(.invalidResponse)
        }
    }
    
    /// Invokes a contract function using a ContractCallParams object.
    /// - Parameters:
    ///   - contractCall: The contract call parameters.
    ///   - force: Whether to force execution for read-only calls.
    /// - Returns: Result of the contract invocation as SCValXDR.
    /// - Throws: `BlendError.transaction(.failed)` or `BlendError.validation(.invalidResponse)` on failure.
    public func invokeContractFunction(
        contractCall: ContractCallParams,
        force: Bool = false
    ) async throws -> SCValXDR {
        return try await withRetry(operation: "invoke_\(contractCall.functionName)") {
            try await self.invokeContractFunctionInternal(contractCall: contractCall, force: force)
        }
    }
    
    /// Internal contract function invocation without retry logic
    private func invokeContractFunctionInternal(
        contractCall: ContractCallParams,
        force: Bool = false
    ) async throws -> SCValXDR {
        do {
            let client = try await getSorobanClient(contractId: contractCall.contractId, sourceKeyPair: self.keyPair)
            let result = try await client.invokeMethod(name: contractCall.functionName, args: contractCall.functionArguments, force: force)
            return result
        } catch let error as SorobanClientError {
            BlendLogger.error("Contract function invocation failed: \(contractCall.functionName)", error: error, category: BlendLogger.network)
            throw BlendError.transaction(.failed)
        } catch {
            BlendLogger.error("Contract function invocation failed with unexpected error: \(contractCall.functionName)", error: error, category: BlendLogger.network)
            throw BlendError.validation(.invalidResponse)
        }
    }
    
//    /// Legacy method for compatibility - redirects to new SorobanClient implementation.
//    /// - Warning: Deprecated. Provide `sourceKeyPair` explicitly using the other overload.
//    @available(*, deprecated, message: "Use invokeContractFunction with explicit sourceKeyPair instead")
//    public func invokeContractFunction(
//        contractId: String,
//        functionName: String,
//        args: [SCValXDR]
//    ) async throws -> SCValXDR {
//        let tempKeyPair = try KeyPair.generateRandomKeyPair()
//        BlendLogger.warning("Using temporary keypair for contract invocation - this should be provided by caller", category: BlendLogger.network)
//        
//        return try await invokeContractFunction(
//            contractId: contractId,
//            functionName: functionName,
//            args: args,
//            force: false
//        )
//    }
    
    /// Simulates a contract function call using SorobanClient - generic, type-safe, and extensible.
    /// - Parameters:
    ///   - contractId: Contract ID to simulate.
    ///   - functionName: Function name to simulate.
    ///   - args: Function arguments with generic type.
    /// - Returns: SimulationStatus containing SimulationResult or error.
    public func simulateContractFunction<Args: Sendable, Result: Decodable>(
        contractId: String,
        functionName: String,
        args: Args
    ) async -> SimulationStatus<Result> {
        do {
            let parsedArgs = args as? [SCValXDR] ?? []
            let contractCallParams: ContractCallParams = ContractCallParams(
                contractId: contractId,
                functionName: functionName,
                functionArguments: parsedArgs
            )
            let result = try await transactionSimulator.simulate(server: sorobanServer, contractCall: contractCallParams)
            let parser = BlendParser()
            
            // Use BlendParser to convert SCValXDR to target type
            let decodedResult: Result = try parser.parseSimulationResult(result, as: Result.self)
            return .success(SimulationResult(result: decodedResult))
            
        } catch let error as BlendParsingError {
            BlendLogger.error("Simulation failed with BlendParsingError: \(error)", category: BlendLogger.network)
            return .failure(.invalidResponse(error.localizedDescription))
        } catch let error as SorobanClientError {
            BlendLogger.error("Simulation failed with SorobanClientError: \(error)", category: BlendLogger.network)
            return .failure(.transactionFailed(error.localizedDescription))
        } catch let error as DecodingError {
            BlendLogger.error("Simulation failed with DecodingError: \(error)", category: BlendLogger.network)
            return .failure(.invalidResponse(error.localizedDescription))
        } catch {
            BlendLogger.error("Simulation failed with unexpected error: \(error)", category: BlendLogger.network)
            return .failure(.unknown(error.localizedDescription))
        }
    }
    
    /// Simulates a contract function call using SorobanClient with explicit ContractCallParams.
    /// - Parameters:
    ///   - contractCall: The contract call parameters.
    /// - Returns: SimulationStatus containing SimulationResult or error.
    public func simulateContractFunction<Result: Decodable>(
        contractCall: ContractCallParams
    ) async -> SimulationStatus<Result> {
        do {
            return try await withRetry(operation: "simulate_\(contractCall.functionName)") {
                return await self.simulateContractFunctionInternal(contractCall: contractCall)
            }
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }
    
    /// Internal contract function simulation without retry logic
    private func simulateContractFunctionInternal<Result: Decodable>(
        contractCall: ContractCallParams
    ) async -> SimulationStatus<Result> {
        do {
            let result = try await transactionSimulator.simulate(server: sorobanServer, contractCall: contractCall)
            let parser = BlendParser()
            // Use BlendParser to convert SCValXDR to target type
            let decodedResult: Result = try parser.parseSimulationResult(result, as: Result.self)
            return .success(SimulationResult(result: decodedResult))
        } catch let error as BlendParsingError {
            BlendLogger.error("Simulation failed with BlendParsingError: \(error)", category: BlendLogger.network)
            return .failure(.invalidResponse(error.localizedDescription))
        } catch let error as SorobanClientError {
            BlendLogger.error("Simulation failed with SorobanClientError: \(error)", category: BlendLogger.network)
            return .failure(.transactionFailed(error.localizedDescription))
        } catch let error as DecodingError {
            BlendLogger.error("Simulation failed with DecodingError: \(error)", category: BlendLogger.network)
            return .failure(.invalidResponse(error.localizedDescription))
        } catch {
            BlendLogger.error("Simulation failed with unexpected error: \(error)", category: BlendLogger.network)
            return .failure(.unknown(error.localizedDescription))
        }
    }
    
    /// Legacy method to simulate an operation.
    /// - Warning: Deprecated. Use `simulateContractFunction` instead.
    @available(*, deprecated, message: "Use simulateContractFunction instead")
    public func simulateContractFunction(
        contractId: String,
        functionName: String,
        args: [SCValXDR],
        sourceKeyPair: KeyPair
    ) async throws -> SimulationResult<SCValXDR> {
        do {
            // Create contract call parameters for the simulator
            let contractCall = ContractCallParams(
                contractId: contractId,
                functionName: functionName,
                functionArguments: args
            )
            
            // Use SorobanTransactionSimulator for simulation
            let result = try await transactionSimulator.simulate(
                server: sorobanServer,
                contractCall: contractCall
            )
            
            return SimulationResult(
                result: result,
                cost: nil,
                footprint: nil
            )
            
        } catch let error as OracleError {
            BlendLogger.error("Contract simulation failed with OracleError: \(error.localizedDescription) | Function: \(functionName), Contract: \(contractId), Args count: \(args.count)", category: BlendLogger.network)
            // Convert OracleError to BlendError for interface consistency
            throw BlendError.transaction(.failed)
        } catch let error as BlendError {
            BlendLogger.error("Contract simulation failed with BlendError: \(error) | Function: \(functionName), Contract: \(contractId), Args count: \(args.count)", category: BlendLogger.network)
            throw error
        } catch {
            BlendLogger.error("Contract simulation failed with unexpected error: \(error.localizedDescription) | Function: \(functionName), Contract: \(contractId), Args count: \(args.count)", category: BlendLogger.network)
            throw BlendError.validation(.invalidResponse)
        }
    }
    
    /// Legacy method to simulate an operation.
    /// - Warning: Deprecated. Use `simulateContractFunction` instead.
    @available(*, deprecated, message: "Use simulateContractFunction instead")
    public func simulateOperation(_ operation: stellarsdk.Operation) async throws -> SimulationResult<SCValXDR> {
        BlendLogger.warning("Legacy simulateOperation method called - consider using simulateContractFunction instead", category: BlendLogger.network)
        
        return SimulationResult(
            result: SCValXDR.void,
            cost: 0,
            footprint: nil
        )
    }
    
    /// Retrieves ledger entries by keys.
    /// - Parameter keys: Ledger entry keys.
    /// - Returns: Dictionary mapping keys to corresponding XDR strings.
    /// - Throws: `BlendError.network(.serverError)` on RPC failure.
    public func getLedgerEntries(keys: [String]) async throws -> [String: Any] {
        struct GetLedgerEntriesParams: Encodable {
            let keys: [String]
        }
        
        struct SorobanLedgerEntry: Decodable {
            let key: String
            let xdr: String
            let lastModifiedLedgerSeq: Int
            let liveUntilLedgerSeq: Int?
        }
        
        struct GetLedgerEntriesResponse: Decodable {
            let entries: [SorobanLedgerEntry]
            let latestLedger: Int
        }
        
        let params = GetLedgerEntriesParams(keys: keys)
        let response = try await performDirectRPC("getLedgerEntries", params: params)
        
        // Parse JSON-RPC response wrapper first
        struct JSONRPCResponse: Decodable {
            let result: GetLedgerEntriesResponse
        }
        
        let rpcResponse = try JSONDecoder().decode(JSONRPCResponse.self, from: response)
        let ledgerResponse = rpcResponse.result
        
        var result = [String: Any]()
        for entry in ledgerResponse.entries {
            result[entry.key] = entry.xdr
        }
        
        return result
    }
    
    // MARK: - Connection Management
    
    /// Checks network connectivity by performing a health check RPC call.
    /// - Returns: Current `ConnectionState`.
    public func checkConnectivity() async -> ConnectionState {
        do {
            let request = try createDirectRPCRequest(method: "getHealth", params: EmptyParams())
            _ = try await performRequest(request)
            
            connectionState = .connected
            connectionStateSubject.send(.connected)
            return .connected
        } catch {
            BlendLogger.warning("Connectivity check failed: \(error)", category: BlendLogger.network)
            connectionState = .disconnected
            connectionStateSubject.send(.disconnected)
            return .disconnected
        }
    }
    
    // MARK: - Request & Response Interceptors
    
    /// Adds a request interceptor to modify URLRequests before sending.
    /// - Parameter interceptor: Closure that takes and returns a URLRequest.
    public func addRequestInterceptor(_ interceptor: @escaping (URLRequest) -> URLRequest) {
        requestInterceptors.append(interceptor)
    }
    
    /// Adds a response interceptor to process response data and URLResponse.
    /// - Parameter interceptor: Closure receiving Data and URLResponse.
    public func addResponseInterceptor(_ interceptor: @escaping (Data, URLResponse) -> Void) {
        responseInterceptors.append(interceptor)
    }
    
    // MARK: - Private Helper Methods
    
    /// Execute an operation with retry mechanism using exponential backoff and jitter
    /// - Parameters:
    ///   - operation: Name of operation for logging
    ///   - task: Async task to execute
    /// - Returns: Result of the operation
    /// - Throws: Last error encountered after all retries are exhausted
    private func withRetry<T>(
        operation: String,
        task: () async throws -> T
    ) async throws -> T {
        let retryConfig = config.retryConfiguration
        let maxAttempts = retryConfig.maxRetries
        let baseDelay = retryConfig.baseDelay
        let maxDelay = retryConfig.maxDelay
        let exponentialBase = retryConfig.exponentialBase
        let jitterRange = retryConfig.jitterRange
        
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                let result = try await task()
                if attempt > 1 {
                    BlendLogger.info("Operation '\(operation)' succeeded on attempt \(attempt)", category: BlendLogger.network)
                }
                return result
            } catch {
                lastError = error
                BlendLogger.warning("Attempt \(attempt)/\(maxAttempts) failed for '\(operation)': \(error.localizedDescription)", category: BlendLogger.network)
                
                // Don't delay on the last attempt
                if attempt < maxAttempts {
                    // Calculate exponential backoff with jitter
                    let exponentialDelay = min(maxDelay, baseDelay * pow(exponentialBase, Double(attempt - 1)))
                    let jitter = Double.random(in: jitterRange)
                    let delay = exponentialDelay * (1.0 + jitter)
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        BlendLogger.error("Operation '\(operation)' failed after \(maxAttempts) attempts", error: lastError, category: BlendLogger.network)
        throw lastError ?? BlendError.network(.serverError)
    }
    
    /// Sets up default logging interceptors for requests and responses.
    private func setupDefaultInterceptors() {
        addRequestInterceptor { request in
            // Minimal logging for critical requests only
            if let url = request.url?.absoluteString, url.contains("health") {
                BlendLogger.debug("→ Health check: \(request.httpMethod ?? "?")", category: BlendLogger.network)
            }
            return request
        }
        
        addResponseInterceptor { data, response in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                BlendLogger.error("← HTTP Error \(httpResponse.statusCode)", category: BlendLogger.network)
            }
        }
    }
    
    /// Obtains a cached or new SorobanClient for contract interactions, thread-safe.
    /// - Parameters:
    ///   - contractId: Contract ID.
    ///   - sourceKeyPair: Source account keypair.
    /// - Returns: SorobanClient instance.
    /// - Throws: Propagates errors from SorobanClient initialization.
    private func getSorobanClient(contractId: String, sourceKeyPair: KeyPair) async throws -> SorobanClient {
        let cacheKey = "\(contractId)_\(sourceKeyPair.accountId)"
        
        if let cachedClient = await sorobanClientCache.client(for: cacheKey) {
            return cachedClient
        }
        
        let clientOptions = ClientOptions(
            sourceAccountKeyPair: sourceKeyPair,
            contractId: contractId,
            network: config.networkType.stellarNetwork,
            rpcUrl: config.rpcEndpoint,
            enableServerLogging: false
        )
        
        let client = try await SorobanClient.forClientOptions(options: clientOptions)
        await sorobanClientCache.store(client: client, for: cacheKey)
        
        return client
    }
    
    /// Creates a direct RPC URLRequest with JSON-RPC 2.0 format.
    /// - Parameters:
    ///   - method: RPC method name.
    ///   - params: Parameters encoded as Encodable.
    /// - Returns: Configured URLRequest.
    /// - Throws: Encoding errors if parameters fail to encode.
    private func createDirectRPCRequest<T: Encodable>(method: String, params: T) throws -> URLRequest {
        let rpcRequest = DirectRPCRequest(
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
        
        return requestInterceptors.reduce(request) { $1($0) }
    }
    
    /// Performs a network request and applies response interceptors.
    /// - Parameter request: URLRequest to perform.
    /// - Returns: Data from the response.
    /// - Throws: `BlendError.network(.connectionFailed)` or server errors.
    private func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            responseInterceptors.forEach { $0(data, response) }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                BlendLogger.error("Invalid HTTP response", category: BlendLogger.network)
                throw BlendError.network(.serverError)
            }
            guard 200...299 ~= httpResponse.statusCode else {
                BlendLogger.error("HTTP error \(httpResponse.statusCode)", category: BlendLogger.network)
                throw BlendError.network(.serverError)
            }
            
            return data
        } catch {
            BlendLogger.error("Network request failed", error: error, category: BlendLogger.network)
            throw BlendError.network(.connectionFailed)
        }
    }
    
    /// Performs a direct RPC call with given method and parameters.
    /// - Parameters:
    ///   - method: RPC method.
    ///   - params: Parameters.
    /// - Returns: Response data.
    /// - Throws: Propagates errors from request creation or network request.
    private func performDirectRPC<T: Encodable>(_ method: String, params: T) async throws -> Data {
        let request = try createDirectRPCRequest(method: method, params: params)
        return try await performRequest(request)
    }
}

// MARK: - Supporting Types

/// Represents the network connectivity state.
public enum ConnectionState: Sendable {
    case connected
    case disconnected
    case connecting
}

/// Structure for JSON-RPC 2.0 requests.
fileprivate struct DirectRPCRequest<T: Encodable>: Encodable {
    let jsonrpc: String
    let id: String
    let method: String
    let params: T
}

/// Empty params struct for RPC calls without parameters.
fileprivate struct EmptyParams: Encodable {}

/// Simulation result of contract invocation or operation.
public struct SimulationResult<Result: Sendable>: Sendable {
    public let result: Result
    public let cost: Int64?
    public let footprint: String?
    public init(result: Result, cost: Int64? = nil, footprint: String? = nil) {
        self.result = result
        self.cost = cost
        self.footprint = footprint
    }
}

/// Actor to provide thread-safe access to SorobanClient cache.
fileprivate actor SorobanClientCacheActor {
    private var clients: [String: SorobanClient] = [:]
    
    func client(for key: String) -> SorobanClient? {
        clients[key]
    }
    
    func store(client: SorobanClient, for key: String) {
        clients[key] = client
    }
}

// MARK: - NetworkService Protocol Legacy Extensions

extension NetworkService {
    /// Legacy deprecated simulateOperation method working with raw Data.
    /// - Warning: Deprecated. Prefer `simulateContractFunction`.
    @available(*, deprecated, message: "Use simulateContractFunction instead")
    public func simulateOperation(_ operation: Data) async throws -> Data {
        BlendLogger.warning("Using legacy simulateOperation method", category: BlendLogger.network)
        return operation
    }
    
    /// Legacy deprecated method to fetch ledger entries returning [Data].
    /// - Warning: Deprecated. Prefer `getLedgerEntries(keys:) -> [String: Any]`.
    @available(*, deprecated, message: "Use getLedgerEntries(keys:) returning [String: Any]")
    public func getLedgerEntries(_ keys: [String]) async throws -> [Data] {
        let request = GetLedgerEntriesRequest(keys: keys)
        let response = try await performDirectRPC("getLedgerEntries", params: request)
        
        let ledgerResponse = try JSONDecoder().decode(GetLedgerEntriesResponse.self, from: response)
        return ledgerResponse.entries?.compactMap { Data(base64Encoded: $0.xdr) } ?? []
    }
}

/// Legacy GetLedgerEntries request struct for deprecated method.
fileprivate struct GetLedgerEntriesRequest: Encodable {
    let keys: [String]
}

/// Legacy GetLedgerEntries response struct for deprecated method.
fileprivate struct GetLedgerEntriesResponse: Decodable {
    let entries: [LedgerEntry]?
    
    struct LedgerEntry: Decodable {
        let xdr: String
    }
}

