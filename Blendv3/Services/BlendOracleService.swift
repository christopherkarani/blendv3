import Foundation

/// Blend Oracle Service - handles Blend protocol oracle operations
/// Uses NetworkService for networking and BlendParser for parsing
@MainActor 
class BlendOracleService: ObservableObject {
    
    // MARK: - Dependencies
    
    private let networkService: NetworkService
    private let parser: BlendParser
    
    // MARK: - Properties
    
    @Published var poolAssetPrices: [String: [String: Double]] = [:] // poolId -> assetId -> price
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Initialization
    
    init(networkService: NetworkService = NetworkService(), parser: BlendParser = BlendParser.shared) {
        self.networkService = networkService
        self.parser = parser
    }
    
    // MARK: - Blend Oracle Operations
    
    /// Get asset price from Blend oracle contract
    func getAssetPrice(poolContract: String, assetId: String) async throws -> Double {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let assetArg = try parser.createSCVal(from: assetId)
            let args = [assetArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolContract,
                method: "get_asset_price",
                args: args,
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            let priceValue = try parser.parseUInt64(from: result)
            
            let price = Double(priceValue) / 1_000_000 // Adjust decimal places as needed
            
            // Update state
            DispatchQueue.main.async {
                if self.poolAssetPrices[poolContract] == nil {
                    self.poolAssetPrices[poolContract] = [:]
                }
                self.poolAssetPrices[poolContract]?[assetId] = price
                self.error = nil
            }
            
            return price
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    /// Get all asset prices for a pool
    func getPoolAssetPrices(poolContract: String) async throws -> [String: Double] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get pool configuration to know which assets to query
            let poolConfig = try await getPoolConfiguration(poolContract: poolContract)
            let assetIds = poolConfig.assetIds
            
            var prices: [String: Double] = [:]
            
            // Fetch prices concurrently
            try await withThrowingTaskGroup(of: (String, Double).self) { group in
                for assetId in assetIds {
                    group.addTask {
                        let price = try await self.getSingleAssetPrice(poolContract: poolContract, assetId: assetId)
                        return (assetId, price)
                    }
                }
                
                for try await (assetId, price) in group {
                    prices[assetId] = price
                }
            }
            
            // Update state
            DispatchQueue.main.async {
                self.poolAssetPrices[poolContract] = prices
                self.error = nil
            }
            
            return prices
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    /// Get oracle price with metadata (timestamp, confidence, etc.)
    func getAssetPriceData(poolContract: String, assetId: String) async throws -> BlendPriceData {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let assetArg = try parser.createSCVal(from: assetId)
            let args = [assetArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolContract,
                method: "get_asset_price_data",
                args: args,
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            let priceDataMap = try parser.parseMap(from: result)
            
            guard let priceScVal = priceDataMap["price"],
                  let timestampScVal = priceDataMap["timestamp"] else {
                throw BlendOracleError.incompleteData
            }
            
            let price = try parser.parseUInt64(from: priceScVal)
            let timestamp = try parser.parseUInt64(from: timestampScVal)
            
            // Parse optional fields
            let confidence = try? parser.parseOptional(from: priceDataMap["confidence"] ?? .void) { scVal in
                try parser.parseUInt32(from: scVal)
            }
            
            let source = try? parser.parseOptional(from: priceDataMap["source"] ?? .void) { scVal in
                try parser.parseString(from: scVal)
            }
            
            let priceData = BlendPriceData(
                price: Double(price) / 1_000_000,
                timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp)),
                confidence: confidence?.flatMap { Double($0) / 100 }, // Convert to percentage
                source: source ?? "unknown"
            )
            
            return priceData
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    /// Update oracle prices (if this service has update permissions)
    func updateOraclePrice(
        oracleContract: String,
        assetId: String,
        price: UInt64,
        timestamp: UInt64,
        sourceKeyPair: Any
    ) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let assetArg = try parser.createSCVal(from: assetId)
            let priceArg = try parser.createSCVal(from: price)
            let timestampArg = try parser.createSCVal(from: timestamp)
            let args = [assetArg, priceArg, timestampArg]
            
            _ = try await networkService.invokeContract(
                contractAddress: oracleContract,
                method: "update_price",
                args: args,
                sourceAccount: sourceKeyPair
            )
            
            // Refresh local price data
            _ = try await getAssetPrice(poolContract: oracleContract, assetId: assetId)
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    /// Get historical price data
    func getHistoricalPrices(
        poolContract: String,
        assetId: String,
        fromLedger: UInt32,
        toLedger: UInt32
    ) async throws -> [BlendPriceHistoryEntry] {
        
        do {
            // Get price update events
            let eventsResponse = try await networkService.getEvents(
                contractAddress: poolContract,
                topics: ["price_update", assetId],
                startLedger: fromLedger,
                endLedger: toLedger
            )
            
            let events = parser.parseEvents(from: eventsResponse)
            var historyEntries: [BlendPriceHistoryEntry] = []
            
            for event in events {
                let topics = try parser.parseEventTopics(from: event)
                
                if topics.contains("price_update") {
                    let historyEntry = try parser.parseEventData(from: event) { data in
                        let dataMap = try parser.parseMap(from: data)
                        
                        guard let priceScVal = dataMap["price"],
                              let timestampScVal = dataMap["timestamp"] else {
                            throw BlendOracleError.incompleteData
                        }
                        
                        let price = try parser.parseUInt64(from: priceScVal)
                        let timestamp = try parser.parseUInt64(from: timestampScVal)
                        
                        return BlendPriceHistoryEntry(
                            assetId: assetId,
                            price: Double(price) / 1_000_000,
                            timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp))
                        )
                    }
                    
                    historyEntries.append(historyEntry)
                }
            }
            
            return historyEntries.sorted { $0.timestamp < $1.timestamp }
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func getSingleAssetPrice(poolContract: String, assetId: String) async throws -> Double {
        let assetArg = try parser.createSCVal(from: assetId)
        let args = [assetArg]
        
        let response = try await networkService.invokeContract(
            contractAddress: poolContract,
            method: "get_asset_price",
            args: args,
            sourceAccount: getDefaultKeyPair()
        )
        
        let result = try parser.parseSingleResult(from: response)
        let priceValue = try parser.parseUInt64(from: result)
        
        return Double(priceValue) / 1_000_000
    }
    
    private func getPoolConfiguration(poolContract: String) async throws -> PoolConfiguration {
        let response = try await networkService.invokeContract(
            contractAddress: poolContract,
            method: "get_config",
            args: [],
            sourceAccount: getDefaultKeyPair()
        )
        
        let result = try parser.parseSingleResult(from: response)
        let configMap = try parser.parseMap(from: result)
        
        guard let assetsScVal = configMap["assets"] else {
            throw BlendOracleError.configurationError("Missing assets in pool config")
        }
        
        let assetsArray = try parser.parseArray(from: assetsScVal)
        let assetIds = try assetsArray.map { try parser.parseString(from: $0) }
        
        return PoolConfiguration(assetIds: assetIds)
    }
    
    private func getDefaultKeyPair() -> Any {
        fatalError("KeyPair should be provided through dependency injection")
    }
}

// MARK: - Data Models

struct BlendPriceData {
    let price: Double
    let timestamp: Date
    let confidence: Double?
    let source: String
}

struct BlendPriceHistoryEntry {
    let assetId: String
    let price: Double
    let timestamp: Date
}

struct PoolConfiguration {
    let assetIds: [String]
}

// MARK: - Error Types

enum BlendOracleError: Error, LocalizedError {
    case incompleteData
    case configurationError(String)
    case updatePermissionDenied
    case invalidAssetId(String)
    
    var errorDescription: String? {
        switch self {
        case .incompleteData:
            return "Incomplete oracle data received"
        case .configurationError(let message):
            return "Pool configuration error: \(message)"
        case .updatePermissionDenied:
            return "Permission denied for oracle update"
        case .invalidAssetId(let assetId):
            return "Invalid asset ID: \(assetId)"
        }
    }
}