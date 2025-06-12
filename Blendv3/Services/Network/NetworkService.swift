//
//  NetworkService.swift
//  Blendv3
//
//  Network service responsible for all networking operations including smart contract calls
//

import Foundation
import Combine

// MARK: - Network Error Types
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError(Error)
    case contractError(String)
    case unauthorized
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .contractError(let message):
            return "Smart contract error: \(message)"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

// MARK: - Key Provider Protocol
protocol KeyProviderProtocol {
    var apiKey: String { get }
    var privateKey: String? { get }
    var contractAddress: String? { get }
}

// MARK: - Network Service Protocol
protocol NetworkServiceProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, NetworkError>
    func callSmartContract(_ method: SmartContractMethod) -> AnyPublisher<Data, NetworkError>
    func simulateContract(_ method: SmartContractMethod) -> AnyPublisher<SimulationResult, NetworkError>
}

// MARK: - Endpoint Configuration
struct Endpoint {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]?
    let body: Data?
    let queryItems: [URLQueryItem]?
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
}

// MARK: - Smart Contract Types
struct SmartContractMethod {
    let name: String
    let parameters: [String: Any]
    let gasLimit: Int?
    let value: String?
}

struct SimulationResult: Decodable {
    let success: Bool
    let gasUsed: Int
    let output: String?
    let error: String?
}

// MARK: - Network Service Implementation
final class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let keyProvider: KeyProviderProtocol
    private let baseURL: String
    private let decoder = JSONDecoder()
    
    init(
        session: URLSession = .shared,
        keyProvider: KeyProviderProtocol,
        baseURL: String
    ) {
        self.session = session
        self.keyProvider = keyProvider
        self.baseURL = baseURL
        
        // Configure decoder
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Generic Request Method
    func request<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, NetworkError> {
        guard let url = buildURL(for: endpoint) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        
        // Add default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(keyProvider.apiKey)", forHTTPHeaderField: "Authorization")
        
        // Add custom headers
        endpoint.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw NetworkError.unauthorized
                case 400...499:
                    throw NetworkError.serverError(httpResponse.statusCode)
                case 500...599:
                    throw NetworkError.serverError(httpResponse.statusCode)
                default:
                    throw NetworkError.invalidResponse
                }
            }
            .decode(type: T.self, decoder: decoder)
            .mapError { error in
                if let networkError = error as? NetworkError {
                    return networkError
                } else if error is DecodingError {
                    return NetworkError.decodingError(error)
                } else {
                    return NetworkError.invalidResponse
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Smart Contract Call
    func callSmartContract(_ method: SmartContractMethod) -> AnyPublisher<Data, NetworkError> {
        guard let contractAddress = keyProvider.contractAddress else {
            return Fail(error: NetworkError.contractError("Missing contract address"))
                .eraseToAnyPublisher()
        }
        
        let contractPayload = buildContractPayload(method: method, address: contractAddress)
        
        let endpoint = Endpoint(
            path: "/api/v1/contract/call",
            method: .post,
            headers: ["X-Contract-Address": contractAddress],
            body: contractPayload,
            queryItems: nil
        )
        
        return performContractRequest(endpoint)
    }
    
    // MARK: - Contract Simulation
    func simulateContract(_ method: SmartContractMethod) -> AnyPublisher<SimulationResult, NetworkError> {
        guard let contractAddress = keyProvider.contractAddress else {
            return Fail(error: NetworkError.contractError("Missing contract address"))
                .eraseToAnyPublisher()
        }
        
        let simulationPayload = buildSimulationPayload(method: method, address: contractAddress)
        
        let endpoint = Endpoint(
            path: "/api/v1/contract/simulate",
            method: .post,
            headers: ["X-Contract-Address": contractAddress],
            body: simulationPayload,
            queryItems: nil
        )
        
        return request(endpoint)
    }
    
    // MARK: - Private Helper Methods
    private func buildURL(for endpoint: Endpoint) -> URL? {
        guard var components = URLComponents(string: baseURL + endpoint.path) else {
            return nil
        }
        
        components.queryItems = endpoint.queryItems
        return components.url
    }
    
    private func buildContractPayload(method: SmartContractMethod, address: String) -> Data? {
        var payload: [String: Any] = [
            "method": method.name,
            "params": method.parameters,
            "address": address
        ]
        
        if let gasLimit = method.gasLimit {
            payload["gasLimit"] = gasLimit
        }
        
        if let value = method.value {
            payload["value"] = value
        }
        
        if let privateKey = keyProvider.privateKey {
            payload["privateKey"] = privateKey
        }
        
        return try? JSONSerialization.data(withJSONObject: payload)
    }
    
    private func buildSimulationPayload(method: SmartContractMethod, address: String) -> Data? {
        let payload: [String: Any] = [
            "method": method.name,
            "params": method.parameters,
            "address": address,
            "simulate": true
        ]
        
        return try? JSONSerialization.data(withJSONObject: payload)
    }
    
    private func performContractRequest(_ endpoint: Endpoint) -> AnyPublisher<Data, NetworkError> {
        guard let url = buildURL(for: endpoint) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(keyProvider.apiKey)", forHTTPHeaderField: "Authorization")
        
        endpoint.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NetworkError.invalidResponse
                }
                return data
            }
            .mapError { error in
                if let networkError = error as? NetworkError {
                    return networkError
                } else {
                    return NetworkError.invalidResponse
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}