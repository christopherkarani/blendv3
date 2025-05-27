//
//  BlendServiceProtocols.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
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

/// Protocol for transaction execution and user data retrieval
protocol TransactionExecutionServiceProtocol: AnyObject {
    func deposit(amount: Decimal) async throws -> String
    func withdraw(amount: Decimal) async throws -> String
    func getUserPositions(userAddress: String) async throws -> UserPositionsResult
    func getUserEmissions(userAddress: String) async throws -> UserEmissionsResult
}

// MARK: - State Management Service

/// Protocol for centralized state management across services
protocol StateManagementServiceProtocol: AnyObject {
    var initState: Published<VaultInitState>.Publisher { get }
    var isLoading: Published<Bool>.Publisher { get }
    var error: Published<BlendVaultError?>.Publisher { get }
    
    func setInitState(_ state: VaultInitState)
    func setLoading(_ loading: Bool)
    func setError(_ error: BlendVaultError?)
    func clearError()
}

// MARK: - Data Transformation Service

/// Protocol for data parsing and transformation operations
protocol DataTransformationServiceProtocol: AnyObject {
    func parsePoolConfig(_ result: SCVal) throws -> PoolConfig
    func convertRateToAPR(_ rate: Int128PartsXDR) -> Decimal
    func transformReserveData(_ data: SCVal) throws -> ReserveData
    func calculateRealAPY(supplyRate: Decimal, borrowRate: Decimal, utilization: Decimal) -> (supply: Decimal, borrow: Decimal)
    func parseReserveList(_ result: SCVal) throws -> [String]
}

// MARK: - Diagnostics Service

/// Protocol for diagnostics, monitoring and health checks
protocol DiagnosticsServiceProtocol: AnyObject {
    func logNetworkEvent(_ event: NetworkEvent)
    func logTransactionEvent(_ event: TransactionEvent)
    func performHealthCheck() async -> HealthCheckResult
    func getPerformanceMetrics() -> PerformanceMetrics
}

// MARK: - Configuration Service

/// Protocol for configuration management across different environments
protocol ConfigurationServiceProtocol: AnyObject {
    var networkType: BlendUSDCConstants.NetworkType { get }
    var contractAddresses: ContractAddresses { get }
    var rpcEndpoint: String { get }
    
    func getRetryConfiguration() -> RetryConfiguration
    func getTimeoutConfiguration() -> TimeoutConfiguration
}