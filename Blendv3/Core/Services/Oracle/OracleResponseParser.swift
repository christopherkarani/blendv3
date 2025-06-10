//
//  OracleResponseParser.swift
//  Blendv3
//
//  Dedicated parsing objects for Oracle contract responses
//

import Foundation
import stellarsdk
import os

/// Protocol for Oracle response parsing
public protocol OracleResponseParserProtocol {
    associatedtype ParsedType
    
    /// Parse SCValXDR response into the expected type
    /// - Parameters:
    ///   - response: Raw SCValXDR response from contract
    ///   - context: Additional context for parsing
    /// - Returns: Parsed response of the expected type
    /// - Throws: OracleError if parsing fails
    func parse(_ response: SCValXDR, context: OracleParsingContext?) throws -> ParsedType
}

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

// MARK: - Optional PriceData Parser

/// Parser for Option<PriceData> responses
public struct OptionalPriceDataParser: OracleResponseParserProtocol {
    public typealias ParsedType = PriceData?
    
    private let debugLogger = DebugLogger(subsystem: "com.blendv3.oracle", category: "OptionalPriceDataParser")
    
    public init() {}
    
    public func parse(_ response: SCValXDR, context: OracleParsingContext?) throws -> PriceData? {
        let assetId = context?.assetId ?? "unknown"
        let symbol = getAssetSymbol(for: assetId)
        
        debugLogger.info("🔮 📝 Parsing Option<PriceData> for \(symbol)")
        
        switch response {
        case .void:
            debugLogger.info("🔮 ❌ No price data available (None) for \(symbol)")
            return nil
            
        case .vec(let vecOptional):
            // Some(PriceData) case - might be wrapped in a vector
            guard let vec = vecOptional, !vec.isEmpty else {
                debugLogger.info("🔮 ❌ Empty vector for \(symbol)")
                return nil
            }
            return try parseWrappedPriceData(from: vec[0], assetId: assetId)
            
        case .map(let mapOptional):
            // Direct PriceData struct (no Option wrapper)
            guard let map = mapOptional else {
                throw OracleError.invalidResponse(
                    details: "Map is nil in direct PriceData response",
                    rawData: String(describing: response)
                )
            }
            return try PriceDataStructParser().parse(.map(mapOptional), context: context)
            
        case .i128(let priceValue):
            debugLogger.info("🔮 💰 Parsing simple i128 price for \(symbol)")
            let price = I128Parser.parseToDecimal(priceValue)
            return PriceData(
                price: price,
                timestamp: context?.timestamp ?? Date(),
                assetId: assetId,
                decimals: 7
            )
            
        default:
            let details = "Unexpected XDR type: \(String(describing: type(of: response)))"
            throw OracleError.invalidResponse(details: details, rawData: String(describing: response))
        }
    }
    
    private func parseWrappedPriceData(from value: SCValXDR, assetId: String) throws -> PriceData? {
        let symbol = getAssetSymbol(for: assetId)
        debugLogger.info("🔮 🔍 Parsing wrapped PriceData for \(symbol)")
        
        switch value {
        case .map(let mapOptional):
            guard let map = mapOptional else {
                let details = "Map is nil in wrapped PriceData"
                throw OracleError.invalidResponse(details: details, rawData: String(describing: value))
            }
            let context = OracleParsingContext(assetId: assetId, functionName: "wrapped_price_data")
            return try PriceDataStructParser().parse(.map(mapOptional), context: context)
            
        case .i128(let priceValue):
            // Simple price value
            let price = I128Parser.parseToDecimal(priceValue)
            return PriceData(
                price: price,
                timestamp: Date(),
                assetId: assetId,
                decimals: 7
            )
            
        default:
            let details = "Unexpected wrapped value type: \(String(describing: type(of: value)))"
            throw OracleError.invalidResponse(details: details, rawData: String(describing: value))
        }
    }
    
    private func getAssetSymbol(for address: String) -> String {
        let assetMapping = [
            BlendUSDCConstants.Testnet.usdc: "USDC",
            BlendUSDCConstants.Testnet.xlm: "XLM",
            BlendUSDCConstants.Testnet.blnd: "BLND",
            BlendUSDCConstants.Testnet.weth: "wETH",
            BlendUSDCConstants.Testnet.wbtc: "wBTC"
        ]
        return assetMapping[address] ?? address
    }
}

// MARK: - PriceData Vector Parser

/// Parser for Option<Vec<PriceData>> responses
public struct PriceDataVectorParser: OracleResponseParserProtocol {
    public typealias ParsedType = [PriceData]
    
    private let debugLogger = DebugLogger(subsystem: "com.blendv3.oracle", category: "PriceDataVectorParser")
    
    public init() {}
    
    public func parse(_ response: SCValXDR, context: OracleParsingContext?) throws -> [PriceData] {
        let assetId = context?.assetId ?? "unknown"
        debugLogger.info("🔮 📝 Parsing Option<Vec<PriceData>> for asset: \(assetId)")
        
        switch response {
        case .void:
            // None case - no price data available
            debugLogger.info("🔮 ❌ No price data available (None) for asset: \(assetId)")
            return []
            
        case .vec(let vecOptional):
            // Some(Vec<PriceData>) case
            guard let vec = vecOptional else {
                let details = "Vector is nil in Option<Vec<PriceData>> response"
                throw OracleError.invalidResponse(details: details, rawData: String(describing: response))
            }
            
            var priceDataArray: [PriceData] = []
            let priceDataParser = PriceDataStructParser()
            
            for (index, item) in vec.enumerated() {
                do {
                    let itemContext = OracleParsingContext(
                        assetId: assetId,
                        functionName: "price_vector_item_\(index)",
                        additionalInfo: ["index": index]
                    )
                    if let priceData = try priceDataParser.parse(item, context: itemContext) {
                        priceDataArray.append(priceData)
                    }
                } catch {
                    debugLogger.warning("🔮 ⚠️ Failed to parse price data at index \(index): \(error)")
                    // Continue parsing other items instead of failing completely
                }
            }
            
            debugLogger.info("🔮 ✅ Successfully parsed \(priceDataArray.count) price data items")
            return priceDataArray
            
        default:
            let details = "Unexpected XDR type for price vector: \(String(describing: type(of: response)))"
            throw OracleError.invalidResponse(details: details, rawData: String(describing: response))
        }
    }
}

// MARK: - PriceData Struct Parser

/// Parser for PriceData struct from map
public struct PriceDataStructParser: OracleResponseParserProtocol {
    public typealias ParsedType = PriceData?
    
    private let debugLogger = DebugLogger(subsystem: "com.blendv3.oracle", category: "PriceDataStructParser")
    
    public init() {}
    
    public func parse(_ response: SCValXDR, context: OracleParsingContext?) throws -> PriceData? {
        guard case .map(let mapOptional) = response, let map = mapOptional else {
            let details = "Expected map for PriceData struct"
            throw OracleError.invalidResponse(details: details, rawData: String(describing: response))
        }
        
        let assetId = context?.assetId ?? "unknown"
        let symbol = getAssetSymbol(for: assetId)
        debugLogger.info("🔮 🔍 Parsing PriceData struct for \(symbol) with \(map.count) fields")
        
        var price: Decimal?
        var timestamp: Date?
        
        for entry in map {
            if case .symbol(let key) = entry.key {
                debugLogger.info("🔮 🔑 Processing field: \(key)")
                
                switch key {
                case "price":
                    if case .i128(let priceValue) = entry.val {
                        price = I128Parser.parseToDecimal(priceValue)
                        debugLogger.info("🔮 💰 Price field parsed: \(price!)")
                    } else {
                        debugLogger.warning("🔮 ⚠️ Price field is not i128: \(entry.val)")
                    }
                    
                case "timestamp":
                    if case .u64(let timestampValue) = entry.val {
                        timestamp = Date(timeIntervalSince1970: TimeInterval(timestampValue))
                        debugLogger.info("🔮 ⏰ Timestamp field parsed: \(timestamp!)")
                    } else {
                        debugLogger.warning("🔮 ⚠️ Timestamp field is not u64: \(entry.val)")
                    }
                    
                default:
                    debugLogger.info("🔮 ❓ Ignoring unknown field: \(key)")
                }
            } else {
                debugLogger.warning("🔮 ⚠️ Non-symbol key: \(entry.key)")
            }
        }
        
        guard let finalPrice = price, let finalTimestamp = timestamp else {
            debugLogger.error("🔮 💥 Missing required PriceData fields - price: \(price != nil), timestamp: \(timestamp != nil)")
            
            let missingFields = [
                price == nil ? "price" : nil,
                timestamp == nil ? "timestamp" : nil
            ].compactMap { $0 }
            
            let details = "Missing required fields: \(missingFields.joined(separator: ", "))"
            throw OracleError.contractError(code: 1, message: details)
        }
        
        let priceData = PriceData(
            price: FixedMath.toFloat(value: finalPrice, decimals: 7),
            timestamp: finalTimestamp,
            assetId: assetId,
            decimals: 7 // Default to 7 decimals for Blend
        )
        
        debugLogger.info("🔮 ✅ PriceData created for \(symbol): $\(priceData.priceInUSD)")
        return priceData
    }
    
    private func getAssetSymbol(for address: String) -> String {
        let assetMapping = [
            BlendUSDCConstants.Testnet.usdc: "USDC",
            BlendUSDCConstants.Testnet.xlm: "XLM",
            BlendUSDCConstants.Testnet.blnd: "BLND",
            BlendUSDCConstants.Testnet.weth: "wETH",
            BlendUSDCConstants.Testnet.wbtc: "wBTC"
        ]
        return assetMapping[address] ?? address
    }
}

// MARK: - Asset Vector Parser

/// Parser for Vec<Asset> responses
public struct AssetVectorParser: OracleResponseParserProtocol {
    public typealias ParsedType = [OracleAsset]
    
    private let debugLogger = DebugLogger(subsystem: "com.blendv3.oracle", category: "AssetVectorParser")
    
    public init() {}
    
    public func parse(_ response: SCValXDR, context: OracleParsingContext?) throws -> [OracleAsset] {
        debugLogger.info("🔮 📝 Parsing Vec<Asset> response")
        
        guard case .vec(let assets) = response, let assetVec = assets else {
            throw OracleError.invalidResponseFormat("Expected vec of assets")
        }
        
        var oracleAssets: [OracleAsset] = []
        
        for (index, assetXDR) in assetVec.enumerated() {
            do {
                let asset = try OracleAsset.fromSCVal(assetXDR)
                oracleAssets.append(asset)
                debugLogger.info("🔮 ✅ Parsed asset \(index): \(asset)")
            } catch {
                debugLogger.warning("🔮 ⚠️ Failed to parse asset at index \(index): \(error)")
                // Continue parsing other assets
            }
        }
        
        debugLogger.info("🔮 ✅ Successfully parsed \(oracleAssets.count) assets")
        return oracleAssets
    }
}

// MARK: - Simple Value Parsers

/// Parser for u32 responses (resolution, decimals)
public struct U32Parser: OracleResponseParserProtocol {
    public typealias ParsedType = UInt32
    
    public init() {}
    
    public func parse(_ response: SCValXDR, context: OracleParsingContext?) throws -> UInt32 {
        guard case .u32(let value) = response else {
            let details = "Expected u32 response for \(context?.functionName ?? "unknown function")"
            throw OracleError.invalidResponseFormat(details)
        }
        return value
    }
}

/// Parser for Asset responses
public struct AssetParser: OracleResponseParserProtocol {
    public typealias ParsedType = OracleAsset
    
    public init() {}
    
    public func parse(_ response: SCValXDR, context: OracleParsingContext?) throws -> OracleAsset {
        return try OracleAsset.fromSCVal(response)
    }
}

// MARK: - I128 Utility Parser

/// Utility for parsing i128 values to Decimal
public struct I128Parser {
    
    /// Parse i128 to Decimal with proper fixed-point arithmetic
    /// Blend Protocol uses 7 decimal places for prices (10^7 = 10,000,000)
    public static func parseToDecimal(_ value: Int128PartsXDR) -> Decimal {
        let debugLogger = DebugLogger(subsystem: "com.blendv3.oracle", category: "I128Parser")
        debugLogger.info("🔮 🔢 Parsing i128 value: hi=\(value.hi), lo=\(value.lo)")
        
        // Convert i128 to a single 128-bit integer value
        let fullValue: Decimal
        
        if value.hi == 0 {
            // Simple case: only low 64 bits are used
            fullValue = Decimal(value.lo)
            debugLogger.info("🔮 🔢 Simple case - using lo value: \(value.lo)")
        } else if value.hi == -1 && (value.lo & 0x8000000000000000) != 0 {
            // Negative number in two's complement
            let signedLo = Int64(bitPattern: value.lo)
            fullValue = Decimal(signedLo)
            debugLogger.info("🔮 🔢 Negative case - signed lo: \(signedLo)")
        } else {
            // Large positive number: combine hi and lo parts
            // hi represents the upper 64 bits, lo represents the lower 64 bits
            let hiDecimal = Decimal(value.hi) * Decimal(sign: .plus, exponent: 64, significand: 1)
            let loDecimal = Decimal(value.lo)
            fullValue = hiDecimal + loDecimal
            debugLogger.info("🔮 🔢 Large number case - combined value: \(fullValue)")
        }
        
        debugLogger.info("🔮 💰 Final parsed price (fixed-point): \(fullValue)")
        return fullValue
    }
}
