//
//  OracleContractFunction.swift
//  Blendv3
//
//  Type-safe Oracle contract function definitions
//

import Foundation
import stellarsdk

/// Type-safe enumeration of Oracle contract functions
/// Provides compile-time safety for contract function names and parameter validation
public enum OracleContractFunction: String, CaseIterable, Sendable {
    
    // MARK: - Core Price Functions
    
    /// Get price for an asset at a specific timestamp
    /// Parameters: asset: Asset, timestamp: u64
    /// Returns: Option<PriceData>
    case price = "price"
    
    /// Get the last recorded price for an asset
    /// Parameters: asset: Asset
    /// Returns: Option<PriceData>
    case lastPrice = "lastprice"
    
    /// Get historical prices for an asset
    /// Parameters: asset: Asset, records: u32
    /// Returns: Option<Vec<PriceData>>
    case prices = "prices"
    
    // MARK: - Configuration Functions
    
    /// Get the resolution factor used by the oracle
    /// Parameters: none
    /// Returns: u32
    case resolution = "resolution"
    
    /// Get the decimal precision of oracle prices
    /// Parameters: none
    /// Returns: u32
    case decimals = "decimals"
    
    /// Get the base asset used by the oracle
    /// Parameters: none
    /// Returns: Asset
    case base = "base"
    
    /// Get all supported assets by the oracle
    /// Parameters: none
    /// Returns: Vec<Asset>
    case assets = "assets"
    
    // MARK: - Function Metadata
    
    /// Human-readable description of the function
    public var description: String {
        switch self {
        case .price:
            return "Get price for asset at timestamp"
        case .lastPrice:
            return "Get last recorded price for asset"
        case .prices:
            return "Get historical prices for asset"
        case .resolution:
            return "Get oracle resolution factor"
        case .decimals:
            return "Get oracle decimal precision"
        case .base:
            return "Get oracle base asset"
        case .assets:
            return "Get all supported assets"
        }
    }
    
    /// Expected parameter count for validation
    public var expectedParameterCount: Int {
        switch self {
        case .price:
            return 2 // asset, timestamp
        case .lastPrice:
            return 1 // asset
        case .prices:
            return 2 // asset, records
        case .resolution, .decimals, .base, .assets:
            return 0 // no parameters
        }
    }
    
    /// Expected return type for documentation
    public var returnType: String {
        switch self {
        case .price, .lastPrice:
            return "Option<PriceData>"
        case .prices:
            return "Option<Vec<PriceData>>"
        case .resolution, .decimals:
            return "u32"
        case .base:
            return "Asset"
        case .assets:
            return "Vec<Asset>"
        }
    }
    
    /// Validate parameter count
    /// - Parameter count: Number of parameters provided
    /// - Throws: OracleError.invalidParameterCount if count doesn't match expected
    public func validateParameterCount(_ count: Int) throws {
        guard count == expectedParameterCount else {
            throw OracleError.invalidParameterCount(
                function: self.rawValue,
                expected: expectedParameterCount,
                actual: count
            )
        }
    }
    
    /// Create contract call parameters with validation
    /// - Parameters:
    ///   - contractId: Oracle contract address
    ///   - arguments: Function arguments
    /// - Returns: ContractCallParams for NetworkService
    /// - Throws: OracleError if validation fails
    public func createContractCall(
        contractId: String,
        arguments: [SCValXDR] = []
    ) throws -> ContractCallParams {
        try validateParameterCount(arguments.count)
        
        return ContractCallParams(
            contractId: contractId,
            functionName: self.rawValue,
            functionArguments: arguments
        )
    }
}

// MARK: - Parameter Builders

extension OracleContractFunction {
    
    /// Create asset parameter for contract calls
    /// - Parameter asset: Oracle asset to convert
    /// - Returns: SCValXDR representing Asset::Stellar(address)
    /// - Throws: OracleError if asset conversion fails
    public static func createAssetParameter(_ asset: OracleAsset) throws -> SCValXDR {
        switch asset {
        case .stellar(let contractAddress):
            let contractAddressXdr = try SCAddressXDR(contractId: contractAddress)
            let addressVal = SCValXDR.address(contractAddressXdr)
            
            // Asset::Stellar(address) enum variant
            return SCValXDR.vec([
                SCValXDR.symbol("Stellar"),
                addressVal
            ])
            
        case .other(let symbol):
            // Asset::Other(symbol) enum variant
            return SCValXDR.vec([
                SCValXDR.symbol("Other"),
                SCValXDR.symbol(symbol)
            ])
        }
    }
    
    /// Create timestamp parameter
    /// - Parameter timestamp: Unix timestamp in seconds
    /// - Returns: SCValXDR u64 value
    public static func createTimestampParameter(_ timestamp: UInt64) -> SCValXDR {
        return SCValXDR.u64(timestamp)
    }
    
    /// Create records parameter
    /// - Parameter records: Number of records to retrieve
    /// - Returns: SCValXDR u32 value
    public static func createRecordsParameter(_ records: UInt32) -> SCValXDR {
        return SCValXDR.u32(records)
    }
}

// MARK: - Contract Call Builder

/// Builder pattern for creating Oracle contract calls
public struct OracleContractCallBuilder {
    private let contractId: String
    private let function: OracleContractFunction
    private var arguments: [SCValXDR] = []
    
    public init(contractId: String, function: OracleContractFunction) {
        self.contractId = contractId
        self.function = function
    }
    
    /// Add asset parameter
    public func withAsset(_ asset: OracleAsset) throws -> OracleContractCallBuilder {
        var builder = self
        builder.arguments.append(try OracleContractFunction.createAssetParameter(asset))
        return builder
    }
    
    /// Add timestamp parameter
    public func withTimestamp(_ timestamp: UInt64) -> OracleContractCallBuilder {
        var builder = self
        builder.arguments.append(OracleContractFunction.createTimestampParameter(timestamp))
        return builder
    }
    
    /// Add records parameter
    public func withRecords(_ records: UInt32) -> OracleContractCallBuilder {
        var builder = self
        builder.arguments.append(OracleContractFunction.createRecordsParameter(records))
        return builder
    }
    
    /// Build the contract call with validation
    public func build() throws -> ContractCallParams {
        return try function.createContractCall(
            contractId: contractId,
            arguments: arguments
        )
    }
}
