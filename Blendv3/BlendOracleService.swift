import Foundation
import Combine
import StellarSDK

// MARK: - Blend Oracle Service Protocol
protocol BlendOracleServiceProtocol {
    // Price Operations
    func getPrice(contractId: String, asset: String, source: String) -> AnyPublisher<PriceData, BlendOracleError>
    func getPrices(contractId: String, assets: [String], source: String) -> AnyPublisher<[PriceData], BlendOracleError>
    func getTwapPrice(contractId: String, asset: String, period: TimeInterval) -> AnyPublisher<TwapPriceData, BlendOracleError>
    
    // Oracle Management
    func updatePrice(contractId: String, asset: String, price: Decimal, source: String) -> AnyPublisher<UpdatePriceResult, BlendOracleError>
    func updatePrices(contractId: String, priceUpdates: [PriceUpdate]) -> AnyPublisher<UpdatePricesResult, BlendOracleError>
    
    // Configuration
    func getOracleConfig(contractId: String) -> AnyPublisher<OracleConfig, BlendOracleError>
    func getSupportedAssets(contractId: String) -> AnyPublisher<[SupportedAsset], BlendOracleError>
    func addAsset(contractId: String, asset: String, config: AssetConfig) -> AnyPublisher<AddAssetResult, BlendOracleError>
    
    // Historical Data
    func getPriceHistory(contractId: String, asset: String, from: Date, to: Date) -> AnyPublisher<[HistoricalPrice], BlendOracleError>
    func getLastUpdateTime(contractId: String, asset: String) -> AnyPublisher<Date, BlendOracleError>
}

// MARK: - Blend Oracle Error
enum BlendOracleError: LocalizedError {
    case networkError(NetworkError)
    case parsingError(ParsingError)
    case assetNotSupported(String)
    case priceStale(asset: String, lastUpdate: Date)
    case invalidPrice
    case unauthorizedSource
    case configError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Oracle network error: \(error.localizedDescription)"
        case .parsingError(let error):
            return "Oracle parsing error: \(error.localizedDescription)"
        case .assetNotSupported(let asset):
            return "Asset not supported: \(asset)"
        case .priceStale(let asset, let lastUpdate):
            return "Price for \(asset) is stale. Last update: \(lastUpdate)"
        case .invalidPrice:
            return "Invalid price data"
        case .unauthorizedSource:
            return "Unauthorized price source"
        case .configError(let message):
            return "Oracle configuration error: \(message)"
        }
    }
}

// MARK: - Data Types
struct PriceData {
    let asset: String
    let price: Decimal
    let timestamp: Date
    let source: String
    let confidence: Decimal?
}

struct TwapPriceData {
    let asset: String
    let twapPrice: Decimal
    let startTime: Date
    let endTime: Date
    let sampleCount: Int
}

struct PriceUpdate {
    let asset: String
    let price: Decimal
    let source: String
    let timestamp: Date
}

struct UpdatePriceResult {
    let asset: String
    let oldPrice: Decimal
    let newPrice: Decimal
    let timestamp: Date
    let transactionHash: String?
}

struct UpdatePricesResult {
    let updatedCount: Int
    let results: [UpdatePriceResult]
    let transactionHash: String?
}

struct OracleConfig {
    let admin: String
    let baseAsset: String
    let decimals: Int
    let heartbeatInterval: TimeInterval
    let priceStalePeriod: TimeInterval
    let authorizedSources: [String]
}

struct SupportedAsset {
    let asset: String
    let isActive: Bool
    let minPrice: Decimal
    let maxPrice: Decimal
    let maxPriceChangeRate: Decimal
}

struct AssetConfig {
    let minPrice: Decimal
    let maxPrice: Decimal
    let maxPriceChangeRate: Decimal
    let requiredSources: Int
}

struct AddAssetResult {
    let asset: String
    let config: AssetConfig
    let transactionHash: String?
}

struct HistoricalPrice {
    let asset: String
    let price: Decimal
    let timestamp: Date
    let source: String
}

// MARK: - Blend Oracle Service Implementation
final class BlendOracleService: BlendOracleServiceProtocol {
    
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
    
    // MARK: - Price Operations
    
    func getPrice(contractId: String, asset: String, source: String) -> AnyPublisher<PriceData, BlendOracleError> {
        let args: [SCVal] = [
            .symbol(asset),
            .symbol(source)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_price", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BlendOracleError.invalidPrice
                }
                
                return try self.parsePriceData(result, asset: asset, source: source)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getPrices(contractId: String, assets: [String], source: String) -> AnyPublisher<[PriceData], BlendOracleError> {
        let assetVec: [SCVal] = assets.map { .symbol($0) }
        let args: [SCVal] = [
            .vec(assetVec),
            .symbol(source)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_prices", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result,
                      case .vec(let priceVec) = result else {
                    throw BlendOracleError.invalidPrice
                }
                
                return try zip(assets, priceVec).map { asset, priceVal in
                    try self.parsePriceData(priceVal, asset: asset, source: source)
                }
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getTwapPrice(contractId: String, asset: String, period: TimeInterval) -> AnyPublisher<TwapPriceData, BlendOracleError> {
        let periodSeconds = UInt64(period)
        let args: [SCVal] = [
            .symbol(asset),
            .u64(periodSeconds)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_twap", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BlendOracleError.invalidPrice
                }
                
                return try self.parseTwapPriceData(result, asset: asset, period: period)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Oracle Management
    
    func updatePrice(contractId: String, asset: String, price: Decimal, source: String) -> AnyPublisher<UpdatePriceResult, BlendOracleError> {
        let priceI128 = convertDecimalToI128(price, decimals: 7)
        let timestamp = UInt64(Date().timeIntervalSince1970)
        
        let args: [SCVal] = [
            .symbol(asset),
            .i128(priceI128),
            .symbol(source),
            .u64(timestamp)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "update_price", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BlendOracleError.invalidPrice
                }
                
                return try self.parseUpdatePriceResult(result, asset: asset, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func updatePrices(contractId: String, priceUpdates: [PriceUpdate]) -> AnyPublisher<UpdatePricesResult, BlendOracleError> {
        let updateVec: [SCVal] = priceUpdates.map { update in
            let priceI128 = convertDecimalToI128(update.price, decimals: 7)
            let timestamp = UInt64(update.timestamp.timeIntervalSince1970)
            
            return .map([
                SCMapEntry(key: .symbol("asset"), val: .symbol(update.asset)),
                SCMapEntry(key: .symbol("price"), val: .i128(priceI128)),
                SCMapEntry(key: .symbol("source"), val: .symbol(update.source)),
                SCMapEntry(key: .symbol("timestamp"), val: .u64(timestamp))
            ])
        }
        
        let args: [SCVal] = [.vec(updateVec)]
        
        return networkService
            .invokeContract(contractId: contractId, method: "update_prices", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BlendOracleError.invalidPrice
                }
                
                return try self.parseUpdatePricesResult(result, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Configuration
    
    func getOracleConfig(contractId: String) -> AnyPublisher<OracleConfig, BlendOracleError> {
        return networkService
            .invokeContract(contractId: contractId, method: "get_config", args: [])
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BlendOracleError.configError("No configuration found")
                }
                
                return try self.parseOracleConfig(result)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getSupportedAssets(contractId: String) -> AnyPublisher<[SupportedAsset], BlendOracleError> {
        return networkService
            .invokeContract(contractId: contractId, method: "get_supported_assets", args: [])
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result,
                      case .vec(let assetsVec) = result else {
                    return []
                }
                
                return assetsVec.compactMap { self.parseSupportedAsset($0) }
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func addAsset(contractId: String, asset: String, config: AssetConfig) -> AnyPublisher<AddAssetResult, BlendOracleError> {
        let configMap: [SCMapEntry] = [
            SCMapEntry(key: .symbol("min_price"), val: .i128(convertDecimalToI128(config.minPrice, decimals: 7))),
            SCMapEntry(key: .symbol("max_price"), val: .i128(convertDecimalToI128(config.maxPrice, decimals: 7))),
            SCMapEntry(key: .symbol("max_price_change_rate"), val: .i128(convertDecimalToI128(config.maxPriceChangeRate, decimals: 4))),
            SCMapEntry(key: .symbol("required_sources"), val: .u32(UInt32(config.requiredSources)))
        ]
        
        let args: [SCVal] = [
            .symbol(asset),
            .map(configMap)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "add_asset", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BlendOracleError.configError("Failed to add asset")
                }
                
                return AddAssetResult(
                    asset: asset,
                    config: config,
                    transactionHash: response.transactionHash
                )
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Historical Data
    
    func getPriceHistory(contractId: String, asset: String, from: Date, to: Date) -> AnyPublisher<[HistoricalPrice], BlendOracleError> {
        let fromTimestamp = UInt64(from.timeIntervalSince1970)
        let toTimestamp = UInt64(to.timeIntervalSince1970)
        
        let args: [SCVal] = [
            .symbol(asset),
            .u64(fromTimestamp),
            .u64(toTimestamp)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_price_history", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result,
                      case .vec(let historyVec) = result else {
                    return []
                }
                
                return historyVec.compactMap { self.parseHistoricalPrice($0, asset: asset) }
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getLastUpdateTime(contractId: String, asset: String) -> AnyPublisher<Date, BlendOracleError> {
        let args: [SCVal] = [.symbol(asset)]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_last_update", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BlendOracleError.assetNotSupported(asset)
                }
                
                guard let timestamp = self.blendParser.parseSCVal(result) as? Date else {
                    throw BlendOracleError.parsingError(.typeMismatch(expected: "Date", actual: String(describing: result)))
                }
                
                return timestamp
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Parsing Methods
    
    private func parsePriceData(_ scVal: SCVal, asset: String, source: String) throws -> PriceData {
        guard case .map(let entries) = scVal else {
            throw BlendOracleError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var priceData = PriceData(
            asset: asset,
            price: 0,
            timestamp: Date(),
            source: source,
            confidence: nil
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "price":
                if let price = blendParser.parseSCVal(entry.val) as? Decimal {
                    priceData.price = price / 10_000_000 // 7 decimals
                }
            case "timestamp":
                if let timestamp = blendParser.parseSCVal(entry.val) as? Date {
                    priceData.timestamp = timestamp
                }
            case "confidence":
                if let confidence = blendParser.parseSCVal(entry.val) as? Decimal {
                    priceData.confidence = confidence / 10_000_000
                }
            default:
                break
            }
        }
        
        return priceData
    }
    
    private func parseTwapPriceData(_ scVal: SCVal, asset: String, period: TimeInterval) throws -> TwapPriceData {
        guard case .map(let entries) = scVal else {
            throw BlendOracleError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var twapData = TwapPriceData(
            asset: asset,
            twapPrice: 0,
            startTime: Date(timeIntervalSinceNow: -period),
            endTime: Date(),
            sampleCount: 0
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "twap_price":
                if let price = blendParser.parseSCVal(entry.val) as? Decimal {
                    twapData.twapPrice = price / 10_000_000
                }
            case "start_time":
                if let startTime = blendParser.parseSCVal(entry.val) as? Date {
                    twapData.startTime = startTime
                }
            case "end_time":
                if let endTime = blendParser.parseSCVal(entry.val) as? Date {
                    twapData.endTime = endTime
                }
            case "sample_count":
                twapData.sampleCount = blendParser.parseSCVal(entry.val) as? Int ?? 0
            default:
                break
            }
        }
        
        return twapData
    }
    
    private func parseUpdatePriceResult(_ scVal: SCVal, asset: String, transactionHash: String?) throws -> UpdatePriceResult {
        guard case .map(let entries) = scVal else {
            throw BlendOracleError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var result = UpdatePriceResult(
            asset: asset,
            oldPrice: 0,
            newPrice: 0,
            timestamp: Date(),
            transactionHash: transactionHash
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "old_price":
                if let price = blendParser.parseSCVal(entry.val) as? Decimal {
                    result.oldPrice = price / 10_000_000
                }
            case "new_price":
                if let price = blendParser.parseSCVal(entry.val) as? Decimal {
                    result.newPrice = price / 10_000_000
                }
            case "timestamp":
                if let timestamp = blendParser.parseSCVal(entry.val) as? Date {
                    result.timestamp = timestamp
                }
            default:
                break
            }
        }
        
        return result
    }
    
    private func parseUpdatePricesResult(_ scVal: SCVal, transactionHash: String?) throws -> UpdatePricesResult {
        guard case .map(let entries) = scVal else {
            throw BlendOracleError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var updatedCount = 0
        var results: [UpdatePriceResult] = []
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "updated_count":
                updatedCount = blendParser.parseSCVal(entry.val) as? Int ?? 0
            case "results":
                if case .vec(let resultsVec) = entry.val {
                    results = resultsVec.compactMap { resultVal in
                        if let asset = extractAssetFromResult(resultVal) {
                            return try? parseUpdatePriceResult(resultVal, asset: asset, transactionHash: nil)
                        }
                        return nil
                    }
                }
            default:
                break
            }
        }
        
        return UpdatePricesResult(
            updatedCount: updatedCount,
            results: results,
            transactionHash: transactionHash
        )
    }
    
    private func parseOracleConfig(_ scVal: SCVal) throws -> OracleConfig {
        guard case .map(let entries) = scVal else {
            throw BlendOracleError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var config = OracleConfig(
            admin: "",
            baseAsset: "USD",
            decimals: 7,
            heartbeatInterval: 3600,
            priceStalePeriod: 86400,
            authorizedSources: []
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "admin":
                config.admin = blendParser.parseSCVal(entry.val) as? String ?? ""
            case "base_asset":
                config.baseAsset = blendParser.parseSCVal(entry.val) as? String ?? "USD"
            case "decimals":
                config.decimals = blendParser.parseSCVal(entry.val) as? Int ?? 7
            case "heartbeat_interval":
                if let interval = blendParser.parseSCVal(entry.val) as? Int {
                    config.heartbeatInterval = TimeInterval(interval)
                }
            case "price_stale_period":
                if let period = blendParser.parseSCVal(entry.val) as? Int {
                    config.priceStalePeriod = TimeInterval(period)
                }
            case "authorized_sources":
                if case .vec(let sourcesVec) = entry.val {
                    config.authorizedSources = sourcesVec.compactMap { blendParser.parseSCVal($0) as? String }
                }
            default:
                break
            }
        }
        
        return config
    }
    
    private func parseSupportedAsset(_ scVal: SCVal) -> SupportedAsset? {
        guard case .map(let entries) = scVal else { return nil }
        
        var asset = SupportedAsset(
            asset: "",
            isActive: true,
            minPrice: 0,
            maxPrice: Decimal.greatestFiniteMagnitude,
            maxPriceChangeRate: 1.0
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "asset":
                asset.asset = blendParser.parseSCVal(entry.val) as? String ?? ""
            case "is_active":
                asset.isActive = blendParser.parseSCVal(entry.val) as? Bool ?? true
            case "min_price":
                if let price = blendParser.parseSCVal(entry.val) as? Decimal {
                    asset.minPrice = price / 10_000_000
                }
            case "max_price":
                if let price = blendParser.parseSCVal(entry.val) as? Decimal {
                    asset.maxPrice = price / 10_000_000
                }
            case "max_price_change_rate":
                if let rate = blendParser.parseSCVal(entry.val) as? Decimal {
                    asset.maxPriceChangeRate = rate / 10000 // basis points
                }
            default:
                break
            }
        }
        
        return asset.asset.isEmpty ? nil : asset
    }
    
    private func parseHistoricalPrice(_ scVal: SCVal, asset: String) -> HistoricalPrice? {
        guard case .map(let entries) = scVal else { return nil }
        
        var historicalPrice = HistoricalPrice(
            asset: asset,
            price: 0,
            timestamp: Date(),
            source: ""
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "price":
                if let price = blendParser.parseSCVal(entry.val) as? Decimal {
                    historicalPrice.price = price / 10_000_000
                }
            case "timestamp":
                if let timestamp = blendParser.parseSCVal(entry.val) as? Date {
                    historicalPrice.timestamp = timestamp
                }
            case "source":
                historicalPrice.source = blendParser.parseSCVal(entry.val) as? String ?? ""
            default:
                break
            }
        }
        
        return historicalPrice
    }
    
    private func extractAssetFromResult(_ scVal: SCVal) -> String? {
        guard case .map(let entries) = scVal else { return nil }
        
        for entry in entries {
            if case .symbol("asset") = entry.key {
                return blendParser.parseSCVal(entry.val) as? String
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func convertDecimalToI128(_ decimal: Decimal, decimals: Int) -> SCI128Parts {
        let multiplier = Decimal(sign: .plus, exponent: decimals, significand: 1)
        let scaled = decimal * multiplier
        let intValue = NSDecimalNumber(decimal: scaled).int64Value
        
        return SCI128Parts(hi: intValue < 0 ? -1 : 0, lo: UInt64(bitPattern: intValue))
    }
    
    private func mapError(_ error: Error) -> BlendOracleError {
        if let oracleError = error as? BlendOracleError {
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