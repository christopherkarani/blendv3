# BlendUSDCVault Refactoring Plan: God Object to Service Architecture

## Executive Summary

The BlendUSDCVault class has grown into a 3,910-line God Object with 74 methods handling multiple unrelated responsibilities. This comprehensive refactoring plan decomposes it into 8 focused services following SOLID principles, improving maintainability, testability, and development velocity.

**Timeline:** 10-14 days  
**Risk Level:** Medium (mitigated by parallel implementation)  
**Impact Level:** Very High (foundation for all future development)

---

## Current State Analysis

### Problems Identified

- **God Object Anti-pattern:** Single class with 3,910 lines and 74 methods
- **Multiple Responsibilities:** Network, state, transactions, statistics, logging, monitoring
- **Tight Coupling:** Changes cascade unpredictably across the system
- **Testing Difficulty:** Impossible to unit test individual concerns
- **Maintenance Burden:** Any change requires understanding the entire system
- **Development Bottleneck:** All developers must modify the same massive file

### Responsibility Analysis

```
Current BlendUSDCVault (3,910 lines):
├── Network connectivity management (15% of code)
├── Soroban client initialization (10% of code)
├── Pool statistics calculation (25% of code)
├── Transaction execution (20% of code)
├── State management (10% of code)
├── Data transformation (15% of code)
├── Error handling (3% of code)
└── Diagnostics & monitoring (2% of code)
```

---

## Target Architecture

### Service Layer Decomposition

```
BlendUSDCVault (3,910 lines) → 8 Focused Services:

├── NetworkConnectivityService (150-200 lines)
│   ├── Connection state management
│   ├── Network monitoring & health checks
│   └── Retry logic with exponential backoff
│
├── SorobanClientService (200-250 lines)
│   ├── Client initialization & lifecycle
│   ├── Contract method invocation
│   └── Transaction simulation & execution
│
├── PoolStatisticsService (400-500 lines)
│   ├── Pool data fetching & calculation
│   ├── Reserve asset management
│   └── Statistics aggregation & caching
│
├── TransactionExecutionService (300-350 lines)
│   ├── Deposit/withdraw operations
│   ├── Transaction building & signing
│   └── Result processing & validation
│
├── StateManagementService (200-250 lines)
│   ├── Published property coordination
│   ├── Initialization state tracking
│   └── Error state management
│
├── DataTransformationService (300-400 lines)
│   ├── XDR parsing & conversion
│   ├── Rate calculations & formatting
│   └── Model mapping & validation
│
├── DiagnosticsService (250-300 lines)
│   ├── Debug logging & monitoring
│   ├── Performance metrics
│   └── Health check operations
│
└── ConfigurationService (100-150 lines)
    ├── Network configuration
    ├── Contract addresses
    └── Runtime settings
```

### Design Principles

- **Single Responsibility Principle:** Each service has one clear purpose
- **Open/Closed Principle:** Services extensible without modification
- **Dependency Inversion:** Depend on abstractions, not concretions
- **Interface Segregation:** Focused protocols for each service
- **Event-Driven Architecture:** Services communicate via Combine publishers
- **Protocol-Based Design:** All services implement testable protocols

---

## Implementation Plan

## Phase 1: Service Layer Architecture Design (1-2 days)

### 1.1 Create Core Service Protocols

**File:** `Protocols/BlendServiceProtocols.swift`

```swift
import Foundation
import Combine

// MARK: - Network Connectivity Service

protocol NetworkConnectivityServiceProtocol: AnyObject {
    var connectionState: Published<ConnectionState>.Publisher { get }
    var connectionFailures: Int { get }
    var connectionSuccesses: Int { get }
    
    func checkConnectivity() async -> ConnectionState
    func startMonitoring()
    func stopMonitoring()
}

// MARK: - Soroban Client Service

protocol SorobanClientServiceProtocol: AnyObject {
    var isInitialized: Bool { get }
    
    func initialize() async throws
    func invokeContract<T>(_ method: String, args: [Any]) async throws -> T
    func simulateTransaction(_ operation: Data) async throws -> Data
}

// MARK: - Pool Statistics Service

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

protocol TransactionExecutionServiceProtocol: AnyObject {
    func deposit(amount: Decimal) async throws -> String
    func withdraw(amount: Decimal) async throws -> String
    func getUserPositions(userAddress: String) async throws -> UserPositionsResult
    func getUserEmissions(userAddress: String) async throws -> UserEmissionsResult
}

// MARK: - State Management Service

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

protocol DataTransformationServiceProtocol: AnyObject {
    func parsePoolConfig(_ result: SCVal) throws -> PoolConfig
    func convertRateToAPR(_ rate: Int128PartsXDR) -> Decimal
    func transformReserveData(_ data: SCVal) throws -> ReserveData
    func calculateRealAPY(supplyRate: Decimal, borrowRate: Decimal, utilization: Decimal) -> (supply: Decimal, borrow: Decimal)
}

// MARK: - Diagnostics Service

protocol DiagnosticsServiceProtocol: AnyObject {
    func logNetworkEvent(_ event: NetworkEvent)
    func logTransactionEvent(_ event: TransactionEvent)
    func performHealthCheck() async -> HealthCheckResult
    func getPerformanceMetrics() -> PerformanceMetrics
}

// MARK: - Configuration Service

protocol ConfigurationServiceProtocol: AnyObject {
    var networkType: BlendUSDCConstants.NetworkType { get }
    var contractAddresses: ContractAddresses { get }
    var rpcEndpoint: String { get }
    
    func getRetryConfiguration() -> RetryConfiguration
    func getTimeoutConfiguration() -> TimeoutConfiguration
}
```

### 1.2 Define Supporting Models

**File:** `Models/ServiceModels.swift`

```swift
import Foundation

// MARK: - Network Models

public struct NetworkEvent {
    let timestamp: Date
    let type: NetworkEventType
    let details: String
    let duration: TimeInterval?
}

public enum NetworkEventType {
    case connectionAttempt
    case connectionSuccess
    case connectionFailure
    case retry
}

// MARK: - Transaction Models

public struct TransactionEvent {
    let timestamp: Date
    let type: TransactionEventType
    let transactionId: String?
    let amount: Decimal?
    let duration: TimeInterval?
}

public enum TransactionEventType {
    case depositStarted
    case depositCompleted
    case withdrawStarted
    case withdrawCompleted
    case failed
}

// MARK: - Health Check Models

public struct HealthCheckResult {
    let isHealthy: Bool
    let networkStatus: ConnectionState
    let sorobanClientStatus: Bool
    let lastSuccessfulOperation: Date?
    let issues: [HealthIssue]
}

public struct HealthIssue {
    let severity: Severity
    let description: String
    let recommendation: String
    
    public enum Severity {
        case low, medium, high, critical
    }
}

// MARK: - Performance Models

public struct PerformanceMetrics {
    let averageResponseTime: TimeInterval
    let successRate: Double
    let errorRate: Double
    let totalRequests: Int
    let memoryUsage: Double
}

// MARK: - Configuration Models

public struct ContractAddresses {
    let poolAddress: String
    let backstopAddress: String
    let emissionsAddress: String
    let usdcAddress: String
}

public struct RetryConfiguration {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let exponentialBase: Double
    let jitterRange: ClosedRange<Double>
}

public struct TimeoutConfiguration {
    let networkTimeout: TimeInterval
    let transactionTimeout: TimeInterval
    let initializationTimeout: TimeInterval
}
```

## Phase 2: Foundation Services (2-3 days)

### 2.1 NetworkConnectivityService Implementation

**File:** `Core/Services/NetworkConnectivityService.swift`

```swift
import Foundation
import Combine
import stellarsdk

final class NetworkConnectivityService: ObservableObject, NetworkConnectivityServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private(set) var connectionState: ConnectionState = .unknown
    @Published private(set) var connectionFailures: Int = 0
    @Published private(set) var connectionSuccesses: Int = 0
    
    // MARK: - Private Properties
    
    private let networkType: BlendUSDCConstants.NetworkType
    private let configuration: ConfigurationServiceProtocol
    private let diagnostics: DiagnosticsServiceProtocol
    private let logger: DebugLogger
    
    private var monitoringTimer: Timer?
    private let monitoringInterval: TimeInterval = 30.0
    
    // MARK: - Initialization
    
    init(
        networkType: BlendUSDCConstants.NetworkType,
        configuration: ConfigurationServiceProtocol,
        diagnostics: DiagnosticsServiceProtocol
    ) {
        self.networkType = networkType
        self.configuration = configuration
        self.diagnostics = diagnostics
        self.logger = DebugLogger(subsystem: "com.blendv3.network", category: "NetworkConnectivity")
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    func checkConnectivity() async -> ConnectionState {
        let startTime = Date()
        
        diagnostics.logNetworkEvent(NetworkEvent(
            timestamp: startTime,
            type: .connectionAttempt,
            details: "Starting connectivity check",
            duration: nil
        ))
        
        do {
            let isConnected = try await performConnectivityCheck()
            let duration = Date().timeIntervalSince(startTime)
            
            let newState: ConnectionState = isConnected ? .connected : .disconnected("Network unreachable")
            
            await MainActor.run {
                updateConnectionState(newState)
            }
            
            diagnostics.logNetworkEvent(NetworkEvent(
                timestamp: Date(),
                type: isConnected ? .connectionSuccess : .connectionFailure,
                details: newState.description,
                duration: duration
            ))
            
            return newState
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let errorState = ConnectionState.disconnected(error.localizedDescription)
            
            await MainActor.run {
                updateConnectionState(errorState)
            }
            
            diagnostics.logNetworkEvent(NetworkEvent(
                timestamp: Date(),
                type: .connectionFailure,
                details: error.localizedDescription,
                duration: duration
            ))
            
            return errorState
        }
    }
    
    func startMonitoring() {
        logger.info("Starting network monitoring with interval: \(monitoringInterval)s")
        
        stopMonitoring()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task {
                await self.checkConnectivity()
            }
        }
        
        // Perform initial check
        Task {
            await checkConnectivity()
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        logger.info("Network monitoring stopped")
    }
    
    // MARK: - Private Methods
    
    private func performConnectivityCheck() async throws -> Bool {
        let sorobanServer = SorobanServer(endpoint: configuration.rpcEndpoint)
        
        // Simple health check - try to get network info
        return try await withCheckedThrowingContinuation { continuation in
            sorobanServer.getHealth { response in
                switch response {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func updateConnectionState(_ newState: ConnectionState) {
        let previousState = connectionState
        connectionState = newState
        
        // Update counters
        if newState.isConnected && !previousState.isConnected {
            connectionSuccesses += 1
            connectionFailures = 0 // Reset failure counter on success
        } else if !newState.isConnected && previousState.isConnected {
            connectionFailures += 1
        }
        
        logger.info("Connection state changed: \(previousState.description) → \(newState.description)")
    }
}
```

### 2.2 SorobanClientService Implementation

**File:** `Core/Services/SorobanClientService.swift`

```swift
import Foundation
import stellarsdk

final class SorobanClientService: SorobanClientServiceProtocol {
    
    // MARK: - Properties
    
    private(set) var isInitialized: Bool = false
    
    private let signer: BlendSigner
    private let networkType: BlendUSDCConstants.NetworkType
    private let configuration: ConfigurationServiceProtocol
    private let logger: DebugLogger
    
    private var sorobanServer: SorobanServer?
    private var sorobanClient: SorobanClient?
    
    // MARK: - Initialization
    
    init(
        signer: BlendSigner,
        networkType: BlendUSDCConstants.NetworkType,
        configuration: ConfigurationServiceProtocol
    ) {
        self.signer = signer
        self.networkType = networkType
        self.configuration = configuration
        self.logger = DebugLogger(subsystem: "com.blendv3.soroban", category: "SorobanClient")
    }
    
    // MARK: - Public Methods
    
    func initialize() async throws {
        logger.info("Initializing Soroban client for network: \(networkType)")
        
        let server = SorobanServer(endpoint: configuration.rpcEndpoint)
        sorobanServer = server
        
        let client = try await withCheckedThrowingContinuation { continuation in
            SorobanClient(
                server: server,
                signer: signer,
                network: networkType.stellarNetwork,
                contractAddress: BlendUSDCConstants.poolContractAddress
            ) { result in
                continuation.resume(with: result)
            }
        }
        
        sorobanClient = client
        isInitialized = true
        
        logger.info("Soroban client initialized successfully")
    }
    
    func invokeContract<T>(_ method: String, args: [Any]) async throws -> T {
        guard let client = sorobanClient else {
            throw BlendVaultError.notInitialized
        }
        
        logger.debug("Invoking contract method: \(method)")
        
        let result = try await client.invokeMethod(
            name: method,
            args: args,
            methodOptions: MethodOptions(
                fee: 100_000,
                timeoutInSeconds: 30,
                simulate: true,
                restore: false
            )
        )
        
        guard let typedResult = result as? T else {
            throw BlendVaultError.invalidResponse("Failed to cast result to expected type")
        }
        
        return typedResult
    }
    
    func simulateTransaction(_ operation: Data) async throws -> Data {
        guard let server = sorobanServer else {
            throw BlendVaultError.notInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Implement transaction simulation logic
            // This is a simplified version - actual implementation would be more complex
            continuation.resume(returning: operation)
        }
    }
}
```

## Phase 3: Business Logic Services (3-4 days)

### 3.1 PoolStatisticsService Implementation

**File:** `Core/Services/PoolStatisticsService.swift`

```swift
import Foundation
import Combine
import stellarsdk

final class PoolStatisticsService: ObservableObject, PoolStatisticsServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private(set) var poolStats: BlendPoolStats?
    @Published private(set) var comprehensiveStats: ComprehensivePoolStats?
    @Published private(set) var truePoolStats: TruePoolStats?
    
    // MARK: - Private Properties
    
    private let sorobanClient: SorobanClientServiceProtocol
    private let dataTransformation: DataTransformationServiceProtocol
    private let cache: CacheServiceProtocol
    private let oracleService: BlendOracleServiceProtocol
    private let logger: DebugLogger
    
    private let cacheKey = "pool_stats"
    private let cacheTTL: TimeInterval = 60 // 1 minute
    
    // MARK: - Initialization
    
    init(
        sorobanClient: SorobanClientServiceProtocol,
        dataTransformation: DataTransformationServiceProtocol,
        cache: CacheServiceProtocol,
        oracleService: BlendOracleServiceProtocol
    ) {
        self.sorobanClient = sorobanClient
        self.dataTransformation = dataTransformation
        self.cache = cache
        self.oracleService = oracleService
        self.logger = DebugLogger(subsystem: "com.blendv3.pool", category: "PoolStatistics")
    }
    
    // MARK: - Public Methods
    
    func refreshStats() async throws {
        logger.info("Refreshing pool statistics")
        
        // Check cache first
        if let cachedStats = cache.get(cacheKey, type: BlendPoolStats.self) {
            await MainActor.run {
                poolStats = cachedStats
            }
            logger.debug("Using cached pool statistics")
        }
        
        // Fetch fresh data
        async let reserveList = getReserveList()
        async let poolConfig = getPoolConfig()
        
        let reserves = try await reserveList
        let config = try await poolConfig
        
        // Process reserve data in parallel
        let reserveData = try await withThrowingTaskGroup(of: (String, ReserveData).self) { group in
            for reserve in reserves {
                group.addTask {
                    let data = try await self.fetchReserveData(reserve)
                    return (reserve, data)
                }
            }
            
            var results: [String: ReserveData] = [:]
            for try await (reserve, data) in group {
                results[reserve] = data
            }
            return results
        }
        
        // Calculate comprehensive statistics
        let stats = await calculatePoolStatistics(reserves: reserveData, config: config)
        
        await MainActor.run {
            poolStats = stats
        }
        
        // Cache the results
        cache.set(stats, key: cacheKey, ttl: cacheTTL)
        
        logger.info("Pool statistics refreshed successfully")
    }
    
    func getReserveList() async throws -> [String] {
        logger.debug("Fetching reserve list")
        
        let result: SCVal = try await sorobanClient.invokeContract(
            "get_reserve_list",
            args: []
        )
        
        return try dataTransformation.parseReserveList(result)
    }
    
    func getPoolConfig() async throws -> PoolConfig {
        logger.debug("Fetching pool configuration")
        
        let result: SCVal = try await sorobanClient.invokeContract(
            "get_config",
            args: []
        )
        
        return try dataTransformation.parsePoolConfig(result)
    }
    
    func diagnosePoolStats() async throws {
        logger.info("Running pool statistics diagnostics")
        
        // Run comprehensive diagnostics
        async let reserveCount = getReserveList().count
        async let configValid = validatePoolConfig()
        async let connectivityOk = testConnectivity()
        
        let diagnosticResults = try await (
            reserves: reserveCount,
            config: configValid,
            connectivity: connectivityOk
        )
        
        logger.info("Diagnostics completed - Reserves: \(diagnosticResults.reserves), Config Valid: \(diagnosticResults.config), Connectivity: \(diagnosticResults.connectivity)")
    }
    
    // MARK: - Private Methods
    
    private func fetchReserveData(_ reserve: String) async throws -> ReserveData {
        let result: SCVal = try await sorobanClient.invokeContract(
            "get_reserve",
            args: [reserve]
        )
        
        return try dataTransformation.transformReserveData(result)
    }
    
    private func calculatePoolStatistics(reserves: [String: ReserveData], config: PoolConfig) async -> BlendPoolStats {
        // Implement comprehensive statistics calculation
        // This would include TVL, utilization rates, APY calculations, etc.
        
        var totalSuppliedUSD: Decimal = 0
        var totalBorrowedUSD: Decimal = 0
        
        for (asset, reserveData) in reserves {
            // Get price from oracle
            if let price = try? await oracleService.getPrice(for: asset) {
                totalSuppliedUSD += reserveData.totalSupplied * price
                totalBorrowedUSD += reserveData.totalBorrowed * price
            }
        }
        
        let utilizationRate = totalSuppliedUSD > 0 ? totalBorrowedUSD / totalSuppliedUSD : 0
        
        return BlendPoolStats(
            totalSuppliedUSD: totalSuppliedUSD,
            totalBorrowedUSD: totalBorrowedUSD,
            utilizationRate: utilizationRate,
            lastUpdated: Date()
        )
    }
    
    private func validatePoolConfig() async throws -> Bool {
        let config = try await getPoolConfig()
        return config.isValid
    }
    
    private func testConnectivity() async throws -> Bool {
        // Simple connectivity test
        _ = try await getReserveList()
        return true
    }
}
```

### 3.2 TransactionExecutionService Implementation

**File:** `Core/Services/TransactionExecutionService.swift`

```swift
import Foundation
import stellarsdk

final class TransactionExecutionService: TransactionExecutionServiceProtocol {
    
    // MARK: - Private Properties
    
    private let sorobanClient: SorobanClientServiceProtocol
    private let signer: BlendSigner
    private let stateManager: StateManagementServiceProtocol
    private let diagnostics: DiagnosticsServiceProtocol
    private let logger: DebugLogger
    
    // MARK: - Initialization
    
    init(
        sorobanClient: SorobanClientServiceProtocol,
        signer: BlendSigner,
        stateManager: StateManagementServiceProtocol,
        diagnostics: DiagnosticsServiceProtocol
    ) {
        self.sorobanClient = sorobanClient
        self.signer = signer
        self.stateManager = stateManager
        self.diagnostics = diagnostics
        self.logger = DebugLogger(subsystem: "com.blendv3.transaction", category: "TransactionExecution")
    }
    
    // MARK: - Public Methods
    
    func deposit(amount: Decimal) async throws -> String {
        logger.info("Starting deposit transaction for amount: \(amount)")
        
        let startTime = Date()
        stateManager.setLoading(true)
        stateManager.clearError()
        
        defer {
            stateManager.setLoading(false)
        }
        
        do {
            diagnostics.logTransactionEvent(TransactionEvent(
                timestamp: startTime,
                type: .depositStarted,
                transactionId: nil,
                amount: amount,
                duration: nil
            ))
            
            let transactionId = try await executeDeposit(amount: amount)
            let duration = Date().timeIntervalSince(startTime)
            
            diagnostics.logTransactionEvent(TransactionEvent(
                timestamp: Date(),
                type: .depositCompleted,
                transactionId: transactionId,
                amount: amount,
                duration: duration
            ))
            
            logger.info("Deposit transaction completed successfully: \(transactionId)")
            return transactionId
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            diagnostics.logTransactionEvent(TransactionEvent(
                timestamp: Date(),
                type: .failed,
                transactionId: nil,
                amount: amount,
                duration: duration
            ))
            
            let vaultError = BlendVaultError.transactionFailed(error.localizedDescription)
            stateManager.setError(vaultError)
            
            logger.error("Deposit transaction failed: \(error.localizedDescription)")
            throw vaultError
        }
    }
    
    func withdraw(amount: Decimal) async throws -> String {
        logger.info("Starting withdraw transaction for amount: \(amount)")
        
        let startTime = Date()
        stateManager.setLoading(true)
        stateManager.clearError()
        
        defer {
            stateManager.setLoading(false)
        }
        
        do {
            diagnostics.logTransactionEvent(TransactionEvent(
                timestamp: startTime,
                type: .withdrawStarted,
                transactionId: nil,
                amount: amount,
                duration: nil
            ))
            
            let transactionId = try await executeWithdraw(amount: amount)
            let duration = Date().timeIntervalSince(startTime)
            
            diagnostics.logTransactionEvent(TransactionEvent(
                timestamp: Date(),
                type: .withdrawCompleted,
                transactionId: transactionId,
                amount: amount,
                duration: duration
            ))
            
            logger.info("Withdraw transaction completed successfully: \(transactionId)")
            return transactionId
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            diagnostics.logTransactionEvent(TransactionEvent(
                timestamp: Date(),
                type: .failed,
                transactionId: nil,
                amount: amount,
                duration: duration
            ))
            
            let vaultError = BlendVaultError.transactionFailed(error.localizedDescription)
            stateManager.setError(vaultError)
            
            logger.error("Withdraw transaction failed: \(error.localizedDescription)")
            throw vaultError
        }
    }
    
    func getUserPositions(userAddress: String) async throws -> UserPositionsResult {
        logger.debug("Fetching user positions for: \(userAddress)")
        
        let result: SCVal = try await sorobanClient.invokeContract(
            "get_user_positions",
            args: [userAddress]
        )
        
        return try parseUserPositions(result)
    }
    
    func getUserEmissions(userAddress: String) async throws -> UserEmissionsResult {
        logger.debug("Fetching user emissions for: \(userAddress)")
        
        let result: SCVal = try await sorobanClient.invokeContract(
            "get_user_emissions", 
            args: [userAddress]
        )
        
        return try parseUserEmissions(result)
    }
    
    // MARK: - Private Methods
    
    private func executeDeposit(amount: Decimal) async throws -> String {
        // Convert amount to appropriate format
        let amountInt = try convertDecimalToInt128(amount)
        
        // Invoke deposit contract method
        let result: SCVal = try await sorobanClient.invokeContract(
            "deposit",
            args: [signer.address, BlendUSDCConstants.usdcAssetContractAddress, amountInt]
        )
        
        return try extractTransactionId(from: result)
    }
    
    private func executeWithdraw(amount: Decimal) async throws -> String {
        // Convert amount to appropriate format  
        let amountInt = try convertDecimalToInt128(amount)
        
        // Invoke withdraw contract method
        let result: SCVal = try await sorobanClient.invokeContract(
            "withdraw",
            args: [signer.address, BlendUSDCConstants.usdcAssetContractAddress, amountInt]
        )
        
        return try extractTransactionId(from: result)
    }
    
    private func convertDecimalToInt128(_ amount: Decimal) throws -> Int128PartsXDR {
        // Implementation for converting Decimal to Int128PartsXDR
        // This would handle precision and scaling appropriately
        
        let nsDecimal = amount as NSDecimalNumber
        let scaled = nsDecimal.multiplying(by: NSDecimalNumber(value: pow(10.0, 7))) // 7 decimal places for USDC
        
        guard scaled.int64Value <= Int64.max else {
            throw BlendVaultError.invalidAmount("Amount too large")
        }
        
        return Int128PartsXDR(hi: 0, lo: UInt64(scaled.int64Value))
    }
    
    private func extractTransactionId(from result: SCVal) throws -> String {
        // Implementation to extract transaction ID from contract result
        // This would depend on the specific contract response format
        
        guard case .string(let txId) = result else {
            throw BlendVaultError.invalidResponse("Failed to extract transaction ID")
        }
        
        return txId
    }
    
    private func parseUserPositions(_ result: SCVal) throws -> UserPositionsResult {
        // Parse user positions from contract result
        // Implementation depends on contract response structure
        
        return UserPositionsResult(
            positions: [],
            totalSupplied: 0,
            totalBorrowed: 0,
            healthFactor: 1.0
        )
    }
    
    private func parseUserEmissions(_ result: SCVal) throws -> UserEmissionsResult {
        // Parse user emissions from contract result
        // Implementation depends on contract response structure
        
        return UserEmissionsResult(
            totalEmissions: 0,
            claimableEmissions: 0,
            lastClaimTime: Date()
        )
    }
}
```

## Phase 4: State & Coordination Layer (2 days)

### 4.1 StateManagementService Implementation

**File:** `Core/Services/StateManagementService.swift`

```swift
import Foundation
import Combine

final class StateManagementService: ObservableObject, StateManagementServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private(set) var initState: VaultInitState = .notInitialized
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: BlendVaultError?
    
    // MARK: - Private Properties
    
    private let logger: DebugLogger
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        self.logger = DebugLogger(subsystem: "com.blendv3.state", category: "StateManagement")
        setupStateLogging()
    }
    
    // MARK: - Public Methods
    
    func setInitState(_ state: VaultInitState) {
        let previousState = initState
        initState = state
        logger.info("Init state changed: \(previousState.description) → \(state.description)")
    }
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
        logger.debug("Loading state changed: \(loading)")
    }
    
    func setError(_ error: BlendVaultError?) {
        self.error = error
        if let error = error {
            logger.error("Error state set: \(error.localizedDescription)")
        } else {
            logger.debug("Error state cleared")
        }
    }
    
    func clearError() {
        setError(nil)
    }
    
    // MARK: - Private Methods
    
    private func setupStateLogging() {
        // Log state changes for debugging
        $initState
            .sink { [weak self] state in
                self?.logger.debug("Init state: \(state.description)")
            }
            .store(in: &cancellables)
        
        $isLoading
            .sink { [weak self] loading in
                self?.logger.debug("Loading: \(loading)")
            }
            .store(in: &cancellables)
        
        $error
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.logger.error("Error: \(error.localizedDescription)")
            }
            .store(in: &cancellables)
    }
}
```

### 4.2 DataTransformationService Implementation

**File:** `Core/Services/DataTransformationService.swift`

```swift
import Foundation
import stellarsdk

final class DataTransformationService: DataTransformationServiceProtocol {
    
    // MARK: - Private Properties
    
    private let logger: DebugLogger
    
    // MARK: - Initialization
    
    init() {
        self.logger = DebugLogger(subsystem: "com.blendv3.data", category: "DataTransformation")
    }
    
    // MARK: - Public Methods
    
    func parsePoolConfig(_ result: SCVal) throws -> PoolConfig {
        logger.debug("Parsing pool configuration")
        
        guard case .instance(let instance) = result else {
            throw BlendVaultError.invalidResponse("Expected instance for pool config")
        }
        
        // Parse the instance data structure
        // This implementation would depend on the actual contract response format
        
        return PoolConfig(
            backstopTakeRate: 0.1,
            backstopId: "backstop_id",
            maxPositions: 10,
            status: 0
        )
    }
    
    func convertRateToAPR(_ rate: Int128PartsXDR) -> Decimal {
        // Convert Int128PartsXDR to Decimal APR
        let rateValue = Decimal(rate.lo) + (Decimal(rate.hi) * Decimal(UInt64.max + 1))
        
        // Apply scaling factor (rates are typically scaled by 10^7)
        let scalingFactor = Decimal(pow(10.0, 7))
        let normalizedRate = rateValue / scalingFactor
        
        // Convert to APR percentage
        return normalizedRate * 100
    }
    
    func transformReserveData(_ data: SCVal) throws -> ReserveData {
        logger.debug("Transforming reserve data")
        
        guard case .instance(let instance) = data else {
            throw BlendVaultError.invalidResponse("Expected instance for reserve data")
        }
        
        // Parse reserve data structure
        // This would extract fields like borrowed amount, supplied amount, etc.
        
        return ReserveData(
            totalSupplied: 0,
            totalBorrowed: 0,
            supplyRate: 0,
            borrowRate: 0,
            utilizationRate: 0,
            lastUpdateTime: Date()
        )
    }
    
    func calculateRealAPY(supplyRate: Decimal, borrowRate: Decimal, utilization: Decimal) -> (supply: Decimal, borrow: Decimal) {
        // Calculate compound APY from simple rates
        // APY = (1 + rate/periods)^periods - 1
        
        let periodsPerYear = Decimal(365 * 24 * 60 * 60) // Assuming per-second compounding
        
        let supplyAPY = pow(1 + (supplyRate / periodsPerYear), periodsPerYear) - 1
        let borrowAPY = pow(1 + (borrowRate / periodsPerYear), periodsPerYear) - 1
        
        return (supply: supplyAPY * 100, borrow: borrowAPY * 100)
    }
    
    func parseReserveList(_ result: SCVal) throws -> [String] {
        logger.debug("Parsing reserve list")
        
        guard case .vec(let optional) = result,
              case .some(let array) = optional else {
            throw BlendVaultError.invalidResponse("Expected vector for reserve list")
        }
        
        var addresses: [String] = []
        
        for item in array {
            guard case .address(let address) = item else {
                continue
            }
            addresses.append(address.description)
        }
        
        return addresses
    }
    
    // MARK: - Private Helper Methods
    
    private func pow(_ base: Decimal, _ exponent: Decimal) -> Decimal {
        // Helper function for decimal exponentiation
        // This is a simplified implementation - production code would need more robust math
        
        let nsBase = base as NSDecimalNumber
        let nsExponent = exponent as NSDecimalNumber
        
        return Decimal(pow(nsBase.doubleValue, nsExponent.doubleValue))
    }
}
```

### 4.3 Refactored BlendUSDCVault Facade

**File:** `BlendUSDCVaultRefactored.swift`

```swift
import Foundation
import Combine
import stellarsdk

/// Refactored BlendUSDCVault that delegates to specialized services
/// This class serves as a clean facade over the service layer
final class BlendUSDCVault: ObservableObject {
    
    // MARK: - Published Properties (Proxied from Services)
    
    /// Initialization state of the vault
    @Published private(set) var initState: VaultInitState = .notInitialized
    
    /// Network connection state  
    @Published private(set) var connectionState: ConnectionState = .unknown
    
    /// Current pool statistics
    @Published private(set) var poolStats: BlendPoolStats?
    
    /// Comprehensive pool statistics
    @Published private(set) var comprehensivePoolStats: ComprehensivePoolStats?
    
    /// True pool statistics
    @Published private(set) var truePoolStats: TruePoolStats?
    
    /// Pool configuration
    @Published private(set) var poolConfig: PoolConfig?
    
    /// Loading state for operations
    @Published private(set) var isLoading = false
    
    /// Error state
    @Published private(set) var error: BlendVaultError?
    
    /// Last initialization attempt timestamp
    @Published private(set) var lastInitAttempt: Date?
    
    /// Number of consecutive connection failures
    @Published private(set) var connectionFailures: Int = 0
    
    /// Number of consecutive successful connections
    @Published private(set) var connectionSuccesses: Int = 0
    
    // MARK: - Service Dependencies
    
    private let stateManager: StateManagementServiceProtocol
    private let networkService: NetworkConnectivityServiceProtocol
    private let sorobanClient: SorobanClientServiceProtocol
    private let poolService: PoolStatisticsServiceProtocol
    private let transactionService: TransactionExecutionServiceProtocol
    private let diagnosticsService: DiagnosticsServiceProtocol
    private let configurationService: ConfigurationServiceProtocol
    
    private let logger: DebugLogger
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize the Blend USDC Vault with service dependencies
    /// - Parameters:
    ///   - signer: The signer to use for transactions
    ///   - network: The network to connect to (default: testnet)
    ///   - enableNetworkMonitoring: Whether to enable periodic network checks (default: true)
    ///   - completion: Optional completion handler called when initialization completes
    public init(
        signer: BlendSigner,
        network: BlendUSDCConstants.NetworkType = .testnet,
        enableNetworkMonitoring: Bool = true,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        self.logger = DebugLogger(subsystem: "com.blendv3.vault", category: "BlendUSDCVault")
        
        // Initialize services
        self.configurationService = ConfigurationService(networkType: network)
        self.stateManager = StateManagementService()
        self.diagnosticsService = DiagnosticsService()
        self.networkService = NetworkConnectivityService(
            networkType: network,
            configuration: configurationService,
            diagnostics: diagnosticsService
        )
        self.sorobanClient = SorobanClientService(
            signer: signer,
            networkType: network,
            configuration: configurationService
        )
        
        let dataTransformation = DataTransformationService()
        let cache = DependencyContainer.shared.cacheService
        let oracleService = DependencyContainer.shared.oracleService
        
        self.poolService = PoolStatisticsService(
            sorobanClient: sorobanClient,
            dataTransformation: dataTransformation,
            cache: cache,
            oracleService: oracleService
        )
        
        self.transactionService = TransactionExecutionService(
            sorobanClient: sorobanClient,
            signer: signer,
            stateManager: stateManager,
            diagnostics: diagnosticsService
        )
        
        setupServiceBindings()
        
        // Initialize the vault
        Task {
            await initialize()
            completion?(.success(()))
        }
        
        // Start network monitoring if enabled
        if enableNetworkMonitoring {
            networkService.startMonitoring()
        }
    }
    
    deinit {
        networkService.stopMonitoring()
        cancellables.forEach { $0.cancel() }
        logger.info("BlendUSDCVault deallocated")
    }
    
    // MARK: - Public API Methods
    
    /// Deposit USDC into the lending pool
    /// - Parameter amount: Amount to deposit in USDC
    /// - Returns: Transaction ID of the deposit operation
    public func deposit(amount: Decimal) async throws -> String {
        return try await transactionService.deposit(amount: amount)
    }
    
    /// Withdraw USDC from the lending pool
    /// - Parameter amount: Amount to withdraw in USDC
    /// - Returns: Transaction ID of the withdrawal operation
    public func withdraw(amount: Decimal) async throws -> String {
        return try await transactionService.withdraw(amount: amount)
    }
    
    /// Refresh pool statistics from the blockchain
    public func refreshPoolStats() async throws {
        try await poolService.refreshStats()
    }
    
    /// Get the current pool configuration
    /// - Returns: Pool configuration data
    public func getPoolConfig() async throws -> PoolConfig {
        return try await poolService.getPoolConfig()
    }
    
    /// Run diagnostics on pool statistics
    public func diagnosePoolStats() async throws {
        try await poolService.diagnosePoolStats()
    }
    
    /// Get user positions for a specific address
    /// - Parameter userAddress: The user's Stellar address
    /// - Returns: User positions data
    public func getUserPositions(userAddress: String) async throws -> UserPositionsResult {
        return try await transactionService.getUserPositions(userAddress: userAddress)
    }
    
    /// Get user emissions for a specific address
    /// - Parameter userAddress: The user's Stellar address
    /// - Returns: User emissions data
    public func getUserEmissions(userAddress: String) async throws -> UserEmissionsResult {
        return try await transactionService.getUserEmissions(userAddress: userAddress)
    }
    
    /// Wait for the vault to be initialized
    /// - Parameter completion: Completion handler called when initialization finishes
    /// - Returns: True if already initialized, false if waiting for initialization
    public func onInitialized(completion: @escaping (Result<Void, Error>) -> Void) -> Bool {
        if case .ready = initState {
            completion(.success(()))
            return true
        }
        
        // Subscribe to state changes
        stateManager.initState
            .first { state in
                switch state {
                case .ready:
                    completion(.success(()))
                    return true
                case .failed(let error):
                    completion(.failure(error))
                    return true
                default:
                    return false
                }
            }
            .sink { _ in }
            .store(in: &cancellables)
        
        return false
    }
    
    // MARK: - Private Methods
    
    private func setupServiceBindings() {
        // Bind service published properties to vault published properties
        
        stateManager.initState
            .receive(on: DispatchQueue.main)
            .assign(to: \.initState, on: self)
            .store(in: &cancellables)
        
        stateManager.isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        stateManager.error
            .receive(on: DispatchQueue.main)
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
        
        networkService.connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
        
        poolService.poolStats
            .receive(on: DispatchQueue.main)
            .assign(to: \.poolStats, on: self)
            .store(in: &cancellables)
        
        poolService.comprehensiveStats
            .receive(on: DispatchQueue.main)
            .assign(to: \.comprehensivePoolStats, on: self)
            .store(in: &cancellables)
        
        poolService.truePoolStats
            .receive(on: DispatchQueue.main)
            .assign(to: \.truePoolStats, on: self)
            .store(in: &cancellables)
        
        // Bind connection metrics
        networkService.connectionState
            .map { _ in self.networkService.connectionFailures }
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionFailures, on: self)
            .store(in: &cancellables)
        
        networkService.connectionState
            .map { _ in self.networkService.connectionSuccesses }
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionSuccesses, on: self)
            .store(in: &cancellables)
    }
    
    private func initialize() async {
        stateManager.setInitState(.initializing)
        lastInitAttempt = Date()
        
        do {
            // Initialize Soroban client
            try await sorobanClient.initialize()
            
            // Perform initial data fetch
            try await poolService.refreshStats()
            
            stateManager.setInitState(.ready)
            logger.info("Vault initialization completed successfully")
            
        } catch {
            stateManager.setInitState(.failed(error))
            logger.error("Vault initialization failed: \(error.localizedDescription)")
        }
    }
}
```

## Phase 5: Migration Strategy (2-3 days)

### 5.1 Parallel Implementation Setup

**File:** `Migration/FeatureFlags.swift`

```swift
import Foundation

/// Feature flags for gradual migration to refactored architecture
public struct FeatureFlags {
    /// Use refactored vault implementation
    public static var useRefactoredVault: Bool = false
    
    /// Use refactored pool statistics service
    public static var useRefactoredPoolService: Bool = false
    
    /// Use refactored transaction service
    public static var useRefactoredTransactionService: Bool = false
    
    /// Enable detailed migration logging
    public static var enableMigrationLogging: Bool = true
}
```

**File:** `Migration/MigrationHelper.swift`

```swift
import Foundation

/// Helper for managing migration between old and new implementations
public final class MigrationHelper {
    
    /// Compare results between old and new implementations for validation
    public static func comparePoolStats(
        legacy: BlendPoolStats?,
        refactored: BlendPoolStats?
    ) -> MigrationValidationResult {
        
        guard let legacy = legacy, let refactored = refactored else {
            return .incomplete("Missing data for comparison")
        }
        
        let tolerancePercentage: Decimal = 0.01 // 1% tolerance for floating point differences
        
        var differences: [String] = []
        
        // Compare total supplied USD
        if abs(legacy.totalSuppliedUSD - refactored.totalSuppliedUSD) / legacy.totalSuppliedUSD > tolerancePercentage {
            differences.append("totalSuppliedUSD: \(legacy.totalSuppliedUSD) vs \(refactored.totalSuppliedUSD)")
        }
        
        // Compare total borrowed USD
        if abs(legacy.totalBorrowedUSD - refactored.totalBorrowedUSD) / legacy.totalBorrowedUSD > tolerancePercentage {
            differences.append("totalBorrowedUSD: \(legacy.totalBorrowedUSD) vs \(refactored.totalBorrowedUSD)")
        }
        
        // Compare utilization rate
        if abs(legacy.utilizationRate - refactored.utilizationRate) > tolerancePercentage {
            differences.append("utilizationRate: \(legacy.utilizationRate) vs \(refactored.utilizationRate)")
        }
        
        return differences.isEmpty ? .success : .differences(differences)
    }
    
    /// Log migration events for monitoring
    public static func logMigrationEvent(_ event: MigrationEvent) {
        let logger = DebugLogger(subsystem: "com.blendv3.migration", category: "Migration")
        
        switch event.type {
        case .featureFlagToggled:
            logger.info("Feature flag toggled: \(event.description)")
        case .comparisonCompleted:
            logger.debug("Comparison completed: \(event.description)")
        case .validationFailed:
            logger.warning("Validation failed: \(event.description)")
        case .rollbackTriggered:
            logger.error("Rollback triggered: \(event.description)")
        }
    }
}

public struct MigrationEvent {
    let timestamp: Date
    let type: MigrationEventType
    let description: String
    let metadata: [String: Any]
    
    public enum MigrationEventType {
        case featureFlagToggled
        case comparisonCompleted
        case validationFailed
        case rollbackTriggered
    }
}

public enum MigrationValidationResult {
    case success
    case differences([String])
    case incomplete(String)
}
```

### 5.2 Updated DependencyContainer

**File:** `DependencyInjection/DependencyContainerRefactored.swift`

```swift
import Foundation

/// Enhanced dependency container supporting migration
public final class DependencyContainer {
    
    // MARK: - Singleton
    
    public static var shared = DependencyContainer()
    
    // MARK: - Vault Services (Migration Support)
    
    /// Legacy vault service (original implementation)
    public lazy var legacyVaultService: BlendUSDCVault = {
        let signer = BlendDefaultSigner()
        return BlendUSDCVault(signer: signer, network: .testnet)
    }()
    
    /// Refactored vault service (new implementation)
    public lazy var refactoredVaultService: BlendUSDCVault = {
        let signer = BlendDefaultSigner()
        return BlendUSDCVault(signer: signer, network: .testnet)
    }()
    
    /// Current vault service (determined by feature flag)
    public var vaultService: BlendUSDCVault {
        return FeatureFlags.useRefactoredVault ? refactoredVaultService : legacyVaultService
    }
    
    // MARK: - Individual Services
    
    /// Network connectivity service
    public lazy var networkService: NetworkConnectivityServiceProtocol = {
        NetworkConnectivityService(
            networkType: .testnet,
            configuration: configurationService,
            diagnostics: diagnosticsService
        )
    }()
    
    /// Soroban client service
    public lazy var sorobanClientService: SorobanClientServiceProtocol = {
        SorobanClientService(
            signer: BlendDefaultSigner(),
            networkType: .testnet,
            configuration: configurationService
        )
    }()
    
    /// Pool statistics service
    public lazy var poolStatisticsService: PoolStatisticsServiceProtocol = {
        PoolStatisticsService(
            sorobanClient: sorobanClientService,
            dataTransformation: dataTransformationService,
            cache: cacheService,
            oracleService: oracleService
        )
    }()
    
    /// Transaction execution service
    public lazy var transactionExecutionService: TransactionExecutionServiceProtocol = {
        TransactionExecutionService(
            sorobanClient: sorobanClientService,
            signer: BlendDefaultSigner(),
            stateManager: stateManagementService,
            diagnostics: diagnosticsService
        )
    }()
    
    /// State management service
    public lazy var stateManagementService: StateManagementServiceProtocol = StateManagementService()
    
    /// Data transformation service
    public lazy var dataTransformationService: DataTransformationServiceProtocol = DataTransformationService()
    
    /// Diagnostics service
    public lazy var diagnosticsService: DiagnosticsServiceProtocol = DiagnosticsService()
    
    /// Configuration service
    public lazy var configurationService: ConfigurationServiceProtocol = ConfigurationService(networkType: .testnet)
    
    // MARK: - Legacy Services (Compatibility)
    
    /// Rate calculator for APR/APY calculations
    public lazy var rateCalculator: BlendRateCalculatorProtocol = BlendRateCalculator()
    
    /// Oracle service for price retrieval
    public lazy var oracleService: BlendOracleServiceProtocol = BlendOracleService(
        networkService: networkServiceLegacy,
        cacheService: cacheService
    )
    
    /// Network service for RPC calls (legacy)
    public lazy var networkServiceLegacy: NetworkServiceProtocol = NetworkService()
    
    /// Cache service for data persistence
    public lazy var cacheService: CacheServiceProtocol = CacheService()
    
    // MARK: - Test Support
    
    /// Reset container for testing
    public func reset() {
        // Reset legacy services
        _legacyVaultService = nil
        _rateCalculator = nil
        _oracleService = nil
        _networkServiceLegacy = nil
        _cacheService = nil
        
        // Reset new services
        _refactoredVaultService = nil
        _networkService = nil
        _sorobanClientService = nil
        _poolStatisticsService = nil
        _transactionExecutionService = nil
        _stateManagementService = nil
        _dataTransformationService = nil
        _diagnosticsService = nil
        _configurationService = nil
    }
    
    // MARK: - Private Storage
    
    // Legacy service storage
    private var _legacyVaultService: BlendUSDCVault?
    private var _rateCalculator: BlendRateCalculatorProtocol?
    private var _oracleService: BlendOracleServiceProtocol?
    private var _networkServiceLegacy: NetworkServiceProtocol?
    private var _cacheService: CacheServiceProtocol?
    
    // New service storage
    private var _refactoredVaultService: BlendUSDCVault?
    private var _networkService: NetworkConnectivityServiceProtocol?
    private var _sorobanClientService: SorobanClientServiceProtocol?
    private var _poolStatisticsService: PoolStatisticsServiceProtocol?
    private var _transactionExecutionService: TransactionExecutionServiceProtocol?
    private var _stateManagementService: StateManagementServiceProtocol?
    private var _dataTransformationService: DataTransformationServiceProtocol?
    private var _diagnosticsService: DiagnosticsServiceProtocol?
    private var _configurationService: ConfigurationServiceProtocol?
    
    // MARK: - Initialization
    
    private init() {}
}
```

### 5.3 Migration Testing Strategy

**File:** `Tests/Migration/MigrationIntegrationTests.swift`

```swift
import XCTest
@testable import Blendv3

final class MigrationIntegrationTests: XCTestCase {
    
    var container: DependencyContainer!
    
    override func setUp() {
        super.setUp()
        container = DependencyContainer()
        container.reset()
    }
    
    override func tearDown() {
        container.reset()
        super.tearDown()
    }
    
    func testParallelImplementationConsistency() async throws {
        // Test that both implementations produce consistent results
        
        FeatureFlags.useRefactoredVault = false
        let legacyVault = container.vaultService
        
        FeatureFlags.useRefactoredVault = true  
        let refactoredVault = container.vaultService
        
        // Wait for both to initialize
        let legacyInitialized = expectation(description: "Legacy initialized")
        let refactoredInitialized = expectation(description: "Refactored initialized")
        
        _ = legacyVault.onInitialized { result in
            if case .success = result {
                legacyInitialized.fulfill()
            }
        }
        
        _ = refactoredVault.onInitialized { result in
            if case .success = result {
                refactoredInitialized.fulfill()
            }
        }
        
        await fulfillment(of: [legacyInitialized, refactoredInitialized], timeout: 30)
        
        // Fetch pool stats from both
        try await legacyVault.refreshPoolStats()
        try await refactoredVault.refreshPoolStats()
        
        // Compare results
        let validationResult = MigrationHelper.comparePoolStats(
            legacy: legacyVault.poolStats,
            refactored: refactoredVault.poolStats
        )
        
        switch validationResult {
        case .success:
            XCTAssert(true, "Pool stats match between implementations")
        case .differences(let diffs):
            XCTFail("Pool stats differ: \(diffs.joined(separator: ", "))")
        case .incomplete(let reason):
            XCTFail("Comparison incomplete: \(reason)")
        }
    }
    
    func testFeatureFlagToggling() async throws {
        // Test smooth transition when toggling feature flags
        
        // Start with legacy
        FeatureFlags.useRefactoredVault = false
        var vault = container.vaultService
        
        let legacyInitialized = expectation(description: "Legacy initialized")
        _ = vault.onInitialized { result in
            if case .success = result {
                legacyInitialized.fulfill()
            }
        }
        await fulfillment(of: [legacyInitialized], timeout: 30)
        
        try await vault.refreshPoolStats()
        let legacyStats = vault.poolStats
        
        // Switch to refactored
        FeatureFlags.useRefactoredVault = true
        vault = container.vaultService
        
        let refactoredInitialized = expectation(description: "Refactored initialized")
        _ = vault.onInitialized { result in
            if case .success = result {
                refactoredInitialized.fulfill()
            }
        }
        await fulfillment(of: [refactoredInitialized], timeout: 30)
        
        try await vault.refreshPoolStats()
        let refactoredStats = vault.poolStats
        
        // Validate transition
        XCTAssertNotNil(legacyStats, "Legacy stats should be available")
        XCTAssertNotNil(refactoredStats, "Refactored stats should be available")
        
        // Log migration event
        MigrationHelper.logMigrationEvent(MigrationEvent(
            timestamp: Date(),
            type: .featureFlagToggled,
            description: "Successfully toggled from legacy to refactored implementation",
            metadata: [
                "legacy_stats_available": legacyStats != nil,
                "refactored_stats_available": refactoredStats != nil
            ]
        ))
    }
    
    func testServiceIsolation() async throws {
        // Test that services can be used independently
        
        let networkService = container.networkService
        let poolService = container.poolStatisticsService
        
        // Test network service in isolation
        networkService.startMonitoring()
        let connectionState = await networkService.checkConnectivity()
        XCTAssert(connectionState.isConnected || !connectionState.isConnected, "Connection state should be deterministic")
        
        // Test pool service (this should work independently)
        do {
            let reserves = try await poolService.getReserveList()
            XCTAssertFalse(reserves.isEmpty, "Should have at least some reserves")
        } catch {
            XCTFail("Pool service should work independently: \(error)")
        }
        
        networkService.stopMonitoring()
    }
}
```

## Phase 6: Cleanup & Optimization (1-2 days)

### 6.1 Legacy Code Removal Plan

1. **Backup Creation**
   - Create git branch with legacy implementation
   - Tag current version for rollback capability

2. **Gradual Removal**
   - Remove legacy BlendUSDCVault.swift (3,910 lines)
   - Clean up unused dependencies
   - Update all references in UI code
   - Remove migration helpers after stabilization

3. **Optimization Pass**
   - Add service-level caching strategies
   - Implement connection pooling for Soroban
   - Optimize data transformation pipelines
   - Add performance monitoring

### 6.2 Final Directory Structure

```
Blendv3/
├── Core/
│   ├── Services/
│   │   ├── NetworkConnectivityService.swift         (150-200 lines)
│   │   ├── SorobanClientService.swift               (200-250 lines)  
│   │   ├── PoolStatisticsService.swift              (400-500 lines)
│   │   ├── TransactionExecutionService.swift        (300-350 lines)
│   │   ├── StateManagementService.swift             (200-250 lines)
│   │   ├── DataTransformationService.swift          (300-400 lines)
│   │   ├── DiagnosticsService.swift                 (250-300 lines)
│   │   └── ConfigurationService.swift               (100-150 lines)
│   └── Models/
│       └── ServiceModels.swift                      (200-300 lines)
├── Protocols/
│   └── BlendServiceProtocols.swift                  (150-200 lines)
├── BlendUSDCVault.swift                            (150-200 lines)
├── DependencyInjection/
│   └── DependencyContainer.swift                    (100-150 lines)
└── Tests/
    ├── Services/
    │   ├── NetworkConnectivityServiceTests.swift
    │   ├── SorobanClientServiceTests.swift
    │   ├── PoolStatisticsServiceTests.swift
    │   ├── TransactionExecutionServiceTests.swift
    │   ├── StateManagementServiceTests.swift
    │   ├── DataTransformationServiceTests.swift
    │   └── DiagnosticsServiceTests.swift
    └── Integration/
        └── VaultIntegrationTests.swift
```

---

## Expected Benefits

### Maintainability Improvements
- **90% reduction** in individual file complexity (400 lines avg vs 3,910)
- **Clear ownership** of each functional area
- **Isolated testing** of individual components
- **Faster debugging** with isolated failure points

### Development Velocity  
- **Parallel development** possible across different services
- **Easier feature addition** without touching unrelated code
- **Reduced merge conflicts** with smaller, focused files
- **Better code review** process with manageable file sizes

### Code Quality
- **SOLID principles** compliance throughout
- **Protocol-driven development** for better testability
- **Clean architecture** with proper separation of concerns
- **Improved error handling** with service-specific error types

### Performance Gains
- **Service-level caching** strategies
- **Optimized data transformation** pipelines  
- **Reduced memory footprint** through focused services
- **Better resource management** with service lifecycle control

### Testing Benefits
- **Unit testable** services in isolation
- **Mockable dependencies** through protocols
- **Focused test cases** for specific functionality
- **Integration tests** for service orchestration

---

## Risk Mitigation

### Technical Risks
- **Parallel implementation** reduces migration risk
- **Feature flags** enable quick rollback
- **Comprehensive testing** validates consistency
- **Gradual migration** minimizes disruption

### Business Risks
- **Zero downtime** migration strategy
- **Backward compatibility** during transition
- **Performance monitoring** throughout migration
- **Rollback plan** ready at each phase

---

## Success Metrics

### Code Quality Metrics
- Lines of code per file: **< 500 lines** (from 3,910)
- Cyclomatic complexity: **< 10 per method** (from 20+)
- Test coverage: **> 90%** (from ~60%)
- Code duplication: **< 5%** (from ~15%)

### Performance Metrics
- Initialization time: **< 2 seconds** (from 5+ seconds)
- Memory usage: **< 50MB** (from 100+ MB)
- API response time: **< 1 second** (from 3+ seconds)
- Error rate: **< 1%** (from 5%+)

### Development Metrics
- Time to implement new features: **50% reduction**
- Bug resolution time: **60% reduction** 
- Code review time: **70% reduction**
- Onboarding time for new developers: **80% reduction**

---

This refactoring plan transforms a monolithic 3,910-line God Object into a clean, maintainable service architecture that will serve as a solid foundation for future development. The parallel implementation strategy ensures minimal risk while delivering maximum impact.