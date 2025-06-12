//
//  PoolConfig.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//

import Foundation

/// Pool configuration
public struct PoolConfig: Codable {
    public let backstopRate: UInt32
    public let maxPositions: UInt32
    public let minCollateral: Decimal
    public let oracle: String
    public let status: UInt32
    
    public init(
        backstopRate: UInt32,
        maxPositions: UInt32,
        minCollateral: Decimal = 0,
        oracle: String = "",
        status: UInt32
    ) {
        self.backstopRate = backstopRate
        self.maxPositions = maxPositions
        self.minCollateral = minCollateral
        self.oracle = oracle
        self.status = status
    }
}
