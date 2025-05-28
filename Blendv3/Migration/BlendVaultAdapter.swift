//
//  BlendVaultAdapter.swift
//  Blendv3
//
//  Adapter layer for gradual migration from BlendUSDCVault to new architecture
//

import Foundation
import Combine
import stellarsdk

/// Adapter that provides a bridge between the legacy BlendUSDCVault and the new service architecture
public class BlendVaultAdapter {
    
    // MARK: - Properties
    
    private let legacyVault: BlendUSDCVault?
    private let newVault: BlendVault?
    private let migrationConfig: MigrationConfiguration
    private let diagnosticsService: DiagnosticsServiceProtocol
    
    // Feature flags for gradual migration
    private var featureFlags: FeatureFlags
    
    // Publishers
    private let migrationStatusSubject = CurrentValueSubject<MigrationStatus, Never>(.notStarted)
    public var migrationStatusPublisher: AnyPublisher<MigrationStatus, Never> {
        migrationStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init(
        legacyVault: BlendUSDCVault? = nil,
        newVault: BlendVault? = nil,
        migrationConfig: MigrationConfiguration = .default,
        diagnosticsService: DiagnosticsServiceProtocol
    ) {
        self.legacyVault = legacyVault
        self.newVault = newVault
        self.migrationConfig = migrationConfig
        self.diagnosticsService = diagnosticsService
        self.featureFlags = migrationConfig.initialFeatureFlags
        
        BlendLogger.info("BlendVaultAdapter initialized with migration config: \(migrationConfig)", 
                        category: BlendLogger.migration)
    }
    
    // MARK: - Public Interface (Matches BlendUSDCVault)
    
    public func initialize() async throws {
        let startTime = Date()
        
        if shouldUseNewImplementation(for: .initialization) {
            BlendLogger.info("Using new vault for initialization", category: BlendLogger.migration)
            try await newVault?.initialize()
        } else {
            BlendLogger.info("Using legacy vault for initialization", category: BlendLogger.migration)
            try await legacyVault?.initialize()
        }
        
        await diagnosticsService.trackOperationTiming(
            operation: "adapter_initialize",
            duration: Date().timeIntervalSince(startTime)
        )
    }
    
    // MARK: - Transaction Operations
    
    public func deposit(amount: Decimal) async throws -> String {
        return try await routeOperation(
            operation: .deposit,
            legacy: { try await self.legacyVault?.deposit(amount: amount) },
            new: { try await self.newVault?.deposit(amount: amount) }
        ) ?? ""
    }
    
    public func withdraw(shares: Decimal) async throws -> String {
        return try await routeOperation(
            operation: .withdraw,
            legacy: { try await self.legacyVault?.withdraw(shares: shares) },
            new: { try await self.newVault?.withdraw(shares: shares) }
        ) ?? ""
    }
    
    public func borrow(amount: Decimal) async throws -> String {
        return try await routeOperation(
            operation: .borrow,
            legacy: { try await self.legacyVault?.borrow(amount: amount) },
            new: { try await self.newVault?.borrow(amount: amount) }
        ) ?? ""
    }
    
    public func repay(amount: Decimal) async throws -> String {
        return try await routeOperation(
            operation: .repay,
            legacy: { try await self.legacyVault?.repay(amount: amount) },
            new: { try await self.newVault?.repay(amount: amount) }
        ) ?? ""
    }
    
    public func claim() async throws -> String {
        return try await routeOperation(
            operation: .claim,
            legacy: { try await self.legacyVault?.claim() },
            new: { try await self.newVault?.claim() }
        ) ?? ""
    }
    
    // MARK: - Data Fetching Operations
    
    public func getPoolData() async throws -> PoolData? {
        return try await routeOperation(
            operation: .getPoolData,
            legacy: { try await self.legacyVault?.getPoolData() },
            new: { try await self.newVault?.getPoolData() }
        )
    }
    
    public func getUserPositions() async throws -> UserPositions? {
        return try await routeOperation(
            operation: .getUserPositions,
            legacy: { try await self.legacyVault?.getUserPositions() },
            new: { try await self.newVault?.getUserPositions() }
        )
    }
    
    public func getReserveData() async throws -> [ReserveData] {
        return try await routeOperation(
            operation: .getReserveData,
            legacy: { try await self.legacyVault?.getReserveData() },
            new: { try await self.newVault?.getReserveData() }
        ) ?? []
    }
    
    // MARK: - Migration Control
    
    public func updateFeatureFlag(_ flag: FeatureFlag, enabled: Bool) {
        featureFlags.setFlag(flag, enabled: enabled)
        
        BlendLogger.info("Feature flag updated: \(flag) = \(enabled)", category: BlendLogger.migration)
        
        // Update migration status
        updateMigrationStatus()
    }
    
    public func enableOperation(_ operation: VaultOperation) {
        featureFlags.enableOperation(operation)
        BlendLogger.info("Operation enabled for new implementation: \(operation)", category: BlendLogger.migration)
    }
    
    public func disableOperation(_ operation: VaultOperation) {
        featureFlags.disableOperation(operation)
        BlendLogger.warning("Operation disabled for new implementation: \(operation)", category: BlendLogger.migration)
    }
    
    public func getMigrationMetrics() -> MigrationMetrics {
        let enabledOperations = VaultOperation.allCases.filter { shouldUseNewImplementation(for: $0) }
        let progress = Double(enabledOperations.count) / Double(VaultOperation.allCases.count)
        
        return MigrationMetrics(
            startDate: migrationConfig.startDate,
            progress: progress,
            enabledOperations: enabledOperations,
            totalOperations: VaultOperation.allCases.count,
            featureFlags: featureFlags
        )
    }
    
    // MARK: - A/B Testing Support
    
    public func runComparison<T: Equatable>(
        operation: VaultOperation,
        legacy: () async throws -> T,
        new: () async throws -> T
    ) async -> ComparisonResult<T> {
        let startTime = Date()
        
        // Run both implementations
        let legacyResult = await runWithTiming { try await legacy() }
        let newResult = await runWithTiming { try await new() }
        
        // Compare results
        let resultsMatch: Bool
        if case .success(let legacyValue) = legacyResult.result,
           case .success(let newValue) = newResult.result {
            resultsMatch = legacyValue == newValue
        } else {
            resultsMatch = false
        }
        
        let comparison = ComparisonResult(
            operation: operation,
            legacyResult: legacyResult,
            newResult: newResult,
            resultsMatch: resultsMatch,
            timestamp: Date()
        )
        
        // Log comparison
        await logComparison(comparison)
        
        return comparison
    }
    
    // MARK: - Private Methods
    
    private func shouldUseNewImplementation(for operation: VaultOperation) -> Bool {
        // Check if globally enabled
        guard featureFlags.isEnabled(.useNewArchitecture) else {
            return false
        }
        
        // Check operation-specific flag
        guard featureFlags.isOperationEnabled(operation) else {
            return false
        }
        
        // Check percentage rollout
        if let percentage = migrationConfig.rolloutPercentage[operation] {
            let random = Int.random(in: 0..<100)
            return random < percentage
        }
        
        return true
    }
    
    private func routeOperation<T>(
        operation: VaultOperation,
        legacy: () async throws -> T?,
        new: () async throws -> T?
    ) async throws -> T? {
        let startTime = Date()
        
        let useNew = shouldUseNewImplementation(for: operation)
        let implementation = useNew ? "new" : "legacy"
        
        BlendLogger.debug("Routing \(operation) to \(implementation) implementation", 
                         category: BlendLogger.migration)
        
        do {
            let result: T?
            if useNew {
                guard newVault != nil else {
                    throw BlendError.migration(.newVaultNotAvailable)
                }
                result = try await new()
            } else {
                guard legacyVault != nil else {
                    throw BlendError.migration(.legacyVaultNotAvailable)
                }
                result = try await legacy()
            }
            
            // Track success
            await diagnosticsService.trackOperationTiming(
                operation: "adapter_\(operation)_\(implementation)",
                duration: Date().timeIntervalSince(startTime)
            )
            
            return result
            
        } catch {
            // Log error
            BlendLogger.error("Operation \(operation) failed on \(implementation) implementation", 
                            error: error, category: BlendLogger.migration)
            
            // Fallback logic if enabled
            if useNew && migrationConfig.enableFallback {
                BlendLogger.warning("Falling back to legacy implementation for \(operation)", 
                                  category: BlendLogger.migration)
                return try await legacy()
            }
            
            throw error
        }
    }
    
    private func runWithTiming<T>(
        _ operation: () async throws -> T
    ) async -> TimedResult<T> {
        let startTime = Date()
        
        do {
            let result = try await operation()
            return TimedResult(
                result: .success(result),
                duration: Date().timeIntervalSince(startTime)
            )
        } catch {
            return TimedResult(
                result: .failure(error),
                duration: Date().timeIntervalSince(startTime)
            )
        }
    }
    
    private func logComparison<T>(_ comparison: ComparisonResult<T>) async {
        let event = NetworkEvent(
            type: .request,
            endpoint: "comparison/\(comparison.operation)",
            method: "COMPARE",
            statusCode: comparison.resultsMatch ? 200 : 500,
            duration: comparison.newResult.duration,
            error: comparison.resultsMatch ? nil : BlendError.migration(.resultMismatch)
        )
        
        await diagnosticsService.logNetworkEvent(event)
    }
    
    private func updateMigrationStatus() {
        let metrics = getMigrationMetrics()
        
        let status: MigrationStatus
        if metrics.progress == 0 {
            status = .notStarted
        } else if metrics.progress < 1.0 {
            status = .inProgress(metrics.progress)
        } else {
            status = .completed
        }
        
        migrationStatusSubject.send(status)
    }
}

// MARK: - Supporting Types

public struct MigrationConfiguration {
    public let startDate: Date
    public let initialFeatureFlags: FeatureFlags
    public let rolloutPercentage: [VaultOperation: Int]
    public let enableFallback: Bool
    public let comparisonMode: Bool
    
    public static let `default` = MigrationConfiguration(
        startDate: Date(),
        initialFeatureFlags: FeatureFlags(),
        rolloutPercentage: [:],
        enableFallback: true,
        comparisonMode: false
    )
}

public class FeatureFlags {
    private var flags: [FeatureFlag: Bool] = [:]
    private var operationFlags: [VaultOperation: Bool] = [:]
    
    public func isEnabled(_ flag: FeatureFlag) -> Bool {
        return flags[flag] ?? false
    }
    
    public func setFlag(_ flag: FeatureFlag, enabled: Bool) {
        flags[flag] = enabled
    }
    
    public func isOperationEnabled(_ operation: VaultOperation) -> Bool {
        return operationFlags[operation] ?? false
    }
    
    public func enableOperation(_ operation: VaultOperation) {
        operationFlags[operation] = true
    }
    
    public func disableOperation(_ operation: VaultOperation) {
        operationFlags[operation] = false
    }
}

public enum FeatureFlag: String, CaseIterable {
    case useNewArchitecture
    case enableCaching
    case enableBatching
    case enableDiagnostics
    case enableMetrics
}

public enum VaultOperation: String, CaseIterable {
    case initialization
    case deposit
    case withdraw
    case borrow
    case repay
    case claim
    case getPoolData
    case getUserPositions
    case getReserveData
}

public enum MigrationStatus {
    case notStarted
    case inProgress(Double) // Progress percentage
    case completed
}

public struct MigrationMetrics {
    public let startDate: Date
    public let progress: Double
    public let enabledOperations: [VaultOperation]
    public let totalOperations: Int
    public let featureFlags: FeatureFlags
}

public struct ComparisonResult<T> {
    public let operation: VaultOperation
    public let legacyResult: TimedResult<T>
    public let newResult: TimedResult<T>
    public let resultsMatch: Bool
    public let timestamp: Date
}

public struct TimedResult<T> {
    public let result: Result<T, Error>
    public let duration: TimeInterval
}

// MARK: - Migration Errors

extension BlendError {
    public enum MigrationError: LocalizedError {
        case legacyVaultNotAvailable
        case newVaultNotAvailable
        case resultMismatch
        case migrationFailed
        
        public var errorDescription: String? {
            switch self {
            case .legacyVaultNotAvailable:
                return "Legacy vault is not available"
            case .newVaultNotAvailable:
                return "New vault is not available"
            case .resultMismatch:
                return "Results from legacy and new implementation do not match"
            case .migrationFailed:
                return "Migration failed"
            }
        }
    }
    
    public static func migration(_ error: MigrationError) -> BlendError {
        return BlendError(
            code: "MIGRATION_ERROR",
            message: error.errorDescription ?? "Migration error",
            details: nil
        )
    }
} 