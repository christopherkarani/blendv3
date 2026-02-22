//
//  BlendVaultAdapterTests.swift
//  Blendv3Tests
//
//  Unit tests for BlendVaultAdapter
//

import XCTest
import Combine
@testable import Blendv3

final class BlendVaultAdapterTests: XCTestCase {
    
    var sut: BlendVaultAdapter!
    var mockLegacyVault: MockBlendUSDCVault!
    var mockNewVault: MockBlendVault!
    var mockDiagnosticsService: MockDiagnosticsService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockLegacyVault = MockBlendUSDCVault()
        mockNewVault = MockBlendVault()
        mockDiagnosticsService = MockDiagnosticsService()
        cancellables = []
        
        let config = MigrationConfiguration(
            startDate: Date(),
            initialFeatureFlags: FeatureFlags(),
            rolloutPercentage: [:],
            enableFallback: true,
            comparisonMode: false
        )
        
        sut = BlendVaultAdapter(
            legacyVault: mockLegacyVault,
            newVault: mockNewVault,
            migrationConfig: config,
            diagnosticsService: mockDiagnosticsService
        )
    }
    
    override func tearDown() {
        sut = nil
        mockLegacyVault = nil
        mockNewVault = nil
        mockDiagnosticsService = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialize_UsesLegacyByDefault() async throws {
        // When
        try await sut.initialize()
        
        // Then
        XCTAssertTrue(mockLegacyVault.initializeCalled)
        XCTAssertFalse(mockNewVault.initializeCalled)
    }
    
    func testInitialize_UsesNewWhenEnabled() async throws {
        // Given
        sut.updateFeatureFlag(.useNewArchitecture, enabled: true)
        sut.enableOperation(.initialization)
        
        // When
        try await sut.initialize()
        
        // Then
        XCTAssertFalse(mockLegacyVault.initializeCalled)
        XCTAssertTrue(mockNewVault.initializeCalled)
    }
    
    // MARK: - Transaction Operation Tests
    
    func testDeposit_RoutesToCorrectImplementation() async throws {
        // Given
        let amount: Decimal = 100
        mockLegacyVault.mockTransactionId = "legacy_tx"
        mockNewVault.mockTransactionId = "new_tx"
        
        // When - Legacy
        let legacyResult = try await sut.deposit(amount: amount)
        
        // Then
        XCTAssertEqual(legacyResult, "legacy_tx")
        XCTAssertTrue(mockLegacyVault.depositCalled)
        XCTAssertFalse(mockNewVault.depositCalled)
        
        // Reset
        mockLegacyVault.depositCalled = false
        
        // When - New
        sut.updateFeatureFlag(.useNewArchitecture, enabled: true)
        sut.enableOperation(.deposit)
        let newResult = try await sut.deposit(amount: amount)
        
        // Then
        XCTAssertEqual(newResult, "new_tx")
        XCTAssertFalse(mockLegacyVault.depositCalled)
        XCTAssertTrue(mockNewVault.depositCalled)
    }
    
    func testWithdraw_HandlesErrors() async throws {
        // Given
        mockLegacyVault.shouldThrowError = true
        
        // When/Then
        do {
            _ = try await sut.withdraw(shares: 50)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is BlendError)
        }
    }
    
    // MARK: - Fallback Tests
    
    func testFallback_WhenNewImplementationFails() async throws {
        // Given
        sut.updateFeatureFlag(.useNewArchitecture, enabled: true)
        sut.enableOperation(.borrow)
        mockNewVault.shouldThrowError = true
        mockLegacyVault.mockTransactionId = "fallback_tx"
        
        // When
        let result = try await sut.borrow(amount: 200)
        
        // Then
        XCTAssertEqual(result, "fallback_tx")
        XCTAssertTrue(mockNewVault.borrowCalled)
        XCTAssertTrue(mockLegacyVault.borrowCalled) // Fallback was used
    }
    
    // MARK: - Feature Flag Tests
    
    func testUpdateFeatureFlag_UpdatesStatus() {
        // Given
        var receivedStatuses: [MigrationStatus] = []
        
        sut.migrationStatusPublisher
            .sink { status in
                receivedStatuses.append(status)
            }
            .store(in: &cancellables)
        
        // When
        sut.updateFeatureFlag(.useNewArchitecture, enabled: true)
        
        // Then
        XCTAssertGreaterThan(receivedStatuses.count, 0)
    }
    
    func testEnableOperation_UpdatesMetrics() {
        // Given
        sut.updateFeatureFlag(.useNewArchitecture, enabled: true)
        
        // When
        sut.enableOperation(.deposit)
        sut.enableOperation(.withdraw)
        
        let metrics = sut.getMigrationMetrics()
        
        // Then
        XCTAssertEqual(metrics.enabledOperations.count, 2)
        XCTAssertTrue(metrics.enabledOperations.contains(.deposit))
        XCTAssertTrue(metrics.enabledOperations.contains(.withdraw))
    }
    
    // MARK: - A/B Testing Tests
    
    func testRunComparison_ComparesResults() async {
        // Given
        mockLegacyVault.mockPoolData = PoolData(
            totalSupply: 1000,
            totalBorrow: 500,
            supplyAPR: 5.0,
            borrowAPR: 8.0
        )
        mockNewVault.mockPoolData = PoolData(
            totalSupply: 1000,
            totalBorrow: 500,
            supplyAPR: 5.0,
            borrowAPR: 8.0
        )
        
        // When
        let comparison = await sut.runComparison(
            operation: .getPoolData,
            legacy: { self.mockLegacyVault.mockPoolData },
            new: { self.mockNewVault.mockPoolData }
        )
        
        // Then
        XCTAssertTrue(comparison.resultsMatch)
    }
    
    func testRunComparison_DetectsMismatch() async {
        // Given
        mockLegacyVault.mockPoolData = PoolData(
            totalSupply: 1000,
            totalBorrow: 500,
            supplyAPR: 5.0,
            borrowAPR: 8.0
        )
        mockNewVault.mockPoolData = PoolData(
            totalSupply: 2000, // Different value
            totalBorrow: 500,
            supplyAPR: 5.0,
            borrowAPR: 8.0
        )
        
        // When
        let comparison = await sut.runComparison(
            operation: .getPoolData,
            legacy: { self.mockLegacyVault.mockPoolData },
            new: { self.mockNewVault.mockPoolData }
        )
        
        // Then
        XCTAssertFalse(comparison.resultsMatch)
    }
    
    // MARK: - Migration Metrics Tests
    
    func testGetMigrationMetrics_CalculatesProgress() {
        // Given
        sut.updateFeatureFlag(.useNewArchitecture, enabled: true)
        
        // When - No operations enabled
        var metrics = sut.getMigrationMetrics()
        XCTAssertEqual(metrics.progress, 0.0)
        
        // Enable half of operations
        let halfCount = VaultOperation.allCases.count / 2
        for (index, operation) in VaultOperation.allCases.enumerated() {
            if index < halfCount {
                sut.enableOperation(operation)
            }
        }
        
        // Then
        metrics = sut.getMigrationMetrics()
        XCTAssertEqual(metrics.progress, 0.5, accuracy: 0.1)
    }
    
    // MARK: - Percentage Rollout Tests
    
    func testPercentageRollout_RespectedForOperations() async throws {
        // Given
        let config = MigrationConfiguration(
            startDate: Date(),
            initialFeatureFlags: {
                let flags = FeatureFlags()
                flags.setFlag(.useNewArchitecture, enabled: true)
                return flags
            }(),
            rolloutPercentage: [.claim: 0], // 0% rollout for claim
            enableFallback: false,
            comparisonMode: false
        )
        
        let adapter = BlendVaultAdapter(
            legacyVault: mockLegacyVault,
            newVault: mockNewVault,
            migrationConfig: config,
            diagnosticsService: mockDiagnosticsService
        )
        
        adapter.enableOperation(.claim)
        
        // When - Run multiple times
        for _ in 0..<10 {
            _ = try? await adapter.claim()
        }
        
        // Then - Should always use legacy due to 0% rollout
        XCTAssertGreaterThan(mockLegacyVault.claimCallCount, 0)
        XCTAssertEqual(mockNewVault.claimCallCount, 0)
    }
}

// MARK: - Mock Classes

private class MockBlendUSDCVault: BlendUSDCVault {
    var initializeCalled = false
    var depositCalled = false
    var withdrawCalled = false
    var borrowCalled = false
    var repayCalled = false
    var claimCallCount = 0
    
    var shouldThrowError = false
    var mockTransactionId = "mock_tx"
    var mockPoolData: PoolData?
    
    override func initialize() async throws {
        initializeCalled = true
        if shouldThrowError {
            throw BlendError.network(.connectionFailed)
        }
    }
    
    override func deposit(amount: Decimal) async throws -> String {
        depositCalled = true
        if shouldThrowError {
            throw BlendError.transaction(.failed)
        }
        return mockTransactionId
    }
    
    override func withdraw(shares: Decimal) async throws -> String {
        withdrawCalled = true
        if shouldThrowError {
            throw BlendError.transaction(.failed)
        }
        return mockTransactionId
    }
    
    override func borrow(amount: Decimal) async throws -> String {
        borrowCalled = true
        if shouldThrowError {
            throw BlendError.transaction(.failed)
        }
        return mockTransactionId
    }
    
    override func repay(amount: Decimal) async throws -> String {
        repayCalled = true
        if shouldThrowError {
            throw BlendError.transaction(.failed)
        }
        return mockTransactionId
    }
    
    override func claim() async throws -> String {
        claimCallCount += 1
        if shouldThrowError {
            throw BlendError.transaction(.failed)
        }
        return mockTransactionId
    }
    
    override func getPoolData() async throws -> PoolData? {
        if shouldThrowError {
            throw BlendError.network(.serverError)
        }
        return mockPoolData
    }
}

private class MockBlendVault {
    var initializeCalled = false
    var depositCalled = false
    var withdrawCalled = false
    var borrowCalled = false
    var repayCalled = false
    var claimCallCount = 0
    
    var shouldThrowError = false
    var mockTransactionId = "new_mock_tx"
    var mockPoolData: PoolData?
    
    func initialize() async throws {
        initializeCalled = true
        if shouldThrowError {
            throw BlendError.network(.connectionFailed)
        }
    }
    
    func deposit(amount: Decimal) async throws -> String {
        depositCalled = true
        if shouldThrowError {
            throw BlendError.transaction(.failed)
        }
        return mockTransactionId
    }
    
    func withdraw(shares: Decimal) async throws -> String {
        withdrawCalled = true
        if shouldThrowError {
            throw BlendError.transaction(.failed)
        }
        return mockTransactionId
    }
    
    func borrow(amount: Decimal) async throws -> String {
        borrowCalled = true
        if shouldThrowError {
            throw BlendError.transaction(.failed)
        }
        return mockTransactionId
    }
    
    func repay(amount: Decimal) async throws -> String {
        repayCalled = true
        if shouldThrowError {
            throw BlendError.transaction(.failed)
        }
        return mockTransactionId
    }
    
    func claim() async throws -> String {
        claimCallCount += 1
        if shouldThrowError {
            throw BlendError.transaction(.failed)
        }
        return mockTransactionId
    }
    
    func getPoolData() async throws -> PoolData? {
        if shouldThrowError {
            throw BlendError.network(.serverError)
        }
        return mockPoolData
    }
    
    func getUserPositions() async throws -> UserPositions? {
        return nil
    }
    
    func getReserveData() async throws -> [ReserveData] {
        return []
    }
}

// MARK: - Test Helpers

private struct PoolData: Equatable {
    let totalSupply: Decimal
    let totalBorrow: Decimal
    let supplyAPR: Decimal
    let borrowAPR: Decimal
} 