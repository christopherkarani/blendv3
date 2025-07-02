//
//  BlendModels.swift
//  Blendv3
//
//  Data models for the refactored BlendVault API
//

import Foundation

// MARK: - Configuration Models

/// Configuration for BlendVault initialization
public struct BlendVaultConfig: Sendable {
    public let network: Network
    public let poolIDs: [String]
    public let primaryPoolID: String
    public let cacheConfig: CacheConfig
    
    public struct CacheConfig: Sendable {
        public let statsTTL: TimeInterval
        public let assetDataTTL: TimeInterval
        public let userPositionTTL: TimeInterval
        
        public init(
            statsTTL: TimeInterval = 300,        // 5 minutes
            assetDataTTL: TimeInterval = 600,    // 10 minutes
            userPositionTTL: TimeInterval = 60   // 1 minute
        ) {
            self.statsTTL = statsTTL
            self.assetDataTTL = assetDataTTL
            self.userPositionTTL = userPositionTTL
        }
    }
    
    public init(
        network: Network,
        poolIDs: [String],
        primaryPoolID: String? = nil,
        cacheConfig: CacheConfig = CacheConfig()
    ) {
        self.network = network
        self.poolIDs = poolIDs
        self.primaryPoolID = primaryPoolID ?? (poolIDs.first ?? "")
        self.cacheConfig = cacheConfig
    }
}

// MARK: - Pool Statistics Models

/// Comprehensive pool statistics including backstop data
public struct PoolStats: Sendable, Codable {
    public let poolID: String
    public let name: String
    public let totalSuppliedUSD: Decimal
    public let totalBorrowedUSD: Decimal
    public let utilizationRate: Decimal
    public let reserves: [PoolReserveData]
    public let backstopStats: BackstopStats
    public let lastUpdated: Date
    
    public var tvl: Decimal {
        return totalSuppliedUSD
    }
    
    public var netAPY: Decimal {
        // Calculate weighted average APY
        return reserves.reduce(Decimal.zero) { total, reserve in
            let weight = reserve.totalSuppliedUSD / totalSuppliedUSD
            return total + (reserve.supplyAPY * weight)
        }
    }
}

/// Individual reserve data within a pool
public struct PoolReserveData: Sendable, Codable {
    public let assetID: String
    public let symbol: String
    public let totalSupplied: Decimal
    public let totalSuppliedUSD: Decimal
    public let totalBorrowed: Decimal
    public let totalBorrowedUSD: Decimal
    public let utilizationRate: Decimal
    public let supplyAPY: Decimal
    public let borrowAPY: Decimal
    public let price: Decimal
    public let scalar: Decimal
    public let collateralFactor: Decimal
    public let liabilityFactor: Decimal
    public let contractAddress: String
}

// MARK: - Backstop Statistics Models

/// Backstop-specific statistics for a pool
@available(macOS 15.0, iOS 18.0, *)
public struct BackstopStats: Sendable, Codable {
    public let poolID: String
    public let totalBackstopLiquidity: Decimal
    public let backstopAPY: Decimal
    public let totalShares: Int128
    public let queuedWithdrawals: Decimal
    public let utilizationRate: Decimal
    public let blndBalance: Decimal
    public let usdcBalance: Decimal
    public let emissionsPerSecond: Decimal
    public let backstopToken: String
    public let lastUpdated: Date
}

// MARK: - User Statistics Models

/// User-specific statistics and positions
public struct UserStats: Sendable, Codable {
    public let userAddress: String
    public let positions: [UserPosition]
    public let backstopStats: UserBackstopStats
    public let totalCollateralUSD: Decimal
    public let totalBorrowedUSD: Decimal
    public let healthFactor: Decimal
    public let netAPY: Decimal
    public let lastUpdated: Date
    
    public var isHealthy: Bool {
        return healthFactor > 1.2
    }
}

/// User position in a specific pool
public struct UserPosition: Sendable, Codable {
    public let poolID: String
    public let suppliedAssets: [UserAssetPosition]
    public let borrowedAssets: [UserAssetPosition]
    public let collateralValue: Decimal
    public let borrowValue: Decimal
    public let healthFactor: Decimal
}

/// User's position in a specific asset
public struct UserAssetPosition: Sendable, Codable {
    public let assetID: String
    public let symbol: String
    public let amount: Decimal
    public let valueUSD: Decimal
    public let apy: Decimal
    public let isCollateral: Bool
}

/// User's backstop positions and rewards
public struct UserBackstopStats: Sendable, Codable {
    public let userAddress: String
    public let positions: [UserBackstopPosition]
    public let totalBackstopValue: Decimal
    public let totalClaimableRewards: Decimal
    public let totalQueuedWithdrawals: Decimal
    public let nextWithdrawalDate: Date?
    public let lastUpdated: Date
}

/// User's backstop position for a specific pool
@available(macOS 15.0, iOS 18.0, *)
public struct UserBackstopPosition: Sendable, Codable {
    public let poolID: String
    public let shares: Int128
    public let valueInUSD: Decimal
    public let queuedWithdrawals: [QueuedWithdrawal]
    public let claimableRewards: Decimal
    public let apy: Decimal
}

// MARK: - Asset Information Models

/// Complete asset information with metadata
public struct Asset: Sendable, Codable, Identifiable {
    public let id: String
    public let contractAddress: String
    public let symbol: String
    public let name: String
    public let decimals: Int
    public let price: Decimal
    public let totalSupply: Decimal?
    public let iconURL: String?
    
    public init(
        id: String,
        contractAddress: String,
        symbol: String,
        name: String,
        decimals: Int,
        price: Decimal,
        totalSupply: Decimal? = nil,
        iconURL: String? = nil
    ) {
        self.id = id
        self.contractAddress = contractAddress
        self.symbol = symbol
        self.name = name
        self.decimals = decimals
        self.price = price
        self.totalSupply = totalSupply
        self.iconURL = iconURL
    }
}

/// Asset statistics with financial data
public struct AssetStats: Sendable, Codable {
    public let asset: Asset
    public let pools: [AssetPoolStats]
    public let totalSuppliedAcrossPools: Decimal
    public let totalBorrowedAcrossPools: Decimal
    public let averageSupplyAPY: Decimal
    public let averageBorrowAPY: Decimal
    public let utilizationRate: Decimal
}

/// Asset statistics within a specific pool
public struct AssetPoolStats: Sendable, Codable {
    public let poolID: String
    public let totalSupplied: Decimal
    public let totalBorrowed: Decimal
    public let supplyAPY: Decimal
    public let borrowAPY: Decimal
    public let utilizationRate: Decimal
}

// MARK: - Transaction Models

/// Result of a transaction operation
public struct TransactionResult: Sendable, Codable {
    public let transactionHash: String
    public let success: Bool
    public let operation: TransactionOperation
    public let amount: Decimal
    public let assetID: String?
    public let poolID: String
    public let gasUsed: UInt64?
    public let timestamp: Date
    public let details: TransactionDetails?
}

/// Type of transaction operation
public enum TransactionOperation: String, Sendable, Codable {
    case poolDeposit
    case poolWithdraw
    case backstopDeposit
    case backstopWithdraw
    case backstopClaim
    case borrow
    case repay
}

/// Additional transaction details
public struct TransactionDetails: Sendable, Codable {
    public let sharesReceived: Decimal?
    public let tokensUsed: [String: Decimal]?
    public let newHealthFactor: Decimal?
    public let rewards: Decimal?
}

/// Transaction estimation result
public struct TransactionEstimate: Sendable, Codable {
    public let operation: TransactionOperation
    public let estimatedGas: UInt64
    public let estimatedCost: Decimal
    public let estimatedOutput: Decimal?
    public let requiredTokens: [String: Decimal]?
    public let healthFactorAfter: Decimal?
    public let warnings: [String]
}

// MARK: - Withdrawal Queue Models

/// Queued withdrawal information
public struct QueuedWithdrawal: Sendable, Codable {
    public let poolID: String
    public let amount: Decimal
    public let queuedAt: Date
    public let availableAt: Date
    public let estimatedValue: Decimal
    public let canExecuteNow: Bool
}

/// Withdrawal optimization suggestion
public struct WithdrawalOptimization: Sendable, Codable {
    public let suggestion: String
    public let potentialSavings: Decimal
    public let action: OptimizationAction
}

/// Optimization action types
public enum OptimizationAction: Sendable, Codable {
    case combineWithdrawals([String])
    case delayWithdrawal(until: Date, reason: String)
    case executeEarly(poolID: String)
}

// MARK: - Health Monitoring Models

/// APY Range for backstop statistics
public struct APYRange: Sendable, Codable {
    public let min: Decimal
    public let max: Decimal
    
    public init(min: Decimal, max: Decimal) {
        self.min = min
        self.max = max
    }
}

/// Overall protocol statistics
public struct BlendStats: Sendable, Codable {
    public let totalSuppliedUSD: Decimal
    public let totalBorrowedUSD: Decimal
    public let totalBackstopLiquidity: Decimal
    public let overallUtilization: Decimal
    public let backstopUtilization: Decimal
    public let backstopAPYRange: APYRange
    public let numberOfPools: Int
    public let numberOfAssets: Int
    public let lastUpdated: Date
}

/// Backstop health alert
public struct BackstopHealthAlert: Sendable, Codable {
    public let poolID: String
    public let alertType: BackstopAlertType
    public let severity: AlertSeverity
    public let message: String
    public let threshold: Decimal
    public let currentValue: Decimal
    public let recommendedAction: String?
}

/// Types of backstop alerts
public enum BackstopAlertType: String, Sendable, Codable {
    case highUtilization
    case lowLiquidity
    case emissionChange
    case withdrawalDelays
}

/// Alert severity levels
public enum AlertSeverity: String, Sendable, Codable {
    case info
    case warning
    case critical
}

/// Overall backstop health status
public struct BackstopHealthStatus: Sendable, Codable {
    public let overallHealth: HealthLevel
    public let alerts: [BackstopHealthAlert]
    public let recommendations: [String]
    public let utilizationTrend: UtilizationTrend
}

/// Pool health status
public struct PoolHealthStatus: Sendable, Codable {
    public let poolID: String
    public let health: HealthLevel
    public let utilizationRate: Decimal
    public let collateralRatio: Decimal
    public let alerts: [String]
}

/// User health status
public struct UserHealthStatus: Sendable, Codable {
    public let healthFactor: Decimal
    public let riskLevel: RiskLevel
    public let backstopExposure: Decimal
    public let diversificationScore: Decimal
    public let recommendations: [String]
}

/// Health levels
public enum HealthLevel: String, Sendable, Codable {
    case excellent
    case good
    case moderate
    case poor
    case critical
}

/// Risk levels
public enum RiskLevel: String, Sendable, Codable {
    case low
    case moderate
    case high
    case critical
}

/// Utilization trend direction
public enum UtilizationTrend: String, Sendable, Codable {
    case increasing
    case stable
    case decreasing
}

// MARK: - Emission Data Models

/// Emission statistics
public struct EmissionStats: Sendable, Codable {
    public let poolID: String
    public let emissionsPerSecond: Decimal
    public let totalDistributed: Decimal
    public let remainingEmissions: Decimal
    public let nextDistribution: Date
}

// MARK: - Network Enum
public enum Network: String, Sendable, Codable {
    case testnet
    case mainnet
}

// MARK: - Network Conversion Extension
extension Network {
    /// Convert BlendModels.Network to BlendConstants.NetworkType
    public var networkType: BlendConstants.NetworkType {
        switch self {
        case .testnet:
            return .testnet
        case .mainnet:
            return .mainnet
        }
    }
} 