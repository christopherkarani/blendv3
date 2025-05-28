//
//  StellarContractID.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//


import Foundation

/// Utility for converting Soroban 32-byte contract hashes (hex) ⇄ StrKey addresses (prefix "C").
///
/// ### Public API
/// * `encode(hex:)` – hex → StrKey (throws if already StrKey or malformed)
/// * `decode(strKey:)` – StrKey → hex (throws on invalid address)
public final class StellarContractID {
    
    // MARK: - Constants ------------------------------------------------------
    
    /// Version byte for Soroban contract addresses (Stellar Protocol)
    private static let versionByte: UInt8 = 0x10
    
    /// CRC-16/XMODEM polynomial (standard CCITT polynomial)
    private static let crcPolynomial: UInt16 = 0x1021
    
    /// Expected raw contract hash length in bytes
    private static let contractHashLength = 32
    
    /// Expected hex string length (64 characters for 32 bytes)
    private static let expectedHexLength = contractHashLength * 2
    
    /// Expected StrKey payload length (version + hash + checksum)
    private static let strKeyPayloadLength = 35
    
    /// Maximum reasonable input length to prevent DoS attacks
    private static let maxInputLength = 1000
    
    // MARK: - Public API -----------------------------------------------------

    /// Encode a **64-char hex string** into a **StrKey contract ID** (starts with `C`).
    /// Throws ``Error.alreadyStrKey`` if the argument is already a valid contract address.
    /// - Parameter hex: 64-character hexadecimal string representing 32 bytes
    /// - Returns: StrKey format contract address starting with 'C'
    /// - Throws: Various ``Error`` cases for invalid input
    public static func encode(hex: String) throws -> String {
        // Normalize and validate input
        let normalizedHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Check if already a StrKey to prevent double encoding
        guard !isStrKeyContract(normalizedHex) else {
            throw StellarContractIDError.alreadyStrKey
        }
        
        // Convert and validate hex
        let rawData = try dataFromHex(normalizedHex)
        guard rawData.count == contractHashLength else {
            throw StellarContractIDError.invalidHexLength(expected: expectedHexLength, actual: normalizedHex.count)
        }
        
        // Create payload and encode
        let payload = createPayload(with: rawData)
        return base32Encode(payload)
    }

    /// Decode a **StrKey contract address** back to its 64-char hex string.
    /// - Parameter strKey: StrKey format contract address starting with 'C'
    /// - Returns: 64-character lowercase hexadecimal string
    /// - Throws: Various ``Error`` cases for invalid input
    public static func decode(strKey: String) throws -> String {
        let validatedData = try validateStrKeyContract(strKey)
        // Skip version byte (first byte) and convert remaining 32 bytes to hex
        let hashData = validatedData.dropFirst().dropLast(2) // Remove version and checksum
        return hashData.stellarHexEncodedString()
    }

    // MARK: - Validation Helpers --------------------------------------------

    /// Whether the supplied string is already a *valid* Soroban contract StrKey.
    /// - Parameter str: String to validate
    /// - Returns: true if valid StrKey contract address, false otherwise
    public static func isStrKeyContract(_ str: String) -> Bool {
        do {
            _ = try validateStrKeyContract(str)
            return true
        } catch {
            return false
        }
    }

    /// Validates StrKey contract format and returns full payload if valid.
    /// - Parameter strKey: StrKey format string to validate
    /// - Returns: Complete payload data (version + hash + checksum)
    /// - Throws: Various ``Error`` cases for validation failures
    @discardableResult
    private static func validateStrKeyContract(_ strKey: String) throws -> Data {
        // Normalize input
        let normalized = strKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic length check to prevent excessive processing
        guard normalized.count <= maxInputLength else {
            throw StellarContractIDError.inputTooLong
        }
        
        // Decode base32
        let decodedData = try base32Decode(normalized)
        
        // Validate payload structure
        guard decodedData.count == strKeyPayloadLength else {
            throw StellarContractIDError.invalidPayloadLength(expected: strKeyPayloadLength, actual: decodedData.count)
        }
        
        // Validate version byte
        guard decodedData.first == versionByte else {
            throw StellarContractIDError.unsupportedVersion(found: decodedData.first ?? 0, expected: versionByte)
        }
        
        // Extract components for checksum validation
        let payloadWithoutChecksum = decodedData.prefix(strKeyPayloadLength - 2)
        let checksumBytes = decodedData.suffix(2)
        let providedChecksum = uint16LittleEndian(from: Data(checksumBytes))
        let calculatedChecksum = crc16XModem(payloadWithoutChecksum)
        
        // Validate checksum
        guard calculatedChecksum == providedChecksum else {
            throw StellarContractIDError.invalidChecksum(calculated: calculatedChecksum, provided: providedChecksum)
        }
        
        return decodedData
    }

    // MARK: - Error Definitions ---------------------------------------------

    public enum StellarContractIDError: Swift.Error, Equatable {
        case invalidHexCharacter(at: String.Index)
        case invalidHexLength(expected: Int, actual: Int)
        case invalidPayloadLength(expected: Int, actual: Int)
        case invalidChecksum(calculated: UInt16, provided: UInt16)
        case unsupportedVersion(found: UInt8, expected: UInt8)
        case invalidBase32Character(Character)
        case alreadyStrKey
        case inputTooLong
        case malformedBase32
    }

    // MARK: - Internal Helpers ----------------------------------------------

    /// Creates a complete payload with version, hash, and checksum.
    /// - Parameter rawHash: 32-byte contract hash
    /// - Returns: Complete payload ready for base32 encoding
    private static func createPayload(with rawHash: Data) -> Data {
        precondition(rawHash.count == contractHashLength, "Hash must be exactly \(contractHashLength) bytes")
        
        // Build payload: version + hash
        var payload = Data(capacity: strKeyPayloadLength)
        payload.append(versionByte)
        payload.append(rawHash)
        
        // Calculate and append checksum in little-endian format
        let checksum = crc16XModem(payload)
        payload.append(UInt8(checksum & 0xFF))        // Low byte
        payload.append(UInt8((checksum >> 8) & 0xFF)) // High byte
        
        return payload
    }

    // MARK: - Byte Manipulation Helpers -------------------------------------

    /// Safely assembles a UInt16 from two little-endian bytes.
    /// - Parameter bytes: Exactly 2 bytes of data
    /// - Returns: UInt16 value in host byte order
    private static func uint16LittleEndian(from bytes: Data) -> UInt16 {
        precondition(bytes.count == 2, "Exactly two bytes expected for UInt16 conversion")
        let lowByte = UInt16(bytes[bytes.startIndex])
        let highByte = UInt16(bytes[bytes.startIndex.advanced(by: 1)])
        return lowByte | (highByte << 8)
    }

    // MARK: - CRC-16/XMODEM Implementation ----------------------------------

    /// Calculates CRC-16/XMODEM checksum with overflow protection.
    /// Uses polynomial 0x1021 (standard CCITT).
    /// - Parameter data: Data to calculate checksum for
    /// - Returns: 16-bit checksum
    private static func crc16XModem(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0
        
        for byte in data {
            crc ^= UInt16(byte) << 8
            
            // Process 8 bits with overflow-safe shifts
            for _ in 0..<8 {
                if (crc & 0x8000) != 0 {
                    crc = (crc &<< 1) ^ crcPolynomial
                } else {
                    crc = crc &<< 1
                }
            }
        }
        
        return crc & 0xFFFF
    }

    // MARK: - Base32 Implementation (RFC 4648, no padding) -----------------

    private static let base32Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    
    /// Pre-computed lookup table for O(1) character to value mapping
    private static let base32DecodeLookup: [Character: Int] = {
        var lookup = [Character: Int]()
        for (index, character) in base32Alphabet.enumerated() {
            lookup[character] = index
        }
        return lookup
    }()

    /// Encodes data to Base32 string (RFC 4648, no padding).
    /// - Parameter data: Raw bytes to encode
    /// - Returns: Base32 encoded string
    private static func base32Encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        
        // Pre-allocate string capacity for better performance
        var result = ""
        result.reserveCapacity((data.count * 8 + 4) / 5) // Theoretical max length
        
        var accumulator: UInt32 = 0
        var bitsInAccumulator = 0
        
        for byte in data {
            accumulator = (accumulator << 8) | UInt32(byte)
            bitsInAccumulator += 8
            
            // Extract 5-bit groups
            while bitsInAccumulator >= 5 {
                let index = Int((accumulator >> (bitsInAccumulator - 5)) & 0x1F)
                result.append(base32Alphabet[index])
                bitsInAccumulator -= 5
            }
        }
        
        // Handle remaining bits
        if bitsInAccumulator > 0 {
            let index = Int((accumulator << (5 - bitsInAccumulator)) & 0x1F)
            result.append(base32Alphabet[index])
        }
        
        return result
    }

    /// Decodes Base32 string to raw data (RFC 4648, no padding).
    /// - Parameter encodedString: Base32 encoded string
    /// - Returns: Decoded raw bytes
    /// - Throws: ``Error.invalidBase32Character`` or ``Error.malformedBase32``
    private static func base32Decode(_ encodedString: String) throws -> Data {
        let normalized = encodedString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return Data() }
        
        // Input length validation
        guard normalized.count <= maxInputLength else {
            throw StellarContractIDError.inputTooLong
        }
        
        var result = Data()
        result.reserveCapacity((normalized.count * 5) / 8) // Theoretical capacity
        
        var accumulator: UInt32 = 0
        var bitsInAccumulator = 0
        
        for character in normalized {
            guard let value = base32DecodeLookup[character] else {
                throw StellarContractIDError.invalidBase32Character(character)
            }
            
            // Prevent accumulator overflow
            guard bitsInAccumulator <= 27 else { // 32 - 5 = 27 max safe bits
                throw StellarContractIDError.malformedBase32
            }
            
            accumulator = (accumulator << 5) | UInt32(value)
            bitsInAccumulator += 5
            
            // Extract complete bytes
            if bitsInAccumulator >= 8 {
                let byte = UInt8((accumulator >> (bitsInAccumulator - 8)) & 0xFF)
                result.append(byte)
                bitsInAccumulator -= 8
            }
        }
        
        return result
    }

    // MARK: - Hex Conversion Helpers ----------------------------------------

    /// Converts hexadecimal string to raw data with comprehensive validation.
    /// - Parameter hexString: Hexadecimal string (case insensitive)
    /// - Returns: Raw bytes
    /// - Throws: ``Error.invalidHexCharacter`` or ``Error.invalidHexLength``
    private static func dataFromHex(_ hexString: String) throws -> Data {
        let normalized = hexString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Validate length
        guard normalized.count % 2 == 0 else {
            throw StellarContractIDError.invalidHexLength(expected: expectedHexLength, actual: normalized.count)
        }
        
        // Pre-validate all characters are valid hex
        for (index, character) in normalized.enumerated() {
            guard character.isHexDigit else {
                let stringIndex = normalized.index(normalized.startIndex, offsetBy: index)
                throw StellarContractIDError.invalidHexCharacter(at: stringIndex)
            }
        }
        
        // Convert to bytes
        var result = Data(capacity: normalized.count / 2)
        var currentIndex = normalized.startIndex
        
        while currentIndex < normalized.endIndex {
            let nextIndex = normalized.index(currentIndex, offsetBy: 2)
            let hexByte = String(normalized[currentIndex..<nextIndex])
            
            // This should never fail due to pre-validation, but keeping guard for safety
            guard let byte = UInt8(hexByte, radix: 16) else {
                throw StellarContractIDError.invalidHexCharacter(at: currentIndex)
            }
            
            result.append(byte)
            currentIndex = nextIndex
        }
        
        return result
    }
}

// MARK: - Extensions -----------------------------------------------------

private extension Data {
    /// Converts data to lowercase hexadecimal string representation.
    /// - Returns: Hex string with lowercase letters
    func stellarHexEncodedString() -> String {
        return self.map { String(format: "%02x", $0) }.joined()
    }
}

private extension Character {
    /// Efficiently checks if character is a valid hexadecimal digit.
    var isHexDigit: Bool {
        return ("0"..."9").contains(self) || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}
