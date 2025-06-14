//
//  NetworkService+TokenMetadata.swift
//  Blendv3
//
//  NetworkService extension for loading token metadata from contract instances
//
//  Usage Example:
//  ```swift
//  let networkService = NetworkService(config: config, keyPair: keyPair)
//  let metadata = try await networkService.loadTokenMetadata(contractId: "CXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
//  print("Token: \(metadata.symbol) (\(metadata.name)) - \(metadata.decimals) decimals")
//  ```

import Foundation
import stellarsdk

// MARK: - NetworkService Token Metadata Extension

extension NetworkService {
    
    /// Load token metadata from on-chain contract instance
    /// Uses the network configuration from this NetworkService instance
    /// - Parameter contractId: Contract ID string
    /// - Returns: TokenMetadata with name, symbol, decimals, and optional classic asset
    /// - Throws: BlendError.tokenMetadata for metadata-specific errors
    public func loadTokenMetadata(contractId: String) async throws -> TokenMetadata {
        BlendLogger.info("Loading token metadata for contract: \(contractId)", category: BlendLogger.network)
        
        do {
            // 1. Validate contract ID format
            guard !contractId.isEmpty else {
                throw BlendError.tokenMetadata(.invalidContractId)
            }
            
            // 2. Build the ledger key for the ContractInstance entry
            let contractAddress: SCAddressXDR
            do {
                contractAddress = try SCAddressXDR(contractId: contractId)
            } catch {
                BlendLogger.error("Invalid contract ID format: \(contractId)", category: BlendLogger.network)
                throw BlendError.tokenMetadata(.invalidContractId)
            }
            
            let instanceKey = LedgerKeyContractDataXDR(
                contract: contractAddress,
                key: .ledgerKeyContractInstance,
                durability: .persistent
            )
            let key = LedgerKeyXDR.contractData(instanceKey)
            
            // 3. Get the ledger entry using existing NetworkService method
            guard let keyXdr = key.xdrEncoded else {
                BlendLogger.error("Failed to encode ledger key for contract: \(contractId)", category: BlendLogger.network)
                throw BlendError.tokenMetadata(.invalidContractId)
            }
            

            
            let response = try await getLedgerEntries(keys: [keyXdr])
            
            guard let entryData = response.values.first as? String else {
                BlendLogger.error("No contract instance found for: \(contractId)", category: BlendLogger.network)
                throw BlendError.tokenMetadata(.noInstance)
            }
            
            // 5. Decode the ledger entry data
            let ledgerEntryData: LedgerEntryDataXDR
            do {
                ledgerEntryData = try LedgerEntryDataXDR(fromBase64: entryData)
            } catch {
                BlendLogger.error("Failed to decode ledger entry data for: \(contractId)", error: error, category: BlendLogger.network)
                throw BlendError.tokenMetadata(.malformed)
            }
            
            // 6. Extract contract data
            guard case .contractData(let contractData) = ledgerEntryData,
                  case .contractInstance(let instance) = contractData.val else {
                BlendLogger.error("Invalid contract data format for: \(contractId)", category: BlendLogger.network)
                throw BlendError.tokenMetadata(.noInstance)
            }
            
            // 7. Parse the storage map using BlendParser
            guard let storage = instance.storage else {
                BlendLogger.error("No storage found in contract instance: \(contractId)", category: BlendLogger.network)
                throw BlendError.tokenMetadata(.malformed)
            }
            
            let parser = BlendParser()
            let metadata: (name: String, symbol: String, decimals: Int)
            do {
                metadata = try parser.extractTokenMetadata(from: storage)
            } catch {
                BlendLogger.error("Failed to extract metadata from contract: \(contractId)", error: error, category: BlendLogger.network)
                throw BlendError.tokenMetadata(.malformed)
            }
            
            // 8. Derive underlying classic asset if contractExecutable == stellarAsset
            let classicAsset = try createClassicAssetIfNeeded(
                instance: instance,
                name: metadata.name,
                symbol: metadata.symbol
            )
            
            let tokenMetadata = TokenMetadata(
                name: metadata.name,
                symbol: metadata.symbol,
                decimals: metadata.decimals,
                asset: classicAsset
            )
            
            BlendLogger.info("Successfully loaded metadata for \(metadata.symbol): \(metadata.name)", category: BlendLogger.network)
            return tokenMetadata
            
        } catch let error as BlendError {
            // Re-throw BlendError as-is
            throw error
        } catch {
            // Wrap unexpected errors
            BlendLogger.error("Unexpected error loading token metadata for: \(contractId)", error: error, category: BlendLogger.network)
            throw BlendError.tokenMetadata(.malformed)
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Create classic Stellar asset if the contract is a bridge adaptor
    /// - Parameters:
    ///   - instance: Contract instance data
    ///   - name: Token name
    ///   - symbol: Token symbol
    /// - Returns: Classic Asset if this is a bridge adaptor, nil otherwise
    /// - Throws: BlendError.tokenMetadata if asset creation fails
    private func createClassicAssetIfNeeded(
        instance: SCContractInstanceXDR,
        name: String,
        symbol: String
    ) throws -> Asset? {
        
        // Check if contractExecutable == token (stellar asset)
        guard case .token = instance.executable else {
            return nil
        }
        
        // Handle native asset
        if name == "native" {
            return Asset(type: AssetType.ASSET_TYPE_NATIVE)
        }
        
        // Handle alphanumeric assets
        // Expected format: "CODE:ISSUER"
        let parts = name.split(separator: ":")
        guard parts.count == 2 else {
            BlendLogger.warning("Invalid asset name format for stellar asset: \(name)", category: BlendLogger.network)
            return nil
        }
        
        let code = String(parts[0])
        let issuerAccountId = String(parts[1])
        
        do {
            let issuerKeyPair = try KeyPair(accountId: issuerAccountId)
            let assetType = code.count <= 4 ? AssetType.ASSET_TYPE_CREDIT_ALPHANUM4 : AssetType.ASSET_TYPE_CREDIT_ALPHANUM12
            
            return Asset(type: assetType, code: code, issuer: issuerKeyPair)
        } catch {
            BlendLogger.warning("Failed to create classic asset for: \(name) - \(error.localizedDescription)", category: BlendLogger.network)
            return nil
        }
    }
} 