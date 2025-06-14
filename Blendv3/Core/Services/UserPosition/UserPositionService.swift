//
//  UserPositionService.swift
//  Blendv3
//
//  Service for managing user positions and related calculations
//  Implements Swift 6.0 features including typed throws and strict concurrency checking
//

import Foundation
import stellarsdk

/// Service for managing user positions and related calculations
@MainActor
final class UserPositionService: UserPositionServiceProtocol {
    
    private let cacheService: CacheServiceProtocol
    private let networkService: NetworkServiceProtocol
    let contractID: String
    let userAccountID: String
    
    // MARK: - Cache Keys
    
    init(cacheService: CacheServiceProtocol, networkService: NetworkServiceProtocol, contractID: String, userAccountID: String) {
        self.cacheService = cacheService
        self.networkService = networkService
        self.contractID = contractID
        self.userAccountID = userAccountID
    }
    
    /// Retrieves positions data from the Blend Protocol and returns it as an array of Position structs.
    func getPositions() async throws -> [Position] {
        let arguments =  [SCValXDR.address(try SCAddressXDR(accountId: userAccountID))]
        let contractCall = ContractCallParams(contractId: contractID, functionName: "get_positions", functionArguments: arguments)
        let simulateResult: SimulationStatus<SCValXDR> = await networkService.simulateContractFunction(contractCall: contractCall)
        switch simulateResult {
        case .success(_):
            let result = try await networkService.invokeContractFunction(contractCall: contractCall, force: false)
            let decodedPositions = try BlendParser.decodePositions(from: result)
            return filterValidPositions(decodedPositions)
        case .failure(let error):
            throw error
        }
    }
    
    private func filterValidPositions(_ positions: [Position]) -> [Position] {
        positions.filter { position in
            if !position.isValid {
                print("Warning: Dropping invalid position for asset \(position.asset)")
                return false
            }
            return true
        }
    }
}


extension UserPositionService {
    
    func convertToStroops(amountString: String) -> UInt64? {
        guard let amount = Double(amountString), amount >= 0 else {
            return nil
        }
        // Ensure correct rounding
        let stroops = (amount * 10_000_000).rounded()
        guard let converted = UInt64(exactly: stroops) else {
            return nil
        }
        return converted
    }
    
    public  func submit(requestType: UInt32, amount: String, asset: String) async throws  {
        guard let depositStroops = convertToStroops(amountString: amount) else {
            throw BlendError.unknown
        }
        
        let int128Value = Int128PartsXDR(hi: 0, lo: depositStroops)
        let amountArg = SCValXDR.i128(int128Value)
        let requestTypeArg = SCValXDR.u32(requestType)
        
        // For USDC operations, we use the USDC contract address
        let requestMap = SCValXDR.map([
            SCMapEntryXDR(key: .symbol("address"), val: SCValXDR.address(try SCAddressXDR(contractId: asset))),
            SCMapEntryXDR(key: .symbol("amount"), val: amountArg),
            SCMapEntryXDR(key: .symbol("request_type"), val: requestTypeArg)
        ])
        
        let requestsVector = SCValXDR.vec([requestMap])
        let sourceAddressXDR = try SCAddressXDR(accountId: userAccountID)
        
        let functionArguments = [
            SCValXDR.address(sourceAddressXDR),
            SCValXDR.address(sourceAddressXDR),
            SCValXDR.address(sourceAddressXDR),
            requestsVector
        ]
        
    
        let contractCall = ContractCallParams(contractId: contractID, functionName: "submit", functionArguments: functionArguments)
        let simulationResult: SimulationStatus<SCValXDR> = await networkService.simulateContractFunction(contractCall: contractCall)
        
        switch simulationResult {
        case .success(_):
            let result = try await networkService.invokeContractFunction(contractCall: contractCall, force: false)
          //  print("Result of Submit: ", result)
        case .failure(let error):
            throw error
        }
    }
}

