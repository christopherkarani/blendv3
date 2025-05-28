//
//  BlendPoolStats.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

/// Represents comprehensive statistics for a Blend lending pool
/// Distinguishes between pool-level data and asset-specific data
public struct BlendPoolStats: Codable {
    
    /// Pool-level aggregated statistics
    public let poolData: PoolLevelData
    
    /// USDC reserve-specific statistics
    public let usdcReserveData: USDCReserveData
    
    /// Backstop insurance data
    public let backstopData: BackstopData
    
    /// Timestamp when these stats were fetched
    public let lastUpdated: Date
    
    /// Initialize comprehensive pool stats
    public init(
        poolData: PoolLevelData,
        usdcReserveData: USDCReserveData,
        backstopData: BackstopData,
        lastUpdated: Date
    ) {
        self.poolData = poolData
        self.usdcReserveData = usdcReserveData
        self.backstopData = backstopData
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Pool Level Data

/// Pool-level aggregated statistics across all assets
public struct PoolLevelData: Codable {
    /// Total value locked in the pool (all assets)
    public let totalValueLocked: Decimal
    
    /// Overall pool utilization rate
    public let overallUtilization: Decimal
    
    /// Pool health score
    public let healthScore: Decimal
    
    /// Number of active reserves in the pool
    public let activeReserves: Int
    
    public init(
        totalValueLocked: Decimal,
        overallUtilization: Decimal,
        healthScore: Decimal,
        activeReserves: Int
    ) {
        self.totalValueLocked = totalValueLocked
        self.overallUtilization = overallUtilization
        self.healthScore = healthScore
        self.activeReserves = activeReserves
    }
}

// MARK: - USDC Reserve Data

/// USDC-specific reserve statistics within the pool
public struct USDCReserveData: Codable {
    /// Total USDC supplied to the reserve
    public let totalSupplied: Decimal
    
    /// Total USDC borrowed from the reserve
    public let totalBorrowed: Decimal
    
    /// Available USDC liquidity
    public var availableLiquidity: Decimal {
        return totalSupplied - totalBorrowed
    }
    
    /// USDC reserve utilization rate
    public let utilizationRate: Decimal
    
    /// USDC supply APR (Annual Percentage Rate)
    public let supplyApr: Decimal
    
    /// USDC supply APY (Annual Percentage Yield with compounding)
    public let supplyApy: Decimal
    
    /// USDC borrow APR
    public let borrowApr: Decimal
    
    /// USDC borrow APY
    public let borrowApy: Decimal
    
    /// USDC collateral factor (95.0% = 0.95)
    public let collateralFactor: Decimal
    
    /// USDC liability factor (105.26% = 1.0526)
    public let liabilityFactor: Decimal
    
    public init(
        totalSupplied: Decimal,
        totalBorrowed: Decimal,
        utilizationRate: Decimal,
        supplyApr: Decimal,
        supplyApy: Decimal,
        borrowApr: Decimal,
        borrowApy: Decimal,
        collateralFactor: Decimal,
        liabilityFactor: Decimal
    ) {
        self.totalSupplied = totalSupplied
        self.totalBorrowed = totalBorrowed
        self.utilizationRate = utilizationRate
        self.supplyApr = supplyApr
        self.supplyApy = supplyApy
        self.borrowApr = borrowApr
        self.borrowApy = borrowApy
        self.collateralFactor = collateralFactor
        self.liabilityFactor = liabilityFactor
    }
}

// MARK: - Backstop Data

/// Backstop insurance pool statistics
public struct BackstopData: Codable {
    /// Total backstop insurance fund
    public let totalBackstop: Decimal
    
    /// Backstop APR
    public let backstopApr: Decimal
    
    /// Q4W (Queue for Withdrawal) percentage
    public let q4wPercentage: Decimal
    
    /// Take rate percentage (10.0% = 0.10)
    public let takeRate: Decimal
    
    /// BLND tokens in backstop
    public let blndAmount: Decimal
    
    /// USDC tokens in backstop
    public let usdcAmount: Decimal
    
    public init(
        totalBackstop: Decimal,
        backstopApr: Decimal,
        q4wPercentage: Decimal,
        takeRate: Decimal,
        blndAmount: Decimal,
        usdcAmount: Decimal
    ) {
        self.totalBackstop = totalBackstop
        self.backstopApr = backstopApr
        self.q4wPercentage = q4wPercentage
        self.takeRate = takeRate
        self.blndAmount = blndAmount
        self.usdcAmount = usdcAmount
    }
}

// MARK: - Backward Compatibility

extension BlendPoolStats {
    /// Legacy total supplied (USDC reserve)
    @available(*, deprecated, message: "Use usdcReserveData.totalSupplied instead")
    public var totalSupplied: Decimal {
        return usdcReserveData.totalSupplied
    }
    
    /// Legacy total borrowed (USDC reserve)
    @available(*, deprecated, message: "Use usdcReserveData.totalBorrowed instead")
    public var totalBorrowed: Decimal {
        return usdcReserveData.totalBorrowed
    }
    
    /// Legacy backstop reserve
    @available(*, deprecated, message: "Use backstopData.totalBackstop instead")
    public var backstopReserve: Decimal {
        return backstopData.totalBackstop
    }
    
    /// Legacy supply APR
    @available(*, deprecated, message: "Use usdcReserveData.supplyApr instead")
    public var supplyApr: Decimal {
        return usdcReserveData.supplyApr
    }
    
    /// Legacy supply APY
    @available(*, deprecated, message: "Use usdcReserveData.supplyApy instead")
    public var supplyApy: Decimal {
        return usdcReserveData.supplyApy
    }
    
    /// Legacy borrow APR
    @available(*, deprecated, message: "Use usdcReserveData.borrowApr instead")
    public var borrowApr: Decimal {
        return usdcReserveData.borrowApr
    }
    
    /// Legacy borrow APY
    @available(*, deprecated, message: "Use usdcReserveData.borrowApy instead")
    public var borrowApy: Decimal {
        return usdcReserveData.borrowApy
    }
    
    /// Legacy utilization rate
    @available(*, deprecated, message: "Use usdcReserveData.utilizationRate instead")
    public var utilizationRate: Decimal {
        return usdcReserveData.utilizationRate
    }
    
    /// Legacy available liquidity
    @available(*, deprecated, message: "Use usdcReserveData.availableLiquidity instead")
    public var availableLiquidity: Decimal {
        return usdcReserveData.availableLiquidity
    }
}

// MARK: - Placeholder Stats

extension BlendPoolStats {
    /// Creates placeholder stats for testing with proper structure
    static func placeholder() -> BlendPoolStats {
        let poolData = PoolLevelData(
            totalValueLocked: 5_000_000,
            overallUtilization: 0.45,
            healthScore: 0.98,
            activeReserves: 3
        )
        
        let usdcReserveData = USDCReserveData(
            totalSupplied: 112_280,
            totalBorrowed: 55_500,
            utilizationRate: 0.494,
            supplyApr: 0.38,
            supplyApy: 0.38,
            borrowApr: 0.48,
            borrowApy: 0.48,
            collateralFactor: 0.95,
            liabilityFactor: 1.0526
        )
        
        let backstopData = BackstopData(
            totalBackstop: 353_750,
            backstopApr: 0.01,
            q4wPercentage: 14.75,
            takeRate: 0.10,
            blndAmount: 250_000,
            usdcAmount: 103_750
        )
        
        return BlendPoolStats(
            poolData: poolData,
            usdcReserveData: usdcReserveData,
            backstopData: backstopData,
            lastUpdated: Date()
        )
    }
}

// MARK: - Comprehensive Pool Statistics

/// Comprehensive pool statistics including all assets
public struct ComprehensivePoolStats {
    /// Pool-level aggregated statistics
    public let poolData: PoolLevelData
    
    /// All asset reserves data
    public let allReserves: [String: AssetReserveData]
    
    /// Backstop insurance data
    public let backstopData: BackstopData
    
    /// Timestamp when these stats were fetched
    public let lastUpdated: Date
    
    public init(
        poolData: PoolLevelData,
        allReserves: [String: AssetReserveData],
        backstopData: BackstopData,
        lastUpdated: Date
    ) {
        self.poolData = poolData
        self.allReserves = allReserves
        self.backstopData = backstopData
        self.lastUpdated = lastUpdated
    }
    
    /// Get USDC reserve data for backward compatibility
    public var usdcReserveData: USDCReserveData {
        guard let usdcAsset = allReserves["USDC"] else {
            return USDCReserveData(
                totalSupplied: 0, totalBorrowed: 0, utilizationRate: 0,
                supplyApr: 0, supplyApy: 0, borrowApr: 0, borrowApy: 0,
                collateralFactor: 0.95, liabilityFactor: 1.0526
            )
        }
        
        return USDCReserveData(
            totalSupplied: usdcAsset.totalSupplied,
            totalBorrowed: usdcAsset.totalBorrowed,
            utilizationRate: usdcAsset.utilizationRate,
            supplyApr: usdcAsset.supplyApr,
            supplyApy: usdcAsset.supplyApy,
            borrowApr: usdcAsset.borrowApr,
            borrowApy: usdcAsset.borrowApy,
            collateralFactor: usdcAsset.collateralFactor,
            liabilityFactor: usdcAsset.liabilityFactor
        )
    }
}

// MARK: - Asset Reserve Data

/// Generic asset reserve data for any asset in the pool
public struct AssetReserveData: Codable {
    /// Asset symbol (e.g., "USDC", "XLM", "BLND")
    public let symbol: String
    
    /// Asset contract address
    public let contractAddress: String
    
    /// Total amount supplied to this reserve
    public let totalSupplied: Decimal
    
    /// Total amount borrowed from this reserve
    public let totalBorrowed: Decimal
    
    /// Asset price in USD (for USD value calculations)
    public let price: Decimal
    
    /// Available liquidity for this asset
    public var availableLiquidity: Decimal {
        return totalSupplied - totalBorrowed
    }
    
    /// Total supplied in USD
    public var totalSuppliedUSD: Decimal {
        return totalSupplied * price
    }
    
    /// Total borrowed in USD
    public var totalBorrowedUSD: Decimal {
        return totalBorrowed * price
    }
    
    /// Available liquidity in USD
    public var availableLiquidityUSD: Decimal {
        return availableLiquidity * price
    }
    
    /// Asset utilization rate
    public let utilizationRate: Decimal
    
    /// Asset supply APR
    public let supplyApr: Decimal
    
    /// Asset supply APY
    public let supplyApy: Decimal
    
    /// Asset borrow APR
    public let borrowApr: Decimal
    
    /// Asset borrow APY
    public let borrowApy: Decimal
    
    /// Asset collateral factor
    public let collateralFactor: Decimal
    
    /// Asset liability factor
    public let liabilityFactor: Decimal
    
    public init(
        symbol: String,
        contractAddress: String,
        totalSupplied: Decimal,
        totalBorrowed: Decimal,
        price: Decimal,
        utilizationRate: Decimal,
        supplyApr: Decimal,
        supplyApy: Decimal,
        borrowApr: Decimal,
        borrowApy: Decimal,
        collateralFactor: Decimal,
        liabilityFactor: Decimal
    ) {
        self.symbol = symbol
        self.contractAddress = contractAddress
        self.totalSupplied = totalSupplied
        self.totalBorrowed = totalBorrowed
        self.price = price
        self.utilizationRate = utilizationRate
        self.supplyApr = supplyApr
        self.supplyApy = supplyApy
        self.borrowApr = borrowApr
        self.borrowApy = borrowApy
        self.collateralFactor = collateralFactor
        self.liabilityFactor = liabilityFactor
    }
}

// MARK: - Pool Summary

/// Simple pool summary for quick overview
public struct PoolSummary {
    public let totalValueLocked: Decimal
    public let totalBorrowed: Decimal
    public let overallUtilization: Decimal
    public let healthScore: Decimal
    public let activeAssets: Int
    public let topAssetByTVL: String
    public let averageSupplyAPY: Decimal
    
    public init(
        totalValueLocked: Decimal,
        totalBorrowed: Decimal,
        overallUtilization: Decimal,
        healthScore: Decimal,
        activeAssets: Int,
        topAssetByTVL: String,
        averageSupplyAPY: Decimal
    ) {
        self.totalValueLocked = totalValueLocked
        self.totalBorrowed = totalBorrowed
        self.overallUtilization = overallUtilization
        self.healthScore = healthScore
        self.activeAssets = activeAssets
        self.topAssetByTVL = topAssetByTVL
        self.averageSupplyAPY = averageSupplyAPY
    }
}

// MARK: - True Pool Statistics (Based on Actual Contract Functions)

/// Individual reserve data for each asset in the pool
public struct PoolReserveData: Codable {
    public let asset: String             // Asset contract address
    public let symbol: String            // Human readable symbol (USDC, XLM, etc.)
    public let totalSupplied: Decimal    // From ReserveData
    public let totalBorrowed: Decimal    // From ReserveData
    public let utilizationRate: Decimal  // Calculated utilization
    public let supplyAPY: Decimal        // Supply APY
    public let borrowAPY: Decimal        // Borrow APY
    public let scalar: Decimal           // Scalar for decimal conversion
    public let price: Decimal            // Asset price in USD
    
    /// Total supplied in USD
    public var totalSuppliedUSD: Decimal {
        return totalSupplied * price
    }
    
    /// Total borrowed in USD  
    public var totalBorrowedUSD: Decimal {
        return totalBorrowed * price
    }
    
    /// Available liquidity
    public var availableLiquidity: Decimal {
        return totalSupplied - totalBorrowed
    }
    
    /// Available liquidity in USD
    public var availableLiquidityUSD: Decimal {
        return availableLiquidity * price
    }
    
    public init(
        asset: String,
        symbol: String,
        totalSupplied: Decimal,
        totalBorrowed: Decimal,
        utilizationRate: Decimal,
        supplyAPY: Decimal,
        borrowAPY: Decimal,
        scalar: Decimal,
        price: Decimal
    ) {
        self.asset = asset
        self.symbol = symbol
        self.totalSupplied = totalSupplied
        self.totalBorrowed = totalBorrowed
        self.utilizationRate = utilizationRate
        self.supplyAPY = supplyAPY
        self.borrowAPY = borrowAPY
        self.scalar = scalar
        self.price = price
    }
}

/// True pool-wide statistics aggregated from all reserves
public struct TruePoolStats {
    public let totalSuppliedUSD: Decimal     // Target: $111.28k
    public let totalBorrowedUSD: Decimal     // Target: $55.50k  
    public let backstopBalanceUSD: Decimal   // Target: $353.75k
    public let overallUtilization: Decimal   // totalBorrowed / totalSupplied
    public let backstopRate: Decimal         // From PoolConfig
    public let poolStatus: UInt32            // From PoolConfig
    public let reserves: [PoolReserveData]   // All individual assets
    public let lastUpdated: Date
    
    /// Available liquidity across all assets
    public var totalAvailableLiquidityUSD: Decimal {
        return totalSuppliedUSD - totalBorrowedUSD
    }
    
    /// Number of active reserves
    public var activeReserves: Int {
        return reserves.count
    }
    
    /// Top asset by TVL
    public var topAssetByTVL: String {
        return reserves.max(by: { $0.totalSuppliedUSD < $1.totalSuppliedUSD })?.symbol ?? "N/A"
    }
    
    /// Average supply APY across all assets (weighted by TVL)
    public var weightedAverageSupplyAPY: Decimal {
        let totalTVL = reserves.reduce(Decimal(0)) { $0 + $1.totalSuppliedUSD }
        guard totalTVL > 0 else { return 0 }
        
        let weightedSum = reserves.reduce(Decimal(0)) { sum, reserve in
            let weight = reserve.totalSuppliedUSD / totalTVL
            return sum + (reserve.supplyAPY * weight)
        }
        return weightedSum
    }
    
    public init(
        totalSuppliedUSD: Decimal,
        totalBorrowedUSD: Decimal,
        backstopBalanceUSD: Decimal,
        overallUtilization: Decimal,
        backstopRate: Decimal,
        poolStatus: UInt32,
        reserves: [PoolReserveData],
        lastUpdated: Date
    ) {
        self.totalSuppliedUSD = totalSuppliedUSD
        self.totalBorrowedUSD = totalBorrowedUSD
        self.backstopBalanceUSD = backstopBalanceUSD
        self.overallUtilization = overallUtilization
        self.backstopRate = backstopRate
        self.poolStatus = poolStatus
        self.reserves = reserves
        self.lastUpdated = lastUpdated
    }
}

/// Emissions data for a specific reserve
public struct EmissionData {
    public let reserveTokenIndex: UInt32
    public let symbol: String
    public let claimableAmount: Decimal
    public let emissionRate: Decimal
    
    public init(reserveTokenIndex: UInt32, symbol: String, claimableAmount: Decimal, emissionRate: Decimal) {
        self.reserveTokenIndex = reserveTokenIndex
        self.symbol = symbol
        self.claimableAmount = claimableAmount
        self.emissionRate = emissionRate
    }
} 