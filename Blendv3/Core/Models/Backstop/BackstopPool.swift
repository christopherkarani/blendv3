//
//  BackstopPool.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//
import Foundation

/// Backstop pool configuration and state
public struct BackstopPool: Codable {
    
    // MARK: - Configuration
    
    /// Pool identifier
    public let poolId: String
    
    /// Backstop token address
    public let backstopTokenAddress: String
    
    /// Underlying LP token address
    public let lpTokenAddress: String
    
    /// Minimum backstop threshold (fixed-point with 7 decimals)
    public let minThreshold: Decimal
    
    /// Maximum backstop capacity (fixed-point with 7 decimals)
    public let maxCapacity: Decimal
    
    /// Backstop take rate (percentage of interest captured)
    public let takeRate: Decimal
    
    // MARK: - Current State
    
    /// Total backstop tokens issued
    public let totalBackstopTokens: Decimal
    
    /// Total LP tokens deposited
    public let totalLpTokens: Decimal
    
    /// Current backstop value in USD
    public let totalValueUSD: Double
    
    /// Last update timestamp
    public let lastUpdateTime: Date
    
    /// Pool status
    public let status: BackstopStatus
    
    // MARK: - Calculated Properties
    
    /// Backstop utilization ratio (0-1)
    public var utilization: Double {
        guard maxCapacity > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalBackstopTokens / maxCapacity).doubleValue
    }
    
    /// Available capacity for new deposits
    public var availableCapacity: Decimal {
        return max(0, maxCapacity - totalBackstopTokens)
    }
    
    /// Exchange rate: LP tokens per backstop token
    public var exchangeRate: Decimal {
        guard totalBackstopTokens > 0 else { return FixedMath.SCALAR_7 }
        return FixedMath.divCeil(totalLpTokens, totalBackstopTokens, scalar: FixedMath.SCALAR_7)
    }
    
    /// Whether the backstop is above minimum threshold
    public var isAboveMinThreshold: Bool {
        return totalBackstopTokens >= minThreshold
    }
    
    public init(
        poolId: String,
        backstopTokenAddress: String,
        lpTokenAddress: String,
        minThreshold: Decimal,
        maxCapacity: Decimal,
        takeRate: Decimal,
        totalBackstopTokens: Decimal,
        totalLpTokens: Decimal,
        totalValueUSD: Double,
        lastUpdateTime: Date = Date(),
        status: BackstopStatus = .active
    ) {
        self.poolId = poolId
        self.backstopTokenAddress = backstopTokenAddress
        self.lpTokenAddress = lpTokenAddress
        self.minThreshold = minThreshold
        self.maxCapacity = maxCapacity
        self.takeRate = takeRate
        self.totalBackstopTokens = totalBackstopTokens
        self.totalLpTokens = totalLpTokens
        self.totalValueUSD = totalValueUSD
        self.lastUpdateTime = lastUpdateTime
        self.status = status
        
        BlendLogger.debug(
            "BackstopPool initialized for pool: \(poolId), utilization: \(utilization)",
            category: BlendLogger.rateCalculation
        )
    }
}

extension BackstopPool: Equatable {
    public static func == (lhs: BackstopPool, rhs: BackstopPool) -> Bool {
        return lhs.poolId == rhs.poolId &&
               lhs.totalBackstopTokens == rhs.totalBackstopTokens &&
               lhs.totalLpTokens == rhs.totalLpTokens
    }
}
