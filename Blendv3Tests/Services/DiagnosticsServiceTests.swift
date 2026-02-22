//
//  DiagnosticsServiceTests.swift
//  Blendv3Tests
//
//  Unit tests for DiagnosticsService
//

import XCTest
import Combine
@testable import Blendv3

final class DiagnosticsServiceTests: XCTestCase {
    
    var sut: DiagnosticsService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = DiagnosticsService()
        cancellables = []
    }
    
    override func tearDown() async throws {
        sut = nil
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Network Event Tests
    
    func testLogNetworkEvent_StoresEvent() async {
        // Given
        let event = NetworkEvent(
            type: .request,
            endpoint: "/test",
            method: "GET",
            statusCode: nil,
            duration: nil,
            error: nil
        )
        
        // When
        await sut.logNetworkEvent(event)
        let recentEvents = await sut.getRecentNetworkEvents(count: 10)
        
        // Then
        XCTAssertEqual(recentEvents.count, 1)
        XCTAssertEqual(recentEvents.first?.endpoint, "/test")
    }
    
    func testLogNetworkEvent_TrimsOldEvents() async {
        // Given - Log more than maxEventCount (1000) events
        for i in 0..<1100 {
            let event = NetworkEvent(
                type: .request,
                endpoint: "/test\(i)",
                method: "GET",
                statusCode: 200,
                duration: 0.1,
                error: nil
            )
            await sut.logNetworkEvent(event)
        }
        
        // When
        let recentEvents = await sut.getRecentNetworkEvents(count: 1100)
        
        // Then
        XCTAssertEqual(recentEvents.count, 1000) // Should be trimmed to max
    }
    
    // MARK: - Transaction Event Tests
    
    func testLogTransactionEvent_StoresEvent() async {
        // Given
        let event = TransactionEvent(
            type: .submitted,
            transactionId: "tx123",
            operation: "deposit",
            success: true,
            error: nil,
            gasUsed: 1000
        )
        
        // When
        await sut.logTransactionEvent(event)
        let recentEvents = await sut.getRecentTransactionEvents(count: 10)
        
        // Then
        XCTAssertEqual(recentEvents.count, 1)
        XCTAssertEqual(recentEvents.first?.transactionId, "tx123")
    }
    
    // MARK: - Health Check Tests
    
    func testPerformHealthCheck_ReturnsResult() async {
        // When
        let result = await sut.performHealthCheck()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertFalse(result.checks.isEmpty)
        XCTAssertTrue(result.duration >= 0)
    }
    
    func testPerformHealthCheck_ChecksAllComponents() async {
        // When
        let result = await sut.performHealthCheck()
        
        // Then
        let checkNames = result.checks.map { $0.name }
        XCTAssertTrue(checkNames.contains("Network Connectivity"))
        XCTAssertTrue(checkNames.contains("Memory Usage"))
        XCTAssertTrue(checkNames.contains("Performance"))
        XCTAssertTrue(checkNames.contains("Error Rate"))
    }
    
    func testHealthStatusPublisher_UpdatesOnHealthCheck() async {
        // Given
        var receivedStatuses: [HealthStatus] = []
        
        sut.healthStatusPublisher
            .sink { status in
                receivedStatuses.append(status)
            }
            .store(in: &cancellables)
        
        // When
        _ = await sut.performHealthCheck()
        
        // Allow time for publisher to emit
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Then
        XCTAssertGreaterThan(receivedStatuses.count, 0)
    }
    
    // MARK: - Performance Metrics Tests
    
    func testGetPerformanceMetrics_InitialState() async {
        // When
        let metrics = await sut.getPerformanceMetrics()
        
        // Then
        XCTAssertEqual(metrics.totalRequests, 0)
        XCTAssertEqual(metrics.totalErrors, 0)
        XCTAssertEqual(metrics.successfulTransactions, 0)
        XCTAssertEqual(metrics.failedTransactions, 0)
    }
    
    func testTrackOperationTiming_UpdatesMetrics() async {
        // Given
        let operation = "testOperation"
        let duration: TimeInterval = 1.5
        
        // When
        await sut.trackOperationTiming(operation: operation, duration: duration)
        let metrics = await sut.getPerformanceMetrics()
        
        // Then
        XCTAssertNotNil(metrics.averageOperationTimings[operation])
        XCTAssertEqual(metrics.averageOperationTimings[operation], duration)
    }
    
    func testTrackOperationTiming_CalculatesAverage() async {
        // Given
        let operation = "testOperation"
        let durations: [TimeInterval] = [1.0, 2.0, 3.0]
        
        // When
        for duration in durations {
            await sut.trackOperationTiming(operation: operation, duration: duration)
        }
        let metrics = await sut.getPerformanceMetrics()
        
        // Then
        let expectedAverage = durations.reduce(0, +) / Double(durations.count)
        XCTAssertEqual(metrics.averageOperationTimings[operation], expectedAverage)
    }
    
    // MARK: - Error Summary Tests
    
    func testGetErrorSummary_NoErrors_ReturnsEmpty() async {
        // When
        let summary = await sut.getErrorSummary()
        
        // Then
        XCTAssertEqual(summary.totalErrors, 0)
        XCTAssertEqual(summary.networkErrors, 0)
        XCTAssertEqual(summary.transactionErrors, 0)
    }
    
    func testGetErrorSummary_WithErrors_CountsCorrectly() async {
        // Given
        let networkError = NetworkEvent(
            type: .error,
            endpoint: "/test",
            method: "GET",
            statusCode: 500,
            duration: nil,
            error: BlendError.network(.serverError)
        )
        
        let transactionError = TransactionEvent(
            type: .failed,
            transactionId: "tx123",
            operation: "deposit",
            success: false,
            error: BlendError.transaction(.failed),
            gasUsed: nil
        )
        
        // When
        await sut.logNetworkEvent(networkError)
        await sut.logTransactionEvent(transactionError)
        let summary = await sut.getErrorSummary()
        
        // Then
        XCTAssertEqual(summary.totalErrors, 2)
        XCTAssertEqual(summary.networkErrors, 1)
        XCTAssertEqual(summary.transactionErrors, 1)
    }
    
    // MARK: - Integration Tests
    
    func testNetworkEventLogging_UpdatesPerformanceMetrics() async {
        // Given
        let successEvent = NetworkEvent(
            type: .response,
            endpoint: "/test",
            method: "GET",
            statusCode: 200,
            duration: 0.5,
            error: nil
        )
        
        let errorEvent = NetworkEvent(
            type: .error,
            endpoint: "/test",
            method: "GET",
            statusCode: 500,
            duration: 0.2,
            error: BlendError.network(.serverError)
        )
        
        // When
        await sut.logNetworkEvent(successEvent)
        await sut.logNetworkEvent(errorEvent)
        let metrics = await sut.getPerformanceMetrics()
        
        // Then
        XCTAssertEqual(metrics.totalRequests, 2)
        XCTAssertEqual(metrics.totalErrors, 1)
        XCTAssertEqual(metrics.averageResponseTime, 0.35, accuracy: 0.01)
    }
    
    func testTransactionEventLogging_UpdatesMetrics() async {
        // Given
        let successEvent = TransactionEvent(
            type: .confirmed,
            transactionId: "tx1",
            operation: "deposit",
            success: true,
            error: nil,
            gasUsed: 1000
        )
        
        let failedEvent = TransactionEvent(
            type: .failed,
            transactionId: "tx2",
            operation: "withdraw",
            success: false,
            error: BlendError.transaction(.failed),
            gasUsed: nil
        )
        
        // When
        await sut.logTransactionEvent(successEvent)
        await sut.logTransactionEvent(failedEvent)
        let metrics = await sut.getPerformanceMetrics()
        
        // Then
        XCTAssertEqual(metrics.successfulTransactions, 1)
        XCTAssertEqual(metrics.failedTransactions, 1)
    }
} 