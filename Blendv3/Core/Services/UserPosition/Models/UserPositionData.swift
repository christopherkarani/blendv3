//
//  UserPositionData.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//

import Foundation

/// User position data
public struct UserPositionData: Codable {
    public let userId: String
    public let supplied: Decimal
    public let borrowed: Decimal
    public let collateral: Decimal
    public let availableToBorrow: Decimal
    public let healthFactor: Decimal
    public let netAPY: Decimal
    public let claimableEmissions: Decimal
    
    public init(
        userId: String,
        supplied: Decimal,
        borrowed: Decimal,
        collateral: Decimal,
        availableToBorrow: Decimal,
        healthFactor: Decimal,
        netAPY: Decimal,
        claimableEmissions: Decimal
    ) {
        self.userId = userId
        self.supplied = supplied
        self.borrowed = borrowed
        self.collateral = collateral
        self.availableToBorrow = availableToBorrow
        self.healthFactor = healthFactor
        self.netAPY = netAPY
        self.claimableEmissions = claimableEmissions
    }
}

