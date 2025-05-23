//
//  BlendPoolStats.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

/// Represents the current statistics of a Blend lending pool
public struct BlendPoolStats {
    
    /// Total amount of USDC supplied to the pool
    public let totalSupplied: Decimal
    
    /// Total amount of USDC borrowed from the pool
    public let totalBorrowed: Decimal
    
    /// Amount reserved for the backstop insurance
    public let backstopReserve: Decimal
    
    /// Current Annual Percentage Yield for suppliers
    public let currentAPY: Decimal
    
    /// Timestamp when these stats were fetched
    public let lastUpdated: Date
    
    /// Utilization rate of the pool (borrowed / supplied)
    public let utilizationRate: Decimal
    
    /// Available liquidity in the pool
    public var availableLiquidity: Decimal {
        return totalSupplied - totalBorrowed
    }
    
    /// Initialize pool stats
    /// - Parameters:
    ///   - totalSupplied: Total supplied amount
    ///   - totalBorrowed: Total borrowed amount
    ///   - backstopReserve: Backstop reserve amount
    ///   - currentAPY: Current APY as a percentage (e.g., 5.5 for 5.5%)
    ///   - lastUpdated: When the stats were fetched
    ///   - utilizationRate: Utilization rate of the pool
    public init(
        totalSupplied: Decimal,
        totalBorrowed: Decimal,
        backstopReserve: Decimal,
        currentAPY: Decimal,
        lastUpdated: Date,
        utilizationRate: Decimal
    ) {
        self.totalSupplied = totalSupplied
        self.totalBorrowed = totalBorrowed
        self.backstopReserve = backstopReserve
        self.currentAPY = currentAPY
        self.lastUpdated = lastUpdated
        self.utilizationRate = utilizationRate
    }
}

// MARK: - Placeholder Stats

extension BlendPoolStats {
    /// Creates placeholder stats for testing
    /// Note: In production, these values would come from the smart contract
    static func placeholder() -> BlendPoolStats {
        return BlendPoolStats(
            totalSupplied: 1_000_000,
            totalBorrowed: 500_000,
            backstopReserve: 50_000,
            currentAPY: 5.5,
            lastUpdated: Date(),
            utilizationRate: 0.5
        )
    }
} 