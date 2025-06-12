import Foundation
import stellarsdk

/// Protocol defining oracle price retrieval methods for Blend Protocol
/// Aligned with the Soroban smart contract functions
public protocol BlendOracleServiceProtocol {
    
    // MARK: - Legacy Methods (Maintained for backward compatibility)
    
    /// Get prices for multiple assets in a single batch request
    /// - Parameter assets: Array of asset IDs to retrieve prices for
    /// - Returns: Dictionary mapping asset IDs to price data
    func getPrices(assets: [OracleAsset]) async throws -> [PriceData]
    
    
    
    /// Get price for a single asset
    /// - Parameter asset: Asset ID to retrieve price for
    /// - Returns: Price data for the asset
    func getPrice(asset: OracleAsset) async throws -> PriceData
    
    /// Get the decimal precision of oracle prices
    /// - Returns: Number of decimal places used by the oracle
    func getOracleDecimals() async throws -> Int
    
    // MARK: - Contract-Aligned Methods
    
    /// Get the resolution factor used by the oracle
    /// Maps to contract's resolution() function
    /// - Returns: Resolution factor used for price calculations
    func getOracleResolution() async throws -> Int
    
    /// Get price for an asset at a specific timestamp
    /// Maps to contract's price(asset: Asset, timestamp: u64) function
    /// - Parameters:
    ///   - asset: Asset to get price for
    ///   - timestamp: Timestamp in seconds since epoch
    /// - Returns: Optional price data (nil if price not available for timestamp)
    func getPrice(asset: OracleAsset, timestamp: UInt64) async throws -> PriceData?
    
    
    /// Get historical prices for an asset
    /// Maps to contract's prices(asset: Asset, records: u32) function
    /// - Parameters:
    ///   - asset: Asset to get price history for
    ///   - records: Number of historical price records to retrieve
    /// - Returns: Optional array of price data (nil if no price history available)
    func getPriceHistory(asset: OracleAsset, records: UInt32) async throws -> [PriceData]?
    
    /// Get the last recorded price for an asset
    /// Maps to contract's lastprice(asset: Asset) function
    /// - Parameter asset: Asset to get price for
    /// - Returns: Optional price data (nil if no price available)
    func getLastPrice(asset: OracleAsset) async throws -> PriceData?
    
    /// Get the base asset used by the oracle
    /// Maps to contract's base() function
    /// - Returns: Base asset of the oracle
    func getBaseAsset() async throws -> OracleAsset
    
    /// Get all supported assets by the oracle
    /// Maps to contract's assets() function
    /// - Returns: Array of assets supported by the oracle
    func getSupportedAssets() async throws -> [OracleAsset]
    
    func assets() async throws -> [String]
    
}

/// Extension to BlendOracleService to implement new protocol methods
extension BlendOracleService: BlendOracleServiceProtocol {
    /// Get the current price for an asset using the current timestamp
    /// Convenience method that uses the current timestamp
    /// - Parameter asset: Asset to get price for
    /// - Returns: Price data for the asset (non-optional for backward compatibility)
    public func getPrice(asset: OracleAsset) async throws -> PriceData {
        // Use current timestamp (seconds since epoch)
        let currentTimestamp = UInt64(Date().timeIntervalSince1970)
        self.debugLogger.info("🔮 Using current timestamp: \(currentTimestamp) for asset: \(asset.description)")
        
        // Call the timestamp-specific function and handle the optional result
        guard let priceData = try await getLastPrice(asset: asset) else {
            // For backward compatibility, throw an error if no price is available
            // This maintains the non-optional return type of the original function
            throw OracleError.priceNotAvailable(asset: asset.assetId, reason: "No price available at timestamp \(currentTimestamp)")
        }
        
        return priceData
    }
    
    public func assets() async throws -> [String] {
        let supportedAssets = try await getSupportedAssets()
        return supportedAssets.map { $0.assetId }
    }
    
    // MARK: - Contract-Aligned Methods
    
    /// Get the resolution factor used by the oracle
    /// Maps to contract's resolution() function
    public func getOracleResolution() async throws -> Int {
        let cacheKey = "oracle_resolution"
        if let cachedResolution = await cacheService.get(cacheKey, type: Int.self) {
            return cachedResolution
        }
        let resolution = try await fetchOracleResolution()
        await cacheService.set(resolution, key: cacheKey, ttl: decimalsCacheTTL)
        return resolution
    }
    
    /// Get price for an asset at a specific timestamp
    /// Maps to contract's price(asset: Asset, timestamp: u64) function
    public func getPrice(asset: OracleAsset, timestamp: UInt64) async throws -> PriceData? {
        debugLogger.info("🔮 Getting price for asset: \(asset.description) at timestamp: \(timestamp)")
        
        return try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
            let assetParam = try OracleContractFunction.createAssetParameter(asset)
            let timestampParam = OracleContractFunction.createTimestampParameter(timestamp)
            
            let context = OracleParsingContext(
                assetId: asset.assetId,
                functionName: "price",
                additionalInfo: ["timestamp": timestamp]
            )
            
            return try await self.oracleNetworkService.simulateAndParse(
                .price,
                arguments: [assetParam, timestampParam],
                using: self.optionalPriceDataParser,
                context: context
            )
        }
    }
    
    /// Get historical prices for an asset
    /// Maps to contract's prices(asset: Asset, records: u32) function
    public func getPriceHistory(asset: OracleAsset, records: UInt32) async throws -> [PriceData]? {
        let assetDescription = asset.description
        BlendLogger.info("🔮 Fetching price history for asset: \(assetDescription) with \(records) records", category: BlendLogger.oracle)
        
        return try await withRetry(maxAttempts: self.maxRetries, delay: self.retryDelay) {
            let assetParam = try OracleContractFunction.createAssetParameter(asset)
            let recordsParam = OracleContractFunction.createRecordsParameter(records)
            
            let context = OracleParsingContext(
                assetId: asset.assetId,
                functionName: "prices",
                additionalInfo: ["records": records]
            )
            
            return try await self.oracleNetworkService.simulateAndParse(
                .prices,
                arguments: [assetParam, recordsParam],
                using: self.priceDataVectorParser,
                context: context
            )
        }
    }
    
    /// Get the last recorded price for an asset
    /// Maps to contract's lastprice(asset: Asset) function
    public func getLastPrice(asset: OracleAsset) async throws -> PriceData? {
        debugLogger.info("🔮 Getting last price for asset: \(asset.description)")
        
        return try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
            let assetParam = try OracleContractFunction.createAssetParameter(asset)
            
            let context = OracleParsingContext(
                assetId: asset.assetId,
                functionName: "lastprice"
            )
            
            return try await self.oracleNetworkService.simulateAndParse(
                .lastPrice,
                arguments: [assetParam],
                using: self.optionalPriceDataParser,
                context: context
            )
        }
    }
    
    /// Get the base asset used by the oracle
    /// Maps to contract's base() function
    public func getBaseAsset() async throws -> OracleAsset {
        BlendLogger.info("🔮 Fetching base asset", category: BlendLogger.oracle)
        
        let cacheKey = "oracle_base_asset"
        if let cachedAsset = await cacheService.get(cacheKey, type: OracleAsset.self) {
            BlendLogger.info("Using cached base asset: \(cachedAsset)", category: BlendLogger.oracle)
            return cachedAsset
        }
        
        return try await measurePerformance(operation: "getBaseAsset", category: BlendLogger.oracle) {
            let context = OracleParsingContext(functionName: "base")
            
            let asset = try await self.oracleNetworkService.simulateAndParse(
                .base,
                using: self.assetParser,
                context: context
            )
            
            // Cache the result
            await cacheService.set(asset, key: cacheKey, ttl: 3600)
            
            BlendLogger.info("Fetched and cached base asset: \(asset)", category: BlendLogger.oracle)
            return asset
        }
    }
    
    /// Get all supported assets by the oracle
    /// Maps to contract's assets() function
    public func getSupportedAssets() async throws -> [OracleAsset] {
        BlendLogger.info("🔮 Fetching supported assets", category: BlendLogger.oracle)
        
        let cacheKey = "oracle_supported_assets"
        if let cachedAssets = await cacheService.get(cacheKey, type: [OracleAsset].self) {
            BlendLogger.info("Using cached supported assets: \(cachedAssets.count)", category: BlendLogger.oracle)
            return cachedAssets
        }
        
        return try await measurePerformance(operation: "getSupportedAssets", category: BlendLogger.oracle) {
            let context = OracleParsingContext(functionName: "assets")
            
            let oracleAssets = try await self.oracleNetworkService.simulateAndParse(
                .assets,
                using: self.assetVectorParser,
                context: context
            )
            
            // Cache the result
            await cacheService.set(oracleAssets, key: cacheKey, ttl: 3600)
            
            BlendLogger.info("Fetched and cached \(oracleAssets.count) supported assets", category: BlendLogger.oracle)
            return oracleAssets
        }
    }
    
    // MARK: - Private Helpers
    
    /// Fetch oracle resolution from the contract
    private func fetchOracleResolution() async throws -> Int {
        return try await withRetry(maxAttempts: self.maxRetries, delay: self.retryDelay) {
            let context = OracleParsingContext(functionName: "resolution")
            
            let resolution = try await self.oracleNetworkService.simulateAndParse(
                .resolution,
                using: self.u32Parser,
                context: context
            )
            
            return Int(resolution)
        }
    }
}

// MARK: - Private Extension for Legacy Support

extension BlendOracleService {
    
    private func getAssetSymbol(for address: String) -> String {
        let assetMapping = [
            BlendConstants.Testnet.usdc: "USDC",
            BlendConstants.Testnet.xlm: "XLM",
            BlendConstants.Testnet.blnd: "BLND",
            BlendConstants.Testnet.weth: "wETH",
            BlendConstants.Testnet.wbtc: "wBTC"
        ]
        return assetMapping[address] ?? address
    }
    
    /// Legacy method to comply with BlendOracleServiceProtocol
    /// Converts legacy string-based asset IDs to OracleAsset and calls new implementation
    public func getPrices(assets: [OracleAsset]) async throws -> [PriceData] {
        // Create result dictionary
        var priceDataCollection: [PriceData] = []
     
        // Fetch prices for each asset
        for asset in assets {
            if let priceData = try? await getPrice(asset: asset) {
                priceDataCollection.append(priceData)
            }
        }
        
        // Ensure we have at least one price
        guard !priceDataCollection.isEmpty else {
            throw OracleError.noDataAvailable(context: "No prices available for any requested assets")
        }
        return priceDataCollection
    }
}
