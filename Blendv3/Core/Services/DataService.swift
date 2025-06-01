//
//  DataService.swift
//  Blendv3
//
//  Data fetching and management service
//

import Foundation
import Combine
import stellarsdk

/// Service for fetching and managing pool data
final class DataService: DataServiceProtocol {
    func fetchPoolStats() async throws {
        
    }
    
    func fetchUserPosition(userId: String) async throws {
        
    }
    
    
    // MARK: - Properties
    
    private let networkService: BlendNetworkServiceProtocol
    private let cacheService: CacheServiceProtocol
    private let errorBoundary: ErrorBoundaryServiceProtocol
    private let validation: ValidationServiceProtocol
    private let configuration: ConfigurationServiceProtocol
    private let logger: DebugLogger
    
    // MARK: - Initialization
    
    init(
        networkService: BlendNetworkServiceProtocol,
        cacheService: CacheServiceProtocol,
        errorBoundary: ErrorBoundaryServiceProtocol,
        validation: ValidationServiceProtocol,
        configuration: ConfigurationServiceProtocol
    ) {
        self.networkService = networkService
        self.cacheService = cacheService
        self.errorBoundary = errorBoundary
        self.validation = validation
        self.configuration = configuration
        self.logger = DebugLogger(subsystem: "com.blendv3.data", category: "DataService")
    }
    
    // MARK: - DataServiceProtocol
    
    func fetchPoolStats() async -> Result<BlendPoolStats, BlendError> {
        logger.debug("Fetching pool stats")
        
        // Check cache first
        if let cached = await cacheService.get("pool_stats", type: BlendPoolStats.self) {
            logger.debug("Returning cached pool stats")
            return .success(cached)
        }
        
        return await errorBoundary.handleWithRetry({
            // Fetch reserve data
            let reserveDataResult = await self.fetchReserveData()
            let reserveData = try reserveDataResult.get()
            
            // Fetch pool config
            let poolConfig = try await self.fetchPoolConfig()
            
            // Calculate pool stats
            let poolData = PoolLevelData(
                totalValueLocked: reserveData.totalSupplied,
                overallUtilization: reserveData.utilizationRate,
                healthScore: Decimal(0.95), // Default health score
                activeReserves: 1 // USDC only for now
            )
            
            let usdcReserveData = USDCReserveData(
                totalSupplied: reserveData.totalSupplied,
                totalBorrowed: reserveData.totalBorrowed,
                utilizationRate: reserveData.utilizationRate,
                supplyApr: reserveData.supplyAPY,
                supplyApy: reserveData.supplyAPY,
                borrowApr: reserveData.borrowAPY,
                borrowApy: reserveData.borrowAPY,
                collateralFactor: Decimal(0.95),
                liabilityFactor: Decimal(1.0526)
            )
            
            let backstopData = BackstopData(
                totalBackstop: Decimal(0), // Would need to fetch from backstop contract
                backstopApr: Decimal(poolConfig.backstopRate) / 10000,
                q4wPercentage: Decimal(0),
                takeRate: Decimal(0.10),
                blndAmount: Decimal(0),
                usdcAmount: Decimal(0)
            )
            
            let stats = BlendPoolStats(
                poolData: poolData,
                usdcReserveData: usdcReserveData,
                backstopData: backstopData,
                lastUpdated: Date()
            )
            
            // Cache the result
            await self.cacheService.set(
                stats,
                key: "pool_stats",
                ttl: self.configuration.getCacheConfiguration().poolStatsCacheTTL
            )
            
            logger.info("Pool stats fetched successfully")
            return stats
        }, maxRetries: configuration.getRetryConfiguration().maxRetries)
    }
    
    func fetchUserPosition(userId: String) async -> Result<UserPositionData, BlendError> {
        logger.debug("Fetching user position for: \(userId)")
        
        // Check cache first
        let cacheKey = "user_position_\(userId)"
        if let cached = await cacheService.get(cacheKey, type: UserPositionData.self) {
            logger.debug("Returning cached user position")
            return .success(cached)
        }
        
        return await errorBoundary.handleWithRetry({
            // Fetch user positions from contract
            let positions = try await self.fetchUserPositions(userId: userId)
            
            // Find USDC position
            guard let usdcPosition = positions.first(where: { position in
                position.assetId == self.configuration.contractAddresses.usdcAddress
            }) else {
                // User has no USDC position
                let emptyPosition = UserPositionData(
                    userId: userId,
                    supplied: 0,
                    borrowed: 0,
                    collateral: 0,
                    availableToBorrow: 0,
                    healthFactor: Decimal.greatestFiniteMagnitude,
                    netAPY: 0,
                    claimableEmissions: 0
                )
                
                await self.cacheService.set(
                    emptyPosition,
                    key: cacheKey,
                    ttl: 30 // Short TTL for empty positions
                )
                
                return emptyPosition
            }
            
            // Calculate health factor
            let healthFactor = try await self.calculateHealthFactor(userId: userId)
            
            // Calculate net APY
            let reserveDataResult = await self.fetchReserveData()
            guard case .success(let reserveData) = reserveDataResult else {
                if case .failure(let error) = reserveDataResult {
                    throw error
                }
                throw BlendError.validation(.invalidResponse)
            }
            
            let netAPY = self.calculateNetAPY(
                supplied: usdcPosition.supplied,
                borrowed: usdcPosition.borrowed,
                supplyAPY: reserveData.supplyAPY,
                borrowAPY: reserveData.borrowAPY
            )
            
            // Get claimable emissions
            let emissions = try await self.fetchClaimableEmissions(userId: userId)
            
            let position = UserPositionData(
                userId: userId,
                supplied: usdcPosition.supplied,
                borrowed: usdcPosition.borrowed,
                collateral: usdcPosition.collateral,
                availableToBorrow: usdcPosition.availableToBorrow,
                healthFactor: healthFactor,
                netAPY: netAPY,
                claimableEmissions: emissions
            )
            
            // Cache the result
            await self.cacheService.set(
                position,
                key: cacheKey,
                ttl: 60 // 1 minute cache for user positions
            )
            
            logger.info("User position fetched successfully")
            return position
        }, maxRetries: configuration.getRetryConfiguration().maxRetries)
    }
    
    func fetchPriceData(assetId: String) async -> Result<PriceData, BlendError> {
        logger.debug("Fetching price data for asset: \(assetId)")
        
        // Check cache first
        let cacheKey = "price_\(assetId)"
        if let cached = await cacheService.get(cacheKey, type: PriceData.self) {
            logger.debug("Returning cached price data")
            return .success(cached)
        }
        
        return await errorBoundary.handleWithRetry({
            // For USDC, return fixed price of 1.0
            if assetId == self.configuration.contractAddresses.usdcAddress {
                let priceData = PriceData(
                    price: Decimal(1.0),
                    timestamp: Date(),
                    assetId: assetId,
                    decimals: 7
                )
                
                // Validate price data
                try self.validation.validateContractResponse(priceData, schema: .priceData)
                
                // Cache the result
                await self.cacheService.set(
                    priceData,
                    key: cacheKey,
                    ttl: self.configuration.getCacheConfiguration().priceCacheTTL
                )
                
                return priceData
            }
            
            // For other assets, fetch from oracle
            let oraclePrice = try await self.fetchOraclePrice(assetId: assetId)
            
            let priceData = PriceData(
                price: oraclePrice.price,
                timestamp: oraclePrice.timestamp,
                assetId: assetId,
                decimals: oraclePrice.decimals
            )
            
            // Validate price data
            try self.validation.validateContractResponse(priceData, schema: .priceData)
            
            // Cache the result
            await self.cacheService.set(
                priceData,
                key: cacheKey,
                ttl: self.configuration.getCacheConfiguration().priceCacheTTL
            )
            
            logger.info("Price data fetched successfully")
            return priceData
        }, maxRetries: configuration.getRetryConfiguration().maxRetries)
    }
    
    func fetchReserveData() async -> Result<ReserveDataResult, BlendError> {
        logger.debug("Fetching reserve data")
        
        // Check cache first
        let cacheKey = "reserve_data_usdc"
        if let cached = await cacheService.get(cacheKey, type: ReserveDataResult.self) {
            logger.debug("Returning cached reserve data")
            return .success(cached)
        }
        
        return await errorBoundary.handleWithRetry({
            // Fetch from contract
            let reserveData = try await self.fetchReserveDataFromContract()
            
            // Validate reserve data
            try self.validation.validateContractResponse(reserveData, schema: .reserveData)
            
            // Cache the result
            await self.cacheService.set(
                reserveData,
                key: cacheKey,
                ttl: self.configuration.getCacheConfiguration().reserveDataCacheTTL
            )
            
            logger.info("Reserve data fetched successfully")
            return reserveData
        }, maxRetries: configuration.getRetryConfiguration().maxRetries)
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchReserveDataFromContract() async throws -> ReserveDataResult {
        logger.debug("Fetching reserve data from contract")
        
        let response = try await networkService.invokeContractFunction(
            contractId: configuration.contractAddresses.poolAddress,
            functionName: "get_reserve",
            args: [
                SCValXDR.address(try SCAddressXDR(contractId: configuration.contractAddresses.usdcAddress))
            ]
        )
        
        // Parse response
        guard case .map(let reserveMap) = response else {
            throw BlendError.validation(.invalidResponse)
        }
        
        // Extract values from map
        var totalSupplied: Decimal = 0
        var totalBorrowed: Decimal = 0
        var supplyRate: Decimal = 0
        var borrowRate: Decimal = 0
        
        if let entries = reserveMap {
            for entry in entries {
                let key = entry.key
                let value = entry.val
                guard case .symbol(let symbol) = key else { continue }
                
                switch symbol {
                case "d_supply":
                    if case .i128(let i128) = value {
                        totalSupplied = try validation.validateI128(i128) / Decimal(10_000_000)
                    }
                case "b_supply":
                    if case .i128(let i128) = value {
                        totalBorrowed = try validation.validateI128(i128) / Decimal(10_000_000)
                    }
                case "ir_mod":
                    if case .u32(let rate) = value {
                        supplyRate = Decimal(rate) / 10000 // Convert basis points to percentage
                    }
                case "b_rate":
                    if case .u32(let rate) = value {
                        borrowRate = Decimal(rate) / 10000 // Convert basis points to percentage
                    }
                default:
                    break
                }
            }
        }
        
        // Calculate utilization rate
        let utilizationRate = totalSupplied > 0 ? totalBorrowed / totalSupplied : 0
        
        return ReserveDataResult(
            totalSupplied: totalSupplied,
            totalBorrowed: totalBorrowed,
            supplyAPY: supplyRate,
            borrowAPY: borrowRate,
            utilizationRate: utilizationRate
        )
    }
    
    private func fetchPoolConfig() async throws -> PoolConfig {
        logger.debug("Fetching pool config")
        
        let response = try await networkService.invokeContractFunction(
            contractId: configuration.contractAddresses.poolAddress,
            functionName: "pool_config",
            args: []
        )
        
        // Parse response
        guard case .map(let configMap) = response else {
            throw BlendError.validation(.invalidResponse)
        }
        
        var backstopRate: UInt32 = 0
        var maxPositions: UInt32 = 10
        var status: UInt32 = 0
        
        if let entries = configMap {
            for entry in entries {
                let key = entry.key
                let value = entry.val
                guard case .symbol(let symbol) = key else { continue }
                
                switch symbol {
                case "backstop_rate":
                    if case .u32(let rate) = value {
                        backstopRate = rate
                    }
                case "max_positions":
                    if case .u32(let max) = value {
                        maxPositions = max
                    }
                case "status":
                    if case .u32(let s) = value {
                        status = s
                    }
                default:
                    break
                }
            }
        }
        
        return PoolConfig(
            backstopRate: backstopRate,
            maxPositions: maxPositions,
            status: status
        )
    }
    
    private func fetchUserPositions(userId: String) async throws -> [Blendv3.AssetPosition] {
        logger.debug("Fetching user positions")
        
        let response = try await networkService.invokeContractFunction(
            contractId: configuration.contractAddresses.poolAddress,
            functionName: "get_positions",
            args: [
                SCValXDR.address(try SCAddressXDR(accountId: userId))
            ]
        )
        
        // Parse response
        guard case .map(let positionsMap) = response else {
            throw BlendError.validation(.invalidResponse)
        }
        
        var positions: [AssetPosition] = []
        
        if let entries = positionsMap {
            for entry in entries {
                let key = entry.key
                let value = entry.val
                guard case .address(let assetAddress) = key,
                      case .map(let positionData) = value else { continue }
                
                var supplied: Decimal = 0
                var borrowed: Decimal = 0
                var collateral: Decimal = 0
                
                for entry in positionData ?? [] {
                    guard case .symbol(let symbol) = entry.key else { continue }
                    let posValue = entry.val
                    
                    switch symbol {
                    case "supply":
                        if case .i128(let i128) = posValue {
                            supplied = try validation.validateI128(i128) / Decimal(10_000_000)
                        }
                    case "liabilities":
                        if case .vec(let liabilities) = posValue {
                            // Sum all liabilities
                            for liability in liabilities ?? [] {
                                if case .i128(let i128) = liability {
                                    borrowed += try validation.validateI128(i128) / Decimal(10_000_000)
                                }
                            }
                        }
                    case "collateral":
                        if case .i128(let i128) = posValue {
                            collateral = try validation.validateI128(i128) / Decimal(10_000_000)
                        }
                    default:
                        break
                    }
                }
                
                // Calculate available to borrow based on collateral
                let availableToBorrow = max(0, collateral * Decimal(0.75) - borrowed) // 75% LTV
                
                positions.append(AssetPosition(
                    assetId: assetAddress.contractId ?? "",
                    supplied: supplied,
                    borrowed: borrowed,
                    collateral: collateral,
                    availableToBorrow: availableToBorrow
                ))
            }
        }
        
        return positions
    }
    
    private func calculateHealthFactor(userId: String) async throws -> Decimal {
        logger.debug("Calculating health factor")
        
        let response = try await networkService.invokeContractFunction(
            contractId: configuration.contractAddresses.poolAddress,
            functionName: "user_health",
            args: [
                SCValXDR.address(try SCAddressXDR(accountId: userId))
            ]
        )
        
        // Parse response - expecting a u32 percentage (10000 = 100%)
        guard case .u32(let healthValue) = response else {
            throw BlendError.validation(.invalidResponse)
        }
        
        // Convert to decimal (1.0 = 100% health)
        return Decimal(healthValue) / 10000
    }
    
    private func fetchClaimableEmissions(userId: String) async throws -> Decimal {
        logger.debug("Fetching claimable emissions")
        
        let response = try await networkService.invokeContractFunction(
            contractId: configuration.contractAddresses.emissionsAddress,
            functionName: "get_claimable",
            args: [
                SCValXDR.address(try SCAddressXDR(accountId: userId)),
                SCValXDR.u32(0) // Pool ID
            ]
        )
        
        // Parse response
        guard case .i128(let i128) = response else {
            // No emissions available
            return 0
        }
        
        return try validation.validateI128(i128) / Decimal(10_000_000)
    }
    
    private func fetchOraclePrice(assetId: String) async throws -> OraclePrice {
        logger.debug("Fetching oracle price for asset: \(assetId)")
        
        // This would normally call the oracle contract
        // For now, return mock data
        return OraclePrice(
            price: Decimal(1.0),
            timestamp: Date(),
            decimals: 7
        )
    }
    
    private func calculateNetAPY(
        supplied: Decimal,
        borrowed: Decimal,
        supplyAPY: Decimal,
        borrowAPY: Decimal
    ) -> Decimal {
        guard supplied > 0 || borrowed > 0 else { return 0 }
        
        let supplyEarnings = supplied * supplyAPY / 100
        let borrowCosts = borrowed * borrowAPY / 100
        let netEarnings = supplyEarnings - borrowCosts
        let totalValue = supplied - borrowed
        
        guard totalValue > 0 else { return -borrowAPY }
        
        return (netEarnings / totalValue) * 100
    }
    
    private func mapPoolStatus(_ status: UInt32) -> String {
        switch status {
        case 0: return "Active"
        case 1: return "Frozen"
        case 2: return "Paused"
        case 3: return "Shutdown"
        default: return "Unknown"
        }
    }
}
// End of DataService implementation
