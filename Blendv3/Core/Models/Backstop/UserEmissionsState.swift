//
//  UserEmissionsState.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//
import Foundation

/// User-specific emissions tracking
public struct UserEmissionsState: Codable {
    
    /// User address
    public let userAddress: String
    
    /// Pool identifier
    public let poolId: String
    
    /// User's backstop token balance
    public let backstopTokenBalance: Decimal
    
    /// User's share of total backstop tokens (0-1)
    public let shareOfPool: Double
    
    /// Total emissions claimed by user
    public let totalClaimed: Decimal
    
    /// Last claim timestamp
    public let lastClaimTime: Date
    
    /// Accrued emissions since last claim
    public let accruedEmissions: Decimal
    
    /// Emissions index at last update
    public let lastEmissionsIndex: Decimal
    
    // MARK: - Calculated Properties
    
    /// Claimable emissions right now
    public var claimableEmissions: Decimal {
        return accruedEmissions
    }
    
    /// Whether user has claimable emissions
    public var hasClaimableEmissions: Bool {
        return accruedEmissions > 0
    }
    
    /// Time since last claim (in seconds)
    public var timeSinceLastClaim: TimeInterval {
        return Date().timeIntervalSince(lastClaimTime)
    }
    
    public init(
        userAddress: String,
        poolId: String,
        backstopTokenBalance: Decimal,
        shareOfPool: Double,
        totalClaimed: Decimal = 0,
        lastClaimTime: Date = Date(),
        accruedEmissions: Decimal = 0,
        lastEmissionsIndex: Decimal = 0
    ) {
        self.userAddress = userAddress
        self.poolId = poolId
        self.backstopTokenBalance = backstopTokenBalance
        self.shareOfPool = shareOfPool
        self.totalClaimed = totalClaimed
        self.lastClaimTime = lastClaimTime
        self.accruedEmissions = accruedEmissions
        self.lastEmissionsIndex = lastEmissionsIndex
        
        BlendLogger.debug(
            "UserEmissionsState initialized for user: \(userAddress), share: \(shareOfPool)",
            category: BlendLogger.rateCalculation
        )
    }
}

extension UserEmissionsState: Equatable {
    public static func == (lhs: UserEmissionsState, rhs: UserEmissionsState) -> Bool {
        return lhs.userAddress == rhs.userAddress &&
               lhs.poolId == rhs.poolId
    }
}
