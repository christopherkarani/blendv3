//
//  ErrorBoundaryServiceTests.swift
//  Blendv3Tests
//
//  Unit tests for ErrorBoundaryService
//

import XCTest
@testable import Blendv3

final class ErrorBoundaryServiceTests: XCTestCase {
    
    var sut: ErrorBoundaryService!
    var mockDiagnostics: MockDiagnosticsService!
    
    override func setUp() {
        super.setUp()
        mockDiagnostics = MockDiagnosticsService()
        sut = ErrorBoundaryService(diagnostics: mockDiagnostics)
    }
    
    override func tearDown() {
        sut = nil
        mockDiagnostics = nil
        super.tearDown()
    }
    
    // MARK: - Handle Tests
    
    func testHandle_SuccessfulOperation_ReturnsSuccess() async {
        // Given
        let expectedValue = "Success"
        
        // When
        let result = await sut.handle {
            return expectedValue
        }
        
        // Then
        switch result {
        case .success(let value):
            XCTAssertEqual(value, expectedValue)
        case .failure:
            XCTFail("Expected success but got failure")
        }
    }
    
    func testHandle_ThrowingOperation_ReturnsFailure() async {
        // Given
        let expectedError = BlendVaultError.networkError("Test error")
        
        // When
        let result = await sut.handle {
            throw expectedError
        }
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertEqual(error, .network(.connectionFailed))
        }
    }
    
    func testHandle_UnknownError_MapsToUnknown() async {
        // Given
        struct UnknownError: Error {}
        
        // When
        let result = await sut.handle {
            throw UnknownError()
        }
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertEqual(error, .unknown)
        }
    }
    
    // MARK: - Handle With Retry Tests
    
    func testHandleWithRetry_SucceedsOnFirstAttempt_ReturnsSuccess() async {
        // Given
        let expectedValue = "Success"
        var attemptCount = 0
        
        // When
        let result = await sut.handleWithRetry({
            attemptCount += 1
            return expectedValue
        }, maxRetries: 3)
        
        // Then
        switch result {
        case .success(let value):
            XCTAssertEqual(value, expectedValue)
            XCTAssertEqual(attemptCount, 1)
        case .failure:
            XCTFail("Expected success but got failure")
        }
    }
    
    func testHandleWithRetry_SucceedsOnSecondAttempt_ReturnsSuccess() async {
        // Given
        let expectedValue = "Success"
        var attemptCount = 0
        
        // When
        let result = await sut.handleWithRetry({
            attemptCount += 1
            if attemptCount == 1 {
                throw BlendVaultError.networkError("Temporary failure")
            }
            return expectedValue
        }, maxRetries: 3)
        
        // Then
        switch result {
        case .success(let value):
            XCTAssertEqual(value, expectedValue)
            XCTAssertEqual(attemptCount, 2)
        case .failure:
            XCTFail("Expected success but got failure")
        }
    }
    
    func testHandleWithRetry_AllRetriesExhausted_ReturnsFailure() async {
        // Given
        var attemptCount = 0
        let maxRetries = 3
        
        // When
        let result = await sut.handleWithRetry({
            attemptCount += 1
            throw BlendVaultError.networkError("Persistent failure")
        }, maxRetries: maxRetries)
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertEqual(error, .network(.connectionFailed))
            XCTAssertEqual(attemptCount, maxRetries)
        }
    }
    
    func testHandleWithRetry_NonRecoverableError_StopsRetrying() async {
        // Given
        var attemptCount = 0
        
        // When
        let result = await sut.handleWithRetry({
            attemptCount += 1
            throw BlendVaultError.insufficientBalance
        }, maxRetries: 3)
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertEqual(error, .insufficientFunds)
            XCTAssertEqual(attemptCount, 1) // Should not retry
        }
    }
    
    // MARK: - Error Mapping Tests
    
    func testErrorMapping_BlendVaultError_MapsCorrectly() async {
        // Test each BlendVaultError mapping
        let testCases: [(BlendVaultError, BlendError)] = [
            (.notInitialized, .initialization("Service not ready")),
            (.invalidAmount, .validation(.invalidInput)),
            (.insufficientBalance, .insufficientFunds),
            (.transactionFailed("Test"), .transaction(.failed)),
            (.networkError("Test"), .network(.connectionFailed)),
            (.initializationFailed("Test"), .initialization("Setup failed")),
            (.invalidResponse, .validation(.invalidResponse)),
            (.unknown("Test"), .unknown)
        ]
        
        for (input, expected) in testCases {
            let result = await sut.handle { throw input }
            
            switch result {
            case .success:
                XCTFail("Expected failure for \(input)")
            case .failure(let error):
                XCTAssertEqual(error, expected, "Failed for input: \(input)")
            }
        }
    }
    
    func testErrorMapping_NetworkErrors_MapsCorrectly() async {
        // Test NSURLError mapping
        let testCases: [(Int, NetworkErrorType)] = [
            (NSURLErrorTimedOut, .timeout),
            (NSURLErrorCannotConnectToHost, .connectionFailed),
            (NSURLErrorNetworkConnectionLost, .connectionFailed),
            (NSURLErrorBadServerResponse, .serverError)
        ]
        
        for (code, expectedType) in testCases {
            let nsError = NSError(domain: NSURLErrorDomain, code: code)
            let result = await sut.handle { throw nsError }
            
            switch result {
            case .success:
                XCTFail("Expected failure for code \(code)")
            case .failure(let error):
                guard case .network(let type) = error else {
                    XCTFail("Expected network error for code \(code)")
                    return
                }
                XCTAssertEqual(type, expectedType, "Failed for code: \(code)")
            }
        }
    }
    
    // MARK: - Logging Tests
    
    func testLogError_LogsToDiagnostics() async {
        // Given
        let error = BlendError.network(.connectionFailed)
        let context = ErrorContext(
            operation: "TestOperation",
            timestamp: Date(),
            metadata: ["key": "value"]
        )
        
        // When
        sut.logError(error, context: context)
        
        // Then
        XCTAssertEqual(mockDiagnostics.loggedEvents.count, 1)
        if let event = mockDiagnostics.loggedEvents.first {
            XCTAssertEqual(event.type, .connectionFailure)
            XCTAssertTrue(event.details.contains("Network error"))
        }
    }
}

// MARK: - Mock Diagnostics Service

class MockDiagnosticsService: DiagnosticsServiceProtocol {
    var loggedEvents: [NetworkEvent] = []
    
    func logNetworkEvent(_ event: NetworkEvent) {
        loggedEvents.append(event)
    }
    
    func logCacheEvent(_ event: CacheEvent) {
        // Not used in these tests
    }
    
    func logTransactionEvent(_ event: TransactionEvent) {
        // Not used in these tests
    }
    
    func generateReport() -> DiagnosticsReport {
        return DiagnosticsReport(
            networkEvents: loggedEvents,
            cacheEvents: [],
            transactionEvents: [],
            performanceMetrics: [:],
            errorCounts: [:]
        )
    }
    
    func reset() {
        loggedEvents.removeAll()
    }
} 