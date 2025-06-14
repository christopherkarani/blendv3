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
    
    // MARK: - Classic Asset Convenience Properties
    
    /// Classic asset in canonical form (e.g., "USDC:GATALT...")
    /// Returns nil if this is not a bridge adaptor token
    public var classicAssetCanonicalForm: String? {
        return asset?.toCanonicalForm()
    }
    
    /// Classic asset code (e.g., "USDC", "XLM")
    /// Returns nil if this is not a bridge adaptor token
    public var classicAssetCode: String? {
        return asset?.code
    }
    
    /// Classic asset issuer account ID
    /// Returns nil if this is not a bridge adaptor token or if it's native XLM
    public var classicAssetIssuer: String? {
        return asset?.issuer?.accountId
    }
    
    /// Detailed classic asset information as a formatted string
    /// Returns a user-friendly description or nil if not a bridge adaptor
    public var classicAssetDetails: String? {
        guard let asset = asset else { return nil }
        
        if asset.type == AssetType.ASSET_TYPE_NATIVE {
            return "Native XLM"
        } else {
            let code = asset.code ?? "Unknown"
            let issuer = asset.issuer?.accountId ?? "Unknown"
            return "\(code) issued by \(issuer)"
        }
    }
} 
