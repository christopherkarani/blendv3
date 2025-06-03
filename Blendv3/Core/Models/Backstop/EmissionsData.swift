//
//  EmissionsData.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//
import Foundation

public struct EmissionsData: Codable {
    
    /// Pool identifier
    public let poolId: String
    
    /// BLND token address
    public let blndTokenAddress: String
    
    /// Emissions per second (fixed-point with 7 decimals)
    public let emissionsPerSecond: Decimal
    
    /// Total emissions allocated to this pool
    public let totalAllocated: Decimal
    
    /// Total emissions claimed so far
    public let totalClaimed: Decimal
    
    /// Last emission update timestamp
    public let lastUpdateTime: Date
    
    /// Emission end timestamp
    public let endTime: Date
    
    /// Whether emissions are currently active
    public let isActive: Bool
    
    // MARK: - Calculated Properties
    
    /// Remaining emissions to be distributed
    public var remainingEmissions: Decimal {
        return max(0, totalAllocated - totalClaimed)
    }
    
    /// Emissions per year
    public var emissionsPerYear: Decimal {
        return emissionsPerSecond * FixedMath.toFixed(value: 31536000, decimals: 7) // seconds in year
    }
    
    /// Whether emissions have ended
    public var hasEnded: Bool {
        return Date() > endTime || remainingEmissions <= 0
    }
    
    /// Time remaining for emissions (in seconds)
    public var timeRemaining: TimeInterval {
        return max(0, endTime.timeIntervalSince(Date()))
    }
    
    public init(
        poolId: String,
        blndTokenAddress: String,
        emissionsPerSecond: Decimal,
        totalAllocated: Decimal,
        totalClaimed: Decimal = 0,
        lastUpdateTime: Date = Date(),
        endTime: Date,
        isActive: Bool = true
    ) {
        self.poolId = poolId
        self.blndTokenAddress = blndTokenAddress
        self.emissionsPerSecond = emissionsPerSecond
        self.totalAllocated = totalAllocated
        self.totalClaimed = totalClaimed
        self.lastUpdateTime = lastUpdateTime
        self.endTime = endTime
        self.isActive = isActive
        
        BlendLogger.debug(
            "EmissionsData initialized for pool: \(poolId), rate: \(emissionsPerSecond)/sec",
            category: BlendLogger.rateCalculation
        )
    }
}


extension EmissionsData: Equatable {
    public static func == (lhs: EmissionsData, rhs: EmissionsData) -> Bool {
        return lhs.poolId == rhs.poolId &&
               lhs.emissionsPerSecond == rhs.emissionsPerSecond
    }
}
