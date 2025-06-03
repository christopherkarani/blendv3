//
//  BlendAssetService.swift
//  Blendv3
//
//  Created by Chris Karani on 30/05/2025.
//

import stellarsdk




protocol BlendAssetServiceProtocol {
    func getAssets() async throws -> [OracleAsset]
    func get(assetData: OracleAsset) async throws -> BlendAssetData
    func getAll(assets: [OracleAsset]) async throws -> [BlendAssetData]
}


struct BlendAssetService: BlendAssetServiceProtocol {
    let client: SorobanClient
    private let logger = DebugLogger(subsystem: "com.blendv3.debug", category: "Pool Service")
    
    /// Get detailed reserve data with extensive logging
    /// Lightweight wrapper around `get_reserve` that returns
    /// human‑readable amounts for a single asset.
    func get(assetData: OracleAsset) async throws -> BlendAssetData {
        // 1️⃣ Fetch the raw reserve map from the chain.
        guard case let .stellar(address) = assetData else {
            throw BlendError.assetRetrivalFailed
        }
        let rawReserve = try await client.invokeMethod(
            name: "get_reserve",
            args: [try SCValXDR.address(SCAddressXDR(contractId: address))],
            methodOptions: stellarsdk.MethodOptions(
                fee: 100_000,
                timeoutInSeconds: 30,
                simulate: true,
                restore: false
            )
        )
        
        
        return try BlendAssetData(rawReserve: rawReserve)
    }
    
    func getAll(assets: [OracleAsset]) async throws -> [BlendAssetData] {
        var assetData: [BlendAssetData] = []
        for address in assets {
            try await assetData.append(get(assetData: address))
        }
        return assetData
    }
    
//    func getAssets() async throws -> [OracleAsset] {
//        
//    }
    
    /// Retrieve All Reserve data
     public func getAssets() async throws -> [OracleAsset] {
         let result = try await client.invokeMethod(
             name: "get_reserve_list",
             args: [], // No arguments required
             methodOptions: stellarsdk.MethodOptions(
                 fee: 100_000,
                 timeoutInSeconds: 30,
                 simulate: true,
                 restore: false
             )
         )
         
         return mapReserves(result)
     }
    /// maps raw data from smart contracts to pool contract addresses
    private func mapReserves(_ reserves: SCValXDR) -> [OracleAsset] {
        guard case .vec(let optional) = reserves,
              case .some(let array) = optional else {
            logger.info("no wallets from getReservelist")
            return []
        }
        
        var assetAddresses: [OracleAsset] = []
        
        for (index, item) in array.enumerated() {
            
            if case .address(let addressXDR) = item {
                
                if let contractId = addressXDR.contractId {
                    assetAddresses.append(OracleAsset.stellar(address: contractId))
                } else if let accountId = addressXDR.accountId {
                    assetAddresses.append(OracleAsset.stellar(address: accountId))
                }
                
            } else {
                logger.warning("⚠️ Unexpected item type at index \(index): \(item)")
            }
        }
        return assetAddresses
    }
}
