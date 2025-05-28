//
//  ABTestingFramework.swift
//  Blendv3
//
//  A/B testing framework for comparing legacy and new implementations
//

import Foundation
import Combine

/// Framework for running A/B tests between legacy and new implementations
public actor ABTestingFramework {
    
    // MARK: - Properties
    
    private let adapter: BlendVaultAdapter
    private let diagnosticsService: DiagnosticsServiceProtocol
    private let configuration: ABTestConfiguration
    
    // Test results storage
    private var testResults: [ABTestResult] = []
    private let maxStoredResults = 1000
    
    // Test metrics
    private var totalTests: Int = 0
    private var successfulMatches: Int = 0
    private var performanceComparisons: [VaultOperation: PerformanceComparison] = [:]
    
    // Publishers
    private let testResultSubject = PassthroughSubject<ABTestResult, Never>()
    public nonisolated var testResultPublisher: AnyPublisher<ABTestResult, Never> {
        testResultSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init(
        adapter: BlendVaultAdapter,
        diagnosticsService: DiagnosticsServiceProtocol,
        configuration: ABTestConfiguration = .default
    ) {
        self.adapter = adapter
        self.diagnosticsService = diagnosticsService
        self.configuration = configuration
        
        BlendLogger.info("ABTestingFramework initialized", category: BlendLogger.testing)
    }
    
    // MARK: - Test Execution
    
    /// Run a single A/B test for a specific operation
    public func runTest(for operation: VaultOperation, parameters: TestParameters) async -> ABTestResult {
        let testId = UUID()
        let startTime = Date()
        
        BlendLogger.info("Starting A/B test \(testId) for operation: \(operation)", category: BlendLogger.testing)
        
        // Execute based on operation type
        let result: ABTestResult
        
        switch operation {
        case .deposit:
            result = await testDeposit(testId: testId, amount: parameters.amount ?? 100)
        case .withdraw:
            result = await testWithdraw(testId: testId, shares: parameters.shares ?? 50)
        case .borrow:
            result = await testBorrow(testId: testId, amount: parameters.amount ?? 200)
        case .repay:
            result = await testRepay(testId: testId, amount: parameters.amount ?? 150)
        case .claim:
            result = await testClaim(testId: testId)
        case .getPoolData:
            result = await testGetPoolData(testId: testId)
        case .getUserPositions:
            result = await testGetUserPositions(testId: testId)
        case .getReserveData:
            result = await testGetReserveData(testId: testId)
        case .initialization:
            result = await testInitialization(testId: testId)
        }
        
        // Store and publish result
        await storeResult(result)
        testResultSubject.send(result)
        
        // Log test completion
        let duration = Date().timeIntervalSince(startTime)
        await diagnosticsService.trackOperationTiming(
            operation: "ab_test_\(operation)",
            duration: duration
        )
        
        BlendLogger.info("A/B test \(testId) completed in \(String(format: "%.3f", duration))s", 
                        category: BlendLogger.testing)
        
        return result
    }
    
    /// Run a comprehensive test suite
    public func runTestSuite(_ suite: TestSuite) async -> TestSuiteResult {
        BlendLogger.info("Starting test suite: \(suite.name)", category: BlendLogger.testing)
        
        let startTime = Date()
        var results: [ABTestResult] = []
        
        // Run tests based on suite configuration
        for testCase in suite.testCases {
            if shouldRunTest(testCase, in: suite) {
                let result = await runTest(for: testCase.operation, parameters: testCase.parameters)
                results.append(result)
                
                // Delay between tests if configured
                if let delay = suite.delayBetweenTests {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // Calculate suite metrics
        let successRate = calculateSuccessRate(for: results)
        let performanceMetrics = calculatePerformanceMetrics(for: results)
        
        let suiteResult = TestSuiteResult(
            id: UUID(),
            name: suite.name,
            timestamp: Date(),
            duration: Date().timeIntervalSince(startTime),
            testResults: results,
            successRate: successRate,
            performanceMetrics: performanceMetrics
        )
        
        BlendLogger.info("Test suite completed: \(suite.name) - Success rate: \(String(format: "%.1f%%", successRate * 100))", 
                        category: BlendLogger.testing)
        
        return suiteResult
    }
    
    // MARK: - Test Analysis
    
    /// Get comprehensive test metrics
    public func getTestMetrics() -> ABTestMetrics {
        let successRate = totalTests > 0 ? Double(successfulMatches) / Double(totalTests) : 0
        
        return ABTestMetrics(
            totalTests: totalTests,
            successfulMatches: successfulMatches,
            failedMatches: totalTests - successfulMatches,
            successRate: successRate,
            performanceComparisons: performanceComparisons,
            recentResults: Array(testResults.suffix(10))
        )
    }
    
    /// Analyze performance differences between implementations
    public func analyzePerformance(for operation: VaultOperation) -> PerformanceAnalysis? {
        guard let comparison = performanceComparisons[operation] else { return nil }
        
        let speedup = comparison.legacyAverage > 0 ? 
            comparison.newAverage / comparison.legacyAverage : 0
        
        let recommendation: PerformanceRecommendation
        if speedup < 0.8 {
            recommendation = .useNew(reason: "New implementation is significantly faster")
        } else if speedup > 1.2 {
            recommendation = .useLegacy(reason: "Legacy implementation is significantly faster")
        } else {
            recommendation = .noPreference(reason: "Performance is comparable")
        }
        
        return PerformanceAnalysis(
            operation: operation,
            comparison: comparison,
            speedup: speedup,
            recommendation: recommendation
        )
    }
    
    /// Generate a comprehensive test report
    public func generateReport() -> ABTestReport {
        let metrics = getTestMetrics()
        let operationAnalyses = VaultOperation.allCases.compactMap { analyzePerformance(for: $0) }
        
        let recommendations = generateRecommendations(
            metrics: metrics,
            analyses: operationAnalyses
        )
        
        return ABTestReport(
            generatedAt: Date(),
            metrics: metrics,
            operationAnalyses: operationAnalyses,
            recommendations: recommendations,
            configuration: configuration
        )
    }
    
    // MARK: - Private Test Methods
    
    private func testDeposit(testId: UUID, amount: Decimal) async -> ABTestResult {
        let comparison = await adapter.runComparison(
            operation: .deposit,
            legacy: { try await self.adapter.deposit(amount: amount) },
            new: { try await self.adapter.deposit(amount: amount) }
        )
        
        return createTestResult(
            testId: testId,
            operation: .deposit,
            comparison: comparison,
            parameters: ["amount": amount]
        )
    }
    
    private func testWithdraw(testId: UUID, shares: Decimal) async -> ABTestResult {
        let comparison = await adapter.runComparison(
            operation: .withdraw,
            legacy: { try await self.adapter.withdraw(shares: shares) },
            new: { try await self.adapter.withdraw(shares: shares) }
        )
        
        return createTestResult(
            testId: testId,
            operation: .withdraw,
            comparison: comparison,
            parameters: ["shares": shares]
        )
    }
    
    private func testBorrow(testId: UUID, amount: Decimal) async -> ABTestResult {
        let comparison = await adapter.runComparison(
            operation: .borrow,
            legacy: { try await self.adapter.borrow(amount: amount) },
            new: { try await self.adapter.borrow(amount: amount) }
        )
        
        return createTestResult(
            testId: testId,
            operation: .borrow,
            comparison: comparison,
            parameters: ["amount": amount]
        )
    }
    
    private func testRepay(testId: UUID, amount: Decimal) async -> ABTestResult {
        let comparison = await adapter.runComparison(
            operation: .repay,
            legacy: { try await self.adapter.repay(amount: amount) },
            new: { try await self.adapter.repay(amount: amount) }
        )
        
        return createTestResult(
            testId: testId,
            operation: .repay,
            comparison: comparison,
            parameters: ["amount": amount]
        )
    }
    
    private func testClaim(testId: UUID) async -> ABTestResult {
        let comparison = await adapter.runComparison(
            operation: .claim,
            legacy: { try await self.adapter.claim() },
            new: { try await self.adapter.claim() }
        )
        
        return createTestResult(
            testId: testId,
            operation: .claim,
            comparison: comparison,
            parameters: [:]
        )
    }
    
    private func testGetPoolData(testId: UUID) async -> ABTestResult {
        let comparison = await adapter.runComparison(
            operation: .getPoolData,
            legacy: { try await self.adapter.getPoolData() },
            new: { try await self.adapter.getPoolData() }
        )
        
        return createTestResult(
            testId: testId,
            operation: .getPoolData,
            comparison: comparison,
            parameters: [:]
        )
    }
    
    private func testGetUserPositions(testId: UUID) async -> ABTestResult {
        let comparison = await adapter.runComparison(
            operation: .getUserPositions,
            legacy: { try await self.adapter.getUserPositions() },
            new: { try await self.adapter.getUserPositions() }
        )
        
        return createTestResult(
            testId: testId,
            operation: .getUserPositions,
            comparison: comparison,
            parameters: [:]
        )
    }
    
    private func testGetReserveData(testId: UUID) async -> ABTestResult {
        let comparison = await adapter.runComparison(
            operation: .getReserveData,
            legacy: { try await self.adapter.getReserveData() },
            new: { try await self.adapter.getReserveData() }
        )
        
        return createTestResult(
            testId: testId,
            operation: .getReserveData,
            comparison: comparison,
            parameters: [:]
        )
    }
    
    private func testInitialization(testId: UUID) async -> ABTestResult {
        let comparison = await adapter.runComparison(
            operation: .initialization,
            legacy: { try await self.adapter.initialize() },
            new: { try await self.adapter.initialize() }
        )
        
        return createTestResult(
            testId: testId,
            operation: .initialization,
            comparison: comparison,
            parameters: [:]
        )
    }
    
    // MARK: - Helper Methods
    
    private func createTestResult<T>(
        testId: UUID,
        operation: VaultOperation,
        comparison: ComparisonResult<T>,
        parameters: [String: Any]
    ) -> ABTestResult {
        let status: TestStatus = comparison.resultsMatch ? .passed : .failed
        
        let legacyError: String? = {
            if case .failure(let error) = comparison.legacyResult.result {
                return error.localizedDescription
            }
            return nil
        }()
        
        let newError: String? = {
            if case .failure(let error) = comparison.newResult.result {
                return error.localizedDescription
            }
            return nil
        }()
        
        return ABTestResult(
            id: testId,
            operation: operation,
            timestamp: comparison.timestamp,
            status: status,
            legacyDuration: comparison.legacyResult.duration,
            newDuration: comparison.newResult.duration,
            resultsMatch: comparison.resultsMatch,
            legacyError: legacyError,
            newError: newError,
            parameters: parameters
        )
    }
    
    private func storeResult(_ result: ABTestResult) async {
        testResults.append(result)
        
        // Trim old results
        if testResults.count > maxStoredResults {
            testResults.removeFirst(testResults.count - maxStoredResults)
        }
        
        // Update metrics
        totalTests += 1
        if result.resultsMatch {
            successfulMatches += 1
        }
        
        // Update performance comparisons
        updatePerformanceComparison(for: result)
    }
    
    private func updatePerformanceComparison(for result: ABTestResult) {
        var comparison = performanceComparisons[result.operation] ?? PerformanceComparison(
            operation: result.operation,
            sampleCount: 0,
            legacyAverage: 0,
            newAverage: 0,
            legacyMin: Double.infinity,
            legacyMax: 0,
            newMin: Double.infinity,
            newMax: 0
        )
        
        // Update sample count
        comparison.sampleCount += 1
        
        // Update legacy metrics
        comparison.legacyAverage = (comparison.legacyAverage * Double(comparison.sampleCount - 1) + result.legacyDuration) / Double(comparison.sampleCount)
        comparison.legacyMin = min(comparison.legacyMin, result.legacyDuration)
        comparison.legacyMax = max(comparison.legacyMax, result.legacyDuration)
        
        // Update new metrics
        comparison.newAverage = (comparison.newAverage * Double(comparison.sampleCount - 1) + result.newDuration) / Double(comparison.sampleCount)
        comparison.newMin = min(comparison.newMin, result.newDuration)
        comparison.newMax = max(comparison.newMax, result.newDuration)
        
        performanceComparisons[result.operation] = comparison
    }
    
    private func shouldRunTest(_ testCase: TestCase, in suite: TestSuite) -> Bool {
        // Check if operation is enabled
        guard configuration.enabledOperations.contains(testCase.operation) else {
            return false
        }
        
        // Check probability
        let random = Double.random(in: 0...1)
        return random <= testCase.probability
    }
    
    private func calculateSuccessRate(for results: [ABTestResult]) -> Double {
        guard !results.isEmpty else { return 0 }
        
        let successCount = results.filter { $0.status == .passed }.count
        return Double(successCount) / Double(results.count)
    }
    
    private func calculatePerformanceMetrics(for results: [ABTestResult]) -> [VaultOperation: PerformanceMetrics] {
        var metrics: [VaultOperation: PerformanceMetrics] = [:]
        
        let groupedResults = Dictionary(grouping: results) { $0.operation }
        
        for (operation, operationResults) in groupedResults {
            let legacyTimes = operationResults.map { $0.legacyDuration }
            let newTimes = operationResults.map { $0.newDuration }
            
            metrics[operation] = PerformanceMetrics(
                averageLegacy: legacyTimes.reduce(0, +) / Double(legacyTimes.count),
                averageNew: newTimes.reduce(0, +) / Double(newTimes.count),
                minLegacy: legacyTimes.min() ?? 0,
                maxLegacy: legacyTimes.max() ?? 0,
                minNew: newTimes.min() ?? 0,
                maxNew: newTimes.max() ?? 0
            )
        }
        
        return metrics
    }
    
    private func generateRecommendations(
        metrics: ABTestMetrics,
        analyses: [PerformanceAnalysis]
    ) -> [String] {
        var recommendations: [String] = []
        
        // Overall success rate recommendation
        if metrics.successRate >= 0.95 {
            recommendations.append("✅ High success rate (\(String(format: "%.1f%%", metrics.successRate * 100))) indicates new implementation is stable")
        } else if metrics.successRate >= 0.8 {
            recommendations.append("⚠️ Moderate success rate (\(String(format: "%.1f%%", metrics.successRate * 100))) - investigate failing cases before full migration")
        } else {
            recommendations.append("❌ Low success rate (\(String(format: "%.1f%%", metrics.successRate * 100))) - new implementation needs fixes")
        }
        
        // Performance recommendations
        let fasterOperations = analyses.filter { $0.speedup < 0.8 }.map { $0.operation }
        if !fasterOperations.isEmpty {
            recommendations.append("🚀 New implementation is faster for: \(fasterOperations.map { $0.rawValue }.joined(separator: ", "))")
        }
        
        let slowerOperations = analyses.filter { $0.speedup > 1.2 }.map { $0.operation }
        if !slowerOperations.isEmpty {
            recommendations.append("🐌 New implementation is slower for: \(slowerOperations.map { $0.rawValue }.joined(separator: ", "))")
        }
        
        // Migration recommendation
        if metrics.successRate >= 0.95 && slowerOperations.isEmpty {
            recommendations.append("✅ Ready for full migration to new implementation")
        } else if metrics.successRate >= 0.8 {
            recommendations.append("⚡ Consider gradual rollout with monitoring")
        } else {
            recommendations.append("🛑 Not ready for migration - address issues first")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

public struct ABTestConfiguration {
    public let enabledOperations: Set<VaultOperation>
    public let maxConcurrentTests: Int
    public let testTimeout: TimeInterval
    public let retryFailedTests: Bool
    public let detailedLogging: Bool
    
    public static let `default` = ABTestConfiguration(
        enabledOperations: Set(VaultOperation.allCases),
        maxConcurrentTests: 5,
        testTimeout: 30.0,
        retryFailedTests: true,
        detailedLogging: true
    )
}

public struct TestParameters {
    public let amount: Decimal?
    public let shares: Decimal?
    public let customParameters: [String: Any]
    
    public init(amount: Decimal? = nil, shares: Decimal? = nil, customParameters: [String: Any] = [:]) {
        self.amount = amount
        self.shares = shares
        self.customParameters = customParameters
    }
}

public struct TestCase {
    public let operation: VaultOperation
    public let parameters: TestParameters
    public let probability: Double // 0.0 to 1.0
    
    public init(operation: VaultOperation, parameters: TestParameters = TestParameters(), probability: Double = 1.0) {
        self.operation = operation
        self.parameters = parameters
        self.probability = probability
    }
}

public struct TestSuite {
    public let name: String
    public let testCases: [TestCase]
    public let delayBetweenTests: TimeInterval?
    public let stopOnFailure: Bool
    
    public init(name: String, testCases: [TestCase], delayBetweenTests: TimeInterval? = nil, stopOnFailure: Bool = false) {
        self.name = name
        self.testCases = testCases
        self.delayBetweenTests = delayBetweenTests
        self.stopOnFailure = stopOnFailure
    }
}

public struct ABTestResult {
    public let id: UUID
    public let operation: VaultOperation
    public let timestamp: Date
    public let status: TestStatus
    public let legacyDuration: TimeInterval
    public let newDuration: TimeInterval
    public let resultsMatch: Bool
    public let legacyError: String?
    public let newError: String?
    public let parameters: [String: Any]
}

public enum TestStatus {
    case passed
    case failed
    case error
    case timeout
}

public struct TestSuiteResult {
    public let id: UUID
    public let name: String
    public let timestamp: Date
    public let duration: TimeInterval
    public let testResults: [ABTestResult]
    public let successRate: Double
    public let performanceMetrics: [VaultOperation: PerformanceMetrics]
}

public struct ABTestMetrics {
    public let totalTests: Int
    public let successfulMatches: Int
    public let failedMatches: Int
    public let successRate: Double
    public let performanceComparisons: [VaultOperation: PerformanceComparison]
    public let recentResults: [ABTestResult]
}

public struct PerformanceComparison {
    public let operation: VaultOperation
    public var sampleCount: Int
    public var legacyAverage: TimeInterval
    public var newAverage: TimeInterval
    public var legacyMin: TimeInterval
    public var legacyMax: TimeInterval
    public var newMin: TimeInterval
    public var newMax: TimeInterval
}

public struct PerformanceMetrics {
    public let averageLegacy: TimeInterval
    public let averageNew: TimeInterval
    public let minLegacy: TimeInterval
    public let maxLegacy: TimeInterval
    public let minNew: TimeInterval
    public let maxNew: TimeInterval
}

public struct PerformanceAnalysis {
    public let operation: VaultOperation
    public let comparison: PerformanceComparison
    public let speedup: Double
    public let recommendation: PerformanceRecommendation
}

public enum PerformanceRecommendation {
    case useNew(reason: String)
    case useLegacy(reason: String)
    case noPreference(reason: String)
}

public struct ABTestReport {
    public let generatedAt: Date
    public let metrics: ABTestMetrics
    public let operationAnalyses: [PerformanceAnalysis]
    public let recommendations: [String]
    public let configuration: ABTestConfiguration
} 