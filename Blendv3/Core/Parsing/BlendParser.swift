//
//  BlendParser.swift
//  Blendv3
//
//  Centralized parser for all Soroban contract responses
//

import Foundation
import stellarsdk
import os

/// Centralized parser for all Soroban contract responses
/// Consolidates parsing logic from all services into a single, reusable component
public final class BlendParser: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let debugLogger = DebugLogger(subsystem: "com.blendv3.parsing", category: "BlendParser")
    
    // MARK: - Initialization
    
    public init() {
        debugLogger.info("🔍 BlendParser initialized")
    }
    
    // MARK: - Generic Parsing Interface
    
    /// Parse SCValXDR to specific type with context
    public func parse<T>(_ value: SCValXDR, as type: T.Type, context: BlendParsingContext) throws -> T {
        debugLogger.debug("🔍 Parsing \(String(describing: type)) for \(context.functionName)")
        
        // Route to specific parsing methods based on type
        switch type {
        case is Decimal.Type:
            return try parseDecimal(value) as! T
        case is Int.Type:
            return try parseInt(value) as! T
        case is UInt32.Type:
            return try parseUInt32(value) as! T
        case is String.Type:
            return try parseString(value) as! T
        case is Bool.Type:
            return try parseBool(value) as! T
        case is [String: Any].Type:
            return try parseMap(value) as! T
        case is [Any].Type:
            return try parseVector(value) as! T
        default:
            throw BlendParsingError.unsupportedOperation("Parsing for type \(type) not implemented")
        }
    }
    
    // MARK: - Specific Type Parsing
    
    /// Parse i128 to Decimal (most common conversion)
    public func parseI128ToDecimal(_ i128: Int128XDR) -> Decimal {
        debugLogger.debug("🔍 Converting i128 to Decimal")
        
        // Convert i128 to Decimal
        // i128 is a 128-bit signed integer with high and low parts
        let high = i128.hi
        let low = i128.lo
        
        // Combine high and low parts to form the full 128-bit value
        let fullValue = (Int64(high) << 64) | Int64(low)
        
        return Decimal(fullValue)
    }
    
    /// Parse SCValXDR to Decimal
    public func parseDecimal(_ value: SCValXDR) throws -> Decimal {
        switch value {
        case .i128(let i128):
            return parseI128ToDecimal(i128)
        case .u32(let u32):
            return Decimal(u32)
        case .u64(let u64):
            return Decimal(u64)
        case .i32(let i32):
            return Decimal(i32)
        case .i64(let i64):
            return Decimal(i64)
        default:
            throw BlendParsingError.invalidType(expected: "numeric", actual: String(describing: value))
        }
    }
    
    /// Parse SCValXDR to Int
    public func parseInt(_ value: SCValXDR) throws -> Int {
        switch value {
        case .u32(let u32):
            return Int(u32)
        case .i32(let i32):
            return Int(i32)
        case .u64(let u64):
            return Int(u64)
        case .i64(let i64):
            return Int(i64)
        case .i128(let i128):
            // Convert i128 to Int (may lose precision)
            let decimal = parseI128ToDecimal(i128)
            return Int(truncating: decimal as NSNumber)
        default:
            throw BlendParsingError.invalidType(expected: "integer", actual: String(describing: value))
        }
    }
    
    /// Parse SCValXDR to UInt32
    public func parseUInt32(_ value: SCValXDR) throws -> UInt32 {
        switch value {
        case .u32(let u32):
            return u32
        case .i32(let i32):
            guard i32 >= 0 else {
                throw BlendParsingError.invalidValue("Negative value cannot be converted to UInt32")
            }
            return UInt32(i32)
        default:
            throw BlendParsingError.invalidType(expected: "u32", actual: String(describing: value))
        }
    }
    
    /// Parse SCValXDR to String
    public func parseString(_ value: SCValXDR) throws -> String {
        switch value {
        case .symbol(let symbol):
            return symbol
        case .string(let string):
            return string
        case .address(let address):
            return parseAddress(address)
        default:
            throw BlendParsingError.invalidType(expected: "string/symbol/address", actual: String(describing: value))
        }
    }
    
    /// Parse SCValXDR to Bool
    public func parseBool(_ value: SCValXDR) throws -> Bool {
        switch value {
        case .bool(let bool):
            return bool
        case .u32(let u32):
            return u32 != 0
        default:
            throw BlendParsingError.invalidType(expected: "bool", actual: String(describing: value))
        }
    }
    
    // MARK: - Complex Type Parsing
    
    /// Parse SCAddressXDR to String
    public func parseAddress(_ address: SCAddressXDR) -> String {
        debugLogger.debug("🔍 Parsing address")
        
        if let contractId = address.contractId {
            return contractId
        } else if let accountId = address.accountId {
            return accountId
        } else {
            debugLogger.warning("🔍 ⚠️ Address has no contractId or accountId")
            return ""
        }
    }
    
    /// Parse SCValXDR map to Dictionary
    public func parseMap(_ value: SCValXDR) throws -> [String: Any] {
        guard case .map(let mapOptional) = value else {
            throw BlendParsingError.invalidType(expected: "map", actual: String(describing: value))
        }
        
        guard let map = mapOptional else {
            return [:]
        }
        
        var result: [String: Any] = [:]
        
        for entry in map {
            let key = try parseString(entry.key)
            let value = try convertSCValToAny(entry.val)
            result[key] = value
        }
        
        debugLogger.debug("🔍 Parsed map with \(result.count) entries")
        return result
    }
    
    /// Parse SCValXDR vector to Array
    public func parseVector(_ value: SCValXDR) throws -> [Any] {
        guard case .vec(let vecOptional) = value else {
            throw BlendParsingError.invalidType(expected: "vector", actual: String(describing: value))
        }
        
        guard let vec = vecOptional else {
            return []
        }
        
        var result: [Any] = []
        
        for item in vec {
            let convertedItem = try convertSCValToAny(item)
            result.append(convertedItem)
        }
        
        debugLogger.debug("🔍 Parsed vector with \(result.count) items")
        return result
    }
    
    // MARK: - Enum Variant Parsing
    
    /// Parse enum variant (common Soroban pattern)
    public func parseEnumVariant(_ value: SCValXDR, expectedSymbol: String) throws -> SCValXDR {
        guard case .vec(let vecOptional) = value else {
            throw BlendParsingError.invalidType(expected: "enum variant (vector)", actual: String(describing: value))
        }
        
        guard let vec = vecOptional, vec.count >= 2 else {
            throw BlendParsingError.malformedResponse("Enum variant must have at least 2 elements")
        }
        
        guard case .symbol(let symbol) = vec[0], symbol == expectedSymbol else {
            throw BlendParsingError.invalidValue("Expected enum symbol '\(expectedSymbol)'")
        }
        
        return vec[1]
    }
    
    /// Create Asset::Stellar(contract_address) parameter for oracle calls
    public func createAssetParameter(contractAddress: String) throws -> SCValXDR {
        debugLogger.debug("🔍 Creating Asset parameter for: \(contractAddress)")
        
        // Create Asset::Stellar(address) enum variant
        let contractAddressXdr = try SCAddressXDR(contractId: contractAddress)
        let addressVal = SCValXDR.address(contractAddressXdr)
        
        // Asset::Stellar(address) as enum variant
        let assetVariant = SCValXDR.vec([
            SCValXDR.symbol("Stellar"),
            addressVal
        ])
        
        return assetVariant
    }
    
    // MARK: - Utility Methods
    
    /// Convert SCValXDR to appropriate Swift type
    private func convertSCValToAny(_ value: SCValXDR) throws -> Any {
        switch value {
        case .bool(let bool):
            return bool
        case .u32(let u32):
            return u32
        case .i32(let i32):
            return i32
        case .u64(let u64):
            return u64
        case .i64(let i64):
            return i64
        case .i128(let i128):
            return parseI128ToDecimal(i128)
        case .symbol(let symbol):
            return symbol
        case .string(let string):
            return string
        case .address(let address):
            return parseAddress(address)
        case .map(let mapOptional):
            return try parseMap(SCValXDR.map(mapOptional))
        case .vec(let vecOptional):
            return try parseVector(SCValXDR.vec(vecOptional))
        case .void:
            return NSNull()
        default:
            debugLogger.warning("🔍 ⚠️ Unsupported SCVal type: \(value)")
            return String(describing: value)
        }
    }
    
    /// Extract value from map by key
    public func extractFromMap(_ map: [SCMapEntryXDR], key: String) -> SCValXDR? {
        for entry in map {
            if case .symbol(let symbol) = entry.key, symbol == key {
                return entry.val
            }
            if case .string(let string) = entry.key, string == key {
                return entry.val
            }
        }
        return nil
    }
    
    /// Validate and extract required field from map
    public func requireFromMap(_ map: [SCMapEntryXDR], key: String) throws -> SCValXDR {
        guard let value = extractFromMap(map, key: key) else {
            throw BlendParsingError.missingRequiredField(key)
        }
        return value
    }
}

// MARK: - Domain-Specific Parsing Extensions

extension BlendParser {
    
    // MARK: - Pool Config Parsing
    
    /// Parse PoolConfig from contract response (returns tuple for service to construct model)
    public func parsePoolConfig(_ value: SCValXDR) throws -> (backstopRate: UInt32, maxPositions: UInt32, minCollateral: Decimal, oracle: String, status: UInt32) {
        guard case .map(let configMapOptional) = value else {
            throw BlendParsingError.invalidType(expected: "map", actual: String(describing: value))
        }
        
        guard let configMap = configMapOptional else {
            throw BlendParsingError.malformedResponse("Pool config map is nil")
        }
        
        var backstopRate: UInt32 = 0
        var maxPositions: UInt32 = 0
        var minCollateral: Decimal = 0
        var oracle = ""
        var status: UInt32 = 0
        
        for entry in configMap {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch (key, entry.val) {
            case ("bstop_rate", .u32(let v)):
                backstopRate = v
            case ("max_positions", .u32(let v)):
                maxPositions = v
            case ("min_collateral", .i128(let v)):
                minCollateral = parseI128ToDecimal(v)
            case ("oracle", .address(let addr)):
                oracle = parseAddress(addr)
            case ("status", .u32(let v)):
                status = v
            default:
                continue
            }
        }
        
        debugLogger.debug("🔍 Parsed PoolConfig: backstopRate=\(backstopRate), maxPositions=\(maxPositions)")
        
        return (backstopRate: backstopRate, maxPositions: maxPositions, minCollateral: minCollateral, oracle: oracle, status: status)
    }
    
    // MARK: - User Balance Parsing
    
    /// Parse UserBalance from contract response (simplified version for parsing)
    public func parseUserBalance(_ value: SCValXDR) throws -> (shares: Decimal, q4w: Decimal) {
        guard case .map(let balanceMapOptional) = value else {
            throw BlendParsingError.invalidType(expected: "map", actual: String(describing: value))
        }
        
        guard let balanceMap = balanceMapOptional else {
            throw BlendParsingError.malformedResponse("User balance map is nil")
        }
        
        var shares: Decimal = 0
        var q4w: Decimal = 0
        
        for entry in balanceMap {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch (key, entry.val) {
            case ("shares", .i128(let i128)):
                shares = parseI128ToDecimal(i128)
            case ("q4w", .i128(let i128)):
                q4w = parseI128ToDecimal(i128)
            default:
                continue
            }
        }
        
        debugLogger.debug("🔍 Parsed UserBalance: shares=\(shares), q4w=\(q4w)")
        
        return (shares: shares, q4w: q4w)
    }
    
    // MARK: - Pool Backstop Data Parsing
    
    /// Parse PoolBackstopData from contract response (simplified version for parsing)
    public func parsePoolBackstopData(_ value: SCValXDR) throws -> (tokens: Decimal, q4wPct: UInt32, blnd: Decimal, usdc: Decimal) {
        guard case .map(let dataMapOptional) = value else {
            throw BlendParsingError.invalidType(expected: "map", actual: String(describing: value))
        }
        
        guard let dataMap = dataMapOptional else {
            throw BlendParsingError.malformedResponse("Pool backstop data map is nil")
        }
        
        var tokens: Decimal = 0
        var q4wPct: UInt32 = 0
        var blnd: Decimal = 0
        var usdc: Decimal = 0
        
        for entry in dataMap {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch (key, entry.val) {
            case ("tokens", .i128(let i128)):
                tokens = parseI128ToDecimal(i128)
            case ("q4w_pct", .u32(let u32)):
                q4wPct = u32
            case ("blnd", .i128(let i128)):
                blnd = parseI128ToDecimal(i128)
            case ("usdc", .i128(let i128)):
                usdc = parseI128ToDecimal(i128)
            default:
                debugLogger.debug("🔍 Ignoring unknown field: \(key)")
                continue
            }
        }
        
        debugLogger.debug("🔍 Parsed PoolBackstopData: tokens=\(tokens), q4wPct=\(q4wPct)")
        
        return (tokens: tokens, q4wPct: q4wPct, blnd: blnd, usdc: usdc)
    }
}
