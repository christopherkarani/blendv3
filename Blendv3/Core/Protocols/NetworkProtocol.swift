//
//  NetworkProtocol.swift
//  Blendv3
//
//  Core protocol definitions for network operations
//

import Foundation
import Combine
import stellarsdk

/// Protocol defining network service requirements
protocol NetworkServiceProtocol {
    /// Submits a transaction to the Stellar network
    func submitTransaction(_ transaction: Transaction) async throws -> SubmitTransactionResponse
    
    /// Fetches account details from the network
    func getAccountDetails(accountId: String) async throws -> AccountResponse
    
    /// Streams account updates
    func streamAccountUpdates(accountId: String) -> AnyPublisher<AccountResponse, Error>
}

/// Protocol for Soroban contract interactions
protocol SorobanServiceProtocol {
    /// Invokes a smart contract function
    func invokeContract(
        contractId: String,
        functionName: String,
        parameters: [SCVal]
    ) async throws -> InvokeHostFunctionResponse
    
    /// Simulates a transaction before submission
    func simulateTransaction(_ transaction: Transaction) async throws -> SimulateTransactionResponse
    
    /// Gets contract data
    func getContractData(contractId: String, key: SCVal) async throws -> SCVal?
}