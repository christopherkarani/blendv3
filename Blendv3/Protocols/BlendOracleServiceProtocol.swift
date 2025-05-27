import Foundation

/// Protocol defining oracle price retrieval methods for Blend Protocol
public protocol BlendOracleServiceProtocol {
    
    /// Get prices for multiple assets in a single batch request
    /// - Parameter assets: Array of asset IDs to retrieve prices for
    /// - Returns: Dictionary mapping asset IDs to price data
    func getPrices(assets: [String]) async throws -> [String: PriceData]
    
    /// Get price for a single asset
    /// - Parameter asset: Asset ID to retrieve price for
    /// - Returns: Price data for the asset
    func getPrice(asset: String) async throws -> PriceData
    
    /// Get the decimal precision of oracle prices
    /// - Returns: Number of decimal places used by the oracle
    func getOracleDecimals() async throws -> Int
}

/// Price data returned by oracle
public struct PriceData: Codable, Equatable {
    /// Price in fixed-point representation with oracle decimals
    public let price: Decimal
    
    /// Timestamp when price was last updated
    public let timestamp: Date
    
    /// Asset identifier
    public let assetId: String
    
    /// Oracle decimals for this price
    public let decimals: Int
    
    /// Computed price in USD as floating point
    public var priceInUSD: Decimal {
        return FixedMath.toFloat(value: price, decimals: decimals)
    }
    
    /// Check if price is stale (older than specified seconds)
    /// - Parameter maxAge: Maximum age in seconds
    /// - Returns: True if price is older than maxAge
    public func isStale(maxAge: TimeInterval = 300) -> Bool {
        return Date().timeIntervalSince(timestamp) > maxAge
    }
    
    public init(price: Decimal, timestamp: Date, assetId: String, decimals: Int = 7) {
        self.price = price
        self.timestamp = timestamp
        self.assetId = assetId
        self.decimals = decimals
    }
} 