//
//  PriceData.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//
import Foundation
import stellarsdk

/// Price data structure that aligns with the smart contract's PriceData struct
public struct PriceData: Codable {
    /// The price value as a Decimal
    public let price: Decimal
    
    /// Timestamp when the price was recorded
    public let timestamp: Date
    
    /// Asset that this price is for
    public let asset: OracleAsset
    
    /// Decimal precision for the price (from contract's decimals function)
    public let decimals: Int
    
    /// Resolution factor for price calculations (from contract's resolution function)
    public let resolution: Int
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case price
        case timestamp
        case asset
        case decimals
        case resolution
    }
    
    /// Legacy assetId accessor for backward compatibility
    public var assetId: String {
        switch asset {
        case .stellar(let address):
            return address
        case .other(let symbol):
            return symbol
        }
    }
    
    /// The price in USD for display and calculations
    public var priceInUSD: Decimal {
        return price
    }
    
    /// Initialize a new PriceData with contract-aligned structure
    /// - Parameters:
    ///   - price: The price value as a Decimal
    ///   - timestamp: Timestamp when the price was recorded
    ///   - asset: Asset that this price is for
    ///   - decimals: Decimal precision for the price
    ///   - resolution: Resolution factor for price calculations
    public init(price: Decimal, timestamp: Date, asset: OracleAsset, decimals: Int, resolution: Int = 1) {
        self.price = price
        self.timestamp = timestamp
        self.asset = asset
        self.decimals = decimals
        self.resolution = resolution
    }
    
    /// Legacy initializer for backward compatibility
    /// - Parameters:
    ///   - price: The price value as a Decimal
    ///   - timestamp: Timestamp when the price was recorded
    ///   - assetId: String identifier for the asset
    ///   - decimals: Decimal precision for the price
    public init(price: Decimal, timestamp: Date, assetId: String, decimals: Int) {
        self.price = price
        self.timestamp = timestamp
        
        // Assume stellar asset for existing code paths
        self.asset = .stellar(address: assetId)
        
        self.decimals = decimals
        self.resolution = 1 // Default resolution for backward compatibility
    }
    
    /// Check if the price data is older than a specified age
    /// - Parameter maxAge: Maximum age in seconds
    /// - Returns: True if the price is older than maxAge
    public func isStale(maxAge: TimeInterval) -> Bool {
        return Date().timeIntervalSince(timestamp) > maxAge
    }
    
    /// Convert to OraclePrice object
    public var oraclePrice: OraclePrice {
        return OraclePrice(
            price: price,
            timestamp: timestamp,
            decimals: decimals,
            resolution: resolution
        )
    }
    
    /// Create PriceData from contract data
    /// - Parameters:
    ///   - price: i128 price value from contract
    ///   - timestamp: u64 timestamp from contract
    ///   - asset: Asset that this price is for
    ///   - decimals: Decimal precision
    ///   - resolution: Resolution factor
    /// - Returns: A new PriceData instance
    public static func fromContractData(
        price: Int128PartsXDR,
        timestamp: UInt64,
        asset: OracleAsset,
        decimals: Int,
        resolution: Int
    ) -> PriceData {
        // Use OraclePrice to handle the conversion
        let oraclePrice = OraclePrice.fromI128(
            price: price,
            timestamp: timestamp,
            decimals: decimals,
            resolution: resolution
        )
        
        return PriceData(
            price: oraclePrice.price,
            timestamp: oraclePrice.timestamp,
            asset: asset,
            decimals: decimals,
            resolution: resolution
        )
    }
    
    /// Convert to contract data format
    /// - Returns: A tuple containing (i128 price, u64 timestamp)
    public func toContractData() -> (Int128PartsXDR, UInt64) {
        // Use OraclePrice to handle the conversion
        let i128Price = oraclePrice.toI128()
        let u64Timestamp = UInt64(timestamp.timeIntervalSince1970)
        
        return (i128Price, u64Timestamp)
    }
    
    /// Format the price for display
    public var formattedPrice: String {
        return oraclePrice.formattedPrice
    }
}
