//
//  OracleService.swift
//  Blendv3
//
//  Refactored Oracle service with proper separation of concerns
//  Uses NetworkService for networking and BlendParser for parsing
//

import Foundation
import Combine

// MARK: - Oracle Service Protocol
protocol OracleServiceProtocol {
    func fetchOraclePrice(symbol: String) -> AnyPublisher<Double, Error>
    func updateOraclePrice(symbol: String, price: Double) -> AnyPublisher<String, Error>
    func simulateOracleUpdate(symbol: String, price: Double) -> AnyPublisher<SimulationResult, Error>
    func fetchMultiplePrices(symbols: [String]) -> AnyPublisher<[String: Double], Error>
    func fetchHistoricalData(symbol: String, days: Int) -> AnyPublisher<[HistoricalDataPoint], Error>
}

// MARK: - Oracle Price Response Model
struct OraclePriceResponse: Decodable {
    let price: Double
    let timestamp: Date
    let source: String
}

// MARK: - Historical Data Response
struct HistoricalDataResponse: Decodable {
    let data: [HistoricalDataPoint]
}

// MARK: - Refactored Oracle Service
final class OracleService: OracleServiceProtocol {
    private let networkService: NetworkServiceProtocol
    private let parser: BlendParserProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        networkService: NetworkServiceProtocol,
        parser: BlendParserProtocol
    ) {
        self.networkService = networkService
        self.parser = parser
    }
    
    // MARK: - Fetch Oracle Price (Refactored)
    func fetchOraclePrice(symbol: String) -> AnyPublisher<Double, Error> {
        let endpoint = Endpoint(
            path: "/api/oracle/price/\(symbol)",
            method: .get,
            headers: nil,
            body: nil,
            queryItems: nil
        )
        
        return networkService.request(endpoint)
            .tryMap { (response: OraclePriceResponse) in
                // Use parser for validation
                let validationResult = self.parser.validate(
                    response.price,
                    using: { $0 > 0 },
                    errorMessage: "Price must be greater than 0"
                )
                
                switch validationResult {
                case .success(let price):
                    return price
                case .failure(let error):
                    throw error
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Update Oracle Price (Refactored)
    func updateOraclePrice(symbol: String, price: Double) -> AnyPublisher<String, Error> {
        let contractMethod = SmartContractMethod(
            name: "updatePrice",
            parameters: [
                "symbol": symbol,
                "price": price,
                "timestamp": Date().timeIntervalSince1970
            ],
            gasLimit: nil,
            value: nil
        )
        
        return networkService.callSmartContract(contractMethod)
            .tryMap { data in
                // Use parser for response parsing
                let parseResult = self.parser.parseContractResponse(data)
                
                switch parseResult {
                case .success(let response):
                    // Use parser for validation
                    let validator = TransactionHashValidator()
                    let validationResult = validator.validate(response.transactionHash)
                    
                    if validationResult.isValid {
                        return response.transactionHash
                    } else {
                        throw ParserError.validationFailed(validationResult.errors.joined(separator: ", "))
                    }
                    
                case .failure(let error):
                    throw error
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Simulate Oracle Update (Refactored)
    func simulateOracleUpdate(symbol: String, price: Double) -> AnyPublisher<SimulationResult, Error> {
        let contractMethod = SmartContractMethod(
            name: "updatePrice",
            parameters: [
                "symbol": symbol,
                "price": price
            ],
            gasLimit: nil,
            value: nil
        )
        
        return networkService.simulateContract(contractMethod)
            .map { $0 as SimulationResult }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Fetch Multiple Prices (Refactored)
    func fetchMultiplePrices(symbols: [String]) -> AnyPublisher<[String: Double], Error> {
        let publishers = symbols.map { symbol in
            fetchOraclePrice(symbol: symbol)
                .map { price in (symbol, price) }
                .catch { _ in
                    // Return default value on error
                    Just((symbol, 0.0))
                        .setFailureType(to: Error.self)
                }
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { tuples in
                Dictionary(uniqueKeysWithValues: tuples)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Fetch Historical Data (Refactored)
    func fetchHistoricalData(symbol: String, days: Int) -> AnyPublisher<[HistoricalDataPoint], Error> {
        let endpoint = Endpoint(
            path: "/api/oracle/history/\(symbol)",
            method: .get,
            headers: nil,
            body: nil,
            queryItems: [URLQueryItem(name: "days", value: String(days))]
        )
        
        return networkService.request(endpoint)
            .tryMap { (response: HistoricalDataResponse) in
                // Use parser for validation of each data point
                return response.data.compactMap { dataPoint in
                    let priceValidation = self.parser.validate(
                        dataPoint,
                        using: { $0.price > 0 && $0.volume >= 0 },
                        errorMessage: "Invalid data point"
                    )
                    
                    switch priceValidation {
                    case .success(let validDataPoint):
                        return validDataPoint
                    case .failure:
                        return nil // Skip invalid data points
                    }
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Key Provider Implementation
struct SecureKeyProvider: KeyProviderProtocol {
    private let keychain: KeychainServiceProtocol
    
    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }
    
    var apiKey: String {
        // Retrieve from secure storage
        keychain.retrieve(key: "api_key") ?? ""
    }
    
    var privateKey: String? {
        // Retrieve from secure storage
        keychain.retrieve(key: "private_key")
    }
    
    var contractAddress: String? {
        // Retrieve from configuration
        keychain.retrieve(key: "contract_address")
    }
}

// MARK: - Keychain Protocol (for demonstration)
protocol KeychainServiceProtocol {
    func retrieve(key: String) -> String?
    func store(key: String, value: String) -> Bool
    func delete(key: String) -> Bool
}