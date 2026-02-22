import XCTest
import stellarsdk
import Combine
@testable import Blendv3

/// Integration tests for BlendUSDCVault that test actual contract interactions
/// These tests require a working testnet connection and may be slower
final class BlendUSDCVaultIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: BlendUSDCVault!
    private var realSigner: BlendSigner!
    private var cancellables: Set<AnyCancellable>!
    
    // Test configuration
    private let testTimeout: TimeInterval = 60.0 // Longer timeout for real network calls
    private let testPublicKey = "GDQERENWDDSQZS7R7WKHZI3BSOYMV3FSWR7TFUYFTKQ447PIX6NREOJM"
    private let testSecretKey = "SDYH3V6ICEM463OTM7EEK7SNHYILXZRHPY45AYZOSK3N4NLF3NQUI4PQ"
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Only run integration tests if explicitly enabled
        guard TestConfiguration.runIntegrationTests else {
            throw XCTSkip("Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable.")
        }
        
        realSigner = BlendSigner(publicKey: testPublicKey)
        sut = BlendUSDCVault(signer: realSigner, network: .testnet)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        sut = nil
        realSigner = nil
        super.tearDown()
    }
    
    // MARK: - Real Contract Interaction Tests
    
    func testRefreshPoolStats_withRealContract_returnsValidData() async throws {
        // Given
        let statsExpectation = XCTestExpectation(description: "Pool stats updated")
        var receivedStats: BlendPoolStats?
        
        sut.$poolStats
            .compactMap { $0 }
            .sink { stats in
                receivedStats = stats
                statsExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        try await sut.refreshPoolStats()
        
        // Then
        await fulfillment(of: [statsExpectation], timeout: testTimeout)
        
        XCTAssertNotNil(receivedStats)
        
        if let stats = receivedStats {
            // Validate pool data structure
            XCTAssertGreaterThan(stats.poolData.totalValueLocked, 0, "TVL should be positive")
            XCTAssertGreaterThanOrEqual(stats.poolData.overallUtilization, 0, "Utilization should be non-negative")
            XCTAssertLessThanOrEqual(stats.poolData.overallUtilization, 1, "Utilization should not exceed 100%")
            XCTAssertGreaterThan(stats.poolData.activeReserves, 0, "Should have active reserves")
            
            // Validate USDC reserve data
            XCTAssertGreaterThan(stats.usdcReserveData.totalSupplied, 0, "USDC supplied should be positive")
            XCTAssertGreaterThanOrEqual(stats.usdcReserveData.totalBorrowed, 0, "USDC borrowed should be non-negative")
            XCTAssertGreaterThanOrEqual(stats.usdcReserveData.utilizationRate, 0, "USDC utilization should be non-negative")
            XCTAssertLessThanOrEqual(stats.usdcReserveData.utilizationRate, 1, "USDC utilization should not exceed 100%")
            
            // Validate APR/APY values are reasonable
            XCTAssertGreaterThanOrEqual(stats.usdcReserveData.supplyApr, 0, "Supply APR should be non-negative")
            XCTAssertLessThan(stats.usdcReserveData.supplyApr, 100, "Supply APR should be reasonable")
            XCTAssertGreaterThanOrEqual(stats.usdcReserveData.borrowApr, 0, "Borrow APR should be non-negative")
            XCTAssertLessThan(stats.usdcReserveData.borrowApr, 100, "Borrow APR should be reasonable")
            
            // Validate collateral factors
            XCTAssertGreaterThan(stats.usdcReserveData.collateralFactor, 0, "Collateral factor should be positive")
            XCTAssertLessThanOrEqual(stats.usdcReserveData.collateralFactor, 1, "Collateral factor should not exceed 100%")
            XCTAssertGreaterThan(stats.usdcReserveData.liabilityFactor, 1, "Liability factor should be > 100%")
            
            // Validate backstop data
            XCTAssertGreaterThan(stats.backstopData.totalBackstop, 0, "Backstop should be positive")
            XCTAssertGreaterThanOrEqual(stats.backstopData.backstopApr, 0, "Backstop APR should be non-negative")
            XCTAssertGreaterThanOrEqual(stats.backstopData.q4wPercentage, 0, "Q4W percentage should be non-negative")
            XCTAssertLessThanOrEqual(stats.backstopData.q4wPercentage, 100, "Q4W percentage should not exceed 100%")
            
            // Validate timestamp
            let timeSinceUpdate = Date().timeIntervalSince(stats.lastUpdated)
            XCTAssertLessThan(timeSinceUpdate, 60, "Stats should be recently updated")
        }
    }
    
    func testRefreshTruePoolStats_withRealContract_returnsValidData() async throws {
        // Given
        let statsExpectation = XCTestExpectation(description: "True pool stats updated")
        var receivedStats: TruePoolStats?
        
        sut.$truePoolStats
            .compactMap { $0 }
            .sink { stats in
                receivedStats = stats
                statsExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        try await sut.refreshTruePoolStats()
        
        // Then
        await fulfillment(of: [statsExpectation], timeout: testTimeout)
        
        XCTAssertNotNil(receivedStats)
        
        if let stats = receivedStats {
            // Validate aggregated totals
            XCTAssertGreaterThan(stats.totalSuppliedUSD, 0, "Total supplied should be positive")
            XCTAssertGreaterThanOrEqual(stats.totalBorrowedUSD, 0, "Total borrowed should be non-negative")
            XCTAssertGreaterThan(stats.backstopBalanceUSD, 0, "Backstop balance should be positive")
            
            // Validate utilization calculation
            let expectedUtilization = stats.totalSuppliedUSD > 0 ? stats.totalBorrowedUSD / stats.totalSuppliedUSD : 0
            XCTAssertEqual(stats.overallUtilization, expectedUtilization, accuracy: 0.001, "Utilization should be calculated correctly")
            
            // Validate backstop rate
            XCTAssertGreaterThan(stats.backstopRate, 0, "Backstop rate should be positive")
            XCTAssertLessThan(stats.backstopRate, 1, "Backstop rate should be less than 100%")
            
            // Validate pool status
            XCTAssertTrue([0, 1, 2, 3].contains(stats.poolStatus), "Pool status should be valid")
            
            // Validate reserves
            XCTAssertGreaterThan(stats.reserves.count, 0, "Should have at least one reserve")
            
            for reserve in stats.reserves {
                XCTAssertFalse(reserve.symbol.isEmpty, "Reserve symbol should not be empty")
                XCTAssertFalse(reserve.asset.isEmpty, "Reserve asset address should not be empty")
                XCTAssertGreaterThanOrEqual(reserve.totalSupplied, 0, "Reserve supplied should be non-negative")
                XCTAssertGreaterThanOrEqual(reserve.totalBorrowed, 0, "Reserve borrowed should be non-negative")
                XCTAssertGreaterThanOrEqual(reserve.utilizationRate, 0, "Reserve utilization should be non-negative")
                XCTAssertLessThanOrEqual(reserve.utilizationRate, 1, "Reserve utilization should not exceed 100%")
                XCTAssertGreaterThan(reserve.scalar, 0, "Reserve scalar should be positive")
                XCTAssertGreaterThan(reserve.price, 0, "Reserve price should be positive")
            }
        }
    }
    
    func testGetPoolConfig_withRealContract_returnsValidConfig() async throws {
        // When
        let config = try await sut.getPoolConfigNew()
        
        // Then
        XCTAssertGreaterThan(config.backstopRate, 0, "Backstop rate should be positive")
        XCTAssertLessThan(config.backstopRate, 10000, "Backstop rate should be reasonable (in basis points)")
        XCTAssertGreaterThan(config.maxPositions, 0, "Max positions should be positive")
        XCTAssertLessThan(config.maxPositions, 100, "Max positions should be reasonable")
        XCTAssertGreaterThanOrEqual(config.minCollateral, 0, "Min collateral should be non-negative")
        XCTAssertFalse(config.oracle.isEmpty, "Oracle address should not be empty")
        XCTAssertTrue([0, 1, 2, 3].contains(config.status), "Pool status should be valid")
        
        // Validate oracle address format (should be a valid Stellar contract address)
        XCTAssertEqual(config.oracle.count, 56, "Oracle address should be 56 characters")
        XCTAssertTrue(config.oracle.hasPrefix("C"), "Oracle address should start with 'C'")
    }
    
    func testGetPoolStatus_withRealContract_returnsValidStatus() async throws {
        // When
        let status = try await sut.getPoolStatus()
        
        // Then
        // Pool should be active on testnet
        XCTAssertTrue(status.isActive, "Pool should be active on testnet")
        XCTAssertGreaterThan(status.blockHeight, 0, "Block height should be positive")
        
        // Last update should be recent
        let timeSinceUpdate = Date().timeIntervalSince(status.lastUpdate)
        XCTAssertLessThan(timeSinceUpdate, 3600, "Status should be recently updated (within 1 hour)")
    }
    
    func testGetUserPositions_withTestUser_returnsValidPositions() async throws {
        // Given
        let userAddress = testPublicKey
        
        // When
        let positions = try await sut.getUserPositions(userAddress: userAddress)
        
        // Then
        XCTAssertEqual(positions.userAddress, userAddress, "User address should match")
        
        // Validate position data structure (values may be zero for test user)
        XCTAssertNotNil(positions.collateral, "Collateral should not be nil")
        XCTAssertNotNil(positions.liabilities, "Liabilities should not be nil")
        XCTAssertNotNil(positions.supply, "Supply should not be nil")
        
        // All position values should be non-negative
        for (asset, amount) in positions.collateral {
            XCTAssertGreaterThanOrEqual(amount, 0, "Collateral for \(asset) should be non-negative")
        }
        
        for (asset, amount) in positions.liabilities {
            XCTAssertGreaterThanOrEqual(amount, 0, "Liabilities for \(asset) should be non-negative")
        }
        
        for (asset, amount) in positions.supply {
            XCTAssertGreaterThanOrEqual(amount, 0, "Supply for \(asset) should be non-negative")
        }
    }
    
    func testGetUserEmissions_withTestUser_returnsValidEmissions() async throws {
        // Given
        let userAddress = testPublicKey
        
        // When
        let emissions = try await sut.getUserEmissions(userAddress: userAddress)
        
        // Then
        XCTAssertEqual(emissions.userAddress, userAddress, "User address should match")
        XCTAssertNotNil(emissions.claimableEmissions, "Claimable emissions should not be nil")
        XCTAssertGreaterThanOrEqual(emissions.totalEmissions, 0, "Total emissions should be non-negative")
        
        // All claimable emissions should be non-negative
        for (asset, amount) in emissions.claimableEmissions {
            XCTAssertGreaterThanOrEqual(amount, 0, "Claimable emissions for \(asset) should be non-negative")
        }
    }
    
    func testGetAllReserveData_withRealContract_returnsValidReserves() async throws {
        // When
        let allReserves = try await sut.getAllReserveData()
        
        // Then
        XCTAssertGreaterThan(allReserves.count, 0, "Should have at least one reserve")
        
        for (symbol, reserveData) in allReserves {
            XCTAssertFalse(symbol.isEmpty, "Symbol should not be empty")
            XCTAssertFalse(reserveData.assetAddress.isEmpty, "Asset address should not be empty")
            XCTAssertGreaterThanOrEqual(reserveData.totalSupplied, 0, "Total supplied should be non-negative")
            XCTAssertGreaterThanOrEqual(reserveData.totalBorrowed, 0, "Total borrowed should be non-negative")
            XCTAssertGreaterThanOrEqual(reserveData.utilizationRate, 0, "Utilization rate should be non-negative")
            XCTAssertLessThanOrEqual(reserveData.utilizationRate, 1, "Utilization rate should not exceed 100%")
            XCTAssertGreaterThanOrEqual(reserveData.supplyAPY, 0, "Supply APY should be non-negative")
            XCTAssertLessThan(reserveData.supplyAPY, 100, "Supply APY should be reasonable")
            XCTAssertGreaterThanOrEqual(reserveData.borrowAPY, 0, "Borrow APY should be non-negative")
            XCTAssertLessThan(reserveData.borrowAPY, 100, "Borrow APY should be reasonable")
            XCTAssertGreaterThan(reserveData.scalar, 0, "Scalar should be positive")
        }
    }
    
    func testGetPoolSummary_withRealData_returnsValidSummary() async throws {
        // Given - First refresh pool stats to get real data
        try await sut.refreshPoolStats()
        
        // Wait for stats to be updated
        let expectation = XCTestExpectation(description: "Pool stats updated")
        sut.$comprehensivePoolStats
            .compactMap { $0 }
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: testTimeout)
        
        // When
        let summary = sut.getPoolSummary()
        
        // Then
        XCTAssertNotNil(summary, "Summary should not be nil with valid stats")
        
        if let summary = summary {
            XCTAssertGreaterThan(summary.totalValueLocked, 0, "TVL should be positive")
            XCTAssertGreaterThanOrEqual(summary.totalBorrowed, 0, "Total borrowed should be non-negative")
            XCTAssertGreaterThanOrEqual(summary.overallUtilization, 0, "Overall utilization should be non-negative")
            XCTAssertLessThanOrEqual(summary.overallUtilization, 1, "Overall utilization should not exceed 100%")
            XCTAssertGreaterThanOrEqual(summary.healthScore, 0, "Health score should be non-negative")
            XCTAssertLessThanOrEqual(summary.healthScore, 1, "Health score should not exceed 100%")
            XCTAssertGreaterThan(summary.activeAssets, 0, "Should have active assets")
            XCTAssertFalse(summary.topAssetByTVL.isEmpty, "Top asset should not be empty")
            XCTAssertGreaterThanOrEqual(summary.averageSupplyAPY, 0, "Average supply APY should be non-negative")
        }
    }
    
    // MARK: - Performance Tests with Real Contract
    
    func testRefreshPoolStats_realContractPerformance_completesWithinTimeLimit() async throws {
        // Given
        let maxDuration: TimeInterval = 30.0 // 30 seconds for real contract calls
        
        // When
        let (_, duration) = try await TestConfiguration.measureTimeAsync {
            try await sut.refreshPoolStats()
        }
        
        // Then
        TestConfiguration.assertDuration(duration, lessThan: maxDuration)
        XCTAssertNotNil(sut.poolStats, "Pool stats should be updated")
    }
    
    func testRefreshTruePoolStats_realContractPerformance_completesWithinTimeLimit() async throws {
        // Given
        let maxDuration: TimeInterval = 45.0 // 45 seconds for comprehensive stats
        
        // When
        let (_, duration) = try await TestConfiguration.measureTimeAsync {
            try await sut.refreshTruePoolStats()
        }
        
        // Then
        TestConfiguration.assertDuration(duration, lessThan: maxDuration)
        XCTAssertNotNil(sut.truePoolStats, "True pool stats should be updated")
    }
    
    func testGetAllReserveData_realContractPerformance_completesWithinTimeLimit() async throws {
        // Given
        let maxDuration: TimeInterval = 60.0 // 60 seconds for all reserves
        
        // When
        let (result, duration) = try await TestConfiguration.measureTimeAsync {
            try await sut.getAllReserveData()
        }
        
        // Then
        TestConfiguration.assertDuration(duration, lessThan: maxDuration)
        XCTAssertGreaterThan(result.count, 0, "Should return reserve data")
    }
    
    // MARK: - Error Handling with Real Contract
    
    func testGetUserPositions_withInvalidUser_handlesGracefully() async throws {
        // Given
        let invalidUserAddress = "INVALID_USER_ADDRESS_THAT_DOES_NOT_EXIST"
        
        // When/Then
        do {
            _ = try await sut.getUserPositions(userAddress: invalidUserAddress)
            // May succeed with empty positions or fail gracefully
        } catch {
            // Should handle invalid user gracefully
            XCTAssertTrue(error is BlendVaultError, "Should throw BlendVaultError for invalid user")
        }
    }
    
    func testGetUserEmissions_withInvalidUser_handlesGracefully() async throws {
        // Given
        let invalidUserAddress = "INVALID_USER_ADDRESS_THAT_DOES_NOT_EXIST"
        
        // When/Then
        do {
            _ = try await sut.getUserEmissions(userAddress: invalidUserAddress)
            // May succeed with zero emissions or fail gracefully
        } catch {
            // Should handle invalid user gracefully
            XCTAssertTrue(error is BlendVaultError, "Should throw BlendVaultError for invalid user")
        }
    }
    
    // MARK: - State Management with Real Data
    
    func testLoadingState_withRealContract_managedCorrectly() async throws {
        // Given
        let loadingExpectation = XCTestExpectation(description: "Loading state changes")
        var loadingStates: [Bool] = []
        
        sut.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count >= 3 { // Initial false, true during operation, false after
                    loadingExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        try await sut.refreshPoolStats()
        
        // Then
        await fulfillment(of: [loadingExpectation], timeout: testTimeout)
        XCTAssertEqual(loadingStates.first, false, "Should start with loading false")
        XCTAssertTrue(loadingStates.contains(true), "Should set loading true during operation")
        XCTAssertEqual(loadingStates.last, false, "Should end with loading false")
    }
    
    func testErrorState_withRealContract_clearsOnSuccess() async throws {
        // Given - Set initial error state
        await MainActor.run {
            sut.error = BlendVaultError.networkError("Test error")
        }
        XCTAssertNotNil(sut.error)
        
        // When - Perform successful operation
        try await sut.refreshPoolStats()
        
        // Then - Error should be cleared
        XCTAssertNil(sut.error, "Error should be cleared after successful operation")
        XCTAssertNotNil(sut.poolStats, "Pool stats should be updated")
    }
    
    // MARK: - Data Consistency Tests
    
    func testPoolStatsConsistency_withRealContract_dataIsConsistent() async throws {
        // When
        try await sut.refreshPoolStats()
        try await sut.refreshTruePoolStats()
        
        // Then
        XCTAssertNotNil(sut.poolStats)
        XCTAssertNotNil(sut.truePoolStats)
        
        if let poolStats = sut.poolStats, let trueStats = sut.truePoolStats {
            // Basic consistency checks
            XCTAssertGreaterThan(poolStats.poolData.totalValueLocked, 0)
            XCTAssertGreaterThan(trueStats.totalSuppliedUSD, 0)
            
            // Utilization should be consistent
            let poolUtilization = poolStats.poolData.overallUtilization
            let trueUtilization = trueStats.overallUtilization
            XCTAssertEqual(poolUtilization, trueUtilization, accuracy: 0.1, "Utilization should be consistent between stats")
        }
    }
    
    // MARK: - Stress Tests
    
    func testMultipleConcurrentRefreshes_withRealContract_handlesCorrectly() async throws {
        // Given
        let concurrentOperations = 5
        
        // When
        let results = try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentOperations {
                group.addTask {
                    try await self.sut.refreshPoolStats()
                }
            }
            
            var completedOperations = 0
            for try await _ in group {
                completedOperations += 1
            }
            return completedOperations
        }
        
        // Then
        XCTAssertEqual(results, concurrentOperations, "All concurrent operations should complete")
        XCTAssertNotNil(sut.poolStats, "Pool stats should be updated")
        XCTAssertFalse(sut.isLoading, "Should not be loading after all operations complete")
    }
}

// MARK: - Test Utilities

extension BlendUSDCVaultIntegrationTests {
    
    /// Helper to skip test if integration tests are disabled
    private func skipIfIntegrationTestsDisabled() throws {
        guard TestConfiguration.runIntegrationTests else {
            throw XCTSkip("Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable.")
        }
    }
    
    /// Helper to validate pool stats structure
    private func validatePoolStatsStructure(_ stats: BlendPoolStats) {
        XCTAssertGreaterThan(stats.poolData.totalValueLocked, 0)
        XCTAssertGreaterThanOrEqual(stats.poolData.overallUtilization, 0)
        XCTAssertLessThanOrEqual(stats.poolData.overallUtilization, 1)
        XCTAssertGreaterThan(stats.poolData.activeReserves, 0)
        
        XCTAssertGreaterThan(stats.usdcReserveData.totalSupplied, 0)
        XCTAssertGreaterThanOrEqual(stats.usdcReserveData.totalBorrowed, 0)
        XCTAssertGreaterThanOrEqual(stats.usdcReserveData.utilizationRate, 0)
        XCTAssertLessThanOrEqual(stats.usdcReserveData.utilizationRate, 1)
        
        XCTAssertGreaterThan(stats.backstopData.totalBackstop, 0)
        XCTAssertGreaterThanOrEqual(stats.backstopData.backstopApr, 0)
    }
    
    /// Helper to validate true pool stats structure
    private func validateTruePoolStatsStructure(_ stats: TruePoolStats) {
        XCTAssertGreaterThan(stats.totalSuppliedUSD, 0)
        XCTAssertGreaterThanOrEqual(stats.totalBorrowedUSD, 0)
        XCTAssertGreaterThan(stats.backstopBalanceUSD, 0)
        XCTAssertGreaterThanOrEqual(stats.overallUtilization, 0)
        XCTAssertLessThanOrEqual(stats.overallUtilization, 1)
        XCTAssertGreaterThan(stats.backstopRate, 0)
        XCTAssertLessThan(stats.backstopRate, 1)
        XCTAssertGreaterThan(stats.reserves.count, 0)
    }
} 