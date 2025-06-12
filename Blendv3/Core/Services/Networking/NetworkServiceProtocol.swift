//
//  NetworkServiceProtocol.swift
//  Blendv3
//
//  Protocol for network service operations
//

import Foundation
import stellarsdk

/// Protocol for Stellar/Soroban network operations
public protocol NetworkServiceProtocol: Sendable {
    
    /// Simulates a Stellar operation
    /// - Parameter operation: Operation data to simulate
    /// - Returns: Result data
    /// - Throws: Network or simulation errors
    func simulateOperation(_ operation: Data) async throws -> Data
    
    /// Retrieves ledger entries by keys
    /// - Parameter keys: Ledger entry keys
    /// - Returns: Array of data representing ledger entries
    /// - Throws: Network errors
    func getLedgerEntries(_ keys: [String]) async throws -> [Data]
    
    /// Fetches a Stellar account
    /// - Parameter accountId: Stellar account ID
    /// - Returns: Account object
    /// - Throws: Network errors
    func getAccount(accountId: String) async throws -> Account
    
    /// Simulates a contract function call
    /// - Parameters:
    ///   - contractId: Contract ID to invoke
    ///   - functionName: Function name to call
    ///   - args: Function arguments as SCValXDR array
    ///   - sourceKeyPair: Source account keypair for signing
    /// - Returns: Result of the simulation as SimulationStatus
    func simulateContractFunction(
        contractId: String,
        functionName: String,
        args: [SCValXDR],
        sourceKeyPair: KeyPair
    ) async -> SimulationStatus<SCValXDR>
    
    /// Invokes a contract function
    /// - Parameters:
    ///   - contractId: Contract ID to invoke
    ///   - functionName: Function name to call
    ///   - args: Function arguments as SCValXDR array
    ///   - sourceKeyPair: Source account keypair for signing
    ///   - force: Whether to force execution for read-only calls
    /// - Returns: Result of the contract invocation as SCValXDR
    /// - Throws: Transaction or validation errors
    func invokeContractFunction(
        contractId: String,
        functionName: String,
        args: [SCValXDR],
        sourceKeyPair: KeyPair,
        force: Bool
    ) async throws -> SCValXDR
}

