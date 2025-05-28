import Foundation
import stellarsdk

/// Protocol defining oracle price retrieval methods for Blend Protocol
/// Aligned with the Soroban smart contract functions
public protocol BlendOracleServiceProtocol {
    
    // MARK: - Legacy Methods (Maintained for backward compatibility)
    
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
    
    // MARK: - Contract-Aligned Methods
    
    /// Get the resolution factor used by the oracle
    /// Maps to contract's resolution() function
    /// - Returns: Resolution factor used for price calculations
    func getOracleResolution() async throws -> Int
    
    /// Get price for an asset at a specific timestamp
    /// Maps to contract's price(asset: Asset, timestamp: u64) function
    /// - Parameters:
    ///   - asset: Asset to get price for
    ///   - timestamp: Timestamp in seconds since epoch
    /// - Returns: Optional price data (nil if price not available for timestamp)
    func getPrice(asset: OracleAsset, timestamp: UInt64) async throws -> PriceData?
    
    /// Get historical prices for an asset
    /// Maps to contract's prices(asset: Asset, records: u32) function
    /// - Parameters:
    ///   - asset: Asset to get price history for
    ///   - records: Number of historical price records to retrieve
    /// - Returns: Optional array of price data (nil if no price history available)
    func getPriceHistory(asset: OracleAsset, records: UInt32) async throws -> [PriceData]?
    
    /// Get the last recorded price for an asset
    /// Maps to contract's lastprice(asset: Asset) function
    /// - Parameter asset: Asset to get price for
    /// - Returns: Optional price data (nil if no price available)
    func getLastPrice(asset: OracleAsset) async throws -> PriceData?
    
    /// Get the base asset used by the oracle
    /// Maps to contract's base() function
    /// - Returns: Base asset of the oracle
    func getBaseAsset() async throws -> OracleAsset
    
    /// Get all supported assets by the oracle
    /// Maps to contract's assets() function
    /// - Returns: Array of assets supported by the oracle
    func getSupportedAssets() async throws -> [OracleAsset]
}