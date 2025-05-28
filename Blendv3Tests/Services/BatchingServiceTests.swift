//
//  BatchingServiceTests.swift
//  Blendv3Tests
//
//  Unit tests for BatchingService
//

import XCTest
@testable import Blendv3
import stellarsdk

final class BatchingServiceTests: XCTestCase {
    
    var sut: BatchingService!
    var mockNetworkService: MockNetworkService!
    var mockDiagnosticsService: MockDiagnosticsService!
    
    override func setUp() async throws {
        try await super.setUp()
        mockNetworkService = MockNetworkService()
        mockDiagnosticsService = MockDiagnosticsService()
        sut = BatchingService(
            networkService: mockNetworkService,
            diagnosticsService: mockDiagnosticsService
        )
    }
    
    override func tearDown() async throws {
        sut = nil
        mockNetworkService = nil
        mockDiagnosticsService = nil
        try await super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testConfigureBatching_UpdatesConfiguration() async {
        // Given
        let maxBatchSize = 20
        let maxWaitTime: TimeInterval = 1.0
        
        // When
        await sut.configureBatching(maxBatchSize: maxBatchSize, maxWaitTime: maxWaitTime)
        let stats = await sut.getStatistics()
        
        // Then
        XCTAssertEqual(stats.maxBatchSize, maxBatchSize)
        XCTAssertEqual(stats.maxWaitTime, maxWaitTime)
    }
    
    // MARK: - Batching Tests
    
    func testBatch_SingleRequest_ProcessesImmediately() async throws {
        // Given
        let request = BatchableRequest(
            type: .getLedgerEntry(key: "test_key"),
            priority: .normal
        )
        mockNetworkService.mockLedgerEntries = [Data("test_data".utf8)]
        
        // When
        let results: [Data] = try await sut.batch([request])
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, Data("test_data".utf8))
    }
    
    func testBatch_MultipleLedgerEntries_BatchesTogether() async throws {
        // Given
        let requests = (1...5).map { i in
            BatchableRequest(
                type: .getLedgerEntry(key: "key_\(i)"),
                priority: .normal
            )
        }
        mockNetworkService.mockLedgerEntries = (1...5).map { Data("data_\($0)".utf8) }
        
        // When
        let results: [Data] = try await sut.batch(requests)
        
        // Then
        XCTAssertEqual(results.count, 5)
        XCTAssertEqual(mockNetworkService.getLedgerEntriesCallCount, 1) // Single batched call
    }
    
    func testBatch_ExceedsMaxBatchSize_ProcessesInMultipleBatches() async throws {
        // Given
        await sut.configureBatching(maxBatchSize: 3, maxWaitTime: 0.1)
        
        let requests = (1...7).map { i in
            BatchableRequest(
                type: .getLedgerEntry(key: "key_\(i)"),
                priority: .normal
            )
        }
        mockNetworkService.mockLedgerEntries = (1...7).map { Data("data_\($0)".utf8) }
        
        // When
        let results: [Data] = try await sut.batch(requests)
        
        // Then
        XCTAssertEqual(results.count, 7)
        // Should be processed in multiple batches due to size limit
        let stats = await sut.getStatistics()
        XCTAssertGreaterThan(stats.totalBatches, 1)
    }
    
    // MARK: - Priority Tests
    
    func testBatch_MixedPriorities_ProcessesCorrectly() async throws {
        // Given
        let highPriorityRequest = BatchableRequest(
            type: .getLedgerEntry(key: "high"),
            priority: .high
        )
        let normalPriorityRequest = BatchableRequest(
            type: .getLedgerEntry(key: "normal"),
            priority: .normal
        )
        
        mockNetworkService.mockLedgerEntries = [
            Data("high_data".utf8),
            Data("normal_data".utf8)
        ]
        
        // When
        let results: [Data] = try await sut.batch([highPriorityRequest, normalPriorityRequest])
        
        // Then
        XCTAssertEqual(results.count, 2)
    }
    
    // MARK: - Error Handling Tests
    
    func testBatch_NetworkError_ThrowsError() async {
        // Given
        let request = BatchableRequest(
            type: .getLedgerEntry(key: "test_key"),
            priority: .normal
        )
        mockNetworkService.shouldThrowError = true
        
        // When/Then
        do {
            let _: [Data] = try await sut.batch([request])
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is BlendError)
        }
    }
    
    // MARK: - Statistics Tests
    
    func testGetStatistics_InitialState() async {
        // When
        let stats = await sut.getStatistics()
        
        // Then
        XCTAssertEqual(stats.totalBatches, 0)
        XCTAssertEqual(stats.totalRequests, 0)
        XCTAssertEqual(stats.averageBatchSize, 0)
        XCTAssertEqual(stats.pendingRequests, 0)
    }
    
    func testGetStatistics_AfterProcessing_UpdatesCorrectly() async throws {
        // Given
        let requests = (1...3).map { i in
            BatchableRequest(
                type: .getLedgerEntry(key: "key_\(i)"),
                priority: .normal
            )
        }
        mockNetworkService.mockLedgerEntries = (1...3).map { Data("data_\($0)".utf8) }
        
        // When
        let _: [Data] = try await sut.batch(requests)
        let stats = await sut.getStatistics()
        
        // Then
        XCTAssertEqual(stats.totalBatches, 1)
        XCTAssertEqual(stats.totalRequests, 3)
        XCTAssertEqual(stats.averageBatchSize, 3.0)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testBatch_ConcurrentRequests_HandlesCorrectly() async throws {
        // Given
        mockNetworkService.mockLedgerEntries = Array(repeating: Data("data".utf8), count: 20)
        
        // When - Submit multiple batches concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    let requests = [
                        BatchableRequest(
                            type: .getLedgerEntry(key: "key_\(i)"),
                            priority: .normal
                        )
                    ]
                    let _: [Data] = try! await self.sut.batch(requests)
                }
            }
        }
        
        // Then
        let stats = await sut.getStatistics()
        XCTAssertEqual(stats.totalRequests, 5)
    }
}

// MARK: - Mock Services

private class MockNetworkService: BlendNetworkServiceProtocol {
    var mockLedgerEntries: [Data] = []
    var mockAccount: Account?
    var shouldThrowError = false
    var getLedgerEntriesCallCount = 0
    
    func simulateOperation(_ operation: Data) async throws -> Data {
        if shouldThrowError {
            throw BlendError.network(.serverError)
        }
        return operation
    }
    
    func getLedgerEntries(_ keys: [String]) async throws -> [Data] {
        getLedgerEntriesCallCount += 1
        if shouldThrowError {
            throw BlendError.network(.serverError)
        }
        return Array(mockLedgerEntries.prefix(keys.count))
    }
    
    func getAccount(accountId: String) async throws -> Account {
        if shouldThrowError {
            throw BlendError.network(.serverError)
        }
        return mockAccount ?? Account(
            accountId: accountId,
            sequenceNumber: 0
        )
    }
    
    func simulateOperation(_ operation: Operation) async throws -> SimulationResult {
        if shouldThrowError {
            throw BlendError.network(.serverError)
        }
        return SimulationResult(result: nil, cost: 0, footprint: nil)
    }
}

private class MockDiagnosticsService: DiagnosticsServiceProtocol {
    var trackedOperations: [(String, TimeInterval)] = []
    
    func logNetworkEvent(_ event: NetworkEvent) {
        // No-op
    }
    
    func logTransactionEvent(_ event: TransactionEvent) {
        // No-op
    }
    
    func performHealthCheck() async -> HealthCheckResult {
        return HealthCheckResult(
            timestamp: Date(),
            status: .healthy,
            checks: [],
            duration: 0
        )
    }
    
    func getPerformanceMetrics() -> PerformanceMetrics {
        return PerformanceMetrics()
    }
    
    func trackOperationTiming(operation: String, duration: TimeInterval) {
        trackedOperations.append((operation, duration))
    }
} 