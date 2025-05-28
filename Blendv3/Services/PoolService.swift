//
//  PoolConfigBuilder.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//

import Foundation
import stellarsdk

protocol PoolServiceProtocol {
    func fetchPoolConfig() async throws -> PoolConfig
}

struct PoolService: PoolServiceProtocol {
    let sorobanClient: SorobanClient

    // Fetch PoolConfig from the blockchain
    func fetchPoolConfig() async throws -> PoolConfig {
        let result = try await sorobanClient.invokeMethod(
            name: "get_config",
            args: [],
            methodOptions: stellarsdk.MethodOptions(
                fee: 100_000,
                timeoutInSeconds: 30,
                simulate: true,
                restore: false
            )
        )
        
        guard case .map(let configMapOptional) = result else {
            throw BlendVaultError.invalidResponse
        }
        guard let configMap = configMapOptional else {
            throw BlendVaultError.invalidResponse
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
                oracle = addr.contractId ?? addr.accountId ?? ""
            case ("status", .u32(let v)):
                status = v
            default:
                continue
            }
        }
        
        return PoolConfig(
            backstopRate: backstopRate,
            maxPositions: maxPositions,
            minCollateral: minCollateral,
            oracle: oracle,
            status: status
        )
    }

    // Helper to convert Int128PartsXDR to Decimal
    private func parseI128ToDecimal(_ value: Int128PartsXDR) -> Decimal {
        // Convert i128 to a single 128-bit integer value
        let fullValue: Decimal
        if value.hi == 0 {
            // Simple case: only low 64 bits are used
            fullValue = Decimal(value.lo)
        } else if value.hi == -1 && (value.lo & 0x8000000000000000) != 0 {
            // Negative number in two's complement
            let signedLo = Int64(bitPattern: value.lo)
            fullValue = Decimal(signedLo)
        } else {
            // Large positive number: combine hi and lo parts
            // hi represents the upper 64 bits, lo represents the lower 64 bits
            let hiDecimal = Decimal(value.hi) * Decimal(sign: .plus, exponent: 64, significand: 1)
            let loDecimal = Decimal(value.lo)
            fullValue = hiDecimal + loDecimal
        }
        // The value from the oracle is in fixed-point format with 7 decimals
        // So we need to return the raw value as-is (it's already scaled)
        return fullValue
    }
}

//
