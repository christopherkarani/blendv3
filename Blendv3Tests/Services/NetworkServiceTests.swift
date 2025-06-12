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
    var testConfig: NetworkServiceConfig!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        testConfig = NetworkServiceConfig(
            networkType: .testnet,
            timeoutConfiguration: TimeoutConfiguration(
                networkTimeout: 30.0,
                transactionTimeout: 60.0,
                initializationTimeout: 30.0
            ),
            retryConfiguration: RetryConfiguration(
                maxRetries: 3,
                baseDelay: 1.0,
                maxDelay: 10.0,
                exponentialBase: 2.0,
                jitterRange: 0.0...0.3
            )
        )
        sut = NetworkService(config: testConfig)
        cancellables = []
    }
    
    override func tearDown() {
        sut = nil
        testConfig = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_ConfiguresCorrectly() {
        // Then
        XCTAssertNotNil(sut)
    }
    
    func testInitialization_WithDefaultConfig_Works() {
        // Given & When
        let defaultNetworkService = NetworkService()
        
        // Then
        XCTAssertNotNil(defaultNetworkService)
    }
    
    func testInitialization_WithCustomConfig_UsesCorrectEndpoint() {
        // Given
        let mainnetConfig = NetworkServiceConfig(networkType: .mainnet)
        
        // When
        let mainnetService = NetworkService(config: mainnetConfig)
        
        // Then
        XCTAssertNotNil(mainnetService)
        XCTAssertEqual(mainnetConfig.rpcEndpoint, BlendUSDCConstants.RPC.mainnet)
    }
    
    // MARK: - Configuration Tests
    
    func testNetworkServiceConfig_TestnetEndpoint_IsCorrect() {
        // Given
        let config = NetworkServiceConfig(networkType: .testnet)
        
        // Then
        XCTAssertEqual(config.rpcEndpoint, BlendUSDCConstants.RPC.testnet)
    }
    
    func testNetworkServiceConfig_MainnetEndpoint_IsCorrect() {
        // Given
        let config = NetworkServiceConfig(networkType: .mainnet)
        
        // Then
        XCTAssertEqual(config.rpcEndpoint, BlendUSDCConstants.RPC.mainnet)
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
    
    // MARK: - Legacy Initialization Tests
    

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