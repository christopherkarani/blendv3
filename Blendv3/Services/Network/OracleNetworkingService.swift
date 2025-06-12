//
//  OracleNetworkingService.swift
//  Blendv3
//
//  Legacy service with mixed responsibilities - TO BE REFACTORED
//  This service currently handles both networking and parsing operations
//

import Foundation
import Combine

// MARK: - Oracle Service (Before Refactoring)
/// This service demonstrates mixed responsibilities that need to be separated:
/// - Networking operations should move to NetworkService
/// - Parsing logic should move to BlendParser
final class OracleNetworkingService {
    private let session = URLSession.shared
    private let baseURL: String
    private var cancellables = Set<AnyCancellable>()
    
    // Temporary keys - ANTI-PATTERN: Should use dependency injection
    private let apiKey = "temp-api-key"
    private let privateKey = "temp-private-key"
    private let contractAddress = "0x1234567890abcdef"
    
    init(baseURL: String) {
        self.baseURL = baseURL
    }
    
    // MARK: - Mixed Concern 1: Direct Network Call + Inline Parsing
    func fetchOraclePrice(symbol: String) -> AnyPublisher<Double, Error> {
        guard let url = URL(string: "\(baseURL)/api/oracle/price/\(symbol)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data in
                // PARSING LOGIC - Should be in BlendParser
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let price = json["price"] as? Double else {
                    throw URLError(.cannotParseResponse)
                }
                
                // VALIDATION LOGIC - Should be in BlendParser
                guard price > 0 else {
                    throw URLError(.cannotParseResponse)
                }
                
                return price
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Mixed Concern 2: Smart Contract Call + Response Parsing
    func updateOraclePrice(symbol: String, price: Double) -> AnyPublisher<String, Error> {
        // CONTRACT CALL LOGIC - Should be in NetworkService
        let contractMethod = [
            "method": "updatePrice",
            "params": [
                "symbol": symbol,
                "price": price,
                "timestamp": Date().timeIntervalSince1970
            ],
            "address": contractAddress,
            "privateKey": privateKey // ANTI-PATTERN: Hardcoded key
        ] as [String : Any]
        
        guard let url = URL(string: "\(baseURL)/api/contract/call"),
              let body = try? JSONSerialization.data(withJSONObject: contractMethod) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data in
                // PARSING LOGIC - Should be in BlendParser
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let txHash = json["transactionHash"] as? String else {
                    throw URLError(.cannotParseResponse)
                }
                
                // VALIDATION LOGIC - Should be in BlendParser
                guard txHash.hasPrefix("0x") && txHash.count == 66 else {
                    throw URLError(.cannotParseResponse)
                }
                
                return txHash
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Mixed Concern 3: Contract Simulation + Complex Parsing
    func simulateOracleUpdate(symbol: String, price: Double) -> AnyPublisher<SimulationResponse, Error> {
        // SIMULATION LOGIC - Should be in NetworkService
        let simulationPayload = [
            "method": "updatePrice",
            "params": [
                "symbol": symbol,
                "price": price
            ],
            "address": contractAddress,
            "simulate": true
        ] as [String : Any]
        
        guard let url = URL(string: "\(baseURL)/api/contract/simulate"),
              let body = try? JSONSerialization.data(withJSONObject: simulationPayload) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data in
                // COMPLEX PARSING - Should be in BlendParser
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw URLError(.cannotParseResponse)
                }
                
                // TRANSFORMATION LOGIC - Should be in BlendParser
                let gasUsed = json["gasUsed"] as? Int ?? 0
                let success = json["success"] as? Bool ?? false
                let error = json["error"] as? String
                
                // More parsing and validation
                var logs: [String] = []
                if let logsArray = json["logs"] as? [[String: Any]] {
                    logs = logsArray.compactMap { log in
                        log["data"] as? String
                    }
                }
                
                return SimulationResponse(
                    success: success,
                    gasUsed: gasUsed,
                    estimatedCost: Double(gasUsed) * 0.00002, // Hardcoded gas price
                    error: error,
                    logs: logs
                )
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Mixed Concern 4: Batch Operations with Inline Parsing
    func fetchMultiplePrices(symbols: [String]) -> AnyPublisher<[String: Double], Error> {
        let publishers = symbols.map { symbol in
            fetchOraclePrice(symbol: symbol)
                .map { price in (symbol, price) }
                .catch { _ in Just((symbol, 0.0)).setFailureType(to: Error.self) }
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { tuples in
                Dictionary(uniqueKeysWithValues: tuples)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Mixed Concern 5: Historical Data with Complex Response Handling
    func fetchHistoricalData(symbol: String, days: Int) -> AnyPublisher<[HistoricalDataPoint], Error> {
        guard let url = URL(string: "\(baseURL)/api/oracle/history/\(symbol)?days=\(days)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data in
                // COMPLEX PARSING AND TRANSFORMATION - Should be in BlendParser
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataPoints = json["data"] as? [[String: Any]] else {
                    throw URLError(.cannotParseResponse)
                }
                
                return dataPoints.compactMap { point in
                    guard let timestamp = point["timestamp"] as? Double,
                          let price = point["price"] as? Double,
                          let volume = point["volume"] as? Double else {
                        return nil
                    }
                    
                    // DATE PARSING - Should be in BlendParser
                    let date = Date(timeIntervalSince1970: timestamp)
                    
                    // VALIDATION - Should be in BlendParser
                    guard price > 0, volume >= 0 else {
                        return nil
                    }
                    
                    return HistoricalDataPoint(
                        date: date,
                        price: price,
                        volume: volume,
                        change: point["change"] as? Double
                    )
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Response Types (Should be moved to appropriate Model files)
struct SimulationResponse {
    let success: Bool
    let gasUsed: Int
    let estimatedCost: Double
    let error: String?
    let logs: [String]
}

struct HistoricalDataPoint {
    let date: Date
    let price: Double
    let volume: Double
    let change: Double?
}