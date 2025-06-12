//
//  PoolConfigBuilder.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//

import Foundation
import stellarsdk



struct PoolService: PoolServiceProtocol {
    let sorobanClient: SorobanClient
    private let logger = DebugLogger(subsystem: "com.blendv3.debug", category: "Pool Service")

    
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
                minCollateral = BlendParser.parseI128ToDecimal(v)
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
}

extension PoolService {
    public func getPoolStatus() async throws  {
        do {
            let statusResult = try await sorobanClient.invokeMethod(
                name: "get_status",
                args: [],
                methodOptions: stellarsdk.MethodOptions(
                    fee: 100_000,
                    timeoutInSeconds: 30,
                    simulate: true,
                    restore: false
                )
            )
            
            logger.info("✅ Pool status retrieved: \(String(describing: statusResult))")
            

            
        } catch {
            logger.error("❌ Failed to get pool status: \(error)")
            throw BlendVaultError.networkError(error.localizedDescription)
        }
    }
}

