//
//  NetworkService.swift
//  Blendv3
//
//  Created by Chris Karani on 22/05/2025.
//

import Foundation
import Combine

// MARK: - Network Errors
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case contractError(String)
    case simulationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .contractError(let message):
            return "Contract error: \(message)"
        case .simulationFailed(let message):
            return "Simulation failed: \(message)"
        }
    }
}

// MARK: - Network Request Protocol
protocol NetworkRequestProtocol {
    var url: URL { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var body: Data? { get }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - Contract Operation Types
enum ContractOperation {
    case invoke(contractId: String, method: String, parameters: [Any])
    case simulate(contractId: String, method: String, parameters: [Any])
    case query(contractId: String, method: String, parameters: [Any])
}

// MARK: - Blockchain Network Configuration
struct NetworkConfiguration {
    let rpcEndpoint: String
    let networkPassPhrase: String
    let timeout: TimeInterval
    
    static let mainnet = NetworkConfiguration(
        rpcEndpoint: "https://horizon.stellar.org",
        networkPassPhrase: "Public Global Stellar Network ; September 2015",
        timeout: 30.0
    )
    
    static let testnet = NetworkConfiguration(
        rpcEndpoint: "https://horizon-testnet.stellar.org",
        networkPassPhrase: "Test SDF Network ; September 2015",
        timeout: 30.0
    )
}

// MARK: - Network Service Protocol
protocol NetworkServiceProtocol {
    func performRequest<T: Codable>(_ request: NetworkRequestProtocol, responseType: T.Type) async throws -> T
    func performContractOperation(_ operation: ContractOperation) async throws -> Data
    func simulateContract(contractId: String, method: String, parameters: [Any]) async throws -> Data
    func invokeContract(contractId: String, method: String, parameters: [Any]) async throws -> Data
    func queryContract(contractId: String, method: String, parameters: [Any]) async throws -> Data
}

// MARK: - Network Service Implementation
@MainActor
final class NetworkService: NetworkServiceProtocol, ObservableObject {
    
    // MARK: - Properties
    private let session: URLSession
    private let configuration: NetworkConfiguration
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(configuration: NetworkConfiguration = .testnet) {
        self.configuration = configuration
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout
        self.session = URLSession(configuration: sessionConfig)
    }
    
    // MARK: - Generic Network Request
    func performRequest<T: Codable>(_ request: NetworkRequestProtocol, responseType: T.Type) async throws -> T {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.allHTTPHeaderFields = request.headers
        urlRequest.httpBody = request.body
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.networkError(NSError(domain: "Invalid response", code: 0))
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.networkError(NSError(domain: "HTTP Error", code: httpResponse.statusCode))
            }
            
            guard !data.isEmpty else {
                throw NetworkError.noData
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                return try decoder.decode(responseType, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
            
        } catch {
            if error is NetworkError {
                throw error
            } else {
                throw NetworkError.networkError(error)
            }
        }
    }
    
    // MARK: - Contract Operations
    func performContractOperation(_ operation: ContractOperation) async throws -> Data {
        switch operation {
        case .invoke(let contractId, let method, let parameters):
            return try await invokeContract(contractId: contractId, method: method, parameters: parameters)
        case .simulate(let contractId, let method, let parameters):
            return try await simulateContract(contractId: contractId, method: method, parameters: parameters)
        case .query(let contractId, let method, let parameters):
            return try await queryContract(contractId: contractId, method: method, parameters: parameters)
        }
    }
    
    func simulateContract(contractId: String, method: String, parameters: [Any]) async throws -> Data {
        let simulationRequest = buildContractRequest(
            contractId: contractId,
            method: method,
            parameters: parameters,
            isSimulation: true
        )
        
        do {
            let (data, response) = try await session.data(for: simulationRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.contractError("Invalid simulation response")
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.simulationFailed("Simulation failed with status: \(httpResponse.statusCode)")
            }
            
            return data
        } catch {
            throw NetworkError.simulationFailed("Simulation error: \(error.localizedDescription)")
        }
    }
    
    func invokeContract(contractId: String, method: String, parameters: [Any]) async throws -> Data {
        let invokeRequest = buildContractRequest(
            contractId: contractId,
            method: method,
            parameters: parameters,
            isSimulation: false
        )
        
        do {
            let (data, response) = try await session.data(for: invokeRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.contractError("Invalid invocation response")
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.contractError("Contract invocation failed with status: \(httpResponse.statusCode)")
            }
            
            return data
        } catch {
            throw NetworkError.contractError("Invocation error: \(error.localizedDescription)")
        }
    }
    
    func queryContract(contractId: String, method: String, parameters: [Any]) async throws -> Data {
        let queryRequest = buildContractRequest(
            contractId: contractId,
            method: method,
            parameters: parameters,
            isSimulation: true
        )
        
        do {
            let (data, response) = try await session.data(for: queryRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.contractError("Invalid query response")
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.contractError("Contract query failed with status: \(httpResponse.statusCode)")
            }
            
            return data
        } catch {
            throw NetworkError.contractError("Query error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helper Methods
    private func buildContractRequest(
        contractId: String,
        method: String,
        parameters: [Any],
        isSimulation: Bool
    ) -> URLRequest {
        let endpoint = isSimulation ? "simulate_transaction" : "submit_transaction"
        let url = URL(string: "\(configuration.rpcEndpoint)/\(endpoint)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "contract_id": contractId,
            "method": method,
            "parameters": parameters,
            "network_passphrase": configuration.networkPassPhrase
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        return request
    }
}

// MARK: - Specific Network Request Implementations
struct GenericNetworkRequest: NetworkRequestProtocol {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]?
    let body: Data?
    
    init(url: URL, method: HTTPMethod = .GET, headers: [String: String]? = nil, body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}