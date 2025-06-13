//
//  BlendParser+TokenMetadata.swift
//  Blendv3
//
//  BlendParser extensions for token metadata parsing
//

import Foundation
import stellarsdk

// MARK: - BlendParser Token Metadata Extensions

extension BlendParser {
    
    /// Decode entry key from SCValXDR to String
    /// Handles symbol and string types commonly used as map keys
    /// - Parameter key: SCValXDR key to decode
    /// - Returns: String representation of the key
    func decodeEntryKey(_ key: SCValXDR) -> String {
        switch key {
        case .symbol(let symbol):
            return symbol
        case .string(let string):
            return string
        default:
            // For other types, try to convert to string representation
            do {
                return try parseString(key)
            } catch {
                // Fallback to description if parsing fails
                return String(describing: key)
            }
        }
    }
    
    /// Convert SCValXDR to native Swift type
    /// Supports common types used in token metadata
    /// - Parameter val: SCValXDR value to convert
    /// - Returns: Native Swift value or nil if conversion fails
    func scValToNative<T>(_ val: SCValXDR) -> T? {
        switch val {
        case .string(let string):
            return string as? T
        case .symbol(let symbol):
            return symbol as? T
        case .u32(let u32):
            if T.self == Int.self {
                return Int(u32) as? T
            } else if T.self == UInt32.self {
                return u32 as? T
            }
            return u32 as? T
        case .i32(let i32):
            if T.self == Int.self {
                return Int(i32) as? T
            } else if T.self == Int32.self {
                return i32 as? T
            }
            return i32 as? T
        case .u64(let u64):
            if T.self == Int.self {
                return Int(u64) as? T
            }
            return u64 as? T
        case .i64(let i64):
            if T.self == Int.self {
                return Int(i64) as? T
            }
            return i64 as? T
        case .bool(let bool):
            return bool as? T
        default:
            return nil
        }
    }
    
    /// Extract metadata from contract instance storage map
    /// - Parameter storage: Array of SCMapEntryXDR from contract instance
    /// - Returns: Tuple containing name, symbol, and decimals if found
    /// - Throws: BlendParsingError if required fields are missing or invalid
    func extractTokenMetadata(from storage: [SCMapEntryXDR]) throws -> (name: String, symbol: String, decimals: Int) {
        var name: String?
        var symbol: String?
        var decimals: Int?
        
        // Look for METADATA entry in storage
        for entry in storage {
            let key = decodeEntryKey(entry.key)
            
            if key == "METADATA" {
                // Parse the metadata map
                guard case .map(let metaMapOptional) = entry.val,
                      let metaMap = metaMapOptional else {
                    continue
                }
                
                // Extract name, symbol, decimal from metadata map
                for metaEntry in metaMap {
                    let metaKey = decodeEntryKey(metaEntry.key)
                    
                    switch metaKey {
                    case "name":
                        name = scValToNative(metaEntry.val)
                    case "symbol":
                        symbol = scValToNative(metaEntry.val)
                    case "decimal":
                        decimals = scValToNative(metaEntry.val)
                    default:
                        continue
                    }
                }
                break
            }
        }
        
        // Validate required fields
        guard let validName = name else {
            throw BlendParsingError.missingRequiredField("name")
        }
        
        guard var validSymbol = symbol else {
            throw BlendParsingError.missingRequiredField("symbol")
        }
        
        guard let validDecimals = decimals else {
            throw BlendParsingError.missingRequiredField("decimal")
        }
        
        // Convert "native" symbol to "XLM"
        if validSymbol == "native" {
            validSymbol = "XLM"
        }
        
        return (name: validName, symbol: validSymbol, decimals: validDecimals)
    }
} 