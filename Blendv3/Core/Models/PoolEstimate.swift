//
//  PoolEstimate.swift
//  Blendv3
//
//  Represents pool-wide statistics for a Blend lending pool, inspired by Blend SDK's PoolEstimate.
//

import Foundation

/// Protocol for pool-wide estimate types (for protocol-oriented design)
public protocol PoolEstimateProtocol {
    var supplyApr: Decimal { get }
    var supplyApy: Decimal { get }
    var borrowApr: Decimal { get }
    var borrowApy: Decimal { get }
    var utilization: Decimal { get }
    var totalSupplied: Decimal { get }
    var totalBorrowed: Decimal { get }
    var backstopApr: Decimal? { get }
    var lastUpdated: Date { get }
}

/// Value type for pool-wide stats (supply/borrow APR/APY, utilization, etc.)
public struct PoolEstimate: PoolEstimateProtocol {
    /// Annual Percentage Rate for suppliers (e.g., 0.0525 for 5.25%)
    public let supplyApr: Decimal
    /// Annual Percentage Yield for suppliers (compounded, if available)
    public let supplyApy: Decimal
    /// Annual Percentage Rate for borrowers
    public let borrowApr: Decimal
    /// Annual Percentage Yield for borrowers (compounded, if available)
    public let borrowApy: Decimal
    /// Utilization rate (borrowed / supplied)
    public let utilization: Decimal
    /// Total supplied to the pool (in asset units)
    public let totalSupplied: Decimal
    /// Total borrowed from the pool (in asset units)
    public let totalBorrowed: Decimal
    /// Backstop APR (if available, optional)
    public let backstopApr: Decimal?
    /// Timestamp when these stats were fetched
    public let lastUpdated: Date
    
    public init(
        supplyApr: Decimal,
        supplyApy: Decimal,
        borrowApr: Decimal,
        borrowApy: Decimal,
        utilization: Decimal,
        totalSupplied: Decimal,
        totalBorrowed: Decimal,
        backstopApr: Decimal? = nil,
        lastUpdated: Date
    ) {
        self.supplyApr = supplyApr
        self.supplyApy = supplyApy
        self.borrowApr = borrowApr
        self.borrowApy = borrowApy
        self.utilization = utilization
        self.totalSupplied = totalSupplied
        self.totalBorrowed = totalBorrowed
        self.backstopApr = backstopApr
        self.lastUpdated = lastUpdated
    }
} 