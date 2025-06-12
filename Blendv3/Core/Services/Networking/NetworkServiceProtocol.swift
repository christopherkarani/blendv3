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
    
    // MARK: - Initialization & Connectivity
    
    /// Initializes the network service
    /// - Throws: Errors during initialization
    func initialize() async throws
    
    /// Checks the current network connectivity state
    /// - Returns: The connection state
    func checkConnectivity() async -> ConnectionState
    
    // MARK: - Interceptors
    
    /// Adds a request interceptor to modify outgoing requests
    /// - Parameter interceptor: Closure to modify URLRequest
    func addRequestInterceptor(_ interceptor: @escaping (URLRequest) -> URLRequest)
    
    /// Adds a response interceptor to handle incoming responses
    /// - Parameter interceptor: Closure to process Data and URLResponse
    func addResponseInterceptor(_ interceptor: @escaping (Data, URLResponse) -> Void)
    
    // MARK: - Ledger Entries
    
    /// Retrieves ledger entries by keys
    /// - Parameter keys: Ledger entry keys
    /// - Returns: Dictionary of ledger entries with keys and associated data
    /// - Throws: Network errors
    func getLedgerEntries(keys: [String]) async throws -> [String: Any]
    
    // MARK: - Account
    
    /// Fetches a Stellar account
    /// - Parameter accountId: Stellar account ID
    /// - Returns: Account object
    /// - Throws: Network errors
    func getAccount(accountId: String) async throws -> Account
    
    // MARK: - Contract Simulation
    
    /// Simulates a contract function call with generic arguments and result types
    /// - Parameters:
    ///   - contractId: Contract ID to invoke
    ///   - functionName: Function name to call
    ///   - args: Function arguments conforming to Sendable
    /// - Returns: Result of the simulation as SimulationStatus with generic Result
    func simulateContractFunction<Args: Sendable, Result: Decodable>(
        contractId: String,
        functionName: String,
        args: Args
    ) async -> SimulationStatus<Result>
    
    /// Simulates a contract function call with ContractCallParams
    /// - Parameter contractCall: Contract call parameters
    /// - Returns: Result of the simulation as SimulationStatus with generic Result
    func simulateContractFunction<Result: Decodable>(
        contractCall: ContractCallParams
    ) async -> SimulationStatus<Result>
    
    // MARK: - Contract Invocation
    
    /// Invokes a contract function
    /// - Parameters:
    ///   - contractCall: Contract call parameters
    ///   - force: Whether to force execution for read-only calls
    /// - Returns: Result of the contract invocation as SCValXDR
    /// - Throws: Transaction or validation errors
    func invokeContractFunction(
        contractCall: ContractCallParams,
        force: Bool
    ) async throws -> SCValXDR
    
}
