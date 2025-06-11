import Foundation

/// Protocol defining user position service operations for the Blend protocol
protocol UserPositionServiceProtocol {
    
    // MARK: - Position Overview
    
    /// Get complete user position across all pools
    func getUserPosition(userAddress: String) async throws -> UserPosition
    
    /// Get user position for a specific pool
    func getUserPositionInPool(userAddress: String, poolAddress: String) async throws -> PoolUserPosition
    
    /// Get user's net worth across all positions
    func getUserNetWorth(userAddress: String) async throws -> NetWorth
    
    // MARK: - Supply Positions
    
    /// Get all user's supply positions
    func getSupplyPositions(userAddress: String) async throws -> [SupplyPosition]
    
    /// Get user's supply position for specific asset
    func getSupplyPosition(
        userAddress: String,
        poolAddress: String,
        assetId: String
    ) async throws -> SupplyPosition?
    
    /// Get total supplied value across all positions
    func getTotalSuppliedValue(userAddress: String) async throws -> Double
    
    // MARK: - Borrow Positions
    
    /// Get all user's borrow positions
    func getBorrowPositions(userAddress: String) async throws -> [BorrowPosition]
    
    /// Get user's borrow position for specific asset
    func getBorrowPosition(
        userAddress: String,
        poolAddress: String,
        assetId: String
    ) async throws -> BorrowPosition?
    
    /// Get total borrowed value across all positions
    func getTotalBorrowedValue(userAddress: String) async throws -> Double
    
    // MARK: - Health & Risk Management
    
    /// Get user's overall health factor
    func getOverallHealthFactor(userAddress: String) async throws -> Double
    
    /// Get user's position health for specific pool
    func getPositionHealth(userAddress: String, poolAddress: String) async throws -> PositionHealth
    
    /// Check if user is at risk of liquidation
    func isAtLiquidationRisk(userAddress: String) async throws -> Bool
    
    /// Get liquidation thresholds for user positions
    func getLiquidationThresholds(userAddress: String) async throws -> [LiquidationThreshold]
    
    // MARK: - Borrowing Power
    
    /// Get user's available borrowing power
    func getAvailableBorrowingPower(userAddress: String) async throws -> Double
    
    /// Get max borrowable amount for specific asset
    func getMaxBorrowableAmount(
        userAddress: String,
        poolAddress: String,
        assetId: String
    ) async throws -> UInt64
    
    /// Get max withdrawable amount for specific asset
    func getMaxWithdrawableAmount(
        userAddress: String,
        poolAddress: String,
        assetId: String
    ) async throws -> UInt64
    
    // MARK: - Rewards & Interest
    
    /// Get accrued supply interest for user
    func getAccruedSupplyInterest(userAddress: String) async throws -> [InterestAccrual]
    
    /// Get accrued borrow interest for user
    func getAccruedBorrowInterest(userAddress: String) async throws -> [InterestAccrual]
    
    /// Get claimable rewards across all positions
    func getClaimableRewards(userAddress: String) async throws -> [RewardAccrual]
    
    // MARK: - Position History
    
    /// Get user's transaction history
    func getTransactionHistory(
        userAddress: String,
        fromLedger: UInt32?,
        toLedger: UInt32?
    ) async throws -> [PositionTransaction]
    
    /// Get position value history over time
    func getPositionValueHistory(
        userAddress: String,
        timeframe: TimeFrame
    ) async throws -> [ValueHistoryPoint]
    
    // MARK: - Portfolio Analytics
    
    /// Get user's asset allocation breakdown
    func getAssetAllocation(userAddress: String) async throws -> AssetAllocation
    
    /// Get user's pool allocation breakdown
    func getPoolAllocation(userAddress: String) async throws -> PoolAllocation
    
    /// Get yield statistics for user positions
    func getYieldStatistics(userAddress: String) async throws -> YieldStatistics
}

// MARK: - Data Models

struct UserPosition {
    let userAddress: String
    let poolPositions: [PoolUserPosition]
    let totalSuppliedValue: Double
    let totalBorrowedValue: Double
    let netWorth: Double
    let overallHealthFactor: Double
    let availableBorrowingPower: Double
    let lastUpdated: Date
}

struct PoolUserPosition {
    let poolAddress: String
    let poolName: String
    let supplyPositions: [SupplyPosition]
    let borrowPositions: [BorrowPosition]
    let healthFactor: Double
    let totalCollateralValue: Double
    let totalBorrowedValue: Double
    let netValue: Double
}

struct SupplyPosition {
    let poolAddress: String
    let assetId: String
    let assetSymbol: String
    let suppliedAmount: UInt64
    let suppliedValue: Double
    let collateralValue: Double
    let isCollateral: Bool
    let supplyRate: Double
    let accruedInterest: UInt64
    let lastUpdateTime: Date
}

struct BorrowPosition {
    let poolAddress: String
    let assetId: String
    let assetSymbol: String
    let borrowedAmount: UInt64
    let borrowedValue: Double
    let borrowRate: Double
    let accruedInterest: UInt64
    let healthImpact: Double
    let lastUpdateTime: Date
}

struct NetWorth {
    let totalAssets: Double
    let totalLiabilities: Double
    let netWorth: Double
    let breakdown: [AssetValue]
}

struct AssetValue {
    let assetId: String
    let assetSymbol: String
    let value: Double
    let percentage: Double
}

struct LiquidationThreshold {
    let poolAddress: String
    let assetId: String
    let currentHealthFactor: Double
    let liquidationThreshold: Double
    let priceDropToLiquidation: Double
    let timeToLiquidationRisk: TimeInterval?
}

struct InterestAccrual {
    let poolAddress: String
    let assetId: String
    let assetSymbol: String
    let accruedAmount: UInt64
    let accruedValue: Double
    let rate: Double
    let lastUpdateTime: Date
}

struct RewardAccrual {
    let poolAddress: String
    let rewardAssetId: String
    let rewardSymbol: String
    let claimableAmount: UInt64
    let claimableValue: Double
    let source: RewardSource
}

struct PositionTransaction {
    let hash: String
    let type: TransactionType
    let poolAddress: String
    let assetId: String
    let amount: UInt64
    let value: Double
    let timestamp: Date
    let status: TransactionStatus
}

struct ValueHistoryPoint {
    let timestamp: Date
    let totalValue: Double
    let suppliedValue: Double
    let borrowedValue: Double
    let netWorth: Double
}

struct AssetAllocation {
    let allocations: [AssetAllocationItem]
    let diversificationScore: Double
}

struct AssetAllocationItem {
    let assetId: String
    let assetSymbol: String
    let netValue: Double
    let percentage: Double
}

struct PoolAllocation {
    let allocations: [PoolAllocationItem]
    let riskScore: Double
}

struct PoolAllocationItem {
    let poolAddress: String
    let poolName: String
    let netValue: Double
    let percentage: Double
}

struct YieldStatistics {
    let totalYieldEarned: Double
    let totalInterestPaid: Double
    let netYield: Double
    let averageSupplyAPY: Double
    let averageBorrowAPY: Double
    let yieldByAsset: [YieldByAsset]
}

struct YieldByAsset {
    let assetId: String
    let assetSymbol: String
    let supplyYield: Double
    let borrowCost: Double
    let netYield: Double
}

// MARK: - Enums

enum RewardSource {
    case supplyRewards
    case backstopRewards
    case liquidationRewards
    case other(String)
}

enum TransactionType {
    case supply
    case withdraw
    case borrow
    case repay
    case liquidation
    case rewardClaim
}

enum TransactionStatus {
    case pending
    case success
    case failed
}

enum TimeFrame {
    case day
    case week
    case month
    case quarter
    case year
    case all
}