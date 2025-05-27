//
//  StellarContractID.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//


import Foundation

/// Utility for converting Soroban 32-byte contract hashes (hex) ⇄ StrKey addresses (prefix “C”).
///
/// ### Public API
/// * `encode(hex:)` – hex → StrKey (throws if already StrKey or malformed)
/// * `decode(strKey:)` – StrKey → hex (throws on invalid address)
public final class StellarContractID {
    // MARK: - Public ---------------------------------------------------------

    /// Encode a **64-char hex string** into a **StrKey contract ID** (starts with `C`).
    /// Throws ``Error.alreadyStrKey`` if the argument is already a valid contract address.
    public static func encode(hex: String) throws -> String {
        guard !isStrKeyContract(hex) else { throw Error.alreadyStrKey }
        let raw = try dataFromHex(hex)
        guard raw.count == 32 else { throw Error.invalidHexLength }
        return base32Encode(payload(with: raw))
    }

    /// Decode a **StrKey contract address** back to its 64-char hex string.
    public static func decode(strKey: String) throws -> String {
        let data = try validateStrKeyContract(strKey)
        return data.dropFirst().stellarHexEncodedString()       // strip version byte
    }

    // MARK: - Validation helpers --------------------------------------------

    /// Whether the supplied string is already a *valid* Soroban contract StrKey.
    public static func isStrKeyContract(_ str: String) -> Bool {
        (try? validateStrKeyContract(str)) != nil
    }

    /// Returns full payload (version + raw + checksum) if valid, else throws.
    @discardableResult
    private static func validateStrKeyContract(_ strKey: String) throws -> Data {
        let data = try base32Decode(strKey)
        guard data.count == 35 else { throw Error.invalidLength }
        guard data.first == versionByte else { throw Error.unsupportedVersion }
        let payload = data.prefix(33)
        let checksum = uint16LittleEndian(from: data.suffix(2))
        guard crc16XModem(payload) == checksum else { throw Error.invalidChecksum }
        return data
    }

    // MARK: - Error definitions ---------------------------------------------

    public enum Error: Swift.Error {
        case invalidHex, invalidHexLength, invalidLength, invalidChecksum, unsupportedVersion, invalidBase32, alreadyStrKey
    }

    // MARK: - Internals ------------------------------------------------------

    private static let versionByte: UInt8 = 0x10 // Soroban contract

    private static func payload(with raw: Data) -> Data {
        var payload = Data([versionByte]) + raw
        let checksum = crc16XModem(payload)           // UInt16
        // append little‑endian bytes safely
        payload.append(UInt8(checksum & 0xFF))
        payload.append(UInt8(checksum >> 8))
        return payload
    }

    // MARK: - Byte helpers ----------------------------------------------------
    /// Assemble a UInt16 from two little‑endian bytes (data.count must be 2).
    private static func uint16LittleEndian(from bytes: Data) -> UInt16 {
        precondition(bytes.count == 2, "Exactly two bytes expected")
        return UInt16(bytes[bytes.startIndex]) | (UInt16(bytes[bytes.startIndex.advanced(by: 1)]) << 8)
    }

    // MARK: CRC-16/XModem ----------------------------------------------------
    private static func crc16XModem(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0
        for byte in data {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return crc & 0xFFFF
    }

    // MARK: Base32 (RFC 4648, no padding) -----------------------------------
    private static let base32Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    private static let alphabetMap: [Character: Int] = {
        var dict = [Character: Int]()
        for (i, c) in base32Alphabet.enumerated() { dict[c] = i }
        return dict
    }()

    private static func base32Encode(_ data: Data) -> String {
        var out = ""; var buffer = 0; var bits = 0
        for byte in data {
            buffer = (buffer << 8) | Int(byte); bits += 8
            while bits >= 5 { out.append(base32Alphabet[(buffer >> (bits - 5)) & 0x1F]); bits -= 5 }
        }
        if bits > 0 { out.append(base32Alphabet[(buffer << (5 - bits)) & 0x1F]) }
        return out
    }

    private static func base32Decode(_ str: String) throws -> Data {
        var buffer = 0; var bits = 0; var bytes = Data()
        for char in str.uppercased() {
            guard let val = alphabetMap[char] else { throw Error.invalidBase32 }
            buffer = (buffer << 5) | val; bits += 5
            if bits >= 8 { bytes.append(UInt8((buffer >> (bits - 8)) & 0xFF)); bits -= 8 }
        }
        return bytes
    }

    // MARK: Hex helpers ------------------------------------------------------
    private static func dataFromHex(_ hex: String) throws -> Data {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count % 2 == 0 else { throw Error.invalidHexLength }
        var data = Data(capacity: trimmed.count / 2)
        var idx = trimmed.startIndex
        while idx < trimmed.endIndex {
            let nxt = trimmed.index(idx, offsetBy: 2)
            guard let byte = UInt8(trimmed[idx..<nxt], radix: 16) else { throw Error.invalidHex }
            data.append(byte); idx = nxt
        }
        return data
    }
}

// MARK: - Convenience --------------------------------------------------------
private extension Data {
    func stellarHexEncodedString() -> String { map { String(format: "%02x", $0) }.joined() }
}
