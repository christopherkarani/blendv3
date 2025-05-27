//
//  AccountChecker.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import stellarsdk

/// Service to check account status and requirements
public class AccountChecker {
    
    private let logger = DebugLogger(subsystem: "com.blendv3.account", category: "AccountChecker")
    private let sdk: StellarSDK
    private let network: BlendUSDCConstants.NetworkType
    
    public init(network: BlendUSDCConstants.NetworkType = .testnet) {
        self.network = network
        let horizonUrl = network == .testnet 
            ? "https://horizon-testnet.stellar.org"
            : "https://horizon.stellar.org"
        self.sdk = StellarSDK(withHorizonUrl: horizonUrl)
        
        logger.info("Initialized AccountChecker for \(network == .testnet ? "testnet" : "mainnet")")
    }
    
    /// Check if account exists and has required setup
    public func checkAccount(publicKey: String) async throws -> AccountStatus {
        let accountResponseEnum = await sdk.accounts.getAccountDetails(accountId: publicKey)
        
        switch accountResponseEnum {
        case .success(let accountResponse):
            print("🔍 DEBUG: Account loaded successfully with \(accountResponse.balances.count) balances")
            logger.info("Account exists with \(accountResponse.balances.count) balances")
            
            // Check for XLM balance
            let xlmBalance = accountResponse.balances.first { $0.assetType == AssetTypeAsString.NATIVE }
            let xlmAmount = Decimal(string: xlmBalance?.balance ?? "0") ?? 0
            print("🔍 DEBUG: XLM balance: \(xlmAmount)")
            logger.info("XLM balance: \(xlmAmount)")
            
            // Check for USDC trustline
            let usdcTrustline = accountResponse.balances.first { balance in
                balance.assetCode == "USDC" && 
                balance.assetIssuer == BlendUSDCConstants.usdcAssetIssuer
            }
            
            let hasUSDCTrustline = usdcTrustline != nil
            let usdcBalance = Decimal(string: usdcTrustline?.balance ?? "0") ?? 0
            
            print("🔍 DEBUG: USDC trustline: \(hasUSDCTrustline ? "Yes" : "No"), balance: \(usdcBalance)")
            logger.info("USDC trustline: \(hasUSDCTrustline ? "Yes" : "No"), balance: \(usdcBalance)")
            
            // Check sequence number
            logger.info("Account sequence: \(accountResponse.sequenceNumber)")
            
            return AccountStatus(
                exists: true,
                xlmBalance: xlmAmount,
                hasUSDCTrustline: hasUSDCTrustline,
                usdcBalance: usdcBalance,
                sequenceNumber: accountResponse.sequenceNumber
            )
            
        case .failure(let error):
            print("🔍 DEBUG: Horizon error: \(error)")
            logger.error("Horizon error: \(error.localizedDescription)")
            
            // Check if it's a 404 (account not found)
            if case .notFound = error {
                print("🔍 DEBUG: Account does not exist on network")
                logger.warning("Account does not exist on network")
                return AccountStatus(
                    exists: false,
                    xlmBalance: 0,
                    hasUSDCTrustline: false,
                    usdcBalance: 0,
                    sequenceNumber: 0
                )
            }
            
            throw error
        }
    }
    
    /// Create trustline for USDC if needed
    public func createUSDCTrustline(signer: BlendSigner) async throws -> String {
        logger.info("Creating USDC trustline")
        
        let keyPair = try signer.getKeyPair()
        let accountId = keyPair.accountId
        
        // Load account details
        let accountResponseEnum = await sdk.accounts.getAccountDetails(accountId: accountId)
        
        guard case .success(let sourceAccount) = accountResponseEnum else {
            if case .failure(let error) = accountResponseEnum {
                throw error
            }
            throw AccountError.trustlineCreationFailed("Failed to load account")
        }
        
        // Create USDC asset
        let usdcAsset = ChangeTrustAsset(
            type: AssetType.ASSET_TYPE_CREDIT_ALPHANUM4,
            code: "USDC",
            issuer: try KeyPair(accountId: BlendUSDCConstants.usdcAssetIssuer)
        )!
        
        // Create change trust operation
        let changeTrustOp = ChangeTrustOperation(
            sourceAccountId: accountId,
            asset: usdcAsset,
            limit: nil // No limit
        )
        
        // Build transaction
        let transaction = try Transaction(
            sourceAccount: sourceAccount,
            operations: [changeTrustOp],
            memo: Memo.none
        )
        
        // Sign transaction
        try transaction.sign(keyPair: keyPair, network: network.stellarNetwork)
        
        logger.debug("Submitting trustline transaction")
        
        // Submit transaction
        let responseEnum = await sdk.transactions.submitTransaction(transaction: transaction)
        
        switch responseEnum {
        case .success(let response):
            // Check if transaction was successful using the correct property
            let isSuccessful = response.transactionResult.code == .success || 
                              response.transactionResult.code == .feeBumpInnerSuccess
            
            if isSuccessful {
                logger.info("USDC trustline created successfully. Hash: \(response.transactionHash)")
                return response.transactionHash
            } else {
                let errorCode = response.transactionResult.code
                logger.error("Failed to create trustline: \(errorCode)")
                throw AccountError.trustlineCreationFailed("\(errorCode)")
            }
            
        case .destinationRequiresMemo(let destinationAccountId):
            logger.error("Destination requires memo: \(destinationAccountId)")
            throw AccountError.trustlineCreationFailed("Destination requires memo: \(destinationAccountId)")
            
        case .failure(let error):
            logger.error("Transaction submission failed: \(error)")
            throw error
        }
    }
}

// MARK: - Models

public struct AccountStatus {
    public let exists: Bool
    public let xlmBalance: Decimal
    public let hasUSDCTrustline: Bool
    public let usdcBalance: Decimal
    public let sequenceNumber: Int64
    
    public var needsFunding: Bool {
        return !exists || xlmBalance < 2 // Need at least 2 XLM for reserves
    }
    
    public var needsUSDCTrustline: Bool {
        return exists && !hasUSDCTrustline
    }
    
    public var isReady: Bool {
        return exists && hasUSDCTrustline && xlmBalance >= 2
    }
    
    public var statusMessage: String {
        if !exists {
            return "Account does not exist. Please fund with XLM."
        } else if xlmBalance < 2 {
            return "Insufficient XLM balance. Need at least 2 XLM."
        } else if !hasUSDCTrustline {
            return "USDC trustline not set up."
        } else {
            return "Account ready for operations."
        }
    }
}

public enum AccountError: LocalizedError {
    case trustlineCreationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .trustlineCreationFailed(let code):
            return "Failed to create USDC trustline: \(code)"
        }
    }
} 
