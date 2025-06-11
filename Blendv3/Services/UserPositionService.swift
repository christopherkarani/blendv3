import Foundation

/// User Position Service implementation for Blend protocol
/// Uses NetworkService for networking and BlendParser for parsing
@MainActor
class UserPositionService: ObservableObject, UserPositionServiceProtocol {
    
    // MARK: - Dependencies
    
    private let networkService: NetworkService
    private let parser: BlendParser
    private let poolService: PoolService
    private let oracleService: BlendOracleService
    
    // MARK: - Published Properties
    
    @Published var userPositions: [String: UserPosition] = [:] // userAddress -> position
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Initialization
    
    init(
        networkService: NetworkService = NetworkService(),
        parser: BlendParser = BlendParser.shared,
        poolService: PoolService = PoolService(),
        oracleService: BlendOracleService = BlendOracleService()
    ) {
        self.networkService = networkService
        self.parser = parser
        self.poolService = poolService
        self.oracleService = oracleService
    }
    
    // MARK: - Position Overview
    
    func getUserPosition(userAddress: String) async throws -> UserPosition {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get all pools where user has positions
            let poolAddresses = try await getUserPoolAddresses(userAddress: userAddress)
            
            var poolPositions: [PoolUserPosition] = []
            var totalSuppliedValue = 0.0
            var totalBorrowedValue = 0.0
            
            // Get position for each pool
            for poolAddress in poolAddresses {
                let poolPosition = try await getUserPositionInPool(
                    userAddress: userAddress,
                    poolAddress: poolAddress
                )
                poolPositions.append(poolPosition)
                totalSuppliedValue += poolPosition.totalCollateralValue
                totalBorrowedValue += poolPosition.totalBorrowedValue
            }
            
            let netWorth = totalSuppliedValue - totalBorrowedValue
            let overallHealthFactor = try await getOverallHealthFactor(userAddress: userAddress)
            let availableBorrowingPower = try await getAvailableBorrowingPower(userAddress: userAddress)
            
            let userPosition = UserPosition(
                userAddress: userAddress,
                poolPositions: poolPositions,
                totalSuppliedValue: totalSuppliedValue,
                totalBorrowedValue: totalBorrowedValue,
                netWorth: netWorth,
                overallHealthFactor: overallHealthFactor,
                availableBorrowingPower: availableBorrowingPower,
                lastUpdated: Date()
            )
            
            // Update state
            DispatchQueue.main.async {
                self.userPositions[userAddress] = userPosition
                self.error = nil
            }
            
            return userPosition
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getUserPositionInPool(userAddress: String, poolAddress: String) async throws -> PoolUserPosition {
        do {
            let userArg = try parser.createAddressSCVal(from: userAddress)
            let args = [userArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_user_position",
                args: args,
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            let positionMap = try parser.parseMap(from: result)
            
            return try parsePoolUserPosition(from: positionMap, poolAddress: poolAddress)
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getUserNetWorth(userAddress: String) async throws -> NetWorth {
        do {
            let userPosition = try await getUserPosition(userAddress: userAddress)
            
            var breakdown: [AssetValue] = []
            
            // Calculate asset breakdown from all positions
            for poolPosition in userPosition.poolPositions {
                for supplyPosition in poolPosition.supplyPositions {
                    if let existingIndex = breakdown.firstIndex(where: { $0.assetId == supplyPosition.assetId }) {
                        breakdown[existingIndex] = AssetValue(
                            assetId: supplyPosition.assetId,
                            assetSymbol: supplyPosition.assetSymbol,
                            value: breakdown[existingIndex].value + supplyPosition.suppliedValue,
                            percentage: 0.0 // Will be calculated after all assets
                        )
                    } else {
                        breakdown.append(AssetValue(
                            assetId: supplyPosition.assetId,
                            assetSymbol: supplyPosition.assetSymbol,
                            value: supplyPosition.suppliedValue,
                            percentage: 0.0
                        ))
                    }
                }
                
                for borrowPosition in poolPosition.borrowPositions {
                    if let existingIndex = breakdown.firstIndex(where: { $0.assetId == borrowPosition.assetId }) {
                        breakdown[existingIndex] = AssetValue(
                            assetId: borrowPosition.assetId,
                            assetSymbol: borrowPosition.assetSymbol,
                            value: breakdown[existingIndex].value - borrowPosition.borrowedValue,
                            percentage: 0.0
                        )
                    } else {
                        breakdown.append(AssetValue(
                            assetId: borrowPosition.assetId,
                            assetSymbol: borrowPosition.assetSymbol,
                            value: -borrowPosition.borrowedValue,
                            percentage: 0.0
                        ))
                    }
                }
            }
            
            // Calculate percentages
            let totalValue = breakdown.reduce(0) { $0 + abs($1.value) }
            breakdown = breakdown.map { asset in
                AssetValue(
                    assetId: asset.assetId,
                    assetSymbol: asset.assetSymbol,
                    value: asset.value,
                    percentage: totalValue > 0 ? (abs(asset.value) / totalValue) * 100 : 0.0
                )
            }
            
            return NetWorth(
                totalAssets: userPosition.totalSuppliedValue,
                totalLiabilities: userPosition.totalBorrowedValue,
                netWorth: userPosition.netWorth,
                breakdown: breakdown
            )
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Supply Positions
    
    func getSupplyPositions(userAddress: String) async throws -> [SupplyPosition] {
        do {
            let userPosition = try await getUserPosition(userAddress: userAddress)
            return userPosition.poolPositions.flatMap { $0.supplyPositions }
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getSupplyPosition(
        userAddress: String,
        poolAddress: String,
        assetId: String
    ) async throws -> SupplyPosition? {
        do {
            let poolPosition = try await getUserPositionInPool(
                userAddress: userAddress,
                poolAddress: poolAddress
            )
            
            return poolPosition.supplyPositions.first { $0.assetId == assetId }
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getTotalSuppliedValue(userAddress: String) async throws -> Double {
        do {
            let userPosition = try await getUserPosition(userAddress: userAddress)
            return userPosition.totalSuppliedValue
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Borrow Positions
    
    func getBorrowPositions(userAddress: String) async throws -> [BorrowPosition] {
        do {
            let userPosition = try await getUserPosition(userAddress: userAddress)
            return userPosition.poolPositions.flatMap { $0.borrowPositions }
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getBorrowPosition(
        userAddress: String,
        poolAddress: String,
        assetId: String
    ) async throws -> BorrowPosition? {
        do {
            let poolPosition = try await getUserPositionInPool(
                userAddress: userAddress,
                poolAddress: poolAddress
            )
            
            return poolPosition.borrowPositions.first { $0.assetId == assetId }
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getTotalBorrowedValue(userAddress: String) async throws -> Double {
        do {
            let userPosition = try await getUserPosition(userAddress: userAddress)
            return userPosition.totalBorrowedValue
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Health & Risk Management
    
    func getOverallHealthFactor(userAddress: String) async throws -> Double {
        do {
            // Get health factors from all pools and calculate weighted average
            let poolAddresses = try await getUserPoolAddresses(userAddress: userAddress)
            var totalCollateral = 0.0
            var weightedHealthSum = 0.0
            
            for poolAddress in poolAddresses {
                let poolPosition = try await getUserPositionInPool(
                    userAddress: userAddress,
                    poolAddress: poolAddress
                )
                
                totalCollateral += poolPosition.totalCollateralValue
                weightedHealthSum += poolPosition.healthFactor * poolPosition.totalCollateralValue
            }
            
            return totalCollateral > 0 ? weightedHealthSum / totalCollateral : Double.infinity
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getPositionHealth(userAddress: String, poolAddress: String) async throws -> PositionHealth {
        do {
            return try await poolService.getPositionHealth(
                poolAddress: poolAddress,
                userAddress: userAddress
            )
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func isAtLiquidationRisk(userAddress: String) async throws -> Bool {
        do {
            let healthFactor = try await getOverallHealthFactor(userAddress: userAddress)
            return healthFactor < 1.1 // 10% buffer above liquidation threshold
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getLiquidationThresholds(userAddress: String) async throws -> [LiquidationThreshold] {
        do {
            let poolAddresses = try await getUserPoolAddresses(userAddress: userAddress)
            var thresholds: [LiquidationThreshold] = []
            
            for poolAddress in poolAddresses {
                let poolPosition = try await getUserPositionInPool(
                    userAddress: userAddress,
                    poolAddress: poolAddress
                )
                
                for supplyPosition in poolPosition.supplyPositions {
                    if supplyPosition.isCollateral {
                        let threshold = LiquidationThreshold(
                            poolAddress: poolAddress,
                            assetId: supplyPosition.assetId,
                            currentHealthFactor: poolPosition.healthFactor,
                            liquidationThreshold: 0.75, // Would be fetched from pool config
                            priceDropToLiquidation: calculatePriceDropToLiquidation(
                                healthFactor: poolPosition.healthFactor
                            ),
                            timeToLiquidationRisk: nil
                        )
                        thresholds.append(threshold)
                    }
                }
            }
            
            return thresholds
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Borrowing Power
    
    func getAvailableBorrowingPower(userAddress: String) async throws -> Double {
        do {
            let userPosition = try await getUserPosition(userAddress: userAddress)
            
            // Calculate borrowing power based on collateral value and current borrowings
            let maxBorrowValue = userPosition.totalSuppliedValue * 0.75 // 75% LTV
            let availableBorrowValue = max(0, maxBorrowValue - userPosition.totalBorrowedValue)
            
            return availableBorrowValue
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getMaxBorrowableAmount(
        userAddress: String,
        poolAddress: String,
        assetId: String
    ) async throws -> UInt64 {
        do {
            let userArg = try parser.createAddressSCVal(from: userAddress)
            let assetArg = try parser.createSCVal(from: assetId)
            let args = [userArg, assetArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_max_borrowable",
                args: args,
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            return try parser.parseUInt64(from: result)
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getMaxWithdrawableAmount(
        userAddress: String,
        poolAddress: String,
        assetId: String
    ) async throws -> UInt64 {
        do {
            let userArg = try parser.createAddressSCVal(from: userAddress)
            let assetArg = try parser.createSCVal(from: assetId)
            let args = [userArg, assetArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_max_withdrawable",
                args: args,
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            return try parser.parseUInt64(from: result)
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Rewards & Interest
    
    func getAccruedSupplyInterest(userAddress: String) async throws -> [InterestAccrual] {
        do {
            let supplyPositions = try await getSupplyPositions(userAddress: userAddress)
            
            return supplyPositions.map { position in
                InterestAccrual(
                    poolAddress: position.poolAddress,
                    assetId: position.assetId,
                    assetSymbol: position.assetSymbol,
                    accruedAmount: position.accruedInterest,
                    accruedValue: Double(position.accruedInterest) / 1_000_000, // Convert from microunits
                    rate: position.supplyRate,
                    lastUpdateTime: position.lastUpdateTime
                )
            }
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getAccruedBorrowInterest(userAddress: String) async throws -> [InterestAccrual] {
        do {
            let borrowPositions = try await getBorrowPositions(userAddress: userAddress)
            
            return borrowPositions.map { position in
                InterestAccrual(
                    poolAddress: position.poolAddress,
                    assetId: position.assetId,
                    assetSymbol: position.assetSymbol,
                    accruedAmount: position.accruedInterest,
                    accruedValue: Double(position.accruedInterest) / 1_000_000, // Convert from microunits
                    rate: position.borrowRate,
                    lastUpdateTime: position.lastUpdateTime
                )
            }
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getClaimableRewards(userAddress: String) async throws -> [RewardAccrual] {
        // This would aggregate rewards from all pools and backstops
        // Simplified implementation
        return []
    }
    
    // MARK: - Position History
    
    func getTransactionHistory(
        userAddress: String,
        fromLedger: UInt32?,
        toLedger: UInt32?
    ) async throws -> [PositionTransaction] {
        // This would fetch transaction history from events across all pools
        // Simplified implementation
        return []
    }
    
    func getPositionValueHistory(
        userAddress: String,
        timeframe: TimeFrame
    ) async throws -> [ValueHistoryPoint] {
        // This would aggregate historical position values
        // Simplified implementation
        return []
    }
    
    // MARK: - Portfolio Analytics
    
    func getAssetAllocation(userAddress: String) async throws -> AssetAllocation {
        do {
            let netWorth = try await getUserNetWorth(userAddress: userAddress)
            
            let allocations = netWorth.breakdown.map { asset in
                AssetAllocationItem(
                    assetId: asset.assetId,
                    assetSymbol: asset.assetSymbol,
                    netValue: asset.value,
                    percentage: asset.percentage
                )
            }
            
            // Calculate diversification score (simple Herfindahl index)
            let herfindahl = allocations.reduce(0) { sum, allocation in
                sum + pow(allocation.percentage / 100, 2)
            }
            let diversificationScore = max(0, (1 - herfindahl) * 100)
            
            return AssetAllocation(
                allocations: allocations,
                diversificationScore: diversificationScore
            )
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getPoolAllocation(userAddress: String) async throws -> PoolAllocation {
        do {
            let userPosition = try await getUserPosition(userAddress: userAddress)
            
            let allocations = userPosition.poolPositions.map { poolPosition in
                PoolAllocationItem(
                    poolAddress: poolPosition.poolAddress,
                    poolName: poolPosition.poolName,
                    netValue: poolPosition.netValue,
                    percentage: userPosition.netWorth > 0 ?
                        (poolPosition.netValue / userPosition.netWorth) * 100 : 0.0
                )
            }
            
            let riskScore = calculatePortfolioRiskScore(allocations: allocations)
            
            return PoolAllocation(
                allocations: allocations,
                riskScore: riskScore
            )
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getYieldStatistics(userAddress: String) async throws -> YieldStatistics {
        // This would calculate comprehensive yield statistics
        // Simplified implementation
        return YieldStatistics(
            totalYieldEarned: 0.0,
            totalInterestPaid: 0.0,
            netYield: 0.0,
            averageSupplyAPY: 0.0,
            averageBorrowAPY: 0.0,
            yieldByAsset: []
        )
    }
    
    // MARK: - Private Methods
    
    private func getUserPoolAddresses(userAddress: String) async throws -> [String] {
        // This would query all pools to find where user has positions
        // Simplified implementation - in reality would be more efficient
        return ["POOL1_ADDRESS", "POOL2_ADDRESS"]
    }
    
    private func parsePoolUserPosition(
        from positionMap: [String: Any],
        poolAddress: String
    ) throws -> PoolUserPosition {
        // Simplified parsing - actual implementation would parse the full structure
        return PoolUserPosition(
            poolAddress: poolAddress,
            poolName: "Pool Name",
            supplyPositions: [],
            borrowPositions: [],
            healthFactor: 1.5,
            totalCollateralValue: 0.0,
            totalBorrowedValue: 0.0,
            netValue: 0.0
        )
    }
    
    private func calculatePriceDropToLiquidation(healthFactor: Double) -> Double {
        // Simplified calculation
        return max(0, (healthFactor - 1.0) / healthFactor * 100)
    }
    
    private func calculatePortfolioRiskScore(allocations: [PoolAllocationItem]) -> Double {
        // Simplified risk calculation based on concentration
        let maxAllocation = allocations.max { $0.percentage < $1.percentage }?.percentage ?? 0
        return min(100, maxAllocation) // Higher concentration = higher risk
    }
    
    private func getDefaultKeyPair() -> Any {
        fatalError("KeyPair should be provided through dependency injection")
    }
}

// MARK: - Error Types

enum UserPositionError: Error, LocalizedError {
    case userNotFound(String)
    case noPositions(String)
    case poolNotFound(String)
    case calculationError(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound(let address):
            return "User not found: \(address)"
        case .noPositions(let address):
            return "No positions found for user: \(address)"
        case .poolNotFound(let poolAddress):
            return "Pool not found: \(poolAddress)"
        case .calculationError(let message):
            return "Calculation error: \(message)"
        }
    }
}