//
//  BlendParser.swift
//  Blendv3
//
//  Centralized parser for all Soroban contract responses
//

import Foundation
import os
import stellarsdk

// MARK: - Oracle Parsing Context

/// Context information for Oracle response parsing
public struct OracleParsingContext {
    let assetId: String?
    let functionName: String
    let timestamp: Date
    let additionalInfo: [String: Any]

    public init(
        assetId: String? = nil,
        functionName: String,
        timestamp: Date = Date(),
        additionalInfo: [String: Any] = [:]
    ) {
        self.assetId = assetId
        self.functionName = functionName
        self.timestamp = timestamp
        self.additionalInfo = additionalInfo
    }
}

/// Centralized parser for all Soroban contract responses
/// Consolidates parsing logic from all services into a single, reusable component
public final class BlendParser: @unchecked Sendable {

    // MARK: - Properties

    private let debugLogger = DebugLogger(
        subsystem: "com.blendv3.parsing",
        category: "BlendParser"
    )

    // MARK: - Initialization

    public init() {
        // Reduced logging: only initialize message
    }

    // MARK: - Generic Parsing Interface

    /// Parse SCValXDR to specific type with context
    public func parse<T>(
        _ value: SCValXDR,
        as type: T.Type,
        context: BlendParsingContext
    ) throws -> T {
        // Removed debug logging for performance

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
            throw BlendParsingError.unsupportedOperation(
                "Parsing for type \(type) not implemented"
            )
        }
    }

    // MARK: - Specific Type Parsing

    /// Parse i128 to Decimal (most common conversion)
    static func parseI128ToDecimal(_ i128: Int128XDR) -> Decimal {
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
            return BlendParser.parseI128ToDecimal(i128)
        case .u32(let u32):
            return Decimal(u32)
        case .u64(let u64):
            return Decimal(u64)
        case .i32(let i32):
            return Decimal(i32)
        case .i64(let i64):
            return Decimal(i64)
        default:
            throw BlendParsingError.invalidType(
                expected: "numeric",
                actual: String(describing: value)
            )
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
            let decimal = BlendParser.parseI128ToDecimal(i128)
            return Int(truncating: decimal as NSNumber)
        default:
            throw BlendParsingError.invalidType(
                expected: "integer",
                actual: String(describing: value)
            )
        }
    }

    /// Parse SCValXDR to UInt32 with enhanced validation
    public func parseUInt32(_ value: SCValXDR) throws -> UInt32 {
        do {
            return try value.validateAndExtractNumericAsU32()
        } catch {
            // Log detailed debugging information for troubleshooting
            debugLogger.error(
                "🔍 ⚠️ Failed to parse UInt32 from: \(value.debugDescription)"
            )
            throw BlendParsingError.invalidType(
                expected: "u32",
                actual: value.debugDescription
            )
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
            throw BlendParsingError.invalidType(
                expected: "string/symbol/address",
                actual: String(describing: value)
            )
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
            throw BlendParsingError.invalidType(
                expected: "bool",
                actual: String(describing: value)
            )
        }
    }

    // MARK: - Complex Type Parsing

    /// Parse SCAddressXDR to String
    public func parseAddress(_ address: SCAddressXDR) -> String {
        if let contractId = address.contractId {
            return contractId
        } else if let accountId = address.accountId {
            return accountId
        } else {
            // Critical logging only
            debugLogger.error("🔍 ⚠️ Address has no contractId or accountId")
            return ""
        }
    }

    /// Parse SCValXDR map to Dictionary
    public func parseMap(_ value: SCValXDR) throws -> [String: Any] {
        guard case .map(let mapOptional) = value else {
            throw BlendParsingError.invalidType(
                expected: "map",
                actual: String(describing: value)
            )
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

        return result
    }

    /// Parse SCValXDR vector to Array
    public func parseVector(_ value: SCValXDR) throws -> [Any] {
        guard case .vec(let vecOptional) = value else {
            throw BlendParsingError.invalidType(
                expected: "vector",
                actual: String(describing: value)
            )
        }

        guard let vec = vecOptional else {
            return []
        }

        var result: [Any] = []

        for item in vec {
            let convertedItem = try convertSCValToAny(item)
            result.append(convertedItem)
        }

        return result
    }

    // MARK: - Enum Variant Parsing

    /// Parse enum variant (common Soroban pattern)
    public func parseEnumVariant(_ value: SCValXDR, expectedSymbol: String)
        throws -> SCValXDR
    {
        guard case .vec(let vecOptional) = value else {
            throw BlendParsingError.invalidType(
                expected: "enum variant (vector)",
                actual: String(describing: value)
            )
        }

        guard let vec = vecOptional, vec.count >= 2 else {
            throw BlendParsingError.malformedResponse(
                "Enum variant must have at least 2 elements"
            )
        }

        guard case .symbol(let symbol) = vec[0], symbol == expectedSymbol else {
            throw BlendParsingError.invalidValue(
                "Expected enum symbol '\(expectedSymbol)'"
            )
        }

        return vec[1]
    }

    /// Create Asset::Stellar(contract_address) parameter for oracle calls
    public func createAssetParameter(contractAddress: String) throws -> SCValXDR
    {
        // Create Asset::Stellar(address) enum variant
        let contractAddressXdr = try SCAddressXDR(contractId: contractAddress)
        let addressVal = SCValXDR.address(contractAddressXdr)

        // Asset::Stellar(address) as enum variant
        let assetVariant = SCValXDR.vec([
            SCValXDR.symbol("Stellar"),
            addressVal,
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
            return BlendParser.parseI128ToDecimal(i128)
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
            // Critical logging only
            debugLogger.warning("🔍 ⚠️ Unsupported SCVal type: \(value)")
            return String(describing: value)
        }
    }

    /// Extract value from map by key
    public func extractFromMap(_ map: [SCMapEntryXDR], key: String) -> SCValXDR?
    {
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
    public func requireFromMap(_ map: [SCMapEntryXDR], key: String) throws
        -> SCValXDR
    {
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
    public func parsePoolConfig(_ value: SCValXDR) throws -> (
        backstopRate: UInt32, maxPositions: UInt32, minCollateral: Decimal,
        oracle: String, status: UInt32
    ) {
        guard case .map(let configMapOptional) = value else {
            throw BlendParsingError.invalidType(
                expected: "map",
                actual: String(describing: value)
            )
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
                minCollateral = BlendParser.parseI128ToDecimal(v)
            case ("oracle", .address(let addr)):
                oracle = parseAddress(addr)
            case ("status", .u32(let v)):
                status = v
            default:
                continue
            }
        }

        return (
            backstopRate: backstopRate, maxPositions: maxPositions,
            minCollateral: minCollateral, oracle: oracle, status: status
        )
    }

    // MARK: - User Balance Parsing

    /// Parse UserBalance from contract response (simplified version for parsing)
    public func parseUserBalance(_ value: SCValXDR) throws -> (
        shares: Decimal, q4w: Decimal
    ) {
        guard case .map(let balanceMapOptional) = value else {
            throw BlendParsingError.invalidType(
                expected: "map",
                actual: String(describing: value)
            )
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
                shares = BlendParser.parseI128ToDecimal(i128)
            case ("q4w", .i128(let i128)):
                q4w = BlendParser.parseI128ToDecimal(i128)
            default:
                continue
            }
        }

        return (shares: shares, q4w: q4w)
    }

    // MARK: - Pool Backstop Data Parsing

    /// Parse PoolBackstopData from contract response (simplified version for parsing)
    public func parsePoolBackstopData(_ value: SCValXDR) throws -> (
        tokens: Decimal, q4wPct: UInt32, blnd: Decimal, usdc: Decimal
    ) {
        guard case .map(let dataMapOptional) = value else {
            throw BlendParsingError.invalidType(
                expected: "map",
                actual: String(describing: value)
            )
        }

        guard let dataMap = dataMapOptional else {
            throw BlendParsingError.malformedResponse(
                "Pool backstop data map is nil"
            )
        }

        var tokens: Decimal = 0
        var q4wPct: UInt32 = 0
        var blnd: Decimal = 0
        var usdc: Decimal = 0

        for entry in dataMap {
            guard case .symbol(let key) = entry.key else { continue }

            switch (key, entry.val) {
            case ("tokens", .i128(let i128)):
                tokens = BlendParser.parseI128ToDecimal(i128)
            case ("q4w_pct", .u32(let u32)):
                q4wPct = u32
            case ("blnd", .i128(let i128)):
                blnd = BlendParser.parseI128ToDecimal(i128)
            case ("usdc", .i128(let i128)):
                usdc = BlendParser.parseI128ToDecimal(i128)
            default:
                // Only log unknown fields that might be important
                if !["id", "timestamp", "version"].contains(key) {
                    debugLogger.warning(
                        "🔍 Unknown field in PoolBackstopData: \(key)"
                    )
                }
                continue
            }
        }

        return (tokens: tokens, q4wPct: q4wPct, blnd: blnd, usdc: usdc)
    }
}

// MARK: - Oracle Response Parsing Extensions

extension BlendParser {

    // MARK: - Oracle Asset Helper

    private func getAssetSymbol(for address: String) -> String {
        let assetMapping = [
            BlendConstants.Testnet.usdc: "USDC",
            BlendConstants.Testnet.xlm: "XLM",
            BlendConstants.Testnet.blnd: "BLND",
            BlendConstants.Testnet.weth: "wETH",
            BlendConstants.Testnet.wbtc: "wBTC",
        ]
        return assetMapping[address] ?? address
    }

    public static func getAssetSymbol(for address: String) -> String {
        let assetMapping = [
            BlendConstants.Testnet.usdc: "USDC",
            BlendConstants.Testnet.xlm: "XLM",
            BlendConstants.Testnet.blnd: "BLND",
            BlendConstants.Testnet.weth: "wETH",
            BlendConstants.Testnet.wbtc: "wBTC",
        ]
        return assetMapping[address] ?? address
    }

    // MARK: - I128 Decimal Parsing (Oracle specific)

    /// Parse i128 to Decimal with proper fixed-point arithmetic for Oracle values
    /// Uses enhanced parsing logic from I128Parser
    static func parseI128ToDecimalOracle(_ value: Int128XDR) -> Decimal {
        // Convert i128 to a single 128-bit integer value
        let fullValue: Decimal

        if value.hi == 0 {
            // Simple case: only low 64 bits are used
            fullValue = Decimal(value.lo)
        } else if value.hi == -1 && (value.lo & 0x8000_0000_0000_0000) != 0 {
            // Negative number in two's complement
            let signedLo = Int64(bitPattern: value.lo)
            fullValue = Decimal(signedLo)
        } else {
            // Large positive number: combine hi and lo parts
            let hiDecimal = Decimal(value.hi) * Decimal(sign: .plus, exponent: 64, significand: 1)
            let loDecimal = Decimal(value.lo)
            fullValue = hiDecimal + loDecimal
        }

        if fullValue == 0 {
            return Decimal(0)
        }

        // Round to 7 decimal places
        var rounded = fullValue
        var result = Decimal()
        NSDecimalRound(&result, &rounded, 7, .plain)

        // Convert to string, strip trailing zeros after decimal point
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 7
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        guard let formatted = formatter.string(from: result as NSNumber), let trimmed = Decimal(string: formatted) else {
            return result
        }
        return trimmed
    }

    // MARK: - Optional PriceData Parsing

    /// Parse Option<PriceData> from Oracle contract response
    public func parseOptionalPriceData(
        _ response: SCValXDR,
        context: OracleParsingContext?
    ) throws -> PriceData? {
        let assetId = context?.assetId ?? "unknown"
        let symbol = getAssetSymbol(for: assetId)

        switch response {
        case .void:
            // None case - no price data available
            return nil

        case .vec(let vecOptional):
            // Some(PriceData) case - might be wrapped in a vector
            guard let vec = vecOptional, !vec.isEmpty else {
                return nil
            }
            return try parseWrappedPriceData(from: vec[0], assetId: assetId)

        case .map(let mapOptional):
            // Direct PriceData struct (no Option wrapper)
            guard let map = mapOptional else {
                throw BlendParsingError.invalidResponse(
                    "Map is nil in direct PriceData response"
                )
            }
            return try parsePriceDataStruct(.map(mapOptional), context: context)

        case .i128(let priceValue):
            // Simple i128 price value
            let price = BlendParser.parseI128ToDecimalOracle(priceValue)
            return PriceData(
                price: price,
                timestamp: context?.timestamp ?? Date(),
                contractID: assetId,
                baseAsset: symbol
            )

        default:
            throw BlendParsingError.invalidType(
                expected: "Option<PriceData>",
                actual: String(describing: response)
            )
        }
    }

    private func parseWrappedPriceData(from value: SCValXDR, assetId: String)
        throws -> PriceData?
    {
        switch value {
        case .map(let mapOptional):
            guard let map = mapOptional else {
                throw BlendParsingError.invalidResponse(
                    "Map is nil in wrapped PriceData"
                )
            }
            let context = OracleParsingContext(
                assetId: assetId,
                functionName: "wrapped_price_data"
            )
            return try parsePriceDataStruct(.map(mapOptional), context: context)

        case .i128(let priceValue):
            // Simple price value
            let price = BlendParser.parseI128ToDecimalOracle(priceValue)
            return PriceData(
                price: price,
                timestamp: Date(),
                assetId: assetId
            )

        default:
            throw BlendParsingError.invalidType(
                expected: "wrapped PriceData",
                actual: String(describing: value)
            )
        }
    }

    // MARK: - PriceData Vector Parsing

    /// Parse Option<Vec<PriceData>> from Oracle contract response
    public func parsePriceDataVector(
        _ response: SCValXDR,
        context: OracleParsingContext?
    ) throws -> [PriceData] {
        let assetId = context?.assetId ?? "unknown"

        switch response {
        case .void:
            // None case - no price data available
            return []

        case .vec(let vecOptional):
            // Some(Vec<PriceData>) case
            guard let vec = vecOptional else {
                throw BlendParsingError.invalidResponse(
                    "Vector is nil in Option<Vec<PriceData>> response"
                )
            }

            var priceDataArray: [PriceData] = []

            for (index, item) in vec.enumerated() {
                do {
                    let itemContext = OracleParsingContext(
                        assetId: assetId,
                        functionName: "price_vector_item_\(index)",
                        additionalInfo: ["index": index]
                    )
                    if let priceData = try parsePriceDataStruct(
                        item,
                        context: itemContext
                    ) {
                        priceDataArray.append(priceData)
                    }
                } catch {
                    // Continue parsing other items instead of failing completely
                    debugLogger.warning(
                        "⚠️ Failed to parse price data at index \(index): \(error)"
                    )
                }
            }

            return priceDataArray

        default:
            throw BlendParsingError.invalidType(
                expected: "Option<Vec<PriceData>>",
                actual: String(describing: response)
            )
        }
    }

    // MARK: - PriceData Struct Parsing

    /// Parse PriceData struct from map
    public func parsePriceDataStruct(
        _ response: SCValXDR,
        context: OracleParsingContext?
    ) throws -> PriceData? {
        guard case .map(let mapOptional) = response, let map = mapOptional
        else {
            throw BlendParsingError.invalidType(
                expected: "map for PriceData struct",
                actual: String(describing: response)
            )
        }

        let assetId = context?.assetId ?? "unknown"
        let symbol = getAssetSymbol(for: assetId)
        var price: Decimal?
        var timestamp: Date?

        for entry in map {
            if case .symbol(let key) = entry.key {
                switch key {
                case "price":
                    if case .i128(let priceValue) = entry.val {
                        price = BlendParser.parseI128ToDecimalOracle(priceValue)
                    }

                case "timestamp":
                    if case .u64(let timestampValue) = entry.val {
                        timestamp = Date(
                            timeIntervalSince1970: TimeInterval(timestampValue)
                        )
                    }

                default:
                    // Ignore unknown fields
                    break
                }
            }
        }

        guard let finalPrice = price, let finalTimestamp = timestamp else {
            let missingFields = [
                price == nil ? "price" : nil,
                timestamp == nil ? "timestamp" : nil,
            ].compactMap { $0 }

            throw BlendParsingError.missingRequiredField(
                "Missing required fields: \(missingFields.joined(separator: ", "))"
            )
        }

        return PriceData(
            price: FixedMath.toFloat(value: finalPrice, decimals: 7),
            timestamp: finalTimestamp,
            contractID: assetId,
            baseAsset: symbol
        )
    }

    // MARK: - Asset Vector Parsing

    /// Parse Vec<Asset> from Oracle contract response
    public func parseAssetVector(_ response: SCValXDR) throws -> [OracleAsset] {
        guard case .vec(let assets) = response, let assetVec = assets else {
            throw BlendParsingError.invalidType(
                expected: "vec of assets",
                actual: String(describing: response)
            )
        }

        var oracleAssets: [OracleAsset] = []

        for (index, assetXDR) in assetVec.enumerated() {
            do {
                let asset = try OracleAsset.fromSCVal(assetXDR)
                oracleAssets.append(asset)
            } catch {
                debugLogger.warning(
                    "⚠️ Failed to parse asset at index \(index): \(error)"
                )
                // Continue parsing other assets
            }
        }

        return oracleAssets
    }

    // MARK: - Simple Value Parsers

    /// Parse u32 response (resolution, decimals)
    public func parseU32Response(
        _ response: SCValXDR,
        context: OracleParsingContext?
    ) throws -> UInt32 {
        guard case .u32(let value) = response else {
            let details =
                "Expected u32 response for \(context?.functionName ?? "unknown function")"
            throw BlendParsingError.invalidType(
                expected: "u32",
                actual: details
            )
        }
        return value
    }

    /// Parse Asset response
    public func parseAssetResponse(_ response: SCValXDR) throws -> OracleAsset {
        return try OracleAsset.fromSCVal(response)
    }
}

// MARK: - Simulation Result Parsing Extensions

extension BlendParser {

    /// Parse SCValXDR simulation result to human-readable format
    /// Handles conversion from SCValXDR to Data for JSON decoding
    /// - Parameters:
    ///   - result: SCValXDR result from simulation
    ///   - targetType: Target type to decode to
    /// - Returns: Parsed result of target type
    /// - Throws: BlendParsingError if parsing fails
    public func parseSimulationResult<T: Decodable>(
        _ result: SCValXDR,
        as targetType: T.Type
    ) throws -> T {
        do {
            // First, try direct SCValXDR to target type conversion for common cases
            if let directResult = try? parseDirectSCValXDR(
                result,
                as: targetType
            ) {
                return directResult
            }

            // Fallback to JSON conversion approach
            let humanReadableData = try convertSCValXDRToData(result)

            // Decode to target type
            let decoder = JSONDecoder()
            return try decoder.decode(targetType, from: humanReadableData)

        } catch let error as BlendParsingError {
            // Re-throw BlendParsingError as-is
            throw error
        } catch let decodingError as DecodingError {
            // Handle decoding errors with more context and attempt recovery
            debugLogger.error(
                "🔍 Decoding failed for type \(targetType): \(decodingError)"
            )

            // Try to provide a more helpful error or attempt recovery
            if let recoveredResult = try? attemptDecodingRecovery(
                result,
                targetType: targetType,
                originalError: decodingError
            ) {
                return recoveredResult
            }

            throw BlendParsingError.decodingError(decodingError)
        } catch {
            // Handle any other errors
            debugLogger.error(
                "🔍 Unexpected error in parseSimulationResult: \(error)"
            )
            throw BlendParsingError.conversionFailed(
                "Unexpected error: \(error.localizedDescription)"
            )
        }
    }

    /// Attempt direct conversion from SCValXDR to target type for common cases
    /// - Parameters:
    ///   - result: SCValXDR to convert
    ///   - targetType: Target type
    /// - Returns: Converted result if successful
    /// - Throws: BlendParsingError if conversion fails
    private func parseDirectSCValXDR<T: Decodable>(
        _ result: SCValXDR,
        as targetType: T.Type
    ) throws -> T {
        // Handle common direct conversions
        switch targetType {
        case is SCValXDR.Type:
            return result as! T

        case is UInt32.Type:
            let value = try parseUInt32(result)
            return value as! T

        case is Int.Type:
            let value = try parseInt(result)
            return value as! T

        case is String.Type:
            let value = try parseString(result)
            return value as! T

        case is Bool.Type:
            let value = try parseBool(result)
            return value as! T

        case is Decimal.Type:
            let value = try parseDecimal(result)
            return value as! T

        case is [String: Any].Type:
            let value = try parseMap(result)
            return value as! T

        case is [Any].Type:
            let value = try parseVector(result)
            return value as! T

        default:
            // For complex types, let the JSON approach handle it
            throw BlendParsingError.unsupportedOperation(
                "Direct conversion not supported for \(targetType)"
            )
        }
    }

    /// Attempt to recover from decoding errors by trying alternative approaches
    /// - Parameters:
    ///   - result: Original SCValXDR
    ///   - targetType: Target type that failed to decode
    ///   - originalError: The original decoding error
    /// - Returns: Recovered result if successful
    /// - Throws: BlendParsingError if recovery fails
    private func attemptDecodingRecovery<T: Decodable>(
        _ result: SCValXDR,
        targetType: T.Type,
        originalError: DecodingError
    ) throws -> T {
        debugLogger.info("🔍 Attempting decoding recovery for \(targetType)")

        // Analyze the decoding error to understand what went wrong
        switch originalError {
        case .typeMismatch(let expectedType, let context):
            debugLogger.info(
                "🔍 Type mismatch: expected \(expectedType), context: \(context.debugDescription)"
            )

            // If expecting an array but got a dictionary, try wrapping in array
            if expectedType is [Any].Type
                || String(describing: expectedType).contains("Array")
            {
                return try recoverArrayMismatch(result, targetType: targetType)
            }

            // If expecting a dictionary but got something else, try wrapping in dictionary
            if expectedType is [String: Any].Type
                || String(describing: expectedType).contains("Dictionary")
            {
                return try recoverDictionaryMismatch(
                    result,
                    targetType: targetType
                )
            }

        case .keyNotFound(let key, let context):
            debugLogger.info(
                "🔍 Key not found: \(key), context: \(context.debugDescription)"
            )
        // Could try providing default values for missing keys

        case .valueNotFound(let type, let context):
            debugLogger.info(
                "🔍 Value not found for type: \(type), context: \(context.debugDescription)"
            )
        // Could try providing default values for missing values

        case .dataCorrupted(let context):
            debugLogger.info(
                "🔍 Data corrupted, context: \(context.debugDescription)"
            )
        // Could try alternative parsing approaches

        @unknown default:
            debugLogger.info("🔍 Unknown decoding error type")
        }

        // If no specific recovery worked, throw the original error
        throw BlendParsingError.decodingError(originalError)
    }

    /// Recover from array type mismatch by wrapping result in array
    private func recoverArrayMismatch<T: Decodable>(
        _ result: SCValXDR,
        targetType: T.Type
    ) throws -> T {
        debugLogger.info("🔍 Attempting array mismatch recovery")

        // Convert the SCValXDR to human-readable format
        let humanReadable = try convertSCValXDRToHumanReadable(result)

        // Wrap in array if it's not already an array
        let arrayWrapped: Any
        if humanReadable is [Any] {
            arrayWrapped = humanReadable
        } else {
            arrayWrapped = [humanReadable]
        }

        // Convert to JSON and decode
        let jsonData = try JSONSerialization.data(
            withJSONObject: arrayWrapped,
            options: []
        )
        let decoder = JSONDecoder()
        return try decoder.decode(targetType, from: jsonData)
    }

    /// Recover from dictionary type mismatch by wrapping result in dictionary
    private func recoverDictionaryMismatch<T: Decodable>(
        _ result: SCValXDR,
        targetType: T.Type
    ) throws -> T {
        debugLogger.info("🔍 Attempting dictionary mismatch recovery")

        // Convert the SCValXDR to human-readable format
        let humanReadable = try convertSCValXDRToHumanReadable(result)

        // Wrap in dictionary if it's not already a dictionary
        let dictWrapped: Any
        if humanReadable is [String: Any] {
            dictWrapped = humanReadable
        } else {
            dictWrapped = [
                "value": humanReadable,
                "type": String(describing: type(of: humanReadable)),
            ]
        }

        // Convert to JSON and decode
        let jsonData = try JSONSerialization.data(
            withJSONObject: dictWrapped,
            options: []
        )
        let decoder = JSONDecoder()
        return try decoder.decode(targetType, from: jsonData)
    }

    /// Convert SCValXDR to human-readable JSON Data
    /// - Parameter value: SCValXDR to convert
    /// - Returns: JSON Data representation
    /// - Throws: BlendParsingError if conversion fails
    public func convertSCValXDRToData(_ value: SCValXDR) throws -> Data {
        // Convert SCValXDR to a human-readable dictionary
        let humanReadable = try convertSCValXDRToHumanReadable(value)

        // Ensure the result is JSON-serializable by wrapping primitives in a container
        let jsonCompatible: Any
        if JSONSerialization.isValidJSONObject(humanReadable) {
            jsonCompatible = humanReadable
        } else {
            // Wrap non-object types in a container for JSON compatibility
            jsonCompatible = [
                "value": humanReadable, "type": "\(type(of: humanReadable))",
            ]
        }

        // Encode to JSON Data with error handling
        do {
            // Validate before serialization
            guard JSONSerialization.isValidJSONObject(jsonCompatible) else {
                debugLogger.error("🔍 Invalid JSON object: \(jsonCompatible)")
                throw BlendParsingError.conversionFailed(
                    "Object is not JSON serializable: \(type(of: jsonCompatible))"
                )
            }

            return try JSONSerialization.data(
                withJSONObject: jsonCompatible,
                options: []
            )
        } catch let error as NSError {
            debugLogger.error(
                "🔍 JSON serialization failed: \(error.localizedDescription)"
            )
            debugLogger.error("🔍 Object type: \(type(of: jsonCompatible))")
            debugLogger.error("🔍 Object description: \(jsonCompatible)")
            throw BlendParsingError.conversionFailed(
                "Failed to convert to JSON: \(error.localizedDescription)"
            )
        }
    }

    /// Convert SCValXDR to human-readable format (Dictionary/Array/Primitive)
    /// - Parameter value: SCValXDR to convert
    /// - Returns: Human-readable representation
    /// - Throws: BlendParsingError if conversion fails
    public func convertSCValXDRToHumanReadable(_ value: SCValXDR) throws -> Any
    {
        switch value {
        case .bool(let bool):
            return bool

        case .void:
            return NSNull()

        case .u32(let u32):
            return u32

        case .i32(let i32):
            return i32

        case .u64(let u64):
            return u64

        case .i64(let i64):
            return i64

        case .u128(let u128):
            // Convert u128 to string for JSON compatibility
            return "\(u128.hi):\(u128.lo)"

        case .i128(let i128):
            // Convert i128 to decimal string for better readability
            let decimal = BlendParser.parseI128ToDecimal(i128)
            return decimal.description

        case .symbol(let symbol):
            return symbol

        case .string(let string):
            return string

        case .address(let address):
            return parseAddress(address)

        case .map(let mapOptional):
            guard let map = mapOptional else {
                return [:]
            }

            var result: [String: Any] = [:]
            for entry in map {
                let key = try convertSCValXDRToHumanReadable(entry.key)
                let value = try convertSCValXDRToHumanReadable(entry.val)

                // Ensure key is a string for JSON compatibility
                let stringKey = key as? String ?? "\(key)"
                result[stringKey] = value
            }
            return result

        case .vec(let vecOptional):
            guard let vec = vecOptional else {
                return []
            }

            var result: [Any] = []
            for item in vec {
                let convertedItem = try convertSCValXDRToHumanReadable(item)
                result.append(convertedItem)
            }
            return result

        case .bytes(let bytes):
            // Convert bytes to base64 string for JSON compatibility
            return bytes.base64EncodedString()

        default:
            // Fallback for any unhandled cases - return as dictionary for JSON compatibility
            return [
                "type": "unknown",
                "description": String(describing: value),
            ]
        }
    }

    /// Get a human-readable description of SCValXDR for debugging
    /// - Parameter value: SCValXDR to describe
    /// - Returns: Human-readable string description
    public func getHumanReadableDescription(_ value: SCValXDR) -> String {
        do {
            let readable = try convertSCValXDRToHumanReadable(value)

            if let data = try? JSONSerialization.data(
                withJSONObject: readable,
                options: .prettyPrinted
            ),
                let jsonString = String(data: data, encoding: .utf8)
            {
                return jsonString
            } else {
                return String(describing: readable)
            }
        } catch {
            return
                "Failed to convert to human-readable format: \(error.localizedDescription)"
        }
    }

    /// Demonstrate parsing capabilities for common SCValXDR types
    /// - Returns: Dictionary showing examples of parsed values
    public func demonstrateParsingCapabilities() -> [String: String] {
        var examples: [String: String] = [:]

        // Example u32 value (like the failing u32: 7 case)
        let u32Example = SCValXDR.u32(7)
        examples["u32_example"] = getHumanReadableDescription(u32Example)

        // Example i128 price value
        let i128Example = SCValXDR.i128(Int128XDR(hi: 0, lo: 12_500_000))
        examples["i128_price_example"] = getHumanReadableDescription(
            i128Example
        )

        // Example map structure
        let mapExample = SCValXDR.map([
            SCMapEntryXDR(
                key: SCValXDR.symbol("price"),
                val: SCValXDR.i128(Int128XDR(hi: 0, lo: 1_000_000))
            ),
            SCMapEntryXDR(
                key: SCValXDR.symbol("timestamp"),
                val: SCValXDR.u64(1_640_995_200)
            ),
        ])
        examples["map_example"] = getHumanReadableDescription(mapExample)

        // Example vector
        let vecExample = SCValXDR.vec([
            SCValXDR.symbol("Some"),
            SCValXDR.u32(42),
        ])
        examples["vector_example"] = getHumanReadableDescription(vecExample)

        return examples
    }
}

// MARK: - Backstop Contract Parsing Extensions

extension BlendParser {
    
    // MARK: - Basic Type Parsing
    
    /// Parse i128 response from contract
    public func parseI128Response(_ response: SCValXDR) throws -> Int128 {
        guard case .i128(let value) = response else {
            throw BlendParsingError.invalidType(
                expected: "i128",
                actual: String(describing: type(of: response))
            )
        }
        
        return convertI128PartsToInt128(value)
    }
    
    /// Parse address response from contract
    public func parseAddressResponse(_ response: SCValXDR) throws -> String {
        guard case .address(let addressXDR) = response else {
            throw BlendParsingError.invalidType(
                expected: "address",
                actual: String(describing: type(of: response))
            )
        }
        
        return try extractAddressString(from: addressXDR)
    }
    
    /// Parse Q4W struct response
    public func parseQ4WResponse(_ response: SCValXDR) throws -> Q4W {
        guard case .map(let mapOptional) = response,
              let map = mapOptional else {
            throw BlendParsingError.invalidType(
                expected: "map",
                actual: String(describing: type(of: response))
            )
        }
        
        var amount: Int128?
        var exp: UInt64?
        
        for pair in map {
            guard case .symbol(let key) = pair.key else { continue }
            
            switch key {
            case "amount":
                guard case .i128(let amountValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "i128",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                amount = convertI128PartsToInt128(amountValue)
                
            case "exp":
                guard case .u64(let expValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "u64",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                exp = expValue
                
            default:
                continue
            }
        }
        
        guard let validAmount = amount, let validExp = exp else {
            throw BlendParsingError.missingRequiredField("Q4W incomplete struct")
        }
        
        return Q4W(amount: validAmount, exp: validExp)
    }
    
    // MARK: - Complex Struct Parsing
    
    /// Parse UserBalance struct response
    public func parseUserBalanceResponse(_ response: SCValXDR) throws -> UserBalance {
        guard case .map(let mapOptional) = response,
              let map = mapOptional else {
            throw BlendParsingError.invalidType(
                expected: "map",
                actual: String(describing: type(of: response))
            )
        }
        
        var q4wArray: [Q4W] = []
        var shares: Int128?
        
        for pair in map {
            guard case .symbol(let key) = pair.key else { continue }
            
            switch key {
            case "q4w":
                guard case .vec(let vecOptional) = pair.val,
                      let vec = vecOptional else {
                    throw BlendParsingError.invalidType(
                        expected: "vec",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                
                for item in vec {
                    let q4w = try parseQ4WResponse(item)
                    q4wArray.append(q4w)
                }
                
            case "shares":
                guard case .i128(let sharesValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "i128",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                shares = convertI128PartsToInt128(sharesValue)
                
            default:
                continue
            }
        }
        
        guard let validShares = shares else {
            throw BlendParsingError.missingRequiredField("UserBalance missing shares")
        }
        
        return UserBalance(q4w: q4wArray, shares: validShares)
    }
    
    /// Parse PoolBackstopData struct response
    public func parsePoolBackstopDataResponse(_ response: SCValXDR) throws -> PoolBackstopData {
        guard case .map(let mapOptional) = response,
              let map = mapOptional else {
            throw BlendParsingError.invalidType(
                expected: "map",
                actual: String(describing: type(of: response))
            )
        }
        
        var blnd: Int128?
        var q4wPct: Int128?
        var shares: Int128?
        var tokenSpotPrice: Int128?
        var tokens: Int128?
        var usdc: Int128?
        
        for pair in map {
            guard case .symbol(let key) = pair.key else { continue }
            
            switch key {
            case "blnd":
                guard case .i128(let blndValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "i128",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                blnd = convertI128PartsToInt128(blndValue)
                
            case "q4w_pct":
                guard case .i128(let q4wValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "i128",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                q4wPct = convertI128PartsToInt128(q4wValue)
                
            case "shares":
                guard case .i128(let sharesValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "i128",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                shares = convertI128PartsToInt128(sharesValue)
                
            case "token_spot_price":
                guard case .i128(let spotPriceValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "i128",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                tokenSpotPrice = convertI128PartsToInt128(spotPriceValue)
                
            case "tokens":
                guard case .i128(let tokensValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "i128",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                tokens = convertI128PartsToInt128(tokensValue)
                
            case "usdc":
                guard case .i128(let usdcValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "i128",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                usdc = convertI128PartsToInt128(usdcValue)
                
            default:
                continue
            }
        }
        
        // All fields are optional in the response, use 0 as default for missing values
        let result = PoolBackstopData(
            blnd: blnd ?? 0,
            q4wPercent: q4wPct ?? 0,
            shares: shares ?? 0,
            tokenSpotPrice: tokenSpotPrice ?? 0,
            tokens: tokens ?? 0,
            usdc: usdc ?? 0
        )
        
        return result
    }
    
    /// Parse BackstopEmissionsData struct response
    public func parseBackstopEmissionsDataResponse(_ response: SCValXDR) throws -> BackstopEmissionsData {
        guard case .map(let mapOptional) = response,
              let map = mapOptional else {
            throw BlendParsingError.invalidType(
                expected: "map",
                actual: String(describing: type(of: response))
            )
        }
        
        var index: Int128?
        var lastTime: UInt64?
        
        for pair in map {
            guard case .symbol(let key) = pair.key else { continue }
            
            switch key {
            case "index":
                guard case .i128(let indexValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "i128",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                index = convertI128PartsToInt128(indexValue)
                
            case "last_time":
                guard case .u64(let timeValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "u64",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                lastTime = timeValue
                
            default:
                continue
            }
        }
        
        guard let validIndex = index, let validLastTime = lastTime else {
            throw BlendParsingError.missingRequiredField("BackstopEmissionsData incomplete")
        }
        
        return BackstopEmissionsData(index: validIndex, lastTime: validLastTime)
    }
    
    /// Parse UserEmissionData struct response
    public func parseUserEmissionDataResponse(_ response: SCValXDR) throws -> UserEmissionData {
        guard case .map(let mapOptional) = response,
              let map = mapOptional else {
            throw BlendParsingError.invalidType(
                expected: "map",
                actual: String(describing: type(of: response))
            )
        }
        
        var accrued: Int128?
        var index: Int128?
        
        for pair in map {
            guard case .symbol(let key) = pair.key else { continue }
            
            switch key {
            case "accrued":
                guard case .i128(let accruedValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "i128",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                accrued = convertI128PartsToInt128(accruedValue)
                
            case "index":
                guard case .i128(let indexValue) = pair.val else {
                    throw BlendParsingError.invalidType(
                        expected: "i128",
                        actual: String(describing: type(of: pair.val))
                    )
                }
                index = convertI128PartsToInt128(indexValue)
                
            default:
                continue
            }
        }
        
        guard let validAccrued = accrued, let validIndex = index else {
            throw BlendParsingError.missingRequiredField("UserEmissionData incomplete")
        }
        
        return UserEmissionData(accrued: validAccrued, index: validIndex)
    }
    
    /// Parse tuple response for token values (BLND, USDC)
    public func parseTokenValueTupleResponse(_ response: SCValXDR) throws -> (Int128, Int128) {
        guard case .vec(let vecOptional) = response,
              let vec = vecOptional,
              vec.count == 2 else {
            throw BlendParsingError.invalidType(
                expected: "tuple<i128,i128>",
                actual: String(describing: type(of: response))
            )
        }
        
        let blndValue = try parseI128Response(vec[0])
        let usdcValue = try parseI128Response(vec[1])
        
        return (blndValue, usdcValue)
    }
    
    // MARK: - Helper Functions
    
    /// Convert i128 parts to Int128
    private func convertI128PartsToInt128(_ parts: Int128PartsXDR) -> Int128 {
        if parts.hi == 0 {
            return Int128(parts.lo)
        } else if parts.hi == -1 && (parts.lo & 0x8000000000000000) != 0 {
            let signedLo = Int64(bitPattern: parts.lo)
            return Int128(signedLo)
        } else {
            // Large number: combine hi and lo parts
            let hiValue = Int128(parts.hi) << 64
            let loValue = Int128(parts.lo)
            return hiValue + loValue
        }
    }
    
    /// Extract address string from SCAddressXDR
    private func extractAddressString(from addressXDR: SCAddressXDR) throws -> String {
        switch addressXDR {
        case .account(let accountXDR):
            return accountXDR.accountId
        case .contract(let contractXDR):
            return ""
        }
    }
}
