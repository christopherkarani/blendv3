//
//  BlendVault.swift
//  Blendv3
//
//  Refactored Blend Vault - Primary API for blend liquidity smart contract interactions
//

import Foundation
@preconcurrency import stellarsdk

/// Primary interface for interacting with Blend Protocol liquidity pools and backstop
@MainActor
public final class BlendVault: ObservableObject, Sendable {

    // MARK: - Private Properties

    private let oracleService: BlendOracleServiceProtocol
    private let poolService: PoolServiceProtocol
    private let backstopService: BackstopContractServiceProtocol
    private let cacheService: CacheServiceProtocol
    private let networkService: NetworkService
    private let assetService: BlendAssetServiceProtocol
    private let userService: UserPositionService
    
    private let keyPair: KeyPair
    private let userAddress: String
    private let config: BlendVaultConfig
    
    // Add the new financial calculator
    private let financialCalculator = BlendProtocolFinancialCalculator()
    
    // MARK: - Public Initialization
    
    /// Initialize BlendVault with KeyPair and configuration
    /// - Parameters:
    ///   - keyPair: User's KeyPair for signing transactions
    ///   - userAddress: User's account address
    ///   - config: Configuration for network, pools, and caching
    public init(
        keyPair: KeyPair,
        userAddress: String,
        config: BlendVaultConfig
    ) async throws {
        self.keyPair = keyPair
        self.userAddress = userAddress
        self.config = config
        
        // Initialize services
        self.networkService = NetworkService(keyPair: keyPair)
        self.cacheService = CacheService()
        
        // Initialize pool service
        self.poolService = PoolService(networkService: networkService)
        
        // Initialize oracle service
        let oracleAddress = config.network == .testnet ? BlendConstants.Testnet.oracle : BlendConstants.Mainnet.oracle
        self.oracleService = BlendOracleService(
            poolId: oracleAddress,
            cacheService: cacheService,
            networkService: networkService,
            sourceKeyPair: keyPair
        )
        
        // Initialize asset service
        self.assetService = BlendAssetService(
            poolID: config.primaryPoolID,
            networkService: networkService
        )
        
        // Initialize user position service
        self.userService = UserPositionService(
            cacheService: cacheService,
            networkService: networkService,
            contractID: config.primaryPoolID,
            userAccountID: userAddress
        )
        
        // Initialize backstop service
        let backstopAddress = config.network == .testnet ? BlendConstants.Testnet.backstop : BlendConstants.Mainnet.backstop
        let rpcEndpoint = config.network == .testnet ? BlendConstants.RPC.testnet : BlendConstants.RPC.mainnet
        
        let backstopConfig = BackstopServiceConfig(
            contractAddress: backstopAddress,
            rpcUrl: rpcEndpoint,
            network: config.network
        )
        
        self.backstopService = BackstopContractService(
            networkService: networkService,
            cacheService: cacheService,
            config: backstopConfig
        )
        
        // Validate initialization
        try await validateInitialization()
    }
    
    // MARK: - Pool Statistics Methods
    
    /// Get comprehensive statistics for a specific pool or the primary pool
    /// - Parameter poolID: Pool identifier, uses primary pool if nil
    /// - Returns: Pool statistics including reserves, utilization, and backstop data
    public func getPoolStats(poolID: String? = nil) async throws -> PoolStats {
        let targetPoolID = poolID ?? config.primaryPoolID
        
        // Get pool configuration
        let poolConfig = try await poolService.fetchPoolConfig(contractId: targetPoolID)
        
        // Get pool assets
        let assetService = BlendAssetService(poolID: targetPoolID, networkService: networkService)
        let assets = try await assetService.getAssets()
        let assetData = try await assetService.getAll(assets: assets)
        
        // Get oracle prices
        let prices = try await oracleService.getPrices(assets: assets)
        let priceMap = Dictionary(uniqueKeysWithValues: zip(assets.map { $0.assetId }, prices))
        
        // Get backstop stats for this pool
        let backstopStats = try await getBackstopStatsForPool(poolID: targetPoolID)
        
        // Calculate pool reserves
        let reserves = try await calculatePoolReserves(
            assets: assetData,
            prices: priceMap,
            backstopRate: Decimal(poolConfig.backstopRate)
        )
        
        // Calculate total values
        let totalSuppliedUSD = reserves.reduce(Decimal.zero) { $0 + $1.totalSuppliedUSD }
        let totalBorrowedUSD = reserves.reduce(Decimal.zero) { $0 + $1.totalBorrowedUSD }
        let utilizationRate = totalSuppliedUSD > 0 ? totalBorrowedUSD / totalSuppliedUSD : Decimal.zero
        
        return PoolStats(
            poolID: targetPoolID,
            name: "Pool \(targetPoolID.suffix(6))", // Can be enhanced with actual pool names
            totalSuppliedUSD: totalSuppliedUSD,
            totalBorrowedUSD: totalBorrowedUSD,
            utilizationRate: utilizationRate,
            reserves: reserves,
            backstopStats: backstopStats,
            lastUpdated: Date()
        )
    }
    
    /// Get statistics for all configured pools
    /// - Returns: Array of pool statistics
    public func getAllPoolsStats() async throws -> [PoolStats] {
        return try await withThrowingTaskGroup(of: PoolStats.self) { group in
            for poolID in config.poolIDs {
                group.addTask {
                    try await self.getPoolStats(poolID: poolID)
                }
            }
            
            var results: [PoolStats] = []
            for try await poolStat in group {
                results.append(poolStat)
            }
            return results
        }
    }
    
    /// Get user-specific statistics and positions
    /// - Returns: User statistics including positions and backstop data
    public func getUserStats() async throws -> UserStats {
        // Get user positions
        let positions = try await userService.getPositions()
        
        // Get user backstop stats
        let backstopStats = try await getUserBackstopStats()
        
        // Convert positions to user-friendly format
        let userPositions = try await convertToUserPositions(positions)
        
        // Calculate aggregate values
        let totalCollateral = userPositions.reduce(Decimal.zero) { $0 + $1.collateralValue }
        let totalBorrowed = userPositions.reduce(Decimal.zero) { $0 + $1.borrowValue }
        
        // Calculate health factor (simplified - can be enhanced)
        let healthFactor = totalBorrowed > 0 ? totalCollateral / totalBorrowed : Decimal(999)
        
        // Calculate net APY (simplified - can be enhanced)
        let netAPY = calculateNetAPY(positions: userPositions)
        
        return UserStats(
            userAddress: userAddress,
            positions: userPositions,
            backstopStats: backstopStats,
            totalCollateralUSD: totalCollateral,
            totalBorrowedUSD: totalBorrowed,
            healthFactor: healthFactor,
            netAPY: netAPY,
            lastUpdated: Date()
        )
    }
    
    /// Get statistics for a specific asset
    /// - Parameter assetID: Asset contract identifier
    /// - Returns: Asset statistics across all pools
    public func getAssetStats(assetID: String) async throws -> AssetStats {
        // Get asset information
        let asset = try await getAssetByContractID(contractID: assetID)
        
        // Gather stats from all pools that contain this asset
        var poolStats: [AssetPoolStats] = []
        var totalSupplied = Decimal.zero
        var totalBorrowed = Decimal.zero
        var supplyAPYSum = Decimal.zero
        var borrowAPYSum = Decimal.zero
        var poolCount = 0
        
        for poolID in config.poolIDs {
            do {
                let assetService = BlendAssetService(poolID: poolID, networkService: networkService)
                let poolAssets = try await assetService.getAssets()
                
                // Check if this asset exists in this pool
                guard poolAssets.contains(where: { 
                    if case .stellar(let address) = $0 {
                        return address == assetID
                    }
                    return false
                }) else {
                    continue
                }
                
                // Get asset data for this pool
                let assetData = try await assetService.getAll(assets: poolAssets)
                guard let specificAssetData = assetData.first(where: { $0.assetId == assetID }) else {
                    continue
                }
                
                // Get pool config for backstop rate - convert to fixed-point for calculations
                let poolConfig = try await poolService.fetchPoolConfig(contractId: poolID)
                let backstopRate = FixedMath.toFixed(value: Double(poolConfig.backstopRate), decimals: 7)
                
                // Calculate APYs using the new unified financial calculator
                let supplyAPY = financialCalculator.calculateAPYFromAssetData(
                    specificAssetData,
                    backstopTakeRate: backstopRate,
                    isSupply: true
                )
                let borrowAPY = financialCalculator.calculateAPYFromAssetData(
                    specificAssetData,
                    backstopTakeRate: backstopRate,
                    isSupply: false
                )
                
                // Use human-readable values for supply and borrow amounts
                let supplied = specificAssetData.suppliedHuman
                let borrowed = specificAssetData.borrowedHuman
                let utilization = supplied > Decimal.zero ? borrowed / supplied : Decimal.zero
                
                // Add to pool stats
                let poolStat = AssetPoolStats(
                    poolID: poolID,
                    totalSupplied: supplied,
                    totalBorrowed: borrowed,
                    supplyAPY: supplyAPY,
                    borrowAPY: borrowAPY,
                    utilizationRate: utilization
                )
                poolStats.append(poolStat)
                
                // Aggregate totals
                totalSupplied += supplied
                totalBorrowed += borrowed
                supplyAPYSum += supplyAPY
                borrowAPYSum += borrowAPY
                poolCount += 1
                
            } catch {
                // Skip pools where we can't get data
                continue
            }
        }
        
        // Calculate averages
        let averageSupplyAPY = poolCount > 0 ? supplyAPYSum / Decimal(poolCount) : Decimal.zero
        let averageBorrowAPY = poolCount > 0 ? borrowAPYSum / Decimal(poolCount) : Decimal.zero
        let overallUtilization = totalSupplied > 0 ? totalBorrowed / totalSupplied : Decimal.zero
        
        return AssetStats(
            asset: asset,
            pools: poolStats,
            totalSuppliedAcrossPools: totalSupplied,
            totalBorrowedAcrossPools: totalBorrowed,
            averageSupplyAPY: averageSupplyAPY,
            averageBorrowAPY: averageBorrowAPY,
            utilizationRate: overallUtilization
        )
    }
    
    /// Get comprehensive protocol statistics
    /// - Returns: Overall Blend protocol statistics
    public func getAllStats() async throws -> BlendStats {
        let poolsStats = try await getAllPoolsStats()
        
        // Aggregate values
        let totalSupplied = poolsStats.reduce(Decimal.zero) { $0 + $1.totalSuppliedUSD }
        let totalBorrowed = poolsStats.reduce(Decimal.zero) { $0 + $1.totalBorrowedUSD }
        let totalBackstop = poolsStats.reduce(Decimal.zero) { $0 + $1.backstopStats.totalBackstopLiquidity }
        
        // Calculate utilization rates
        let overallUtilization = totalSupplied > 0 ? totalBorrowed / totalSupplied : Decimal.zero
        let backstopUtilization = poolsStats.reduce(Decimal.zero) { $0 + $1.backstopStats.utilizationRate } / Decimal(poolsStats.count)
        
        // Find APY range
        let apyValues = poolsStats.map { $0.backstopStats.backstopAPY }
        let minAPY = apyValues.min() ?? Decimal.zero
        let maxAPY = apyValues.max() ?? Decimal.zero
        
        // Count unique assets
        let uniqueAssets = Set(poolsStats.flatMap { $0.reserves.map { $0.assetID } })
        
        return BlendStats(
            totalSuppliedUSD: totalSupplied,
            totalBorrowedUSD: totalBorrowed,
            totalBackstopLiquidity: totalBackstop,
            overallUtilization: overallUtilization,
            backstopUtilization: backstopUtilization,
            backstopAPYRange: APYRange(min: minAPY, max: maxAPY),
            numberOfPools: poolsStats.count,
            numberOfAssets: uniqueAssets.count,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Pool Operations
    
    /// Deposit assets to a liquidity pool
    /// - Parameters:
    ///   - amount: Amount to deposit
    ///   - assetID: Asset contract identifier
    ///   - poolID: Target pool identifier, uses primary pool if nil
    /// - Returns: Transaction result with details
    public func depositToPool(amount: Decimal, assetID: String, poolID: String? = nil) async throws -> TransactionResult {
        let targetPoolID = poolID ?? config.primaryPoolID
        
        // Validate amount
        guard amount > 0 else {
            throw BlendVaultError.invalidAmount("Amount must be greater than zero")
        }
        
        // Validate asset is supported
        let assets = try await getAvailableAssets()
        guard assets.contains(where: { $0.contractAddress == assetID }) else {
            throw BlendVaultError.assetNotSupported(assetID)
        }
        
        // Use UserPositionService to submit the deposit
        do {
            // RequestType 0 = Supply (without collateral)
            // RequestType 1 = SupplyCollateral
            let requestType: UInt32 = 1 // Default to supply as collateral
            try await userService.submit(
                requestType: requestType,
                amount: amount.description,
                asset: assetID
            )
            
            // Invalidate caches
            await invalidateCachesAfterTransaction()
            
            return TransactionResult(
                transactionHash: "pending", // Would be returned by submit
                success: true,
                operation: .poolDeposit,
                amount: amount,
                assetID: assetID,
                poolID: targetPoolID,
                gasUsed: nil,
                timestamp: Date(),
                details: nil
            )
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Withdraw assets from a liquidity pool
    /// - Parameters:
    ///   - amount: Amount to withdraw
    ///   - assetID: Asset contract identifier
    ///   - poolID: Source pool identifier, uses primary pool if nil
    /// - Returns: Transaction result with details
    public func withdrawFromPool(amount: Decimal, assetID: String, poolID: String? = nil) async throws -> TransactionResult {
        let targetPoolID = poolID ?? config.primaryPoolID
        
        // Validate amount
        guard amount > 0 else {
            throw BlendVaultError.invalidAmount("Amount must be greater than zero")
        }
        
        // Check user has sufficient balance
        let userStats = try await getUserStats()
        let hasBalance = userStats.positions.contains { position in
            position.poolID == targetPoolID &&
            position.suppliedAssets.contains { $0.assetID == assetID && $0.amount >= amount }
        }
        
        guard hasBalance else {
            throw BlendVaultError.insufficientBalance(required: amount, available: Decimal.zero)
        }
        
        // Use UserPositionService to submit the withdrawal
        do {
            // RequestType 2 = Withdraw
            // RequestType 3 = WithdrawCollateral
            let requestType: UInt32 = 3 // Default to withdraw collateral
            try await userService.submit(
                requestType: requestType,
                amount: amount.description,
                asset: assetID
            )
            
            // Invalidate caches
            await invalidateCachesAfterTransaction()
            
            return TransactionResult(
                transactionHash: "pending",
                success: true,
                operation: .poolWithdraw,
                amount: amount,
                assetID: assetID,
                poolID: targetPoolID,
                gasUsed: nil,
                timestamp: Date(),
                details: nil
            )
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Estimate the cost of a pool deposit
    /// - Parameters:
    ///   - amount: Amount to deposit
    ///   - assetID: Asset contract identifier
    ///   - poolID: Target pool identifier, uses primary pool if nil
    /// - Returns: Transaction estimate with costs and warnings
    public func estimatePoolDeposit(amount: Decimal, assetID: String, poolID: String? = nil) async throws -> TransactionEstimate {
        // Simplified estimation - can be enhanced with actual simulation
        return TransactionEstimate(
            operation: .poolDeposit,
            estimatedGas: 1000000, // 1M stroops
            estimatedCost: Decimal(0.1), // 0.1 XLM
            estimatedOutput: amount, // Same amount in pool tokens
            requiredTokens: [assetID: amount],
            healthFactorAfter: nil,
            warnings: []
        )
    }
    
    /// Estimate the cost of a pool withdrawal
    /// - Parameters:
    ///   - amount: Amount to withdraw
    ///   - assetID: Asset contract identifier
    ///   - poolID: Source pool identifier, uses primary pool if nil
    /// - Returns: Transaction estimate with costs and warnings
    public func estimatePoolWithdrawal(amount: Decimal, assetID: String, poolID: String? = nil) async throws -> TransactionEstimate {
        // Check if withdrawal would affect health factor
        let userStats = try await getUserStats()
        var warnings: [String] = []
        
        if userStats.healthFactor < 2.0 {
            warnings.append("This withdrawal may significantly reduce your health factor")
        }
        
        return TransactionEstimate(
            operation: .poolWithdraw,
            estimatedGas: 1000000,
            estimatedCost: Decimal(0.1),
            estimatedOutput: amount,
            requiredTokens: nil,
            healthFactorAfter: userStats.healthFactor * 0.9, // Estimate
            warnings: warnings
        )
    }
    
    // MARK: - Backstop Operations
    
    /// Deposit to backstop with automatic BLND/USDC token handling
    /// - Parameters:
    ///   - amount: Total amount to deposit (will be split between BLND/USDC)
    ///   - poolID: Target pool backstop, uses primary pool if nil
    /// - Returns: Transaction result with details
    public func depositToBackstop(amount: Decimal, poolID: String? = nil) async throws -> TransactionResult {
        let targetPoolID = poolID ?? config.primaryPoolID
        
        // Validate amount
        guard amount > 0 else {
            throw BlendVaultError.invalidAmount("Amount must be greater than zero")
        }
        
        // Get current backstop composition using human-readable values
        let backstopStats = try await getBackstopStatsForPool(poolID: targetPoolID)
        
        // Calculate required tokens based on current BLND/USDC composition
        // Use individual token balances to determine the ratio
        let totalTokenBalance = backstopStats.blndBalance + backstopStats.usdcBalance
        let blndRatio = totalTokenBalance > 0 ? backstopStats.blndBalance / totalTokenBalance : Decimal(0.8) // Default 80% BLND
        let usdcRatio = Decimal(1) - blndRatio
        
        let requiredBLND = amount * blndRatio
        let requiredUSDC = amount * usdcRatio
        
        // Execute backstop deposit
        do {
            let result = try await backstopService.deposit(
                from: userAddress,
                poolAddress: targetPoolID,
                amount: amount
            )
            
            // Invalidate caches
            await invalidateCachesAfterTransaction()
            
            // Convert shares received to human-readable format
            let sharesHuman = convertBlendFixedPointToHuman(value: Decimal(Double(result.sharesReceived)))
            
            return TransactionResult(
                transactionHash: result.transactionHash ?? "pending",
                success: true,
                operation: .backstopDeposit,
                amount: amount,
                assetID: nil,
                poolID: targetPoolID,
                gasUsed: nil,
                timestamp: Date(),
                details: TransactionDetails(
                    sharesReceived: sharesHuman,
                    tokensUsed: ["BLND": requiredBLND, "USDC": requiredUSDC],
                    newHealthFactor: nil,
                    rewards: nil
                )
            )
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Queue a backstop withdrawal
    /// - Parameters:
    ///   - amount: Amount of shares to withdraw
    ///   - poolID: Source pool backstop, uses primary pool if nil
    /// - Returns: Transaction result with queue details
    public func queueBackstopWithdrawal(amount: Decimal, poolID: String? = nil) async throws -> TransactionResult {
        let targetPoolID = poolID ?? config.primaryPoolID
        
        // Queue the withdrawal
        do {
            let _ = try await backstopService.queueWithdrawal(
                from: userAddress,
                poolAddress: targetPoolID,
                amount: amount
            )
            
            // Invalidate caches
            await invalidateCachesAfterTransaction()
            
            return TransactionResult(
                transactionHash: "pending",
                success: true,
                operation: .backstopWithdraw,
                amount: amount,
                assetID: nil,
                poolID: targetPoolID,
                gasUsed: nil,
                timestamp: Date(),
                details: TransactionDetails(
                    sharesReceived: nil,
                    tokensUsed: nil,
                    newHealthFactor: nil,
                    rewards: nil
                )
            )
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Dequeue a backstop withdrawal
    /// - Parameters:
    ///   - amount: Amount to dequeue
    ///   - poolID: Pool backstop identifier, uses primary pool if nil
    /// - Returns: Transaction result
    public func dequeueBackstopWithdrawal(amount: Decimal, poolID: String? = nil) async throws -> TransactionResult {
        let targetPoolID = poolID ?? config.primaryPoolID
        
        do {
            try await backstopService.dequeueWithdrawal(
                from: userAddress,
                poolAddress: targetPoolID,
                amount: amount
            )
            
            // Invalidate caches
            await invalidateCachesAfterTransaction()
            
            return TransactionResult(
                transactionHash: "pending",
                success: true,
                operation: .backstopWithdraw,
                amount: amount,
                assetID: nil,
                poolID: targetPoolID,
                gasUsed: nil,
                timestamp: Date(),
                details: nil
            )
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Execute a matured backstop withdrawal
    /// - Parameters:
    ///   - amount: Amount to withdraw
    ///   - poolID: Source pool backstop, uses primary pool if nil
    /// - Returns: Transaction result with withdrawn amount
    public func executeBackstopWithdrawal(amount: Decimal, poolID: String? = nil) async throws -> TransactionResult {
        let targetPoolID = poolID ?? config.primaryPoolID
        
        do {
            let result = try await backstopService.withdraw(
                from: userAddress,
                poolAddress: targetPoolID,
                amount: amount
            )
            
            // Invalidate caches
            await invalidateCachesAfterTransaction()
            
            // Convert withdrawn amount to human-readable format
            let withdrawnAmountHuman = convertBlendFixedPointToHuman(value: Decimal(Double(result.amountWithdrawn)))
            
            return TransactionResult(
                transactionHash: result.transactionHash ?? "pending",
                success: true,
                operation: .backstopWithdraw,
                amount: withdrawnAmountHuman,
                assetID: nil,
                poolID: targetPoolID,
                gasUsed: nil,
                timestamp: Date(),
                details: nil
            )
        } catch {
            throw mapServiceError(error)
        }
    }
    
    /// Claim backstop rewards from multiple pools in a single transaction
    /// - Parameter poolIDs: Pool identifiers to claim from, uses all configured pools if nil
    /// - Returns: Transaction result with claimed rewards
    public func claimBackstopRewards(poolIDs: [String]? = nil) async throws -> TransactionResult {
        let targetPools = poolIDs ?? config.poolIDs
        
        do {
            let result = try await backstopService.claim(
                from: userAddress,
                poolAddresses: targetPools,
                to: userAddress
            )
            
            // Invalidate caches
            await invalidateCachesAfterTransaction()
            
            // Convert claimed rewards to human-readable format
            let claimedRewardsHuman = convertBlendFixedPointToHuman(value: Decimal(Double(result.totalClaimed)))
            
            return TransactionResult(
                transactionHash: result.transactionHash ?? "pending",
                success: true,
                operation: .backstopClaim,
                amount: claimedRewardsHuman,
                assetID: "BLND",
                poolID: targetPools.first ?? "",
                gasUsed: nil,
                timestamp: Date(),
                details: TransactionDetails(
                    sharesReceived: nil,
                    tokensUsed: nil,
                    newHealthFactor: nil,
                    rewards: claimedRewardsHuman
                )
            )
        } catch {
            throw mapServiceError(error)
        }
    }
    
    // MARK: - Asset & Utility Methods
    
    /// Get all available assets across configured pools
    /// - Returns: Array of assets with metadata
    public func getAvailableAssets() async throws -> [Asset] {
        var allAssets: [Asset] = []
        let processedAssetIDs = NSMutableSet()
        
        // Gather assets from all pools
        for poolID in config.poolIDs {
            let assetService = BlendAssetService(poolID: poolID, networkService: networkService)
            let poolAssets = try await assetService.getAssets()
            
            for oracleAsset in poolAssets {
                guard case .stellar(let address) = oracleAsset else { continue }
                
                // Skip if already processed
                if processedAssetIDs.contains(address) { continue }
                processedAssetIDs.add(address)
                
                // Get asset metadata
                let contractAddress = try StellarContractID.toStrKey(address)
                let metadata = try await networkService.loadTokenMetadata(contractId: contractAddress)
                
                // Get price from oracle
                let priceData = try? await oracleService.getPrice(asset: oracleAsset)
                
                let asset = Asset(
                    id: address,
                    contractAddress: contractAddress,
                    symbol: metadata.symbol,
                    name: metadata.name,
                    decimals: metadata.decimals,
                    price: priceData?.price ?? Decimal.zero,
                    totalSupply: nil,
                    iconURL: nil
                )
                
                allAssets.append(asset)
            }
        }
        
        return allAssets
    }
    
    /// Get asset information by contract ID
    /// - Parameter contractID: Asset contract identifier
    /// - Returns: Asset with metadata
    public func getAssetByContractID(contractID: String) async throws -> Asset {
        let assets = try await getAvailableAssets()
        guard let asset = assets.first(where: { $0.contractAddress == contractID }) else {
            throw BlendVaultError.assetNotSupported(contractID)
        }
        return asset
    }
    
    /// Refresh user positions and return updated stats
    /// - Returns: Updated user statistics
    public func refreshUserPositions() async throws -> UserStats {
        // Clear user-related caches
        await cacheService.clear()
        
        // Fetch fresh data
        return try await getUserStats()
    }
    
    // MARK: - Backstop Stats Methods
    
    /// Get backstop statistics for a specific pool
    /// - Parameter poolID: Pool identifier, uses primary pool if nil
    /// - Returns: Backstop statistics
    @available(macOS 15.0, iOS 18.0, *)
    public func getBackstopStats(poolID: String? = nil) async throws -> BackstopStats {
        let targetPoolID = poolID ?? config.primaryPoolID
        return try await getBackstopStatsForPool(poolID: targetPoolID)
    }
    
    /// Get backstop statistics for all configured pools
    /// - Returns: Array of backstop statistics
    @available(macOS 15.0, iOS 18.0, *)
    public func getAllBackstopStats() async throws -> [BackstopStats] {
        return try await withThrowingTaskGroup(of: BackstopStats.self) { group in
            for poolID in config.poolIDs {
                group.addTask {
                    try await self.getBackstopStatsForPool(poolID: poolID)
                }
            }
            
            var results: [BackstopStats] = []
            for try await stat in group {
                results.append(stat)
            }
            return results
        }
    }
    
    /// Get user's backstop statistics
    /// - Returns: User backstop statistics
    @available(macOS 15.0, iOS 18.0, *)
    public func getUserBackstopStats() async throws -> UserBackstopStats {
        var positions: [UserBackstopPosition] = []
        var totalValue = Decimal.zero
        let totalRewards = Decimal.zero
        var totalQueued = Decimal.zero
        var earliestWithdrawal: Date?
        
        for poolID in config.poolIDs {
            let balance = try await backstopService.getUserBalance(pool: poolID, user: userAddress)
            
            if balance.shares > 0 || !balance.q4w.isEmpty {
                // Convert shares to human-readable format using FixedMath
                let sharesHuman = FixedMath.toFloat(value: Decimal(Double(balance.shares)), decimals: 7)
                
                // Calculate position value using the total backstop value and user's share percentage
                let poolData = try await backstopService.getPoolData(pool: poolID)
                let humanPoolData = poolData.humanReadable
                
                // Total backstop value = tokens × token spot price
                let totalBackstopValue = humanPoolData.tokens * humanPoolData.tokenSpotPrice
                let totalShares = FixedMath.toFloat(value: Decimal(Double(poolData.shares)), decimals: 7)
                
                // Calculate user's position value based on their share percentage
                let positionValue = totalShares > 0 ? (sharesHuman / totalShares) * totalBackstopValue : Decimal.zero
                totalValue += positionValue
                
                // Calculate queued withdrawals using FixedMath
                var queuedWithdrawals: [QueuedWithdrawal] = []
                var poolQueuedAmount = Decimal.zero
                
                for q4w in balance.q4w {
                    let queuedAmountHuman = FixedMath.toFloat(value: Decimal(Double(q4w.amount)), decimals: 7)
                    poolQueuedAmount += queuedAmountHuman
                    
                    // Track earliest withdrawal
                    if earliestWithdrawal == nil || q4w.expirationDate < earliestWithdrawal! {
                        earliestWithdrawal = q4w.expirationDate
                    }
                    
                    let queuedWithdrawal = QueuedWithdrawal(
                        poolID: poolID,
                        amount: queuedAmountHuman,
                        queuedAt: Date(), // Approximation - actual queue time not available
                        availableAt: q4w.expirationDate,
                        estimatedValue: queuedAmountHuman, // Simplified - should use share price conversion
                        canExecuteNow: q4w.isExpired
                    )
                    
                    queuedWithdrawals.append(queuedWithdrawal)
                }
                
                totalQueued += poolQueuedAmount
                
                // Calculate backstop APY from pool data
                let backstopStats = try await getBackstopStatsForPool(poolID: poolID)
                
                let position = UserBackstopPosition(
                    poolID: poolID,
                    shares: balance.shares,
                    valueInUSD: positionValue,
                    queuedWithdrawals: queuedWithdrawals,
                    claimableRewards: Decimal.zero, // To be calculated with emissions data
                    apy: backstopStats.backstopAPY
                )
                
                positions.append(position)
            }
        }
        
        return UserBackstopStats(
            userAddress: userAddress,
            positions: positions,
            totalBackstopValue: totalValue,
            totalClaimableRewards: totalRewards,
            totalQueuedWithdrawals: totalQueued,
            nextWithdrawalDate: earliestWithdrawal,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Health Monitoring
    
    /// Get backstop health alerts
    /// - Returns: Array of health alerts
    public func getBackstopHealthAlerts() async throws -> [BackstopHealthAlert] {
        var alerts: [BackstopHealthAlert] = []
        
        let allBackstopStats = try await getAllBackstopStats()
        
        for stats in allBackstopStats {
            // High utilization alert (80% threshold)
            if stats.utilizationRate > 0.8 {
                alerts.append(BackstopHealthAlert(
                    poolID: stats.poolID,
                    alertType: .highUtilization,
                    severity: stats.utilizationRate > 0.9 ? .critical : .warning,
                    message: "Backstop utilization is high",
                    threshold: 0.8,
                    currentValue: stats.utilizationRate,
                    recommendedAction: "Consider adding more liquidity to backstop"
                ))
            }
            
            // Low liquidity alert (20% of normal)
            // This is simplified - should compare to historical average
            let minLiquidity = Decimal(1000000) // $1M minimum
            if stats.totalBackstopLiquidity < minLiquidity {
                alerts.append(BackstopHealthAlert(
                    poolID: stats.poolID,
                    alertType: .lowLiquidity,
                    severity: .warning,
                    message: "Backstop liquidity is below recommended levels",
                    threshold: minLiquidity,
                    currentValue: stats.totalBackstopLiquidity,
                    recommendedAction: "Monitor backstop liquidity levels"
                ))
            }
        }
        
        return alerts
    }
    
    /// Get backstop health status
    /// - Returns: Overall backstop health status
    public func getBackstopHealthStatus() async throws -> BackstopHealthStatus {
        let alerts = try await getBackstopHealthAlerts()
        
        // Determine overall health
        let criticalCount = alerts.filter { $0.severity == .critical }.count
        let warningCount = alerts.filter { $0.severity == .warning }.count
        
        let overallHealth: HealthLevel
        if criticalCount > 0 {
            overallHealth = .critical
        } else if warningCount > 2 {
            overallHealth = .poor
        } else if warningCount > 0 {
            overallHealth = .moderate
        } else {
            overallHealth = .excellent
        }
        
        // Generate recommendations
        var recommendations: [String] = []
        if criticalCount > 0 {
            recommendations.append("Immediate action required for critical alerts")
        }
        if alerts.contains(where: { $0.alertType == .highUtilization }) {
            recommendations.append("Consider reducing backstop withdrawals")
        }
        
        return BackstopHealthStatus(
            overallHealth: overallHealth,
            alerts: alerts,
            recommendations: recommendations,
            utilizationTrend: .stable // Simplified
        )
    }
    
    // MARK: - Withdrawal Queue Management
    
    /// Get next available withdrawal
    /// - Returns: Next withdrawal that can be executed, if any
    public func getNextAvailableWithdrawal() async throws -> QueuedWithdrawal? {
        let userBackstop = try await getUserBackstopStats()
        let allWithdrawals = userBackstop.positions.flatMap { $0.queuedWithdrawals }
        
        return allWithdrawals
            .filter { $0.canExecuteNow }
            .sorted { $0.availableAt < $1.availableAt }
            .first
    }
    
    /// Get all queued withdrawals
    /// - Returns: Array of queued withdrawals
    public func getWithdrawalQueue() async throws -> [QueuedWithdrawal] {
        let userBackstop = try await getUserBackstopStats()
        return userBackstop.positions.flatMap { $0.queuedWithdrawals }
    }
    
    // MARK: - Private Helper Methods
    
    /// Convert a raw fixed-point value to human-readable format using asset-specific decimals
    /// - Parameters:
    ///   - value: Raw fixed-point value
    ///   - assetID: Asset identifier to get metadata for decimal places
    /// - Returns: Human-readable decimal value
    private func convertToHumanReadable(value: Decimal, forAssetID assetID: String) async throws -> Decimal {
        let contractAddress = try StellarContractID.toStrKey(assetID)
        let metadata = try await networkService.loadTokenMetadata(contractId: contractAddress)
        return FixedMath.toFloat(value: value, decimals: metadata.decimals)
    }
    
    /// Convert a human-readable value to fixed-point format using asset-specific decimals
    /// - Parameters:
    ///   - value: Human-readable decimal value
    ///   - assetID: Asset identifier to get metadata for decimal places
    /// - Returns: Fixed-point decimal value
    private func convertToFixedPoint(value: Decimal, forAssetID assetID: String) async throws -> Decimal {
        let contractAddress = try StellarContractID.toStrKey(assetID)
        let metadata = try await networkService.loadTokenMetadata(contractId: contractAddress)
        return FixedMath.toFixed(value: Double(value.description) ?? 0.0, decimals: metadata.decimals)
    }
    
    /// Convert a raw fixed-point value to human-readable format using standard 7-decimal Blend scaling
    /// - Parameter value: Raw fixed-point value
    /// - Returns: Human-readable decimal value
    private func convertBlendFixedPointToHuman(value: Decimal) -> Decimal {
        return FixedMath.toFloat(value: value, decimals: 7)
    }
    
    /// Convert a human-readable value to Blend fixed-point format using standard 7-decimal scaling
    /// - Parameter value: Human-readable decimal value
    /// - Returns: Fixed-point decimal value
    private func convertHumanToBlendFixedPoint(value: Decimal) -> Decimal {
        return FixedMath.toFixed(value: Double(value.description) ?? 0.0, decimals: 7)
    }
    
    /// Format contract address for display
    /// - Parameter address: Full contract address
    /// - Returns: Formatted address (e.g., "GATA...5V56")
    private func formatContractAddress(_ address: String) -> String {
        guard address.count > 8 else { return address }
        let prefix = String(address.prefix(4))
        let suffix = String(address.suffix(4))
        return "\(prefix)...\(suffix)"
    }
    
    private func validateInitialization() async throws {
        // Validate network connectivity
        let decimals = try await oracleService.getOracleDecimals()
        if decimals <= 0 {
            throw BlendVaultError.initializationFailed("Invalid oracle decimals")
        }
    }
    
    @available(macOS 15.0, iOS 18.0, *)
    private func getBackstopStatsForPool(poolID: String) async throws -> BackstopStats {
        let poolData = try await backstopService.getPoolData(pool: poolID)
        
        // Use the humanReadable property for proper fixed-point conversion
        let humanData = poolData.humanReadable
        
        // CORRECT: Calculate total backstop value using tokens × token spot price
        // 
        // The backstop pool contains individual BLND and USDC tokens, but these are combined
        // into "backstop tokens" which represent shares of the entire pool. The total value
        // is calculated as: total_tokens × token_spot_price
        //
        // Example with your data:
        // - tokens: 50,066.97 backstop tokens  
        // - tokenSpotPrice: $1.51371 per backstop token
        // - totalValue: 50,066.97 × 1.51371 = $75,790 ✅
        //
        // ❌ WRONG: blnd + usdc = 477,457 + 15,157 = $492,615 (incorrect)
        // ✅ CORRECT: tokens × tokenSpotPrice = 50,067 × 1.514 = $75,790
        let totalLiquidity = humanData.tokens * humanData.tokenSpotPrice
        
        // Calculate utilization rate: q4w is already a percentage in humanReadable
        let utilizationRate = humanData.q4wPercent / 100 // Convert percentage to decimal
        
        // Calculate backstop APY based on emissions and pool data
        // This is a simplified calculation - could be enhanced with actual emission rates
        let baseAPY = Decimal(0.05) // 5% base APY
        let utilizationBonus = utilizationRate * Decimal(0.03) // Up to 3% bonus for utilization
        let backstopAPY = baseAPY + utilizationBonus
        
        // Convert shares using FixedMath for proper decimal handling
        let sharesHuman = FixedMath.toFloat(value: Decimal(Double(poolData.shares)), decimals: 7)
        
        // Convert queued withdrawals percentage to actual amount
        let queuedWithdrawals = utilizationRate * totalLiquidity
        
        return BackstopStats(
            poolID: poolID,
            totalBackstopLiquidity: totalLiquidity,
            backstopAPY: backstopAPY,
            totalShares: Int128(sharesHuman.description) ?? poolData.shares,
            queuedWithdrawals: queuedWithdrawals,
            utilizationRate: utilizationRate,
            blndBalance: humanData.blnd,
            usdcBalance: humanData.usdc,
            emissionsPerSecond: Decimal(0), // To be implemented
            backstopToken: "", // To be implemented
            lastUpdated: Date()
        )
    }
    
    private func calculatePoolReserves(
        assets: [BlendAssetData],
        prices: [String: PriceData],
        backstopRate: Decimal
    ) async throws -> [PoolReserveData] {
        var reserves: [PoolReserveData] = []
        
        for asset in assets {
            let contractAddress = try StellarContractID.toStrKey(asset.assetId)
            let metadata = try await networkService.loadTokenMetadata(contractId: contractAddress)
            
            let price = prices[asset.assetId]?.price ?? Decimal.zero
            
            // BORROWED AMOUNT CALCULATION FIX:
            // Use actual borrowed amount with accrued interest (dSupply * dRate) for more precision
            let totalSupplied = asset.suppliedHuman
            
            // Calculate actual borrowed amount including accrued interest
            let dSupplyHuman = FixedMath.toFloat(value: asset.dSupply, decimals: 7)
            let dRateHuman = FixedMath.toFloat(value: asset.dRate, decimals: 9)
            let totalBorrowed = dSupplyHuman * dRateHuman
            
            let totalSuppliedUSD = totalSupplied * price
            let totalBorrowedUSD = totalBorrowed * price
            
            let utilizationRate = totalSupplied > Decimal.zero ? totalBorrowed / totalSupplied : Decimal.zero
            
            // Use the new unified calculator for APY calculations
            let borrowAPY = financialCalculator.calculateAPYFromAssetData(
                asset,
                backstopTakeRate: backstopRate,
                isSupply: false
            )
            let supplyAPY = financialCalculator.calculateAPYFromAssetData(
                asset,
                backstopTakeRate: backstopRate,
                isSupply: true
            )
            
            // APY DEBUG: Add additional debugging for APY calculations
            print("💹 APY Debug - \(metadata.symbol):")
            print("  Supply APY: \(supplyAPY)%")
            print("  Borrow APY: \(borrowAPY)%")
            print("  Utilization: \(utilizationRate)")
            print("  Backstop Rate: \(FixedMath.toFloat(value: backstopRate, decimals: 7))")
            
            // Convert collateral and liability factors from raw fixed-point to percentages
            let collateralFactor = FixedMath.toFloat(value: asset.cFactor, decimals: 7) * 100
            
            // LIABILITY FACTOR CALCULATION FIX:
            // Always calculate liability factor as inverse of collateral factor for consistency with image
            let cFactorDecimal = FixedMath.toFloat(value: asset.cFactor, decimals: 7)
            let liabilityFactor = cFactorDecimal > 0 ? (1.0 / cFactorDecimal) * 100 : 100.0
            
            // DEBUG: Print raw factor values for comparison
            let rawLiabilityFactor = FixedMath.toFloat(value: asset.lFactor, decimals: 7)
            print("🔧 Factor Debug - \(metadata.symbol):")
            print("  Raw cFactor: \(asset.cFactor) → \(cFactorDecimal)")
            print("  Raw lFactor: \(asset.lFactor) → \(rawLiabilityFactor)")
            print("  Calculated liability: \(liabilityFactor)%")
            
            // Format contract address for display (truncate for readability)
            let displayAddress = formatContractAddress(contractAddress)
            
            let reserve = PoolReserveData(
                assetID: asset.assetId,
                symbol: metadata.symbol,
                totalSupplied: totalSupplied,
                totalSuppliedUSD: totalSuppliedUSD,
                totalBorrowed: totalBorrowed,
                totalBorrowedUSD: totalBorrowedUSD,
                utilizationRate: utilizationRate,
                supplyAPY: supplyAPY,
                borrowAPY: borrowAPY,
                price: price,
                scalar: asset.scalar,
                collateralFactor: collateralFactor,
                liabilityFactor: liabilityFactor,
                contractAddress: displayAddress
            )
            
            reserves.append(reserve)
        }
        
        return reserves
    }
    
    private func convertToUserPositions(_ positions: [Position]) async throws -> [UserPosition] {
        var userPositions: [UserPosition] = []
        
        for position in positions {
            // Get asset metadata for decimal information
            let contractAddress = try StellarContractID.toStrKey(position.asset)
            let metadata = try await networkService.loadTokenMetadata(contractId: contractAddress)
            
            // Get current price from oracle
            let oracleAsset = OracleAsset.stellar(address: position.asset)
            let priceData = try? await oracleService.getPrice(asset: oracleAsset)
            let currentPrice = priceData?.price ?? Decimal.zero
            
            // Convert deposited amount from fixed-point to human-readable
            let depositedHuman = FixedMath.toFloat(value: position.depositedAmount, decimals: metadata.decimals)
            let borrowedHuman = FixedMath.toFloat(value: position.borrowedAmount, decimals: metadata.decimals)
            let collateralHuman = FixedMath.toFloat(value: position.collateralValue, decimals: metadata.decimals)
            
            // Calculate USD values
            let depositedValueUSD = depositedHuman * currentPrice
            let borrowedValueUSD = borrowedHuman * currentPrice
            let collateralValueUSD = collateralHuman * currentPrice
            
            // Create supplied asset entries
            var suppliedAssets: [UserAssetPosition] = []
            if depositedHuman > 0 {
                // Get asset-specific APY for supply
                let assetService = BlendAssetService(poolID: config.primaryPoolID, networkService: networkService)
                let poolAssets = try await assetService.getAssets()
                let assetData = try await assetService.getAll(assets: poolAssets)
                
                if let specificAssetData = assetData.first(where: { $0.assetId == position.asset }) {
                    let poolConfig = try await poolService.fetchPoolConfig(contractId: config.primaryPoolID)
                    let backstopRate = FixedMath.toFixed(value: Double(poolConfig.backstopRate), decimals: 7)
                    let supplyAPY = financialCalculator.calculateAPYFromAssetData(
                        specificAssetData,
                        backstopTakeRate: backstopRate,
                        isSupply: true
                    )
                    
                    let suppliedAsset = UserAssetPosition(
                        assetID: position.asset,
                        symbol: metadata.symbol,
                        amount: depositedHuman,
                        valueUSD: depositedValueUSD,
                        apy: supplyAPY,
                        isCollateral: true // Supplied assets are typically used as collateral
                    )
                    suppliedAssets.append(suppliedAsset)
                }
            }
            
            // Create borrowed asset entries
            var borrowedAssets: [UserAssetPosition] = []
            if borrowedHuman > 0 {
                // Get asset-specific APY for borrow
                let assetService = BlendAssetService(poolID: config.primaryPoolID, networkService: networkService)
                let poolAssets = try await assetService.getAssets()
                let assetData = try await assetService.getAll(assets: poolAssets)
                
                if let specificAssetData = assetData.first(where: { $0.assetId == position.asset }) {
                    let borrowAPY = try specificAssetData.calculateBorrowAPY()
                    
                    let borrowedAsset = UserAssetPosition(
                        assetID: position.asset,
                        symbol: metadata.symbol,
                        amount: borrowedHuman,
                        valueUSD: borrowedValueUSD,
                        apy: borrowAPY,
                        isCollateral: false // Borrowed assets are not collateral
                    )
                    borrowedAssets.append(borrowedAsset)
                }
            }
            
            // Create user position
            let userPosition = UserPosition(
                poolID: config.primaryPoolID,
                suppliedAssets: suppliedAssets,
                borrowedAssets: borrowedAssets,
                collateralValue: collateralValueUSD,
                borrowValue: borrowedValueUSD,
                healthFactor: position.healthFactor
            )
            
            userPositions.append(userPosition)
        }
        
        return userPositions
    }
    
    private func calculateNetAPY(positions: [UserPosition]) -> Decimal {
        guard !positions.isEmpty else { return Decimal.zero }
        
        var totalSupplyValue = Decimal.zero
        var totalBorrowValue = Decimal.zero
        var weightedSupplyAPY = Decimal.zero
        var weightedBorrowAPY = Decimal.zero
        
        for position in positions {
            // Calculate weighted APYs for supplied assets
            for suppliedAsset in position.suppliedAssets {
                totalSupplyValue += suppliedAsset.valueUSD
                weightedSupplyAPY += suppliedAsset.apy * suppliedAsset.valueUSD
            }
            
            // Calculate weighted APYs for borrowed assets
            for borrowedAsset in position.borrowedAssets {
                totalBorrowValue += borrowedAsset.valueUSD
                weightedBorrowAPY += borrowedAsset.apy * borrowedAsset.valueUSD
            }
        }
        
        // Calculate net APY: (supply earnings - borrow costs) / total value
        let supplyEarnings = totalSupplyValue > 0 ? weightedSupplyAPY / totalSupplyValue : Decimal.zero
        let borrowCosts = totalBorrowValue > 0 ? weightedBorrowAPY / totalBorrowValue : Decimal.zero
        let totalValue = totalSupplyValue + totalBorrowValue
        
        if totalValue > 0 {
            let netEarnings = (supplyEarnings * totalSupplyValue) - (borrowCosts * totalBorrowValue)
            return netEarnings / totalValue
        }
        
        return Decimal.zero
    }
    
    private func invalidateCachesAfterTransaction() async {
        // Invalidate user and pool data caches
        await cacheService.clear() // Simplified - should be more targeted
    }
    
    private func mapServiceError(_ error: Error) -> BlendVaultError {
        if let oracleError = error as? OracleError {
            return .oracleError(oracleError)
        } else if let backstopError = error as? BackstopError {
            return .backstopError(backstopError)
        } else if let blendError = error as? BlendError {
            return .poolError(blendError)
        } else {
            return .unknown(error.localizedDescription)
        }
    }
    
    // MARK: - Debugging & Testing
    
    /// Run financial calculator validation tests
    public func runCalculatorValidationTests() {
        let tests = BlendProtocolFinancialCalculatorTests()
        tests.runAllTests()
    }
    
    /// Test the new calculator with live data from a specific asset
    public func testCalculatorWithLiveData(assetID: String) async {
        do {
            let assetService = BlendAssetService(poolID: config.primaryPoolID, networkService: networkService)
            let poolAssets = try await assetService.getAssets()
            let assetData = try await assetService.getAll(assets: poolAssets)
            
            guard let specificAssetData = assetData.first(where: { $0.assetId == assetID }) else {
                print("❌ Asset \(assetID) not found in primary pool")
                return
            }
            
            let poolConfig = try await poolService.fetchPoolConfig(contractId: config.primaryPoolID)
            let backstopRate = FixedMath.toFixed(value: Double(poolConfig.backstopRate), decimals: 7)
            
            // Test new calculator
            let newSupplyAPY = financialCalculator.calculateAPYFromAssetData(
                specificAssetData,
                backstopTakeRate: backstopRate,
                isSupply: true
            )
            let newBorrowAPY = financialCalculator.calculateAPYFromAssetData(
                specificAssetData,
                backstopTakeRate: backstopRate,
                isSupply: false
            )
            
            // Test old calculator for comparison
            let oldSupplyAPY = try specificAssetData.calculateSupplyAPY(backstopTakeRate: backstopRate)
            let oldBorrowAPY = try specificAssetData.calculateBorrowAPY()
            
            print("\n🧪 Calculator Comparison for \(assetID):")
            print("📊 NEW Calculator:")
            print("  Supply APY: \(String(format: "%.4f", Double(truncating: newSupplyAPY as NSNumber)))%")
            print("  Borrow APY: \(String(format: "%.4f", Double(truncating: newBorrowAPY as NSNumber)))%")
            print("📈 OLD Calculator:")
            print("  Supply APY: \(String(format: "%.4f", Double(truncating: oldSupplyAPY as NSNumber)))%")
            print("  Borrow APY: \(String(format: "%.4f", Double(truncating: oldBorrowAPY as NSNumber)))%")
            print("🔍 Utilization: \(String(format: "%.4f", Double(truncating: (specificAssetData.suppliedHuman > 0 ? (specificAssetData.borrowedHuman / specificAssetData.suppliedHuman) : Decimal.zero) as NSNumber)))")
            
        } catch {
            print("❌ Error testing calculator: \(error)")
        }
    }
}



