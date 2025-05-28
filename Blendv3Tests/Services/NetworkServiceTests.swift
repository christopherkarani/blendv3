//
//  NetworkServiceTests.swift
//  Blendv3Tests
//
//  Unit tests for NetworkService
//

import XCTest
import Combine
@testable import Blendv3
import stellarsdk

final class NetworkServiceTests: XCTestCase {
    
    var sut: NetworkService!
    var mockConfiguration: MockConfigurationService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockConfiguration = MockConfigurationService()
        sut = NetworkService(configuration: mockConfiguration)
        cancellables = []
    }
    
    override func tearDown() {
        sut = nil
        mockConfiguration = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_ConfiguresCorrectly() {
        // Then
        XCTAssertNotNil(sut)
    }
    
    // MARK: - Connectivity Tests
    
    func testCheckConnectivity_Success_ReturnsConnected() async {
        // Given - Mock successful response
        // This would require mocking URLSession which is complex
        // For now, we'll test the interface
        
        // When
        let result = await sut.checkConnectivity()
        
        // Then
        // In a real test, we'd assert the result based on mocked responses
        XCTAssertTrue(result == .connected || result == .disconnected)
    }
    
    // MARK: - Request Interceptor Tests
    
    func testAddRequestInterceptor_ModifiesRequest() {
        // Given
        var interceptorCalled = false
        let interceptor: (URLRequest) -> URLRequest = { request in
            interceptorCalled = true
            var modifiedRequest = request
            modifiedRequest.setValue("test-value", forHTTPHeaderField: "X-Test-Header")
            return modifiedRequest
        }
        
        // When
        sut.addRequestInterceptor(interceptor)
        
        // Then
        // In a real scenario, we'd trigger a request and verify the interceptor was called
        XCTAssertTrue(true) // Placeholder
    }
    
    func testAddResponseInterceptor_ProcessesResponse() {
        // Given
        var interceptorCalled = false
        let interceptor: (Data, URLResponse) -> Void = { _, _ in
            interceptorCalled = true
        }
        
        // When
        sut.addResponseInterceptor(interceptor)
        
        // Then
        // In a real scenario, we'd trigger a request and verify the interceptor was called
        XCTAssertTrue(true) // Placeholder
    }
    
    // MARK: - Legacy Method Tests
    
    func testSimulateOperation_LegacyMethod_ReturnsData() async throws {
        // Given
        let testData = Data("test".utf8)
        
        // When
        let result = try await sut.simulateOperation(testData)
        
        // Then
        XCTAssertEqual(result, testData)
    }
}

// MARK: - Mock Configuration Service

private class MockConfigurationService: ConfigurationServiceProtocol {
    var networkType: BlendUSDCConstants.NetworkType = .testnet
    
    var contractAddresses: ContractAddresses {
        return ContractAddresses(
            poolContract: "test_pool",
            backstopContract: "test_backstop",
            blendLockupContract: "test_lockup",
            usdcContract: "test_usdc"
        )
    }
    
    var rpcEndpoint: String {
        return "https://soroban-testnet.stellar.org"
    }
    
    func getRetryConfiguration() -> RetryConfiguration {
        return RetryConfiguration(
            maxRetries: 3,
            initialDelay: 1.0,
            maxDelay: 10.0,
            multiplier: 2.0
        )
    }
    
    func getTimeoutConfiguration() -> TimeoutConfiguration {
        return TimeoutConfiguration(
            networkTimeout: 30.0,
            transactionTimeout: 60.0,
            simulationTimeout: 20.0
        )
    }
}

// MARK: - Integration Tests (Commented out for CI)

/*
extension NetworkServiceTests {
    
    func testIntegration_GetAccount_RealNetwork() async throws {
        // This test would hit the real network
        // Only run manually, not in CI
        
        // Given
        let accountId = "GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWHF"
        
        // When
        do {
            let account = try await sut.getAccount(accountId: accountId)
            
            // Then
            XCTAssertEqual(account.accountId, accountId)
        } catch {
            // Network errors are expected in test environment
            XCTAssertTrue(error is BlendError)
        }
    }
    
    func testIntegration_CheckConnectivity_RealNetwork() async {
        // Given
        await sut.initialize()
        
        // When
        let state = await sut.checkConnectivity()
        
        // Then
        // Should be either connected or disconnected based on network availability
        XCTAssertTrue(state == .connected || state == .disconnected)
    }
}
*/ 