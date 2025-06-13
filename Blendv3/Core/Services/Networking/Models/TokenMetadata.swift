//
//  TokenMetadata.swift
//  Blendv3
//
//  Token metadata loaded from on-chain contract instances
//

import Foundation
import stellarsdk

/// Represents token metadata loaded from a Soroban contract instance
/// Contains name, symbol, decimals, and optional classic Stellar asset information
@MainActor
public struct TokenMetadata: Sendable {
    /// Token name (e.g., "USD Coin")
    let name: String
    
    /// Token symbol (e.g., "USDC", "XLM")
    let symbol: String
    
    /// Number of decimal places for the token
    let decimals: Int
    
    /// Classic Stellar asset if this is a bridge adaptor contract
    let asset: Asset?
    
    /// Initialize TokenMetadata
    /// - Parameters:
    ///   - name: Token name
    ///   - symbol: Token symbol
    ///   - decimals: Number of decimal places
    ///   - asset: Optional classic Stellar asset for bridge adaptors
    public init(name: String, symbol: String, decimals: Int, asset: Asset? = nil) {
        self.name = name
        self.symbol = symbol
        self.decimals = decimals
        self.asset = asset
    }
}

// MARK: - TokenMetadata Extensions

extension TokenMetadata {
    /// User-friendly description of the token
    public var description: String {
        if let asset = asset {
            return "\(symbol) (\(name)) - Bridge to \(asset.toCanonicalForm())"
        } else {
            return "\(symbol) (\(name))"
        }
    }
    
    /// Whether this token represents a classic Stellar asset
    public var isClassicAsset: Bool {
        return asset != nil
    }
    
    /// Whether this token is the native XLM token
    public var isNative: Bool {
        return symbol == "XLM" || name == "native"
    }
} 
