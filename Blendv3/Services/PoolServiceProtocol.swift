import Foundation

/// Protocol defining pool service operations for the Blend protocol
protocol PoolServiceProtocol {
    
    // MARK: - Pool Information
    
    /// Get pool configuration data
    func getPoolConfig(poolAddress: String) async throws -> PoolConfig
    
    /// Get pool reserves for all assets
    func getPoolReserves(poolAddress: String) async throws -> [String: PoolReserve]
    
    /// Get pool status information
    func getPoolStatus(poolAddress: String) async throws -> PoolStatus
    
    // MARK: - Liquidity Operations
    
    /// Supply assets to the pool
    func supply(
        poolAddress: String,
        assetId: String,
        amount: UInt64,
        sourceKeyPair: Any
    ) async throws -> String // Returns transaction hash
    
    /// Withdraw assets from the pool
    func withdraw(
        poolAddress: String,
        assetId: String,
        amount: UInt64,
        sourceKeyPair: Any
    ) async throws -> String
    
    /// Get user's supplied balance
    func getSuppliedBalance(
        poolAddress: String,
        userAddress: String,
        assetId: String
    ) async throws -> UInt64
    
    // MARK: - Borrowing Operations
    
    /// Borrow assets from the pool
    func borrow(
        poolAddress: String,
        assetId: String,
        amount: UInt64,
        sourceKeyPair: Any
    ) async throws -> String
    
    /// Repay borrowed assets
    func repay(
        poolAddress: String,
        assetId: String,
        amount: UInt64,
        sourceKeyPair: Any
    ) async throws -> String
    
    /// Get user's borrowed balance
    func getBorrowedBalance(
        poolAddress: String,
        userAddress: String,
        assetId: String
    ) async throws -> UInt64
    
    // MARK: - Pool Analytics
    
    /// Get pool utilization rates
    func getPoolUtilization(poolAddress: String) async throws -> [String: Double]
    
    /// Get current interest rates
    func getInterestRates(poolAddress: String) async throws -> [String: InterestRates]
    
    /// Get pool total value locked (TVL)
    func getPoolTVL(poolAddress: String) async throws -> Double
    
    // MARK: - Risk Management
    
    /// Get user's position health
    func getPositionHealth(
        poolAddress: String,
        userAddress: String
    ) async throws -> PositionHealth
    
    /// Check if position can be liquidated
    func canLiquidate(
        poolAddress: String,
        userAddress: String
    ) async throws -> Bool
    
    /// Get liquidation threshold for assets
    func getLiquidationThresholds(
        poolAddress: String
    ) async throws -> [String: Double]
}

// MARK: - Data Models

struct PoolConfig {
    let poolAddress: String
    let name: String
    let assets: [PoolAsset]
    let reserveFactor: Double
    let maxUtilizationRate: Double
    let oracle: String
    let backstop: String?
}

struct PoolAsset {
    let assetId: String
    let assetType: AssetType
    let decimals: Int
    let collateralFactor: Double
    let liquidationThreshold: Double
    let liquidationPenalty: Double
    let reserveFactor: Double
    let supplyCap: UInt64?
    let borrowCap: UInt64?
}

struct PoolReserve {
    let assetId: String
    let totalSupplied: UInt64
    let totalBorrowed: UInt64
    let availableLiquidity: UInt64
    let utilizationRate: Double
    let supplyIndex: UInt64
    let borrowIndex: UInt64
    let lastUpdateTime: Date
}

struct PoolStatus {
    let isActive: Bool
    let isPaused: Bool
    let totalSuppliedValue: Double
    let totalBorrowedValue: Double
    let totalLiquidityValue: Double
    let utilizationRate: Double
    let lastUpdateTime: Date
}

struct InterestRates {
    let supplyRate: Double
    let borrowRate: Double
    let baseRate: Double
    let slope1: Double
    let slope2: Double
    let optimalUtilization: Double
}

struct PositionHealth {
    let healthFactor: Double
    let totalCollateralValue: Double
    let totalBorrowedValue: Double
    let availableBorrowValue: Double
    let liquidationThreshold: Double
    let isHealthy: Bool
}

enum AssetType {
    case native
    case stellar
    case contract
}