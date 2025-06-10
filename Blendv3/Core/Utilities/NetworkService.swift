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

/// Enhanced network service for Stellar/Soroban contract interactions using SorobanClient.
/// Provides methods for account retrieval, contract invocation, simulation, ledger queries,
/// and network connection management.
@MainActor
public final class NetworkService {
    
    // MARK: - Initialization & Configuration
    
    private let configuration: ConfigurationServiceProtocol
    private let session: URLSession
    private let baseURL: URL
    
    private let sorobanClientCache = SorobanClientCacheActor()
    
    private var connectionState: ConnectionState = .disconnected
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    
    private var requestInterceptors: [(URLRequest) -> URLRequest] = []
    private var responseInterceptors: [(Data, URLResponse) -> Void] = []
    
    /// Initializes the NetworkService with configuration.
    /// Configures URLSession with connection pooling and sets up interceptors.
    public init(configuration: ConfigurationServiceProtocol) {
        self.configuration = configuration
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.getTimeoutConfiguration().networkTimeout
        config.timeoutIntervalForResource = configuration.getTimeoutConfiguration().networkTimeout * 2
        config.httpMaximumConnectionsPerHost = 6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: config)
        self.baseURL = URL(string: configuration.rpcEndpoint)!
        
        setupDefaultInterceptors()
        BlendLogger.info("NetworkService initialized with endpoint: \(configuration.rpcEndpoint)", category: BlendLogger.network)
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
        BlendLogger.debug("Fetching account: \(accountId)", category: BlendLogger.network)
        
        let sdk = StellarSDK(withHorizonUrl: configuration.rpcEndpoint)
        
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
    ///   - sourceKeyPair: Source account keypair for signing.
    ///   - force: Whether to force execution for read-only calls.
    /// - Returns: Result of the contract invocation as SCValXDR.
    /// - Throws: `BlendError.transaction(.failed)` or `BlendError.validation(.invalidResponse)` on failure.
    public func invokeContractFunction(
        contractId: String,
        functionName: String,
        args: [SCValXDR],
        sourceKeyPair: KeyPair,
        force: Bool = false
    ) async throws -> SCValXDR {
        BlendLogger.debug("Invoking contract function: \(functionName) on \(contractId)", category: BlendLogger.network)
        
        do {
            let client = try await getSorobanClient(contractId: contractId, sourceKeyPair: sourceKeyPair)
            let result = try await client.invokeMethod(name: functionName, args: args, force: force)
            
            BlendLogger.debug("Contract function invocation successful: \(functionName)", category: BlendLogger.network)
            return result
            
        } catch let error as SorobanClientError {
            BlendLogger.error("Contract function invocation failed: \(functionName)", error: error, category: BlendLogger.network)
            throw BlendError.transaction(.failed)
        } catch {
            BlendLogger.error("Contract function invocation failed with unexpected error: \(functionName)", error: error, category: BlendLogger.network)
            throw BlendError.validation(.invalidResponse)
        }
    }
    
    /// Legacy method for compatibility - redirects to new SorobanClient implementation.
    /// - Warning: Deprecated. Provide `sourceKeyPair` explicitly using the other overload.
    @available(*, deprecated, message: "Use invokeContractFunction with explicit sourceKeyPair instead")
    public func invokeContractFunction(
        contractId: String,
        functionName: String,
        args: [SCValXDR]
    ) async throws -> SCValXDR {
        let tempKeyPair = try KeyPair.generateRandomKeyPair()
        BlendLogger.warning("Using temporary keypair for contract invocation - this should be provided by caller", category: BlendLogger.network)
        
        return try await invokeContractFunction(
            contractId: contractId,
            functionName: functionName,
            args: args,
            sourceKeyPair: tempKeyPair,
            force: false
        )
    }
    
    /// Simulates a contract function call using SorobanClient - generic, type-safe, and extensible.
    /// - Parameters:
    ///   - contractId: Contract ID to simulate.
    ///   - functionName: Function name to simulate.
    ///   - args: Function arguments with generic type.
    ///   - sourceKeyPair: Source account keypair.
    /// - Returns: SimulationStatus containing SimulationResult or error.
    public func simulateContractFunction<Args: Sendable, Result: Decodable>(
        contractId: String,
        functionName: String,
        args: Args,
        sourceKeyPair: KeyPair
    ) async -> SimulationStatus<Result> {
        BlendLogger.debug("Simulating contract function: \(functionName) on \(contractId)", category: BlendLogger.network)
        do {
            let client = try await getSorobanClient(contractId: contractId, sourceKeyPair: sourceKeyPair)
            let tx = try await client.buildInvokeMethodTx(name: functionName, args: args as? [SCValXDR] ?? [])
            guard let simulationData = try? tx.getSimulationData() else {
                return .failure(.invalidResponse("No simulation data returned"))
            }
            // SCValXDR may be Data, or needs to be converted to Data for decoding
            let returnedValue = simulationData.returnedValue
            // If SCValXDR is Data, use directly
            if let data = returnedValue as? Data {
                let decodedResult: Result = try JSONDecoder().decode(Result.self, from: data)
                return .success(SimulationResult(result: decodedResult))
            }
            // If SCValXDR has a method or computed property to get Data, use it here
            if let dataConvertible = returnedValue as? CustomStringConvertible, let data = (dataConvertible.description).data(using: .utf8) {
                let decodedResult: Result = try JSONDecoder().decode(Result.self, from: data)
                return .success(SimulationResult(result: decodedResult))
            }
            // Otherwise, fail with error
            return .failure(.invalidResponse("Could not convert SCValXDR to Data for decoding"))
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
        BlendLogger.debug("Simulating contract function: \(functionName) on \(contractId) with args count: \(args.count)", category: BlendLogger.network)
        
        do {
            let client = try await getSorobanClient(contractId: contractId, sourceKeyPair: sourceKeyPair)
            let tx = try await client.buildInvokeMethodTx(name: functionName, args: args)
            let simulationData = try tx.getSimulationData()
            
            // Cost extraction not available in SimulateHostFunctionResult
            BlendLogger.debug("Simulation cost property not available in SimulateHostFunctionResult", category: BlendLogger.network)
            
            // Footprint is no longer available in SimulateHostFunctionResult
            // Removed extraction of footprint from simulation data
            
            BlendLogger.debug("Simulation result for function \(functionName): \(String(describing: simulationData.returnedValue))", category: BlendLogger.network)
            
            return SimulationResult(
                result: simulationData.returnedValue,
                cost: nil,
                footprint: nil
            )
            
        } catch let error as SorobanClientError {
            BlendLogger.error("Contract simulation failed with SorobanClientError: \(error.localizedDescription) | Function: \(functionName), Contract: \(contractId), Args count: \(args.count)", category: BlendLogger.network)
            throw BlendError.transaction(.failed)
        } catch let error as BlendError {
            BlendLogger.error("Contract simulation failed with BlendError: \(error) | Function: \(functionName), Contract: \(contractId), Args count: \(args.count)", category: BlendLogger.network)
            throw error
        } catch let error as DecodingError {
            BlendLogger.error("Contract simulation failed with DecodingError: \(error.localizedDescription) | Function: \(functionName), Contract: \(contractId), Args count: \(args.count)", category: BlendLogger.network)
            throw BlendError.validation(.invalidResponse)
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
        BlendLogger.debug("Getting ledger entries for \(keys.count) keys", category: BlendLogger.network)
        
        struct GetLedgerEntriesParams: Encodable {
            let keys: [String]
        }
        
        let params = GetLedgerEntriesParams(keys: keys)
        let response = try await performDirectRPC("getLedgerEntries", params: params)
        
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
        
        var result = [String: Any]()
        for entry in entries {
            if let key = entry["key"], let xdr = entry["xdr"] {
                result[key] = xdr
            }
        }
        
        BlendLogger.debug("Got \(result.count) ledger entries", category: BlendLogger.network)
        return result
    }
    
    // MARK: - Connection Management
    
    /// Checks network connectivity by performing a health check RPC call.
    /// - Returns: Current `ConnectionState`.
    public func checkConnectivity() async -> ConnectionState {
        BlendLogger.debug("Checking connectivity", category: BlendLogger.network)
        
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
    
    /// Sets up default logging interceptors for requests and responses.
    private func setupDefaultInterceptors() {
        addRequestInterceptor { request in
            BlendLogger.debug("→ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")", category: BlendLogger.network)
            if let body = request.httpBody {
                BlendLogger.debug("→ Body: \(body.count) bytes", category: BlendLogger.network)
            }
            return request
        }
        
        addResponseInterceptor { data, response in
            if let httpResponse = response as? HTTPURLResponse {
                BlendLogger.debug("← \(httpResponse.statusCode) \(data.count) bytes", category: BlendLogger.network)
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
            network: determineNetwork(),
            rpcUrl: configuration.rpcEndpoint,
            enableServerLogging: false
        )
        
        let client = try await SorobanClient.forClientOptions(options: clientOptions)
        await sorobanClientCache.store(client: client, for: cacheKey)
        
        return client
    }
    
    /// Determines the Stellar network based on the RPC endpoint URL.
    /// - Returns: Corresponding `Network` enum value.
    private func determineNetwork() -> Network {
        if configuration.rpcEndpoint.contains("testnet") {
            return Network.testnet
        } else if configuration.rpcEndpoint.contains("futurenet") {
            return Network.futurenet
        } else {
            return Network.public
        }
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
        BlendLogger.debug("Fetching \(keys.count) legacy ledger entries", category: BlendLogger.network)
        
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

