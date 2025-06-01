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

    // Config  (all fixed-point with 7 decimals unless noted)
    public let decimals     : Int
    public let enabled      : Bool
    public let index        : Int
    public let cFactor      : Decimal
    public let lFactor      : Decimal
    public let maxUtil      : Decimal
    public let rBase        : Decimal
    public let rOne         : Decimal
    public let rTwo         : Decimal
    public let rThree       : Decimal
    public let reactivity   : Decimal
    public let supplyCap    : Decimal
    public let utilTarget   : Decimal

    // Live data (already divided by `scalar`)
    public let totalSupplied: Decimal
    public let totalBorrowed: Decimal
    public let borrowRate   : Decimal   // APY %
    public let supplyRate   : Decimal   // APY %
    public let backstopCredit: Decimal
    public let irModifier   : Decimal
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
                    case "c_factor":  if case .u32(let v) = item.val { cFactor  = Decimal(v)/_FIXED_SCALE }
                    case "l_factor":  if case .u32(let v) = item.val { lFactor  = Decimal(v)/_FIXED_SCALE }
                    case "max_util":  if case .u32(let v) = item.val { maxUtil  = Decimal(v)/_FIXED_SCALE }
                    case "r_base":    if case .u32(let v) = item.val { rBase    = Decimal(v)/_FIXED_SCALE }
                    case "r_one":     if case .u32(let v) = item.val { rOne     = Decimal(v)/_FIXED_SCALE }
                    case "r_two":     if case .u32(let v) = item.val { rTwo     = Decimal(v)/_FIXED_SCALE }
                    case "r_three":   if case .u32(let v) = item.val { rThree   = Decimal(v)/_FIXED_SCALE }
                    case "reactivity":if case .u32(let v) = item.val { reactivity = Decimal(v)/_FIXED_SCALE }
                    case "supply_cap":
                        if case .i128(let v) = item.val { supplyCap = BlendParser.parseI128ToDecimal(v) }
                    case "util":      if case .u32(let v) = item.val { utilTarget = Decimal(v)/_FIXED_SCALE }
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
                            borrowRate = BlendParser.parseI128ToDecimal(v)/_FIXED_SCALE * 100  // → percent
                        }
                    case "d_rate":
                        if case .i128(let v) = item.val {
                            supplyRate = BlendParser.parseI128ToDecimal(v)/_FIXED_SCALE * 100
                        }
                    case "backstop_credit":
                        if case .i128(let v) = item.val {
                            backstopCred = BlendParser.parseI128ToDecimal(v)/scalar
                        }
                    case "ir_mod":
                        if case .i128(let v) = item.val {
                            irMod = BlendParser.parseI128ToDecimal(v)/_FIXED_SCALE
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
    // 2. Scale supplied & borrowed by the scalar found in the blob
    // ---------------------------------------------------------------------
    if scalar != 0 {
        totalSupplied /= scalar
        totalBorrowed /= scalar
    }

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
        backstopCredit: backstopCred,
        irModifier:     irMod,
        lastUpdate:     lastUpdate
    )
}


extension BlendAssetData {
    var totalSuppliedUSD: Decimal {
        return totalSupplied * pricePerToken
    }
    
    var totalBorrowedUSD: Decimal {
        return totalBorrowed * pricePerToken
    }
}
