//
//  BlendUSDCConstants.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import stellarsdk

/// Constants for interacting with the Blend USDC lending pool on Soroban
public struct BlendUSDCConstants {
    
    // MARK: - Network Configuration
    
    /// Soroban RPC endpoints
    public struct RPC {
        public static let testnet = "https://soroban-testnet.stellar.org"
        public static let mainnet = "https://soroban.stellar.org"
    }
    
    // MARK: - Contract Addresses
    
    /// Blend pool contract address for USDC
    public static let poolContractAddress = "CAMKTT6LIXNOKZJVFI64EBEQE25UYAQZBTHDIQ4LEDJLTCM6YVME6IIY"
    
    /// USDC asset contract address on Soroban
    public static let usdcAssetContractAddress = "CAQCFVLOBK5GIULPNZRGATJJMIZL5BSP7X5YJVMGCPTUEPFM4AVSRCJU"
    
    // MARK: - Asset Information
    
    /// USDC asset issuer on Stellar
    public static let usdcAssetIssuer = "GATALTGTWIOT6BUDBCZM3Q4OQ4BO2COLOAZ7IYSKPLC2PMSOPPGF5V56"
    
    /// USDC asset code
    public static let usdcAssetCode = "USDC"
    
    // MARK: - Contract Functions
    
    /// Function names for pool operations
    public struct Functions {
        /// Submit function for deposits and withdrawals
        public static let submit = "submit"
    }
    
    // MARK: - Request Types
    
    /// Request type constants for the submit function
    public enum RequestType: UInt32 {
        /// Supply collateral (deposit) to the pool
        case supplyCollateral = 0
        
        /// Withdraw collateral from the pool
        case withdrawCollateral = 1
        
        /// Supply liquidity (different from collateral)
        case supply = 2
        
        /// Withdraw liquidity
        case withdraw = 3
        
        /// Borrow from the pool
        case borrow = 4
        
        /// Repay borrowed amount
        case repay = 5
        
        /// Fill a bad debt auction
        case fillBadDebtAuction = 6
        
        /// Fill an interest auction
        case fillInterestAuction = 7
        
        /// Delete a liquidation auction
        case deleteLiquidationAuction = 8
    }
    
    // MARK: - Scaling Constants
    
    /// USDC uses 7 decimal places on Stellar (10^7)
    public static let usdcScalingFactor: Int64 = 10_000_000
    
    /// Converts a Decimal amount to the scaled Int128PartsXDR format used by the contract
    public static func scaleAmount(_ amount: Decimal) -> Int128PartsXDR {
        let scaledAmount = amount * Decimal(usdcScalingFactor)
        
        // Convert to Int64 for amounts that fit in 64 bits
        // For USDC with 7 decimals, this handles amounts up to ~922 trillion USDC
        let scaledInt64 = Int64(truncating: scaledAmount as NSNumber)
        
        // For positive values less than 2^63, hi is 0 and lo contains the value
        // For negative values, we need to handle two's complement
        if scaledInt64 >= 0 {
            return Int128PartsXDR(hi: 0, lo: UInt64(scaledInt64))
        } else {
            // For negative numbers in two's complement
            return Int128PartsXDR(hi: -1, lo: UInt64(bitPattern: scaledInt64))
        }
    }
    
    /// Converts a scaled Int128PartsXDR amount back to Decimal
    public static func unscaleAmount(_ scaledAmount: Int128PartsXDR) -> Decimal {
        // For amounts that fit in 64 bits (which should be all USDC amounts)
        let value: Int64
        if scaledAmount.hi == 0 {
            // Positive value
            value = Int64(scaledAmount.lo)
        } else if scaledAmount.hi == -1 {
            // Negative value (two's complement)
            value = Int64(bitPattern: scaledAmount.lo)
        } else {
            // For very large values, we'd need more complex handling
            // For USDC, this shouldn't happen in practice
            fatalError("Amount too large to handle: hi=\(scaledAmount.hi)")
        }
        
        return Decimal(value) / Decimal(usdcScalingFactor)
    }
    
    /// Helper to create Int128PartsXDR from a raw Int128 value
    public static func int128Parts(from value: Int64) -> Int128PartsXDR {
        if value >= 0 {
            return Int128PartsXDR(hi: 0, lo: UInt64(value))
        } else {
            return Int128PartsXDR(hi: -1, lo: UInt64(bitPattern: value))
        }
    }
} 