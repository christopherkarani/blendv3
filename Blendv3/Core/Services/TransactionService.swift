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
final class TransactionService: TransactionServiceProtocol {
    
    // MARK: - Properties
    
    private let networkService: BlendNetworkServiceProtocol
    private let errorBoundary: ErrorBoundaryServiceProtocol
    private let validation: ValidationServiceProtocol
    private let logger: DebugLogger
    private let configuration: ConfigurationServiceProtocol
    
    // MARK: - Initialization
    
    init(
        networkService: BlendNetworkServiceProtocol,
        errorBoundary: ErrorBoundaryServiceProtocol,
        validation: ValidationServiceProtocol,
        configuration: ConfigurationServiceProtocol
    ) {
        self.networkService = networkService
        self.errorBoundary = errorBoundary
        self.validation = validation
        self.configuration = configuration
        self.logger = DebugLogger(subsystem: "com.blendv3.transaction", category: "Transaction")
    }
    
    // MARK: - TransactionServiceProtocol
    
    func deposit(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError> {
        logger.info("Starting deposit of \(amount) USDC")
        
        return await errorBoundary.handleWithRetry({
            // Validate input
            try self.validation.validateUserInput(amount, rules: .depositAmount)
            
            // Build transaction
            let transaction = try await self.buildDepositTransaction(
                amount: amount,
                userAccount: userAccount
            )
            
            // Sign and submit
            let result = try await self.signAndSubmitTransaction(
                transaction,
                signers: [userAccount]
            )
            
            // Validate result
            try self.validation.validateContractResponse(result, schema: .transactionResult)
            
            self.logger.info("Deposit successful: \(result)")
            return result
        }, maxRetries: configuration.getRetryConfiguration().maxRetries)
    }
    
    func withdraw(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError> {
        logger.info("Starting withdrawal of \(amount) USDC")
        
        return await errorBoundary.handleWithRetry({
            // Validate input
            try self.validation.validateUserInput(amount, rules: ValidationRules(
                minValue: Decimal(0.01),
                maxValue: nil, // No max for withdrawals
                required: true,
                customValidators: []
            ))
            
            // Build transaction
            let transaction = try await self.buildWithdrawTransaction(
                amount: amount,
                userAccount: userAccount
            )
            
            // Sign and submit
            let result = try await self.signAndSubmitTransaction(
                transaction,
                signers: [userAccount]
            )
            
            // Validate result
            try self.validation.validateContractResponse(result, schema: .transactionResult)
            
            self.logger.info("Withdrawal successful: \(result)")
            return result
        }, maxRetries: configuration.getRetryConfiguration().maxRetries)
    }
    
    func borrow(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError> {
        logger.info("Starting borrow of \(amount) USDC")
        
        return await errorBoundary.handleWithRetry({
            // Validate input
            try self.validation.validateUserInput(amount, rules: ValidationRules(
                minValue: Decimal(1), // Minimum 1 USDC borrow
                maxValue: Decimal(100_000), // Maximum 100k USDC borrow
                required: true,
                customValidators: []
            ))
            
            // Build transaction
            let transaction = try await self.buildBorrowTransaction(
                amount: amount,
                userAccount: userAccount
            )
            
            // Sign and submit
            let result = try await self.signAndSubmitTransaction(
                transaction,
                signers: [userAccount]
            )
            
            // Validate result
            try self.validation.validateContractResponse(result, schema: .transactionResult)
            
            self.logger.info("Borrow successful: \(result)")
            return result
        }, maxRetries: configuration.getRetryConfiguration().maxRetries)
    }
    
    func repay(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError> {
        logger.info("Starting repayment of \(amount) USDC")
        
        return await errorBoundary.handleWithRetry({
            // Validate input
            try self.validation.validateUserInput(amount, rules: ValidationRules(
                minValue: Decimal(0.01),
                maxValue: nil, // No max for repayments
                required: true,
                customValidators: []
            ))
            
            // Build transaction
            let transaction = try await self.buildRepayTransaction(
                amount: amount,
                userAccount: userAccount
            )
            
            // Sign and submit
            let result = try await self.signAndSubmitTransaction(
                transaction,
                signers: [userAccount]
            )
            
            // Validate result
            try self.validation.validateContractResponse(result, schema: .transactionResult)
            
            self.logger.info("Repayment successful: \(result)")
            return result
        }, maxRetries: configuration.getRetryConfiguration().maxRetries)
    }
    
    func claimEmissions(userAccount: KeyPair) async -> Result<String, BlendError> {
        logger.info("Starting emissions claim")
        
        return await errorBoundary.handleWithRetry({
            // Build transaction
            let transaction = try await self.buildClaimEmissionsTransaction(
                userAccount: userAccount
            )
            
            // Sign and submit
            let result = try await self.signAndSubmitTransaction(
                transaction,
                signers: [userAccount]
            )
            
            // Validate result
            try self.validation.validateContractResponse(result, schema: .transactionResult)
            
            self.logger.info("Emissions claim successful: \(result)")
            return result
        }, maxRetries: configuration.getRetryConfiguration().maxRetries)
    }
    
    // MARK: - Private Transaction Building Methods
    
    private func buildDepositTransaction(
        amount: Decimal,
        userAccount: KeyPair
    ) async throws -> Transaction {
        logger.debug("Building deposit transaction")
        
        // Get current account state
        let sourceAccount = try await networkService.getAccount(accountId: userAccount.accountId)
        
        // Convert amount to stroops
        let amountInStroops = Int64(truncating: (amount * Decimal(10_000_000)) as NSNumber)
        
        // Build supply operation
        let invokeArgs = InvokeContractArgsXDR(
            contractAddress: try SCAddressXDR(contractId: configuration.contractAddresses.poolAddress),
            functionName: "supply",
            args: [
                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId)),
                SCValXDR.address(try SCAddressXDR(contractId: configuration.contractAddresses.usdcAddress)),
                SCValXDR.i128(Int128PartsXDR(hi: 0, lo: UInt64(amountInStroops)))
            ]
        )
        
        let supplyOp = InvokeHostFunctionOperation(
            hostFunction: HostFunctionXDR.invokeContract(invokeArgs),
            sourceAccountId: userAccount.accountId
        )
        
        // Build transaction
        let transaction = try Transaction(
            sourceAccount: sourceAccount,
            operations: [supplyOp],
            memo: Memo.text("Blend Deposit"),
            timeBounds: nil,
            maxOperationFee: 100_000 // 0.01 XLM
        )
        
        return transaction
    }
    
    private func buildWithdrawTransaction(
        amount: Decimal,
        userAccount: KeyPair
    ) async throws -> Transaction {
        logger.debug("Building withdraw transaction")
        
        // Get current account state
        let sourceAccount = try await networkService.getAccount(accountId: userAccount.accountId)
        
        // Convert amount to stroops
        let amountInStroops = Int64(truncating: (amount * Decimal(10_000_000)) as NSNumber)
        
        // Build withdraw operation
        let invokeArgs = InvokeContractArgsXDR(
            contractAddress: try SCAddressXDR(contractId: configuration.contractAddresses.poolAddress),
            functionName: "withdraw",
            args: [
                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId)),
                SCValXDR.address(try SCAddressXDR(contractId: configuration.contractAddresses.usdcAddress)),
                SCValXDR.i128(Int128PartsXDR(hi: 0, lo: UInt64(amountInStroops))),
                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId))
            ]
        )
        
        let withdrawOp = InvokeHostFunctionOperation(
            hostFunction: HostFunctionXDR.invokeContract(invokeArgs),
            sourceAccountId: userAccount.accountId
        )
        
        // Build transaction
        let transaction = try Transaction(
            sourceAccount: sourceAccount,
            operations: [withdrawOp],
            memo: Memo.text("Blend Withdraw"),
            timeBounds: nil,
            maxOperationFee: 100_000 // 0.01 XLM
        )
        
        return transaction
    }
    
    private func buildBorrowTransaction(
        amount: Decimal,
        userAccount: KeyPair
    ) async throws -> Transaction {
        logger.debug("Building borrow transaction")
        
        // Get current account state
        let sourceAccount = try await networkService.getAccount(accountId: userAccount.accountId)
        
        // Convert amount to stroops
        let amountInStroops = Int64(truncating: (amount * Decimal(10_000_000)) as NSNumber)
        
        // Build borrow operation
        let invokeArgs = InvokeContractArgsXDR(
            contractAddress: try SCAddressXDR(contractId: configuration.contractAddresses.poolAddress),
            functionName: "borrow",
            args: [
                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId)),
                SCValXDR.address(try SCAddressXDR(contractId: configuration.contractAddresses.usdcAddress)),
                SCValXDR.i128(Int128PartsXDR(hi: 0, lo: UInt64(amountInStroops)))
            ]
        )
        
        let borrowOp = InvokeHostFunctionOperation(
            hostFunction: HostFunctionXDR.invokeContract(invokeArgs),
            sourceAccountId: userAccount.accountId
        )
        
        // Build transaction
        let transaction = try Transaction(
            sourceAccount: sourceAccount,
            operations: [borrowOp],
            memo: Memo.text("Blend Borrow"),
            timeBounds: nil,
            maxOperationFee: 100_000 // 0.01 XLM
        )
        
        return transaction
    }
    
    private func buildRepayTransaction(
        amount: Decimal,
        userAccount: KeyPair
    ) async throws -> Transaction {
        logger.debug("Building repay transaction")
        
        // Get current account state
        let sourceAccount = try await networkService.getAccount(accountId: userAccount.accountId)
        
        // Convert amount to stroops
        let amountInStroops = Int64(truncating: (amount * Decimal(10_000_000)) as NSNumber)
        
        // Build repay operation
        let invokeArgs = InvokeContractArgsXDR(
            contractAddress: try SCAddressXDR(contractId: configuration.contractAddresses.poolAddress),
            functionName: "repay",
            args: [
                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId)),
                SCValXDR.address(try SCAddressXDR(contractId: configuration.contractAddresses.usdcAddress)),
                SCValXDR.i128(Int128PartsXDR(hi: 0, lo: UInt64(amountInStroops)))
            ]
        )
        
        let repayOp = InvokeHostFunctionOperation(
            hostFunction: HostFunctionXDR.invokeContract(invokeArgs),
            sourceAccountId: userAccount.accountId
        )
        
        // Build transaction
        let transaction = try Transaction(
            sourceAccount: sourceAccount,
            operations: [repayOp],
            memo: Memo.text("Blend Repay"),
            timeBounds: nil,
            maxOperationFee: 100_000 // 0.01 XLM
        )
        
        return transaction
    }
    
    private func buildClaimEmissionsTransaction(
        userAccount: KeyPair
    ) async throws -> Transaction {
        logger.debug("Building claim emissions transaction")
        
        // Get current account state
        let sourceAccount = try await networkService.getAccount(accountId: userAccount.accountId)
        
        // Build claim operation
        let invokeArgs = InvokeContractArgsXDR(
            contractAddress: try SCAddressXDR(contractId: configuration.contractAddresses.poolAddress),
            functionName: "claim",
            args: [
                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId)),
                SCValXDR.vec([
                    SCValXDR.u32(0), // Pool ID
                    SCValXDR.u32(1)  // Reserve ID for USDC
                ]),
                SCValXDR.address(try SCAddressXDR(accountId: userAccount.accountId))
            ]
        )
        
        let claimOp = InvokeHostFunctionOperation(
            hostFunction: HostFunctionXDR.invokeContract(invokeArgs),
            sourceAccountId: userAccount.accountId
        )
        
        // Build transaction
        let transaction = try Transaction(
            sourceAccount: sourceAccount,
            operations: [claimOp],
            memo: Memo.text("Blend Claim"),
            timeBounds: nil,
            maxOperationFee: 100_000 // 0.01 XLM
        )
        
        return transaction
    }
    
    // MARK: - Private Helper Methods
    
    private func signAndSubmitTransaction(
        _ transaction: Transaction,
        signers: [KeyPair]
    ) async throws -> String {
        logger.debug("Signing and submitting transaction")
        
        // Sign transaction
        for signer in signers {
            try transaction.sign(keyPair: signer, network: .testnet)
        }
        
        // Submit transaction
        let response = try await networkService.submitTransaction(transaction)
        
        // Extract transaction hash
        let hash = response.transactionHash
        
        // Validate hash is not empty
        guard !hash.isEmpty else {
            throw BlendError.transaction(.failed)
        }
        
        return hash
    }
} 