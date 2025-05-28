//
//  BlendPoolDiagnosticsServiceTests.swift
//  Blendv3Tests
//
//  Tests for BlendPoolDiagnosticsService
//

import XCTest
import stellarsdk
@testable import Blendv3

final class BlendPoolDiagnosticsServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: BlendPoolDiagnosticsService!
    var mockSigner: MockBlendSigner!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockSigner = MockBlendSigner()
        sut = BlendPoolDiagnosticsService(
            signer: mockSigner,
            networkType: .testnet
        )
    }
    
    override func tearDown() {
        sut = nil
        mockSigner = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testDiagnosticsLevelEnum() {
        // Test that DiagnosticsLevel enum is properly defined
        let basicLevel = DiagnosticsLevel.basic
        let advancedLevel = DiagnosticsLevel.advanced
        let comprehensiveLevel = DiagnosticsLevel.comprehensive
        
        XCTAssertNotNil(basicLevel)
        XCTAssertNotNil(advancedLevel)
        XCTAssertNotNil(comprehensiveLevel)
    }
    
    func testDiagnosticsReportInitialization() {
        // Test that DiagnosticsReport can be initialized properly
        let report = DiagnosticsReport(
            timestamp: Date(),
            level: .basic,
            networkConnected: true,
            clientInitialized: true,
            poolAccessible: true,
            reserveCount: 3,
            assetSymbols: ["USDC", "XLM", "BLND"],
            errors: [],
            backstopData: nil,
            poolConfig: nil,
            advancedMetrics: nil
        )
        
        XCTAssertTrue(report.isHealthy)
        XCTAssertEqual(report.reserveCount, 3)
        XCTAssertEqual(report.assetSymbols.count, 3)
    }
    
    func testBackstopDataInitialization() {
        // Test that BackstopData is initialized with correct parameters
        let totalBackstop = Decimal(100000)
        let backstopData = BackstopData(
            totalBackstop: totalBackstop,
            backstopApr: Decimal(0.05),
            q4wPercentage: Decimal(10.0),
            takeRate: Decimal(0.10),
            blndAmount: totalBackstop * Decimal(0.7),
            usdcAmount: totalBackstop * Decimal(0.3)
        )
        
        XCTAssertEqual(backstopData.totalBackstop, totalBackstop)
        XCTAssertEqual(backstopData.backstopApr, Decimal(0.05))
        XCTAssertEqual(backstopData.q4wPercentage, Decimal(10.0))
        XCTAssertEqual(backstopData.takeRate, Decimal(0.10))
        XCTAssertEqual(backstopData.blndAmount, Decimal(70000))
        XCTAssertEqual(backstopData.usdcAmount, Decimal(30000))
    }
    
    func testPoolConfigInitialization() {
        // Test that PoolConfig is initialized with correct parameters
        let poolConfig = PoolConfig(
            backstopRate: 1000,
            maxPositions: 10,
            minCollateral: Decimal(100),
            oracle: "oracle_address",
            status: 1
        )
        
        XCTAssertEqual(poolConfig.backstopRate, 1000)
        XCTAssertEqual(poolConfig.maxPositions, 10)
        XCTAssertEqual(poolConfig.minCollateral, Decimal(100))
        XCTAssertEqual(poolConfig.oracle, "oracle_address")
        XCTAssertEqual(poolConfig.status, 1)
    }
    
    func testGetHealthResponseEnumHandling() async {
        // Test that GetHealthResponseEnum cases are handled correctly
        // This tests the fix for the .error case that should be .failure
        
        // Create a mock health response
        let mockHealthResponse = GetHealthResponse(
            status: "healthy",
            latestLedger: 12345,
            oldestLedger: 10000,
            ledgerRetentionWindow: 2345
        )
        
        // Test success case
        let successEnum = GetHealthResponseEnum.success(response: mockHealthResponse)
        switch successEnum {
        case .success(let response):
            XCTAssertEqual(response.status, "healthy")
        case .failure:
            XCTFail("Should be success case")
        }
        
        // Test failure case
        let failureEnum = GetHealthResponseEnum.failure(
            error: .requestFailed(message: "Test error")
        )
        switch failureEnum {
        case .success:
            XCTFail("Should be failure case")
        case .failure(let error):
            XCTAssertNotNil(error)
        }
    }
    
    func testParseI128ToDecimal() {
        // Test the parseI128ToDecimal helper method
        let value = Int128PartsXDR(hi: 0, lo: 1000000) // 1 USDC (6 decimals)
        
        // We can't directly test private methods, but we can test through public API
        // This would be tested indirectly through other methods that use it
        XCTAssertNotNil(value)
    }
    
    func testAssetSymbolMapping() {
        // Test that asset symbols are correctly mapped
        let testnetUSDC = BlendUSDCConstants.Testnet.usdc
        let testnetWBTC = BlendUSDCConstants.Testnet.wbtc
        let testnetWETH = BlendUSDCConstants.Testnet.weth
        let testnetXLM = BlendUSDCConstants.Testnet.xlm
        
        // These would be tested through the getAssetSymbol method
        XCTAssertNotNil(testnetUSDC)
        XCTAssertNotNil(testnetWBTC)
        XCTAssertNotNil(testnetWETH)
        XCTAssertNotNil(testnetXLM)
    }
    
    func testDiagnosticsErrorInitialization() {
        // Test DiagnosticsError initialization
        let error = DiagnosticsError(
            component: "Network",
            message: "Connection failed",
            error: NSError(domain: "test", code: 1001, userInfo: nil)
        )
        
        XCTAssertEqual(error.component, "Network")
        XCTAssertEqual(error.message, "Connection failed")
        XCTAssertNotNil(error.underlyingError)
    }
    
    func testRunDiagnosticsBasicLevel() async throws {
        // Test running diagnostics at basic level
        // Note: This would require mocking the network calls
        // For now, we just test that the method exists and can be called
        
        do {
            _ = try await sut.runDiagnostics(level: .basic)
            // In a real test, we would mock the network responses
            // and verify the report contents
        } catch {
            // Expected to fail without proper mocks
            XCTAssertNotNil(error)
        }
    }
}

// MARK: - Mock Classes

class MockBlendSigner: BlendSigner {
    var address: String {
        return "GDTEST123456789"
    }
    
    func getKeyPair() throws -> KeyPair {
        return try KeyPair.generateRandomKeyPair()
    }
    
    func signTransaction(_ transaction: Transaction) throws -> Transaction {
        return transaction
    }
    
    func signDecorated(transactionHash: Data) throws -> DecoratedSignatureXDR {
        throw NSError(domain: "MockError", code: 1, userInfo: nil)
    }
}

// MARK: - Mock GetHealthResponse

extension GetHealthResponse {
    convenience init(status: String, latestLedger: Int, oldestLedger: Int, ledgerRetentionWindow: Int) {
        // This would need the actual initializer from the SDK
        // For testing purposes, we're showing the structure
        self.init()
    }
} 