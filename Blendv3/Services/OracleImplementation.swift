import Foundation
import stellarsdk

/// Extension to BlendOracleService to implement new protocol methods
extension BlendOracleService {
    
    // MARK: - Contract-Aligned Methods
    
    /// Get the resolution factor used by the oracle
    /// Maps to contract's resolution() function
    public func getOracleResolution() async throws -> Int {
        BlendLogger.info("🔮 Fetching oracle resolution", category: BlendLogger.oracle)
        
        let cacheKey = "oracle_resolution"
        if let cachedResolution = await cacheService.get(cacheKey, type: Int.self) {
            BlendLogger.info("Using cached oracle resolution: \(cachedResolution)", category: BlendLogger.oracle)
            return cachedResolution
        }
        
        return try await measurePerformance(operation: "getOracleResolution", category: BlendLogger.oracle) {
            let resolution = try await fetchOracleResolution()
            await cacheService.set(resolution, key: cacheKey, ttl: decimalsCacheTTL)
            BlendLogger.info("Fetched and cached oracle resolution: \(resolution)", category: BlendLogger.oracle)
            return resolution
        }
    }
    
    /// Get price for an asset at a specific timestamp
    /// Maps to contract's price(asset: Asset, timestamp: u64) function
    public func getPrice(asset: OracleAsset, timestamp: UInt64) async throws -> PriceData? {
        let assetDescription = asset.description
        BlendLogger.info("🔮 Fetching price for asset: \(assetDescription) at timestamp: \(timestamp)", category: BlendLogger.oracle)
        
        return try await withRetry(maxAttempts: self.maxRetries, delay: self.retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
            
            // Create Asset parameter
            let assetParam = asset.toSCVal()
            let timestampParam = SCValXDR.u64(timestamp)
            
            // Create contract call for price() function
            let contractCall = ContractCallParams(
                contractId: self.oracleAddress,
                functionName: "price",
                functionArguments: [assetParam, timestampParam]
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            
            // Parse Option<PriceData> response
            guard let priceData = try self.parseOptionalPriceData(from: response, assetId: asset.assetId) else {
                return nil
            }
            
            // Get decimals and resolution for proper scaling
            let decimals = try await self.getOracleDecimals()
            let resolution = try await self.getOracleResolution()
            
            return PriceData(
                price: priceData.price,
                timestamp: priceData.timestamp,
                asset: asset,
                decimals: decimals,
                resolution: resolution
            )
        }
    }
    
    /// Get historical prices for an asset
    /// Maps to contract's prices(asset: Asset, records: u32) function
    public func getPriceHistory(asset: OracleAsset, records: UInt32) async throws -> [PriceData]? {
        let assetDescription = asset.description
        BlendLogger.info("🔮 Fetching price history for asset: \(assetDescription), records: \(records)", category: BlendLogger.oracle)
        
        return try await withRetry(maxAttempts: self.maxRetries, delay: self.retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
            
            // Create Asset parameter
            let assetParam = asset.toSCVal()
            let recordsParam = SCValXDR.u32(records)
            
            // Create contract call for prices() function
            let contractCall = ContractCallParams(
                contractId: self.oracleAddress,
                functionName: "prices",
                functionArguments: [assetParam, recordsParam]
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            
            // Parse Option<Vec<PriceData>> response
            return try self.parseOptionalPriceDataVector(from: response, assetId: asset.assetId)
        }
    }
    
    /// Get the last recorded price for an asset
    /// Maps to contract's lastprice(asset: Asset) function
    public func getLastPrice(asset: OracleAsset) async throws -> PriceData? {
        let assetDescription = asset.description
        BlendLogger.info("🔮 Fetching last price for asset: \(assetDescription)", category: BlendLogger.oracle)
        let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
        
        // Create Asset parameter
        let assetParam = asset.toSCVal()
        //let contract = try! StellarContractID.encode(hex: asset.assetId)
        //print("Contract: \(contract)")
        // Create contract call for lastprice() function
        let contractCall = ContractCallParams(
            contractId: self.oracleAddress,
            functionName: "lastprice",
            functionArguments: [assetParam]
        )
        
        let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
        
        // Parse Option<PriceData> response
        guard let priceData = try self.parseOptionalPriceData(from: response, assetId: asset.assetId) else {
            return nil
        }
        
        // Get decimals and resolution for proper scaling
        let decimals = try await self.getOracleDecimals()
        let resolution = try await self.getOracleResolution()
        
        return PriceData(
            price: priceData.price,
            timestamp: priceData.timestamp,
            asset: asset,
            decimals: decimals,
            resolution: resolution
        )
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
            let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
            
            // Create contract call for base() function
            let contractCall = ContractCallParams(
                contractId: self.oracleAddress,
                functionName: "base",
                functionArguments: []
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            
            // Parse Asset response
            let asset = try OracleAsset.fromSCVal(response)
            
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
            let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
            
            // Create contract call for assets() function
            let contractCall = ContractCallParams(
                contractId: self.oracleAddress,
                functionName: "assets",
                functionArguments: []
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            
            // Parse Vec<Asset> response
            guard case .vec(let assets) = response, let oracleAsset = assets else {
                throw OracleError.invalidResponseFormat("Expected vec of assets")
            }
            
            
            
            // Convert each SCVal to OracleAsset
            let oracleAssets: [OracleAsset] = try oracleAsset.compactMap { try OracleAsset.fromSCVal($0) }
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
            let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
            
            // Create contract call for resolution() function
            let contractCall = ContractCallParams(
                contractId: self.oracleAddress,
                functionName: "resolution",
                functionArguments: []
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            
            // Parse u32 response
            guard case .u32(let resolution) = response else {
                throw OracleError.invalidResponseFormat("Expected u32 for resolution")
            }
            
            return Int(resolution)
        }
    }
}

// MARK: - Private Extension for Legacy Support

extension BlendOracleService {
    
    /// Legacy method to comply with BlendOracleServiceProtocol
    /// Converts legacy string-based asset ID to OracleAsset and calls new implementation
    public func getPrice(asset: String) async throws -> PriceData {
        // Convert string asset ID to OracleAsset (assuming Stellar asset)
        let oracleAsset = OracleAsset.stellar(address: asset)
        
        // Use new implementation to get price
        if let priceData = try await getLastPrice(asset: oracleAsset) {
            return priceData
        } else {
            throw OracleError.priceNotAvailable(asset: asset, reason: "No price data available")
        }
    }
    
    /// Legacy method to comply with BlendOracleServiceProtocol
    /// Converts legacy string-based asset IDs to OracleAsset and calls new implementation
    public func getPrices(assets: [String]) async throws -> [String: PriceData] {
        // Convert string asset IDs to OracleAssets (assuming Stellar assets)
        let oracleAssets = assets.map { OracleAsset.stellar(address: $0) }
        
        // Create result dictionary
        var result: [String: PriceData] = [:]
        
        // Fetch prices for each asset
        for asset in oracleAssets {
            if let priceData = try? await getLastPrice(asset: asset) {
                // Use assetId as key for backward compatibility
                result[asset.assetId] = priceData
            }
        }
        
        // Ensure we have at least one price
        guard !result.isEmpty else {
            throw OracleError.noDataAvailable(context: "No prices available for any requested assets")
        }
        
        return result
    }
}
