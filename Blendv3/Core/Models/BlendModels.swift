//
//  BlendModels.swift
//  Blendv3
//
//  Core data models for the Blend protocol
//

import Foundation
import stellarsdk

// MARK: - Lending Pool Models

/// Represents a lending pool in the Blend protocol
struct LendingPool: Identifiable, Codable {
    let id: String
    let name: String
    let poolAddress: String
    let backstopAddress: String
    let oracleId: String
    let supportedAssets: [PoolAsset]
    let totalValueLocked: Decimal
    let isActive: Bool
    
    var displayName: String {
        name.isEmpty ? "Pool \(id.prefix(8))" : name
    }
}

/// Represents an asset supported by a lending pool
struct PoolAsset: Identifiable, Codable {
    let id: String
    let assetCode: String
    let assetIssuer: String?
    let totalSupply: Decimal
    let totalBorrowed: Decimal
    let utilizationRate: Decimal
    let supplyAPY: Decimal
    let borrowAPY: Decimal
    let reserveFactor: Decimal
    
    var isNative: Bool {
        assetCode == "XLM" && assetIssuer == nil
    }
    
    var availableLiquidity: Decimal {
        totalSupply - totalBorrowed
    }
}// MARK: - User Position Models

/// Represents a user's position in a lending pool
struct UserPosition: Identifiable, Codable {
    let id: String
    let poolId: String
    let userAddress: String
    let suppliedAssets: [SuppliedAsset]
    let borrowedAssets: [BorrowedAsset]
    let healthFactor: Decimal
    let netAPY: Decimal
    
    var totalSuppliedValue: Decimal {
        suppliedAssets.reduce(0) { $0 + $1.valueInUSD }
    }
    
    var totalBorrowedValue: Decimal {
        borrowedAssets.reduce(0) { $0 + $1.valueInUSD }
    }
    
    var isHealthy: Bool {
        healthFactor > 1.0
    }
}

/// Represents a supplied asset in a user's position
struct SuppliedAsset: Identifiable, Codable {
    let id: String
    let assetCode: String
    let amount: Decimal
    let valueInUSD: Decimal
    let apy: Decimal
    let isCollateral: Bool
}

/// Represents a borrowed asset in a user's position
struct BorrowedAsset: Identifiable, Codable {
    let id: String
    let assetCode: String
    let amount: Decimal
    let valueInUSD: Decimal
    let apy: Decimal
    let accruedInterest: Decimal
}// MARK: - Backstop Models

/// Represents backstop module information
struct BackstopInfo: Codable {
    let poolId: String
    let totalDeposits: Decimal
    let q4wPercentage: Decimal
    let rewardEmissions: Decimal
    let insuranceCoverage: Decimal
}

// MARK: - Transaction Models

/// Represents a lending transaction
enum LendingTransaction {
    case supply(asset: String, amount: Decimal)
    case withdraw(asset: String, amount: Decimal)
    case borrow(asset: String, amount: Decimal)
    case repay(asset: String, amount: Decimal)
    case liquidate(userAddress: String, debtAsset: String, collateralAsset: String)
}

// MARK: - Error Models

/// Errors specific to Blend operations
enum BlendError: LocalizedError {
    case insufficientLiquidity
    case healthFactorTooLow
    case assetNotSupported
    case poolNotActive
    case invalidAmount
    case contractError(String)
    
    var errorDescription: String? {
        switch self {
        case .insufficientLiquidity:
            return "Insufficient liquidity in the pool"
        case .healthFactorTooLow:
            return "Health factor would be too low after this operation"
        case .assetNotSupported:
            return "This asset is not supported by the pool"
        case .poolNotActive:
            return "The lending pool is not active"
        case .invalidAmount:
            return "Invalid amount specified"
        case .contractError(let message):
            return "Contract error: \(message)"
        }
    }
}