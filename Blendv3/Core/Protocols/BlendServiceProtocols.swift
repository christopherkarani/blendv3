//
//  BlendServiceProtocols.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright 2024. All rights reserved.
//

import Foundation
import Combine
import stellarsdk

// MARK: - Network Connectivity Service

/// Protocol for network connectivity monitoring and management
protocol NetworkConnectivityServiceProtocol: AnyObject {
    var connectionState: Published<ConnectionState>.Publisher { get }
    var connectionFailures: Int { get }
    var connectionSuccesses: Int { get }
    
    func checkConnectivity() async -> ConnectionState
    func startMonitoring()
    func stopMonitoring()
}

// MARK: - Soroban Client Service

/// Protocol for Soroban client management and contract interactions
protocol SorobanClientServiceProtocol: AnyObject {
    var isInitialized: Bool { get }
    
    func initialize() async throws
    func invokeContract<T>(_ method: String, args: [Any]) async throws -> T
    func simulateTransaction(_ operation: Data) async throws -> Data
}

// MARK: - Pool Statistics Service

/// Protocol for pool statistics fetching and calculation
protocol PoolStatisticsServiceProtocol: AnyObject {
    var poolStats: Published<BlendPoolStats?>.Publisher { get }
    var comprehensiveStats: Published<ComprehensivePoolStats?>.Publisher { get }
    var truePoolStats: Published<TruePoolStats?>.Publisher { get }
    
    func refreshStats() async throws
    func getReserveList() async throws -> [String]
    func getPoolConfig() async throws -> PoolConfig
    func diagnosePoolStats() async throws
}

// MARK: - Transaction Execution Service


// MARK: - State Management Service

/// Protocol for centralized state management across services
protocol StateManagementServiceProtocol: AnyObject {
    var initStatePublisher: Published<VaultInitState>.Publisher { get }
    var isLoading: Published<Bool>.Publisher { get }
    var error: Published<BlendVaultError?>.Publisher { get }
    
    func setInitState(_ state: VaultInitState) async
    func setLoading(_ loading: Bool) async
    func setError(_ error: BlendVaultError?) async
    func clearError() async
}

// MARK: - Data Transformation Service

/// Protocol for data parsing and transformation operations
protocol DataTransformationServiceProtocol: AnyObject {
    func parsePoolConfig(_ result: SCValXDR) throws -> PoolConfig
    func convertRateToAPR(_ rate: Int128PartsXDR) -> Decimal
    func transformReserveData(_ data: SCValXDR) throws -> ReserveData
    func calculateRealAPY(supplyRate: Decimal, borrowRate: Decimal, utilization: Decimal) -> (supply: Decimal, borrow: Decimal)
    func parseReserveList(_ result: SCValXDR) throws -> [String]
}

// MARK: - Diagnostics Service


// MARK: - Configuration Service

/// Protocol for configuration management across different environments
public protocol ConfigurationServiceProtocol: AnyObject {
    var networkType: BlendUSDCConstants.NetworkType { get }
    var contractAddresses: ContractAddresses { get }
    var rpcEndpoint: String { get }
    
    func getRetryConfiguration() -> RetryConfiguration
    func getTimeoutConfiguration() -> TimeoutConfiguration
    func getCacheConfiguration() -> CacheConfiguration
}

// MARK: - Validation Service

/// Protocol for input/output validation and sanitization
protocol ValidationServiceProtocol: AnyObject {
    func validateContractResponse<T>(_ response: T, schema: ValidationSchema) throws
    func validateUserInput<T>(_ input: T, rules: ValidationRules) throws
    func sanitizeOutput<T>(_ output: T) -> T
    func validateI128(_ value: Int128PartsXDR) throws -> Decimal
}

// MARK: - Batching Service



// MARK: - Transaction Service

/// Protocol for managing all transaction operations
protocol TransactionServiceProtocol: AnyObject {
    func deposit(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError>
    func withdraw(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError>
    func borrow(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError>
    func repay(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError>
    func claimEmissions(userAccount: KeyPair) async -> Result<String, BlendError>
}

// MARK: - Network Service



// MARK: - Data Service

/// Protocol for data fetching and management
@MainActor
protocol DataServiceProtocol: AnyObject, Sendable {
    /// Fetch pool statistics
    /// - Returns: BlendPoolStats or throws BlendError
    func fetchPoolStats() async throws -> BlendPoolStats
    
    /// Fetch user position data (delegates to UserPositionService)
    /// - Parameter userId: The user's account ID
    /// - Returns: UserPositionData or throws BlendError
    func fetchUserPosition(userId: String) async throws -> UserPositionData
    
    /// Fetch price data for an asset
    /// - Parameter assetId: Asset contract ID
    /// - Returns: PriceData or throws BlendError
    func fetchPriceData(assetId: String) async throws -> PriceData
}
