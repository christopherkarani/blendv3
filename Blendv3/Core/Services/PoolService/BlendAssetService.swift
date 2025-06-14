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
    let poolID: String
    let networkService: NetworkServiceProtocol
    let parser: BlendParser
    
    init(poolID: String, networkService: NetworkServiceProtocol, parser: BlendParser = BlendParser()) {
        self.poolID = poolID
        self.networkService = networkService
        self.parser = parser
    }
    private let logger = DebugLogger(subsystem: "com.blendv3.debug", category: "Pool Service")
    
    /// Get detailed reserve data with extensive logging
    /// Lightweight wrapper around `get_reserve` that returns
    /// human‑readable amounts for a single asset.
    func get(assetData: OracleAsset) async throws -> BlendAssetData {
        // 1️⃣ Fetch the raw reserve map from the chain.
        guard case let .stellar(address) = assetData else {
            throw BlendError.assetRetrivalFailed
        }
        let params = ContractCallParams(contractId: poolID, functionName: "get_reserve", functionArguments: [try SCValXDR.address(SCAddressXDR(contractId: address))])
        let result: SimulationStatus<SCValXDR> = await networkService.simulateContractFunction(contractCall: params)
        
        if case .success(let value) = result {
            return try BlendAssetData(rawReserve: value.result)
        } else {
            throw BlendError.assetRetrivalFailed
        }
    }
    
    func getAll(assets: [OracleAsset]) async throws -> [BlendAssetData] {
        var assetData: [BlendAssetData] = []
        for address in assets {
            try await assetData.append(get(assetData: address))
        }
        return assetData
    }
    
    
    /// Retrieve All Reserve data
     public func getAssets() async throws -> [OracleAsset] {
         let params = ContractCallParams(contractId: poolID, functionName: "get_reserve_list", functionArguments: [])
         let dimulationResult: SimulationStatus<SCValXDR> = await networkService.simulateContractFunction(contractCall: params)
         
         if case .success(let value) = dimulationResult {
             return parser.mapAssetReserves(value.result)
         } else {
             throw BlendError.assetRetrivalFailed
         }
     }
    
}


extension BlendParser {
    /// maps raw data from smart contracts to pool contract addresses
    public func mapAssetReserves(_ reserves: SCValXDR) -> [OracleAsset] {
        guard case .vec(let optional) = reserves,
              case .some(let array) = optional else {
            return []
        }
        
        var assetAddresses: [OracleAsset] = []
        
        for (_, item) in array.enumerated() {
            
            if case .address(let addressXDR) = item {
                
                if let contractId = addressXDR.contractId {
                    assetAddresses.append(OracleAsset.stellar(address: contractId))
                } else if let accountId = addressXDR.accountId {
                    assetAddresses.append(OracleAsset.stellar(address: accountId))
                }
                
            } else {
                
            }
        }
        return assetAddresses
    }
}
