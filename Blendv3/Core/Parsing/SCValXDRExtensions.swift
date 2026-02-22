//
//  SCValXDRExtensions.swift
//  Blendv3
//
//  Extensions to SCValXDR for better parsing and debugging
//

import Foundation
import stellarsdk

// MARK: - SCValXDR Parsing Extensions

extension SCValXDR {
    
    /// Initialize SCValXDR from XDR string with better error handling
    /// - Parameter xdr: Base64 encoded XDR string
    /// - Throws: Enhanced parsing errors with context
    public init(xdr: String) throws {
        // Clean the input string
        let cleanXDR = xdr.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanXDR.isEmpty else {
            throw SCValXDRError.emptyXDRString
        }
        
        do {
            // Use the standard fromXdr method
            self = try SCValXDR.fromXdr(base64: cleanXDR)
        } catch let error as StellarSDKError {
            // Handle specific Stellar SDK errors
            throw SCValXDRError.stellarSDKError(error.localizedDescription, originalXDR: cleanXDR)
        } catch {
            // Handle generic parsing errors
            throw SCValXDRError.parsingFailed(error.localizedDescription, originalXDR: cleanXDR)
        }
    }
    
    /// Get a human-readable description of the SCValXDR content
    public var debugDescription: String {
        switch self {
        case .bool(let value):
            return "SCV_BOOL: \(value)"
        case .void:
            return "SCV_VOID"
        case .error(let error):
            return "SCV_ERROR: \(error)"
        case .u32(let value):
            return "SCV_U32: \(value)"
        case .i32(let value):
            return "SCV_I32: \(value)"
        case .u64(let value):
            return "SCV_U64: \(value)"
        case .i64(let value):
            return "SCV_I64: \(value)"
        case .timepoint(let value):
            return "SCV_TIMEPOINT: \(value)"
        case .duration(let value):
            return "SCV_DURATION: \(value)"
        case .u128(let value):
            return "SCV_U128: hi=\(value.hi), lo=\(value.lo)"
        case .i128(let value):
            return "SCV_I128: hi=\(value.hi), lo=\(value.lo)"
        case .u256(let value):
            return "SCV_U256: \(value)"
        case .i256(let value):
            return "SCV_I256: \(value)"
        case .bytes(let data):
            return "SCV_BYTES: \(data.count) bytes"
        case .string(let string):
            return "SCV_STRING: \"\(string)\""
        case .symbol(let symbol):
            return "SCV_SYMBOL: \(symbol)"
        case .vec(let array):
            return "SCV_VEC: \(array?.count ?? 0) items"
        case .map(let map):
            return "SCV_MAP: \(map?.count ?? 0) entries"
        case .address(let address):
            return "SCV_ADDRESS: \(address)"
        case .contractInstance(let instance):
            return "SCV_CONTRACT_INSTANCE: \(instance)"
        case .ledgerKeyContractInstance:
            return "SCV_LEDGER_KEY_CONTRACT_INSTANCE"
        case .ledgerKeyNonce(let nonce):
            return "SCV_LEDGER_KEY_NONCE: \(nonce)"
        }
    }
    
    /// Safely extract u32 value with validation
    public var safeU32: UInt32? {
        switch self {
        case .u32(let value):
            return value
        case .i32(let value) where value >= 0:
            return UInt32(value)
        default:
            return nil
        }
    }
    
    /// Safely extract any numeric value as UInt32
    public var numericAsU32: UInt32? {
        switch self {
        case .u32(let value):
            return value
        case .i32(let value) where value >= 0:
            return UInt32(value)
        case .u64(let value) where value <= UInt32.max:
            return UInt32(value)
        case .i64(let value) where value >= 0 && value <= UInt32.max:
            return UInt32(value)
        default:
            return nil
        }
    }
}

// MARK: - SCValXDR Error Types

/// Enhanced error types for SCValXDR parsing
public enum SCValXDRError: Error, LocalizedError {
    case emptyXDRString
    case stellarSDKError(String, originalXDR: String)
    case parsingFailed(String, originalXDR: String)
    case invalidDiscriminant(Int32, originalXDR: String)
    case unsupportedType(String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyXDRString:
            return "Empty XDR string provided"
        case .stellarSDKError(let message, let originalXDR):
            return "Stellar SDK parsing error: \(message) for XDR: \(originalXDR.prefix(50))..."
        case .parsingFailed(let message, let originalXDR):
            return "XDR parsing failed: \(message) for XDR: \(originalXDR.prefix(50))..."
        case .invalidDiscriminant(let discriminant, let originalXDR):
            return "Invalid discriminant \(discriminant) for XDR: \(originalXDR.prefix(50))..."
        case .unsupportedType(let type):
            return "Unsupported SCVal type: \(type)"
        }
    }
}

// MARK: - Debugging Utilities

extension SCValXDR {
    
    /// Log detailed debugging information about this SCValXDR
    public func logDebugInfo(logger: DebugLogger) {
        logger.info("🔍 SCValXDR Debug Info:")
        logger.info("  Type discriminant: \(self.type())")
        logger.info("  Description: \(self.debugDescription)")
        
        // Log additional type-specific information
        switch self {
        case .u32(let value):
            logger.info("  U32 value: \(value) (0x\(String(value, radix: 16)))")
        case .i32(let value):
            logger.info("  I32 value: \(value) (0x\(String(UInt32(bitPattern: value), radix: 16)))")
        case .vec(let array):
            if let array = array {
                logger.info("  Vector contents:")
                for (index, item) in array.enumerated() {
                    logger.info("    [\(index)]: \(item.debugDescription)")
                }
            } else {
                logger.info("  Vector is nil")
            }
        case .map(let map):
            if let map = map {
                logger.info("  Map contents:")
                for entry in map {
                    logger.info("    \(entry.key.debugDescription) -> \(entry.val.debugDescription)")
                }
            } else {
                logger.info("  Map is nil")
            }
        default:
            break
        }
    }
}

// MARK: - Validation Helpers

extension SCValXDR {
    
    /// Validate that this SCValXDR is a valid u32 and return its value
    public func validateAndExtractU32() throws -> UInt32 {
        guard let value = safeU32 else {
            throw SCValXDRError.unsupportedType("Expected u32, got \(self.debugDescription)")
        }
        return value
    }
    
    /// Validate that this SCValXDR is numeric and can be safely converted to UInt32
    public func validateAndExtractNumericAsU32() throws -> UInt32 {
        guard let value = numericAsU32 else {
            throw SCValXDRError.unsupportedType("Cannot convert \(self.debugDescription) to UInt32")
        }
        return value
    }
    
    /// Check if this SCValXDR represents a successful result (not an error)
    public var isSuccessResult: Bool {
        switch self {
        case .error:
            return false
        default:
            return true
        }
    }
} 