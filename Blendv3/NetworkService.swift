import Foundation

/// Network service implementation for Stellar/Soroban RPC calls
public final class NetworkService: NetworkServiceProtocol {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let baseURL: URL
    private let timeout: TimeInterval = 30.0
    
    // MARK: - Initialization
    
    public init(baseURL: String = "https://soroban-testnet.stellar.org") {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        
        self.session = URLSession(configuration: config)
        self.baseURL = URL(string: baseURL)!
        
        BlendLogger.info("Network service initialized with baseURL: \(baseURL)", category: BlendLogger.network)
    }
    
    // MARK: - NetworkServiceProtocol
    
    public func simulateOperation(_ operation: Data) async throws -> Data {
        BlendLogger.info("Simulating operation", category: BlendLogger.network)
        
        return try await measurePerformance(operation: "simulateOperation", category: BlendLogger.network) {
            let request = try createRPCRequest(method: "simulateTransaction", params: operation)
            return try await performRequest(request)
        }
    }
    
    public func getLedgerEntries(_ keys: [String]) async throws -> [Data] {
        BlendLogger.info("Fetching \(keys.count) ledger entries", category: BlendLogger.network)
        
        return try await measurePerformance(operation: "getLedgerEntries", category: BlendLogger.network) {
            let keysData = try JSONEncoder().encode(keys)
            let request = try createRPCRequest(method: "getLedgerEntries", params: keysData)
            let responseData = try await performRequest(request)
            
            // Parse response and extract ledger entries
            let response = try JSONDecoder().decode(LedgerEntriesResponse.self, from: responseData)
            
            BlendLogger.info("Successfully fetched \(response.entries.count) ledger entries", category: BlendLogger.network)
            return response.entries.map { $0.data }
        }
    }
    
    // MARK: - Private Methods
    
    private func createRPCRequest(method: String, params: Data) throws -> URLRequest {
        BlendLogger.debug("Creating RPC request for method: \(method)", category: BlendLogger.network)
        
        let rpcRequest = RPCRequest(
            jsonrpc: "2.0",
            id: UUID().uuidString,
            method: method,
            params: params
        )
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BlendProtocol/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            request.httpBody = try JSONEncoder().encode(rpcRequest)
            BlendLogger.debug("RPC request created successfully", category: BlendLogger.network)
            return request
        } catch {
            BlendLogger.error("Failed to encode RPC request", error: error, category: BlendLogger.network)
            throw NetworkError.encodingError(error)
        }
    }
    
    private func performRequest(_ request: URLRequest) async throws -> Data {
        BlendLogger.debug("Performing network request to: \(request.url?.absoluteString ?? "unknown")", category: BlendLogger.network)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            BlendLogger.debug("Received HTTP response with status: \(httpResponse.statusCode)", category: BlendLogger.network)
            
            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = "HTTP \(httpResponse.statusCode)"
                BlendLogger.error("HTTP error: \(errorMessage)", category: BlendLogger.network)
                throw NetworkError.httpError(httpResponse.statusCode, errorMessage)
            }
            
            BlendLogger.debug("Request completed successfully, received \(data.count) bytes", category: BlendLogger.network)
            return data
            
        } catch let error as NetworkError {
            throw error
        } catch {
            BlendLogger.error("Network request failed", error: error, category: BlendLogger.network)
            throw NetworkError.networkError(error)
        }
    }
}

// MARK: - Supporting Types

private struct RPCRequest: Codable {
    let jsonrpc: String
    let id: String
    let method: String
    let params: Data
}

private struct LedgerEntriesResponse: Codable {
    let entries: [LedgerEntry]
    
    struct LedgerEntry: Codable {
        let data: Data
    }
}

// MARK: - Network Errors

public enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String)
    case encodingError(Error)
    case decodingError(Error)
    case networkError(Error)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timeout"
        }
    }
} 