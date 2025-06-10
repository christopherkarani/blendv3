//
//  TransactionService.swift
//  Blendv3
//
//  Transaction management service
//

import Foundation
import stellarsdk
import Combine

/// Service for managing all transaction operations
//final class TransactionService: TransactionServiceProtocol {
//    
//    // MARK: - Properties
//    
//    private let networkService: NetworkServiceProtocol
//    private let validation: ValidationServiceProtocol
//    private let logger: DebugLogger
//    private let configuration: ConfigurationServiceProtocol
//    
//    // MARK: - Initialization
//    
//    init(
//        networkService: NetworkServiceProtocol,
//        validation: ValidationServiceProtocol,
//        configuration: ConfigurationServiceProtocol
//    ) {
//        self.networkService = networkService
//        self.validation = validation
//        self.configuration = configuration
//        self.logger = DebugLogger(subsystem: "com.blendv3.transaction", category: "Transaction")
//    }
//    
//    // MARK: - TransactionServiceProtocol
//    
//    func deposit(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError> {
//        logger.info("Starting deposit of \(amount) USDC")
//        
//        do {
//            // Validate input
//            try validation.validateUserInput(amount, rules: .depositAmount)
//            
//            // Build and submit transaction
//            let transactionHash = try await networkService.submitDepositTransaction(
//                amount: amount,
//                userAccount: userAccount
//            )
//            
//            logger.info("Deposit successful: \(transactionHash)")
//            return .success(transactionHash)
//        } catch {
//            let blendError = error as? BlendError ?? BlendError.unknown
//            logger.error("Deposit failed: \(blendError)")
//            return .failure(blendError)
//        }
//    }
//    
//    func withdraw(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError> {
//        logger.info("Starting withdrawal of \(amount) USDC")
//        
//        do {
//            // Validate input
//            try validation.validateUserInput(amount, rules: .withdrawAmount)
//            
//            // Build and submit transaction
//            let transactionHash = try await networkService.submitWithdrawTransaction(
//                amount: amount,
//                userAccount: userAccount
//            )
//            
//            logger.info("Withdrawal successful: \(transactionHash)")
//            return .success(transactionHash)
//        } catch {
//            let blendError = error as? BlendError ?? BlendError.withdraw("Failed")
//            logger.error("Withdrawal failed: \(blendError)")
//            return .failure(blendError)
//        }
//    }
//    
//    func borrow(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError> {
//        logger.info("Starting borrow of \(amount) USDC")
//        
//        do {
//            
//            // Build and submit transaction
//            let transactionHash = try await networkService.submitBorrowTransaction(
//                amount: amount,
//                userAccount: userAccount
//            )
//            
//            logger.info("Borrow successful: \(transactionHash)")
//            return .success(transactionHash)
//        } catch {
//            let blendError = error as? BlendError ?? BlendError.borrowError("Borrow Failed")
//            logger.error("Borrow failed: \(blendError)")
//            return .failure(blendError)
//        }
//    }
//    
//    func repay(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError> {
//        logger.info("Starting repayment of \(amount) USDC")
//        
//        do {
//            // Validate input
//          //  try validation.validateUserInput(amount, rules: .repayAmount)
//            
//            // Build and submit transaction
//            let transactionHash = try await networkService.submitRepayTransaction(
//                amount: amount,
//                userAccount: userAccount
//            )
//            
//            logger.info("Repayment successful: \(transactionHash)")
//            return .success(transactionHash)
//        } catch {
//            let blendError = error as? BlendError ?? BlendError.unknown
//            logger.error("Repayment failed: \(blendError)")
//            return .failure(blendError)
//        }
//    }
//    
//    func claimEmissions(userAccount: KeyPair) async -> Result<String, BlendError> {
//        logger.info("Starting emissions claim")
//        
//        do {
//            // Build and submit transaction
//            let transactionHash = try await networkService.submitClaimEmissionsTransaction(
//                userAccount: userAccount
//            )
//            
//            logger.info("Emissions claim successful: \(transactionHash)")
//            return .success(transactionHash)
//        } catch {
//            let blendError = error as? BlendError ?? BlendError.unknown
//            logger.error("Emissions claim failed: \(blendError)")
//            return .failure(blendError)
//        }
//    }
//    
//    // MARK: - Private Transaction Building Methods
//    
//    private func buildDepositTransaction(
//        amount: Decimal,
//        userAccount: KeyPair
//    ) async throws -> Transaction {
//        logger.debug("Building deposit transaction")
//        
//        // Get current account state
//        let sourceAccount = try await networkService.getAccount(accountId: userAccount.accountId)
//        
//        // Convert amount to stroops
//        let amountInStroops = Int64(truncating: (amount * Decimal(10_000_000)) as NSNumber)
//        
//        // Build supply operation
//        let invokeArgs = InvokeContractArgsXDR(
//            contractAddress: try SCAddressXDR(contractId: configuration.contractAddresses.poolAddress),
//            functionName: "supply",
//            args: [
//                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId)),
//                SCValXDR.address(try SCAddressXDR(contractId: configuration.contractAddresses.usdcAddress)),
//                SCValXDR.i128(Int128PartsXDR(hi: 0, lo: UInt64(amountInStroops)))
//            ]
//        )
//        
//        let supplyOp = InvokeHostFunctionOperation(
//            hostFunction: HostFunctionXDR.invokeContract(invokeArgs),
//            sourceAccountId: userAccount.accountId
//        )
//        
//        // Build transaction
//        let transaction = try Transaction(
//            sourceAccount: sourceAccount,
//            operations: [supplyOp],
//            memo: Memo.text("Blend Deposit"),
//            timeBounds: nil,
//            maxOperationFee: 100_000 // 0.01 XLM
//        )
//        
//        return transaction
//    }
//    
//    private func buildWithdrawTransaction(
//        amount: Decimal,
//        userAccount: KeyPair
//    ) async throws -> Transaction {
//        logger.debug("Building withdraw transaction")
//        
//        // Get current account state
//        let sourceAccount = try await networkService.getAccount(accountId: userAccount.accountId)
//        
//        // Convert amount to stroops
//        let amountInStroops = Int64(truncating: (amount * Decimal(10_000_000)) as NSNumber)
//        
//        // Build withdraw operation
//        let invokeArgs = InvokeContractArgsXDR(
//            contractAddress: try SCAddressXDR(contractId: configuration.contractAddresses.poolAddress),
//            functionName: "withdraw",
//            args: [
//                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId)),
//                SCValXDR.address(try SCAddressXDR(contractId: configuration.contractAddresses.usdcAddress)),
//                SCValXDR.i128(Int128PartsXDR(hi: 0, lo: UInt64(amountInStroops))),
//                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId))
//            ]
//        )
//        
//        let withdrawOp = InvokeHostFunctionOperation(
//            hostFunction: HostFunctionXDR.invokeContract(invokeArgs),
//            sourceAccountId: userAccount.accountId
//        )
//        
//        // Build transaction
//        let transaction = try Transaction(
//            sourceAccount: sourceAccount,
//            operations: [withdrawOp],
//            memo: Memo.text("Blend Withdraw"),
//            timeBounds: nil,
//            maxOperationFee: 100_000 // 0.01 XLM
//        )
//        
//        return transaction
//    }
//    
//    private func buildBorrowTransaction(
//        amount: Decimal,
//        userAccount: KeyPair
//    ) async throws -> Transaction {
//        logger.debug("Building borrow transaction")
//        
//        // Get current account state
//        let sourceAccount = try await networkService.getAccount(accountId: userAccount.accountId)
//        
//        // Convert amount to stroops
//        let amountInStroops = Int64(truncating: (amount * Decimal(10_000_000)) as NSNumber)
//        
//        // Build borrow operation
//        let invokeArgs = InvokeContractArgsXDR(
//            contractAddress: try SCAddressXDR(contractId: configuration.contractAddresses.poolAddress),
//            functionName: "borrow",
//            args: [
//                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId)),
//                SCValXDR.address(try SCAddressXDR(contractId: configuration.contractAddresses.usdcAddress)),
//                SCValXDR.i128(Int128PartsXDR(hi: 0, lo: UInt64(amountInStroops)))
//            ]
//        )
//        
//        let borrowOp = InvokeHostFunctionOperation(
//            hostFunction: HostFunctionXDR.invokeContract(invokeArgs),
//            sourceAccountId: userAccount.accountId
//        )
//        
//        // Build transaction
//        let transaction = try Transaction(
//            sourceAccount: sourceAccount,
//            operations: [borrowOp],
//            memo: Memo.text("Blend Borrow"),
//            timeBounds: nil,
//            maxOperationFee: 100_000 // 0.01 XLM
//        )
//        
//        return transaction
//    }
//    
//    private func buildRepayTransaction(
//        amount: Decimal,
//        userAccount: KeyPair
//    ) async throws -> Transaction {
//        logger.debug("Building repay transaction")
//        
//        // Get current account state
//        let sourceAccount = try await networkService.getAccount(accountId: userAccount.accountId)
//        
//        // Convert amount to stroops
//        let amountInStroops = Int64(truncating: (amount * Decimal(10_000_000)) as NSNumber)
//        
//        // Build repay operation
//        let invokeArgs = InvokeContractArgsXDR(
//            contractAddress: try SCAddressXDR(contractId: configuration.contractAddresses.poolAddress),
//            functionName: "repay",
//            args: [
//                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId)),
//                SCValXDR.address(try SCAddressXDR(contractId: configuration.contractAddresses.usdcAddress)),
//                SCValXDR.i128(Int128PartsXDR(hi: 0, lo: UInt64(amountInStroops)))
//            ]
//        )
//        
//        let repayOp = InvokeHostFunctionOperation(
//            hostFunction: HostFunctionXDR.invokeContract(invokeArgs),
//            sourceAccountId: userAccount.accountId
//        )
//        
//        // Build transaction
//        let transaction = try Transaction(
//            sourceAccount: sourceAccount,
//            operations: [repayOp],
//            memo: Memo.text("Blend Repay"),
//            timeBounds: nil,
//            maxOperationFee: 100_000 // 0.01 XLM
//        )
//        
//        return transaction
//    }
//    
//    private func buildClaimEmissionsTransaction(
//        userAccount: KeyPair
//    ) async throws -> Transaction {
//        logger.debug("Building claim emissions transaction")
//        
//        // Get current account state
//        let sourceAccount = try await networkService.getAccount(accountId: userAccount.accountId)
//        
//        // Build claim operation
//        let invokeArgs = InvokeContractArgsXDR(
//            contractAddress: try SCAddressXDR(contractId: configuration.contractAddresses.poolAddress),
//            functionName: "claim",
//            args: [
//                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId)),
//                SCValXDR.vec([
//                    SCValXDR.u32(0), // Pool ID
//                    SCValXDR.u32(1)  // Reserve ID for USDC
//                ]),
//                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId))
//            ]
//        )
//        
//        let claimOp = InvokeHostFunctionOperation(
//            hostFunction: HostFunctionXDR.invokeContract(invokeArgs),
//            sourceAccountId: userAccount.accountId
//        )
//        
//        // Build transaction
//        let transaction = try Transaction(
//            sourceAccount: sourceAccount,
//            operations: [claimOp],
//            memo: Memo.text("Blend Claim"),
//            timeBounds: nil,
//            maxOperationFee: 100_000 // 0.01 XLM
//        )
//        
//        return transaction
//    }
//    
//    // MARK: - Private Helper Methods
//    
//    private func signAndSubmitTransaction(
//        _ transaction: Transaction,
//        signers: [KeyPair]
//    ) async throws -> String {
//        logger.debug("Signing and submitting transaction")
//        
//        // Sign transaction
//        for signer in signers {
//            try transaction.sign(keyPair: signer, network: .testnet)
//        }
//        
//        // Submit transaction
//        let response = try await networkService.submitTransaction(transaction)
//        
//        // Extract transaction hash
//        let hash = response.transactionHash
//        
//        // Validate hash is not empty
//        guard !hash.isEmpty else {
//            throw BlendError.transaction(.failed)
//        }
//        
//        return hash
//    }
//}
