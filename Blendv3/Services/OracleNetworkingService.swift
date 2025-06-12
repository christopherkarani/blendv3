//
//  OracleNetworkingService.swift
//  Blendv3
//
//  Created by Chris Karani on 22/05/2025.
//
//  NOTE: This service demonstrates the OLD architecture where networking
//  operations were scattered across multiple services. This should be
//  refactored to use the consolidated NetworkService instead.

import Foundation
import Combine

// MARK: - Oracle Service Errors
enum OracleServiceError: Error, LocalizedError {
    case invalidOracleEndpoint
    case priceDataUnavailable
    case staleData
    case networkFailure(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidOracleEndpoint:
            return "Invalid oracle endpoint"
        case .priceDataUnavailable:
            return "Price data unavailable"
        case .staleData:
            return "Price data is stale"
        case .networkFailure(let error):
            return "Network failure: \(error.localizedDescription)"
        }
    }
}

// MARK: - Oracle Data Models
struct PriceData {
    let asset: String
    let price: Double
    let timestamp: UInt64
    let confidence: Double
}

struct OracleConfig {
    let baseURL: String
    let timeout: TimeInterval
    let maxStaleTime: TimeInterval
    
    static let `default` = OracleConfig(
        baseURL: "https://api.oracle.example.com",
        timeout: 10.0,
        maxStaleTime: 300.0 // 5 minutes
    )
}

// MARK: - Oracle Networking Service (OLD ARCHITECTURE - TO BE REFACTORED)
@MainActor
final class OracleNetworkingService: ObservableObject {
    
    // MARK: - Properties
    private let session: URLSession
    private let config: OracleConfig
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(config: OracleConfig = .default) {
        self.config = config
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeout
        self.session = URLSession(configuration: sessionConfig)
    }
    
    // MARK: - Oracle Network Operations (SHOULD BE MOVED TO NetworkService)
    
    /// This method demonstrates duplicate networking code that should be consolidated
    func fetchPriceData(for asset: String) async throws -> PriceData {
        guard let url = URL(string: "\(config.baseURL)/prices/\(asset)") else {
            throw OracleServiceError.invalidOracleEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            // This is duplicate networking code that exists in NetworkService
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OracleServiceError.networkFailure(NSError(domain: "Invalid response", code: 0))
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw OracleServiceError.networkFailure(NSError(domain: "HTTP Error", code: httpResponse.statusCode))
            }
            
            // This parsing logic should be moved to BlendParser
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw OracleServiceError.priceDataUnavailable
            }
            
            return try parsePriceData(from: json, asset: asset)
            
        } catch {
            throw OracleServiceError.networkFailure(error)
        }
    }
    
    /// This method also demonstrates duplicate networking code
    func fetchMultiplePrices(for assets: [String]) async throws -> [PriceData] {
        let assetList = assets.joined(separator: ",")
        guard let url = URL(string: "\(config.baseURL)/prices?assets=\(assetList)") else {
            throw OracleServiceError.invalidOracleEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            // More duplicate networking code
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OracleServiceError.networkFailure(NSError(domain: "Invalid response", code: 0))
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw OracleServiceError.networkFailure(NSError(domain: "HTTP Error", code: httpResponse.statusCode))
            }
            
            // More parsing logic that should be in BlendParser
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pricesArray = json["prices"] as? [[String: Any]] else {
                throw OracleServiceError.priceDataUnavailable
            }
            
            return try pricesArray.compactMap { priceJson in
                guard let asset = priceJson["asset"] as? String else { return nil }
                return try parsePriceData(from: priceJson, asset: asset)
            }
            
        } catch {
            throw OracleServiceError.networkFailure(error)
        }
    }
    
    /// Contract simulation call - this should use NetworkService's contract operations
    func simulateOracleContract(contractId: String, method: String, parameters: [Any]) async throws -> Data {
        guard let url = URL(string: "\(config.baseURL)/simulate") else {
            throw OracleServiceError.invalidOracleEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "contract_id": contractId,
            "method": method,
            "parameters": parameters
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            // Yet more duplicate networking code
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OracleServiceError.networkFailure(NSError(domain: "Invalid response", code: 0))
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw OracleServiceError.networkFailure(NSError(domain: "Simulation failed", code: httpResponse.statusCode))
            }
            
            return data
            
        } catch {
            throw OracleServiceError.networkFailure(error)
        }
    }
    
    // MARK: - Private Parsing Methods (SHOULD BE MOVED TO BlendParser)
    
    private func parsePriceData(from json: [String: Any], asset: String) throws -> PriceData {
        guard let price = json["price"] as? Double,
              let timestamp = json["timestamp"] as? UInt64 else {
            throw OracleServiceError.priceDataUnavailable
        }
        
        let confidence = json["confidence"] as? Double ?? 1.0
        
        // Check if data is stale
        let currentTime = UInt64(Date().timeIntervalSince1970)
        if currentTime - timestamp > UInt64(config.maxStaleTime) {
            throw OracleServiceError.staleData
        }
        
        return PriceData(
            asset: asset,
            price: price,
            timestamp: timestamp,
            confidence: confidence
        )
    }
}

// MARK: - REFACTORED Oracle Service (Using NetworkService and BlendParser)
@MainActor
final class RefactoredOracleService: ObservableObject {
    
    // MARK: - Properties
    private let networkService: NetworkService
    private let parser: BlendParser
    private let config: OracleConfig
    
    @Published var isLoading = false
    @Published var lastError: Error?
    
    // MARK: - Initialization
    init(
        networkService: NetworkService? = nil,
        config: OracleConfig = .default
    ) {
        self.networkService = networkService ?? NetworkService()
        self.parser = BlendParser()
        self.config = config
    }
    
    // MARK: - Refactored Methods (Using Consolidated Services)
    
    func fetchPriceData(for asset: String) async throws -> PriceData {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let url = URL(string: "\(config.baseURL)/prices/\(asset)") else {
                throw OracleServiceError.invalidOracleEndpoint
            }
            
            let request = GenericNetworkRequest(url: url, method: .GET, headers: ["Accept": "application/json"])
            
            // Use consolidated NetworkService instead of duplicate code
            let response = try await networkService.performRequest(request, responseType: [String: Any].self)
            
            return try parsePriceDataUsingBlendParser(from: response, asset: asset)
            
        } catch {
            lastError = error
            if error is OracleServiceError {
                throw error
            } else {
                throw OracleServiceError.networkFailure(error)
            }
        }
    }
    
    func fetchMultiplePrices(for assets: [String]) async throws -> [PriceData] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let assetList = assets.joined(separator: ",")
            guard let url = URL(string: "\(config.baseURL)/prices?assets=\(assetList)") else {
                throw OracleServiceError.invalidOracleEndpoint
            }
            
            let request = GenericNetworkRequest(url: url, method: .GET, headers: ["Accept": "application/json"])
            
            // Use consolidated NetworkService
            let response = try await networkService.performRequest(request, responseType: [String: Any].self)
            
            guard let pricesArray = response["prices"] as? [[String: Any]] else {
                throw OracleServiceError.priceDataUnavailable
            }
            
            return try pricesArray.compactMap { priceJson in
                guard let asset = priceJson["asset"] as? String else { return nil }
                return try parsePriceDataUsingBlendParser(from: priceJson, asset: asset)
            }
            
        } catch {
            lastError = error
            if error is OracleServiceError {
                throw error
            } else {
                throw OracleServiceError.networkFailure(error)
            }
        }
    }
    
    func simulateOracleContract(contractId: String, method: String, parameters: [Any]) async throws -> ContractResponse {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Use NetworkService's contract operations instead of duplicate code
            let operation = ContractOperation.simulate(
                contractId: contractId,
                method: method,
                parameters: parameters
            )
            
            let responseData = try await networkService.performContractOperation(operation)
            
            // Use BlendParser for consistent parsing
            return try parser.parseContractResponse(from: responseData)
            
        } catch {
            lastError = error
            if error is OracleServiceError {
                throw error
            } else {
                throw OracleServiceError.networkFailure(error)
            }
        }
    }
    
    // MARK: - Private Methods (Using BlendParser)
    
    private func parsePriceDataUsingBlendParser(from json: [String: Any], asset: String) throws -> PriceData {
        // This could be enhanced to use BlendParser's SCVal parsing if the data comes in that format
        guard let price = json["price"] as? Double,
              let timestamp = json["timestamp"] as? UInt64 else {
            throw OracleServiceError.priceDataUnavailable
        }
        
        let confidence = json["confidence"] as? Double ?? 1.0
        
        // Check if data is stale
        let currentTime = UInt64(Date().timeIntervalSince1970)
        if currentTime - timestamp > UInt64(config.maxStaleTime) {
            throw OracleServiceError.staleData
        }
        
        return PriceData(
            asset: asset,
            price: price,
            timestamp: timestamp,
            confidence: confidence
        )
    }
}

// MARK: - Extensions
extension PriceData: CustomStringConvertible {
    var description: String {
        return "PriceData(asset: \(asset), price: \(price), timestamp: \(timestamp), confidence: \(confidence))"
    }
}