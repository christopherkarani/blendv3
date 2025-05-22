//
//  SorobanService.swift
//  Blendv3
//
//  Service for Soroban smart contract interactions
//

import Foundation
import stellarsdk

/// Service responsible for Soroban smart contract operations
final class SorobanService: SorobanServiceProtocol {
    
    // MARK: - Properties
    
    private let sorobanServer: SorobanServer
    private let network: Network
    
    // MARK: - Initialization
    
    init(isTestnet: Bool = true) {
        let rpcUrl = isTestnet ? Constants.Network.testnetSorobanRPC : Constants.Network.mainnetSorobanRPC
        self.sorobanServer = SorobanServer(endpoint: rpcUrl)
        self.network = isTestnet ? .testnet : .public
    }
    
    // MARK: - SorobanServiceProtocol Implementation
    
    func invokeContract(
        contractId: String,
        functionName: String,
        parameters: [SCVal]
    ) async throws -> InvokeHostFunctionResponse {
        // Implementation will be added when we have specific contract details
        throw BlendError.contractError("Not implemented yet")
    }
    
    func simulateTransaction(_ transaction: Transaction) async throws -> SimulateTransactionResponse {
        return try await withCheckedThrowingContinuation { continuation in
            sorobanServer.simulateTransaction(transaction: transaction) { response in
                switch response {
                case .success(let result):
                    continuation.resume(returning: result)
                case .failure(let error):
                    continuation.resume(throwing: BlendError.contractError(error.localizedDescription))
                }
            }
        }
    }    
    func getContractData(contractId: String, key: SCVal) async throws -> SCVal? {
        return try await withCheckedThrowingContinuation { continuation in
            // Create ledger key for contract data
            let contractDataKey = LedgerKey.contractData(
                LedgerKeyContractData(
                    contract: try! Address(accountId: contractId),
                    key: key,
                    durability: .persistent
                )
            )
            
            sorobanServer.getLedgerEntries(base64Keys: [contractDataKey.xdrEncoded!]) { response in
                switch response {
                case .success(let result):
                    if let entry = result.entries?.first,
                       let contractData = entry.xdr {
                        // Parse the contract data
                        do {
                            let ledgerEntry = try LedgerEntryXDR(xdr: contractData)
                            if case .contractData(let data) = ledgerEntry.data {
                                continuation.resume(returning: data.val)
                            } else {
                                continuation.resume(returning: nil)
                            }
                        } catch {
                            continuation.resume(throwing: BlendError.contractError("Failed to parse contract data"))
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                case .failure(let error):
                    continuation.resume(throwing: BlendError.contractError(error.localizedDescription))
                }
            }
        }
    }
}