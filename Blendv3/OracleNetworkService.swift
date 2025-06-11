import Foundation
import Combine
import StellarSDK

// MARK: - Oracle Network Service Protocol
protocol OracleNetworkServiceProtocol {
    func getAssetPrice(contractId: String, asset: String) -> AnyPublisher<OracleData, OracleError>
    func getMultipleAssetPrices(contractId: String, assets: [String]) -> AnyPublisher<[OracleData], OracleError>
    func getLastUpdateTime(contractId: String) -> AnyPublisher<Date, OracleError>
    func getSupportedAssets(contractId: String) -> AnyPublisher<[String], OracleError>
}

// MARK: - Oracle Error
enum OracleError: LocalizedError {
    case networkError(NetworkError)
    case parsingError(ParsingError)
    case assetNotSupported(String)
    case priceNotAvailable
    case invalidContractId
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Oracle network error: \(error.localizedDescription)"
        case .parsingError(let error):
            return "Oracle parsing error: \(error.localizedDescription)"
        case .assetNotSupported(let asset):
            return "Asset not supported: \(asset)"
        case .priceNotAvailable:
            return "Price not available"
        case .invalidContractId:
            return "Invalid oracle contract ID"
        }
    }
}

// MARK: - Oracle Network Service Implementation
final class OracleNetworkService: OracleNetworkServiceProtocol {
    
    // MARK: - Properties
    private let networkService: NetworkServiceProtocol
    private let blendParser: BlendParserProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(networkService: NetworkServiceProtocol = NetworkService(),
         blendParser: BlendParserProtocol = BlendParser()) {
        self.networkService = networkService
        self.blendParser = blendParser
    }
    
    // MARK: - Public Methods
    
    func getAssetPrice(contractId: String, asset: String) -> AnyPublisher<OracleData, OracleError> {
        // Build the function arguments
        let args: [SCVal] = [
            .symbol(asset)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_price", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw OracleError.priceNotAvailable
                }
                
                return try self.blendParser.parseOracleData(result)
            }
            .mapError { error in
                if let oracleError = error as? OracleError {
                    return oracleError
                } else if let networkError = error as? NetworkError {
                    return .networkError(networkError)
                } else if let parsingError = error as? ParsingError {
                    return .parsingError(parsingError)
                } else {
                    return .networkError(.networkError(error))
                }
            }
            .eraseToAnyPublisher()
    }
    
    func getMultipleAssetPrices(contractId: String, assets: [String]) -> AnyPublisher<[OracleData], OracleError> {
        // Build the function arguments
        let assetVec: [SCVal] = assets.map { .symbol($0) }
        let args: [SCVal] = [
            .vec(assetVec)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_prices", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result,
                      case .vec(let priceVec) = result else {
                    throw OracleError.priceNotAvailable
                }
                
                return try priceVec.map { try self.blendParser.parseOracleData($0) }
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getLastUpdateTime(contractId: String) -> AnyPublisher<Date, OracleError> {
        return networkService
            .invokeContract(contractId: contractId, method: "last_update", args: [])
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw OracleError.priceNotAvailable
                }
                
                guard let timestamp = self.blendParser.parseSCVal(result) as? Date else {
                    throw OracleError.parsingError(.typeMismatch(expected: "Date", actual: String(describing: result)))
                }
                
                return timestamp
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getSupportedAssets(contractId: String) -> AnyPublisher<[String], OracleError> {
        return networkService
            .invokeContract(contractId: contractId, method: "get_supported_assets", args: [])
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result,
                      case .vec(let assetVec) = result else {
                    throw OracleError.priceNotAvailable
                }
                
                return assetVec.compactMap { scVal in
                    self.blendParser.parseSCVal(scVal) as? String
                }
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func mapError(_ error: Error) -> OracleError {
        if let oracleError = error as? OracleError {
            return oracleError
        } else if let networkError = error as? NetworkError {
            return .networkError(networkError)
        } else if let parsingError = error as? ParsingError {
            return .parsingError(parsingError)
        } else {
            return .networkError(.networkError(error))
        }
    }
}