//
//  PositionsEstimate.swift
//  Blendv3
//
//  Represents user-specific position stats for a Blend lending pool, inspired by Blend SDK's PositionsEstimate.
//

import Foundation

/// Protocol for user position estimate types (for protocol-oriented design)
public protocol PositionsEstimateProtocol {
    var netApr: Decimal { get }
    var netApy: Decimal { get }
    var healthFactor: Decimal { get }
    var totalSupplied: Decimal { get }
    var totalBorrowed: Decimal { get }
    var lastUpdated: Date { get }
}

/// Value type for user-specific stats (net APR/APY, health factor, etc.)
public struct PositionsEstimate: PositionsEstimateProtocol {
    /// Net Annual Percentage Rate for the user's position (e.g., 0.0325 for 3.25%)
    public let netApr: Decimal
    /// Net Annual Percentage Yield for the user's position (compounded, if available)
    public let netApy: Decimal
    /// Health factor (liquidation threshold, >1 is healthy)
    public let healthFactor: Decimal
    /// Total supplied by the user (in asset units)
    public let totalSupplied: Decimal
    /// Total borrowed by the user (in asset units)
    public let totalBorrowed: Decimal
    /// Timestamp when these stats were fetched
    public let lastUpdated: Date
    
    public init(
        netApr: Decimal,
        netApy: Decimal,
        healthFactor: Decimal,
        totalSupplied: Decimal,
        totalBorrowed: Decimal,
        lastUpdated: Date
    ) {
        self.netApr = netApr
        self.netApy = netApy
        self.healthFactor = healthFactor
        self.totalSupplied = totalSupplied
        self.totalBorrowed = totalBorrowed
        self.lastUpdated = lastUpdated
    }
} 