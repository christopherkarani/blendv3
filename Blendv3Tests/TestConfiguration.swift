import Foundation
import XCTest
@testable import Blendv3

/// Test configuration and utilities for Blend v3 tests
public struct TestConfiguration {
    
    // MARK: - Test Environment
    
    /// Whether to run integration tests that require network connectivity
    public static var runIntegrationTests: Bool {
        return ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] == "1"
    }
    
    /// Whether to run performance tests (may be slow)
    public static var runPerformanceTests: Bool {
        return ProcessInfo.processInfo.environment["RUN_PERFORMANCE_TESTS"] == "1"
    }
    
    /// Whether to enable verbose logging during tests
    public static var verboseLogging: Bool {
        return ProcessInfo.processInfo.environment["VERBOSE_TEST_LOGGING"] == "1"
    }
    
    // MARK: - Test Constants
    
    public struct Oracle {
        public static let testAssets = [
            BlendUSDCConstants.Testnet.usdc,
            BlendUSDCConstants.Testnet.xlm,
            BlendUSDCConstants.Testnet.blnd,
            BlendUSDCConstants.Testnet.weth,
            BlendUSDCConstants.Testnet.wbtc
        ]
        
        public static let invalidAssets = [
            "INVALID_ASSET_ADDRESS_1",
            "INVALID_ASSET_ADDRESS_2",
            "NOT_A_REAL_CONTRACT_ADDRESS"
        ]
        
        public static let expectedPriceRanges: [String: (min: Decimal, max: Decimal)] = [
            BlendUSDCConstants.Testnet.usdc: (0.95, 1.05),  // USDC ~$1.00
            BlendUSDCConstants.Testnet.xlm: (0.05, 1.00),   // XLM reasonable range
            BlendUSDCConstants.Testnet.blnd: (0.001, 1.00), // BLND reasonable range
            BlendUSDCConstants.Testnet.weth: (1000, 5000),  // ETH reasonable range
            BlendUSDCConstants.Testnet.wbtc: (20000, 80000) // BTC reasonable range
        ]
    }
    
    public struct Timeouts {
        public static let unitTest: TimeInterval = 5.0
        public static let integrationTest: TimeInterval = 30.0
        public static let performanceTest: TimeInterval = 60.0
        public static let networkCall: TimeInterval = 10.0
    }
    
    public struct Performance {
        public static let maxOracleCallDuration: TimeInterval = 5.0
        public static let maxBatchOracleCallDuration: TimeInterval = 10.0
        public static let maxCacheRetrievalDuration: TimeInterval = 0.1
        public static let cacheSpeedupFactor: Double = 0.1 // Cache should be 10x faster
    }
    
    // MARK: - Test Utilities
    
    /// Skip test if integration tests are disabled
    public static func skipIfIntegrationTestsDisabled() throws {
        guard runIntegrationTests else {
            throw XCTSkip("Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable.")
        }
    }
    
    /// Skip test if performance tests are disabled
    public static func skipIfPerformanceTestsDisabled() throws {
        guard runPerformanceTests else {
            throw XCTSkip("Performance tests disabled. Set RUN_PERFORMANCE_TESTS=1 to enable.")
        }
    }
    
    /// Measure execution time of a block
    public static func measureTime<T>(_ block: () throws -> T) rethrows -> (result: T, duration: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        return (result, duration)
    }
    
    /// Measure execution time of an async block
    public static func measureTimeAsync<T>(_ block: () async throws -> T) async rethrows -> (result: T, duration: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        return (result, duration)
    }
    
    /// Assert that a duration is within expected bounds
    public static func assertDuration(
        _ duration: TimeInterval,
        lessThan maxDuration: TimeInterval,
        message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertLessThan(
            duration,
            maxDuration,
            message.isEmpty ? "Duration \(duration)s should be less than \(maxDuration)s" : message,
            file: file,
            line: line
        )
    }
    
    /// Assert that a price is within expected range for an asset
    public static func assertPriceInRange(
        _ price: Decimal,
        for asset: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let range = Oracle.expectedPriceRanges[asset] else {
            XCTAssertGreaterThan(price, 0, "Price should be positive for unknown asset \(asset)", file: file, line: line)
            return
        }
        
        XCTAssertGreaterThanOrEqual(
            price,
            range.min,
            "Price \(price) should be >= \(range.min) for \(asset)",
            file: file,
            line: line
        )
        
        XCTAssertLessThanOrEqual(
            price,
            range.max,
            "Price \(price) should be <= \(range.max) for \(asset)",
            file: file,
            line: line
        )
    }
    
    /// Validate PriceData structure
    public static func validatePriceData(
        _ priceData: PriceData,
        for asset: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Basic validation
        XCTAssertEqual(priceData.assetId, asset, "Asset ID should match", file: file, line: line)
        XCTAssertGreaterThan(priceData.price, 0, "Price should be positive", file: file, line: line)
        XCTAssertFalse(priceData.price.isNaN, "Price should not be NaN", file: file, line: line)
        XCTAssertFalse(priceData.price.isInfinite, "Price should not be infinite", file: file, line: line)
        
        // Timestamp validation
        let now = Date()
        let oneYearAgo = now.addingTimeInterval(-365 * 24 * 3600)
        XCTAssertGreaterThan(priceData.timestamp, oneYearAgo, "Timestamp should not be too old", file: file, line: line)
        XCTAssertLessThanOrEqual(priceData.timestamp, now, "Timestamp should not be in the future", file: file, line: line)
        
        // Decimals validation
        XCTAssertGreaterThan(priceData.decimals, 0, "Decimals should be positive", file: file, line: line)
        XCTAssertLessThanOrEqual(priceData.decimals, 18, "Decimals should be reasonable", file: file, line: line)
        
        // Price range validation
        assertPriceInRange(priceData.priceInUSD, for: asset, file: file, line: line)
    }
    
    /// Generate test price data
    public static func generateMockPriceData(
        for asset: String,
        price: Decimal? = nil,
        timestamp: Date? = nil,
        decimals: Int = 7
    ) -> PriceData {
        let finalPrice = price ?? {
            if let range = Oracle.expectedPriceRanges[asset] {
                let mid = (range.min + range.max) / 2
                return mid
            }
            return Decimal(1_000_000) // Default $1.00 with 7 decimals
        }()
        
        return PriceData(
            price: finalPrice,
            timestamp: timestamp ?? Date(),
            assetId: asset,
            decimals: decimals
        )
    }
    
    /// Generate multiple test price data entries
    public static func generateMockPriceDataArray(
        for asset: String,
        count: Int,
        basePrice: Decimal? = nil,
        startTime: Date? = nil,
        intervalSeconds: TimeInterval = 3600
    ) -> [PriceData] {
        let start = startTime ?? Date().addingTimeInterval(-TimeInterval(count) * intervalSeconds)
        let base = basePrice ?? Decimal(1_000_000)
        
        return (0..<count).map { index in
            let timestamp = start.addingTimeInterval(TimeInterval(index) * intervalSeconds)
            let priceVariation = Decimal(Double.random(in: 0.95...1.05)) // ±5% variation
            let price = base * priceVariation
            
            return PriceData(
                price: price,
                timestamp: timestamp,
                assetId: asset,
                decimals: 7
            )
        }
    }
}

// MARK: - Test Assertions

/// Custom assertions for Oracle testing
public extension XCTestCase {
    
    /// Assert that oracle response time is acceptable
    func assertOraclePerformance<T>(
        _ operation: () async throws -> T,
        maxDuration: TimeInterval = TestConfiguration.Performance.maxOracleCallDuration,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> T {
        let (result, duration) = try await TestConfiguration.measureTimeAsync(operation)
        TestConfiguration.assertDuration(duration, lessThan: maxDuration, file: file, line: line)
        return result
    }
    
    /// Assert that cache performance is acceptable
    func assertCachePerformance<T>(
        _ operation: () throws -> T,
        maxDuration: TimeInterval = TestConfiguration.Performance.maxCacheRetrievalDuration,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T {
        let (result, duration) = TestConfiguration.measureTime(operation)
        TestConfiguration.assertDuration(duration, lessThan: maxDuration, file: file, line: line)
        return result
    }
    
    /// Assert that price data is valid
    func assertValidPriceData(
        _ priceData: PriceData,
        for asset: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        TestConfiguration.validatePriceData(priceData, for: asset, file: file, line: line)
    }
    
    /// Assert that price is in expected range
    func assertPriceInRange(
        _ price: Decimal,
        for asset: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        TestConfiguration.assertPriceInRange(price, for: asset, file: file, line: line)
    }
}

// MARK: - Test Environment Setup

/// Environment setup for tests
public struct TestEnvironment {
    
    /// Setup test environment
    public static func setup() {
        // Configure logging for tests
        if TestConfiguration.verboseLogging {
            BlendLogger.setLogLevel(.debug)
        } else {
            BlendLogger.setLogLevel(.error) // Reduce noise in tests
        }
        
        // Setup test-specific configurations
        setupTestNetworking()
        setupTestCaching()
    }
    
    /// Cleanup test environment
    public static func cleanup() {
        // Clear any test caches
        clearTestCaches()
        
        // Reset logging
        BlendLogger.setLogLevel(.info)
    }
    
    private static func setupTestNetworking() {
        // Configure network timeouts for testing
        // This would be implemented based on your networking layer
    }
    
    private static func setupTestCaching() {
        // Configure cache settings for testing
        // This would be implemented based on your caching layer
    }
    
    private static func clearTestCaches() {
        // Clear test caches
        // This would be implemented based on your caching layer
    }
} 