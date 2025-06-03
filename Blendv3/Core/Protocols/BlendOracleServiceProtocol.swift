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
        let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
      let contractCall = ContractCallParams(
          contractId: self.oracleAddress,
          functionName: "assets",
          functionArguments: []
      )
        
        let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
        dump(response)
        return []
    }
    


    
//    public func getSupportedAssets() async throws -> [String] {
//        <#code#>
//    }
    

    
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
        let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
        
        // Create Asset parameter
      //  let assetParam = asset.toSCVal()
        let timestampParam = SCValXDR.u64(timestamp)
        let assetParam = try SCValXDR.address(SCAddressXDR(contractId: asset.assetId))
        
        let functionArguments = SCValXDR.vec([
            SCValXDR.symbol("Stellar"),
            assetParam
        ])
        
        // Create contract call for price() function
        let contractCall = ContractCallParams(
            contractId: self.oracleAddress,
            functionName: "price",
            functionArguments: [functionArguments, timestampParam]
        )
        
        let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
        
        // Parse Option<PriceData> response
        guard let priceData = try self.parseOptionalPriceData(from: response, asset: asset) else {
            return nil
        }
        
        let asset = try? StellarContractID.toStrKey(priceData.contractID)
     
        return PriceData(
            price: priceData.price,
            timestamp: priceData.timestamp,
            contractID: priceData.contractID,
            decimals: priceData.decimals,
            resolution: priceData.resolution,
            baseAsset: asset ?? ""
        )
      
    }
    /// Get historical prices for an asset
    /// Maps to contract's prices(asset: Asset, records: u32) function
    public func getPriceHistory(asset: OracleAsset, records: UInt32) async throws -> [PriceData]? {
        let assetDescription = asset.description
        BlendLogger.info("🔮 Fetching price history for asset: \(assetDescription) with \(records) records", category: BlendLogger.oracle)
        
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
            
            self.debugLogger.info("🔮 Executing prices() call with arguments: \(String(describing: assetParam)), records: \(records)")
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            self.debugLogger.info("🔮 Prices response received: \(String(describing: response))")
            
            // Parse Option<Vec<PriceData>> response
            return try self.parseOptionalPriceDataVector(from: response, assetId: asset.assetId)
        }
    }
    
    /// Get the last recorded price for an asset
    /// Maps to contract's lastprice(asset: Asset) function
    public func getLastPrice(asset: OracleAsset) async throws -> PriceData? {
        let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
        let assetParam = try SCValXDR.address(SCAddressXDR(contractId: asset.assetId))
        
        let functionArguments = SCValXDR.vec([
            SCValXDR.symbol("Stellar"),
            assetParam
        ])
        
          
        let contractCall = ContractCallParams(
            contractId: self.oracleAddress,
            functionName: "lastprice",
            functionArguments: [functionArguments]
        )
        
        let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
        
        // Parse Option<PriceData> response
        guard let priceData = try self.parseOptionalPriceData(from: response, asset: asset) else {
            return nil
        }
        
        let baseAsset = try? StellarContractID.toStrKey(asset.assetId)

        return PriceData(
            price: priceData.price,
            timestamp: priceData.timestamp,
            contractID: asset.assetId,
            decimals: priceData.decimals,
            resolution: priceData.resolution,
            baseAsset: baseAsset ?? ""
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
    
    private func getAssetSymbol(for address: String) -> String {
        let assetMapping = [
            BlendUSDCConstants.Testnet.usdc: "USDC",
            BlendUSDCConstants.Testnet.xlm: "XLM",
            BlendUSDCConstants.Testnet.blnd: "BLND",
            BlendUSDCConstants.Testnet.weth: "wETH",
            BlendUSDCConstants.Testnet.wbtc: "wBTC"
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
