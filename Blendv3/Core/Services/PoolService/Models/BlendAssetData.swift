//
//  BlendAssetData.swift
//  Blendv3
//
//  Created by Chris Karani on 30/05/2025.
//
import Foundation
import stellarsdk

// MARK: - Model -------------------------------------------------------------

/// Everything we care about from the reserve blob, already scaled
/// to human-readable decimals.
public struct BlendAssetData: Codable, Equatable {
    // Top-level
    public let assetId      : String          // 32-byte contract ID (hex)
    public let scalar       : Decimal         // 1e7 for Blend reserves

    // Config (raw fixed-point integers as stored on-chain)
    public let decimals     : Int
    public let enabled      : Bool
    public let index        : Int
    public let cFactor      : Decimal   // Raw fixed-point (not divided by scalar)
    public let lFactor      : Decimal   // Raw fixed-point (not divided by scalar)
    public let maxUtil      : Decimal   // Raw fixed-point (not divided by scalar)
    public let rBase        : Decimal   // Raw fixed-point (not divided by scalar)
    public let rOne         : Decimal   // Raw fixed-point (not divided by scalar)
    public let rTwo         : Decimal   // Raw fixed-point (not divided by scalar)
    public let rThree       : Decimal   // Raw fixed-point (not divided by scalar)
    public let reactivity   : Decimal   // Raw fixed-point (not divided by scalar)
    public let supplyCap    : Decimal   // Raw fixed-point (not divided by scalar)
    public let utilTarget   : Decimal   // Raw fixed-point (not divided by scalar)

    // Live data (raw values from chain)
    public let totalSupplied: Decimal   // Raw fixed-point (not divided by scalar)
    public let totalBorrowed: Decimal   // Raw fixed-point (not divided by scalar)
    public let borrowRate   : Decimal   // Raw fixed-point (not divided by scalar)
    public let supplyRate   : Decimal   // Raw fixed-point (not divided by scalar)
    public let dRate        : Decimal   // Raw fixed-point (SCALAR_12 = 1e12)
    public let backstopCredit: Decimal  // Raw fixed-point (not divided by scalar)
    public let irModifier   : Decimal   // Raw fixed-point (not divided by scalar)
    public let lastUpdate   : Date
    public var pricePerToken        : Decimal = 0
}

// MARK: - Convenience Init --------------------------------------------------

public extension BlendAssetData {
    /// Builds a `BlendAssetData` directly from the raw Soroban `SCValXDR`
    /// returned by the on‑chain `get_reserve` method.
    ///
    /// Usage:
    /// ```swift
    /// let raw: SCValXDR = try await client.invokeMethod(...)
    /// let asset = try BlendAssetData(rawReserve: raw)
    /// ```
    init(rawReserve raw: SCValXDR) throws {
        self = try parseBlendReserve(raw)
    }
}

// MARK: - Parser ------------------------------------------------------------

private let _FIXED_SCALE = Decimal(10_000_000)   // 1e7

/// Convert a 32-byte `WrappedData32` into a lowercase hex string.
private func hexString(from wrapped: WrappedData32) -> String {
    wrapped.wrapped.map { String(format: "%02x", $0) }.joined()
}

/// Main entry – call this with the value you printed via `po rawReserve`
func parseBlendReserve(_ raw: SCValXDR) throws -> BlendAssetData {
    // ---------------------------------------------------------------------
    // 0. Root map sanity-check
    // ---------------------------------------------------------------------
    guard case .map(let rootOpt) = raw, let root = rootOpt else {
        throw BlendVaultError.invalidResponse
    }

    // Helper storage while we walk the map
    var assetHex: String?
    var scalar  : Decimal = _FIXED_SCALE      // default 1e7

    // Config
    var decimals      = 7
    var enabled       = false
    var index         = 0
    var cFactor       = Decimal.zero
    var lFactor       = Decimal.zero
    var maxUtil       = Decimal.zero
    var rBase         = Decimal.zero
    var rOne          = Decimal.zero
    var rTwo          = Decimal.zero
    var rThree        = Decimal.zero
    var reactivity    = Decimal.zero
    var supplyCap     = Decimal.zero
    var utilTarget    = Decimal.zero

    // Data
    var totalSupplied = Decimal.zero
    var totalBorrowed = Decimal.zero
    var borrowRate    = Decimal.zero
    var supplyRate    = Decimal.zero
    var dRate         = Decimal.zero
    var backstopCred  = Decimal.zero
    var irMod         = Decimal.zero
    var lastUpdate    = Date(timeIntervalSince1970: 0)

    // ---------------------------------------------------------------------
    // 1. Walk the root map
    // ---------------------------------------------------------------------
    for entry in root {
        guard case .symbol(let key) = entry.key else { continue }

        switch key {

        //------------------------------------------------------------------
        case "asset":
            if case .address(let addr) = entry.val,
               case .contract(let wd32) = addr {
                assetHex = hexString(from: wd32)
            }

        //------------------------------------------------------------------
        case "scalar":
            if case .i128(let val) = entry.val {
                scalar = BlendParser.parseI128ToDecimal(val)
            }

        //------------------------------------------------------------------
        case "config":
            if case .map(let cfgOpt) = entry.val, let cfg = cfgOpt {
                for item in cfg {
                    guard case .symbol(let k) = item.key else { continue }
                    switch k {
                    case "decimals":  if case .u32(let v) = item.val { decimals  = Int(v) }
                    case "enabled":   if case .bool(let v) = item.val { enabled   = v }
                    case "index":     if case .u32(let v) = item.val { index     = Int(v) }
                    case "c_factor":  if case .u32(let v) = item.val { cFactor  = Decimal(v) }
                    case "l_factor":  if case .u32(let v) = item.val { lFactor  = Decimal(v) }
                    case "max_util":  if case .u32(let v) = item.val { maxUtil  = Decimal(v) }
                    case "r_base":    if case .u32(let v) = item.val { rBase    = Decimal(v) }
                    case "r_one":     if case .u32(let v) = item.val { rOne     = Decimal(v) }
                    case "r_two":     if case .u32(let v) = item.val { rTwo     = Decimal(v) }
                    case "r_three":   if case .u32(let v) = item.val { rThree   = Decimal(v) }
                    case "reactivity":if case .u32(let v) = item.val { reactivity = Decimal(v) }
                    case "supply_cap":
                        if case .i128(let v) = item.val { supplyCap = BlendParser.parseI128ToDecimal(v) }
                    case "util":      if case .u32(let v) = item.val { utilTarget = Decimal(v) }
                    default: break
                    }
                }
            }

        //------------------------------------------------------------------
        case "data":
            if case .map(let datOpt) = entry.val, let dat = datOpt {
                for item in dat {
                    guard case .symbol(let k) = item.key else { continue }
                    switch k {
                    case "b_supply":
                        if case .i128(let v) = item.val {
                            totalSupplied = BlendParser.parseI128ToDecimal(v)
                        }
                    case "d_supply":
                        if case .i128(let v) = item.val {
                            totalBorrowed = BlendParser.parseI128ToDecimal(v)
                        }
                    case "b_rate":
                        if case .i128(let v) = item.val {
                            borrowRate = BlendParser.parseI128ToDecimal(v)  // Raw fixed-point value
                        }
                    case "d_rate":
                        if case .i128(let v) = item.val {
                            dRate = BlendParser.parseI128ToDecimal(v)  // Raw fixed-point value (SCALAR_12)
                        }
                    case "backstop_credit":
                        if case .i128(let v) = item.val {
                            backstopCred = BlendParser.parseI128ToDecimal(v)  // Raw fixed-point value
                        }
                    case "ir_mod":
                        if case .i128(let v) = item.val {
                            irMod = BlendParser.parseI128ToDecimal(v)  // Raw fixed-point value
                        }
                    case "last_time":
                        if case .u64(let v) = item.val {
                            lastUpdate = Date(timeIntervalSince1970: TimeInterval(v))
                        }
                    default: break
                    }
                }
            }

        default: break
        }
    }

    // ---------------------------------------------------------------------
    // 2. Keep raw values without scaling (we'll scale at calculation time)
    // ---------------------------------------------------------------------
    // No scaling needed - we want to keep the raw fixed-point values

    // ---------------------------------------------------------------------
    // 3. Assemble and return
    // ---------------------------------------------------------------------
    guard let asset = assetHex else {
        throw BlendVaultError.unknown("Missing asset address in reserve map")
    }

    return BlendAssetData(
        assetId:        asset,
        scalar:         scalar,
        decimals:       decimals,
        enabled:        enabled,
        index:          index,
        cFactor:        cFactor,
        lFactor:        lFactor,
        maxUtil:        maxUtil,
        rBase:          rBase,
        rOne:           rOne,
        rTwo:           rTwo,
        rThree:         rThree,
        reactivity:     reactivity,
        supplyCap:      supplyCap,
        utilTarget:     utilTarget,
        totalSupplied:  totalSupplied,
        totalBorrowed:  totalBorrowed,
        borrowRate:     borrowRate,
        supplyRate:     supplyRate,
        dRate:          dRate,
        backstopCredit: backstopCred,
        irModifier:     irMod,
        lastUpdate:     lastUpdate
    )
}


extension BlendAssetData {
    var totalSuppliedUSD: Decimal {
        // Convert from raw fixed-point to human-readable before multiplying by price
        let suppliedHuman = FixedMath.toFloat(value: totalSupplied, decimals: 7)
        return suppliedHuman * pricePerToken
    }
    
    var totalBorrowedUSD: Decimal {
        // Convert from raw fixed-point to human-readable before multiplying by price
        let borrowedHuman = FixedMath.toFloat(value: totalBorrowed, decimals: 7)
        return borrowedHuman * pricePerToken
    }
    
    // Helper methods to get human-readable values
    var suppliedHuman: Decimal {
        return FixedMath.toFloat(value: totalSupplied, decimals: 7)
    }
    
    var borrowedHuman: Decimal {
        return FixedMath.toFloat(value: totalBorrowed, decimals: 7)
    }
}
