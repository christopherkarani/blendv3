//
//  OraclePrice.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//

import Foundation
import stellarsdk

/// Oracle price structure that aligns with the smart contract's PriceData
public struct OraclePrice {
    /// The price value as a Decimal
    public let price: Decimal
    
    /// Timestamp when the price was recorded
    public let timestamp: Date
    
    /// Decimal precision for the price (from contract's decimals function)
    public let decimals: Int
    
    /// Resolution factor for price calculations (from contract's resolution function)
    public let resolution: Int
    
    /// Initialize a new OraclePrice
    /// - Parameters:
    ///   - price: The price value as a Decimal
    ///   - timestamp: Timestamp when the price was recorded
    ///   - decimals: Decimal precision for the price
    ///   - resolution: Resolution factor for price calculations (default: 1)
    public init(price: Decimal, timestamp: Date, decimals: Int, resolution: Int = 1) {
        self.price = price
        self.timestamp = timestamp
        self.decimals = decimals
        self.resolution = resolution
    }
    
    /// Calculate the scaled price value with decimals and resolution applied
    /// This represents how the price would be stored in the contract as an i128
    public var scaledPrice: Decimal {
        let decimalFactor = pow(10.0, Double(decimals))
        return price * Decimal(decimalFactor) * Decimal(resolution)
    }
    
    /// Convert the price to an i128 representation for contract interaction
    /// - Returns: An Int128PartsXDR representing the price scaled by decimals and resolution
    public func toI128() -> Int128PartsXDR {
        let scaled = scaledPrice
        
        // For now, assume our numbers fit in the low bits (lo)
        // In a production system, we would need more robust handling of very large numbers
        return Int128PartsXDR(hi: 0, lo: UInt64(NSDecimalNumber(decimal: scaled).uint64Value))
    }
    
    /// Create an OraclePrice from an i128 value from the contract
    /// - Parameters:
    ///   - price: The i128 price value
    ///   - timestamp: The timestamp as UInt64 (seconds since epoch)
    ///   - decimals: The decimal precision
    ///   - resolution: The resolution factor
    /// - Returns: A new OraclePrice instance
    public static func fromI128(price: Int128PartsXDR, timestamp: UInt64, decimals: Int, resolution: Int) -> OraclePrice {
        // Convert the i128 to a Decimal
        // For now, assume the price fits in the low bits (lo)
        let scaledPrice = Decimal(UInt64(price.lo))
        
        // Unscale the price by dividing by decimals and resolution
        let decimalFactor = pow(10.0, Double(decimals))
        let unscaledPrice = scaledPrice / (Decimal(decimalFactor) * Decimal(resolution))
        
        // Convert timestamp to Date
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        
        return OraclePrice(
            price: unscaledPrice,
            timestamp: date,
            decimals: decimals,
            resolution: resolution
        )
    }
    
    /// Format the price for display with appropriate currency symbol and decimal places
    public var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        
        // Dynamically determine maximum fraction digits based on price value
        if price < 0.01 {
            formatter.maximumFractionDigits = 6
        } else if price < 1 {
            formatter.maximumFractionDigits = 4
        } else {
            formatter.maximumFractionDigits = 2
        }
        
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "$\(price)"
    }
}
