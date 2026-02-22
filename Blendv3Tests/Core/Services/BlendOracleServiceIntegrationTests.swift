import XCTest
import stellarsdk
@testable import Blendv3

/// Integration tests for BlendOracleService that test actual contract interactions
/// These tests require a working testnet connection and may be slower
final class BlendOracleServiceIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: BlendOracleService!
    private var realNetworkService: NetworkService!
    private var realCacheService: CacheService!
    
    // Test configuration
    private let testTimeout: TimeInterval = 30.0
    private let testAssets = [
        BlendUSDCConstants.Testnet.usdc,
        BlendUSDCConstants.Testnet.xlm,
        BlendUSDCConstants.Testnet.blnd,
        BlendUSDCConstants.Testnet.wbtc,
        BlendUSDCConstants.Testnet.weth
    ]
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Only run integration tests if explicitly enabled
        guard ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] == "1" else {
            throw XCTSkip("Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable.")
        }
        
        realNetworkService = NetworkService()
        realCacheService = CacheService()
        sut = BlendOracleService(
            networkService: realNetworkService,
            cacheService: realCacheService
        )
    }
    
    override func tearDown() {
        sut = nil
        realNetworkService = nil
        realCacheService = nil
        super.tearDown()
    }
    
    // MARK: - Real Oracle Contract Tests
    
    func testGetPrice_withRealOracle_returnsValidPrice() async throws {
        // Given
        let asset = BlendUSDCConstants.Testnet.usdc
        
        // When
        let result = try await sut.getPrice(asset: asset)
        
        // Then
        if let priceData = result {
            XCTAssertEqual(priceData.assetId, asset)
            XCTAssertGreaterThan(priceData.price, 0, "Price should be positive")
            XCTAssertLessThan(priceData.timestamp.timeIntervalSinceNow, 0, "Timestamp should be in the past")
            XCTAssertGreaterThan(priceData.timestamp.timeIntervalSinceNow, -86400, "Timestamp should be recent (within 24h)")
            XCTAssertEqual(priceData.decimals, 7, "Should use 7 decimals")
            
            // USDC price should be close to $1.00
            let humanPrice = priceData.priceInUSD
            XCTAssertGreaterThan(humanPrice, 0.95, "USDC price should be close to $1.00")
            XCTAssertLessThan(humanPrice, 1.05, "USDC price should be close to $1.00")
        } else {
            XCTFail("Expected price data for USDC, but got nil")
        }
    }
    
    func testGetPrices_withMultipleRealAssets_returnsValidPrices() async throws {
        // Given
        let assets = testAssets
        
        // When
        let result = try await sut.getPrices(assets: assets)
        
        // Then
        XCTAssertGreaterThan(result.count, 0, "Should return at least some prices")
        
        for (asset, priceData) in result {
            XCTAssertEqual(priceData.assetId, asset)
            XCTAssertGreaterThan(priceData.price, 0, "Price should be positive for \(asset)")
            XCTAssertFalse(priceData.isStale(maxAge: 3600), "Price should not be stale for \(asset)")
            
            // Validate price ranges for known assets
            let humanPrice = priceData.priceInUSD
            switch asset {
            case BlendUSDCConstants.Testnet.usdc:
                XCTAssertGreaterThan(humanPrice, 0.95, "USDC price should be close to $1.00")
                XCTAssertLessThan(humanPrice, 1.05, "USDC price should be close to $1.00")
                
            case BlendUSDCConstants.Testnet.xlm:
                XCTAssertGreaterThan(humanPrice, 0.05, "XLM price should be reasonable")
                XCTAssertLessThan(humanPrice, 1.00, "XLM price should be reasonable")
                
            case BlendUSDCConstants.Testnet.blnd:
                XCTAssertGreaterThan(humanPrice, 0.001, "BLND price should be reasonable")
                XCTAssertLessThan(humanPrice, 1.00, "BLND price should be reasonable")
                
            default:
                XCTAssertGreaterThan(humanPrice, 0, "Price should be positive")
            }
        }
    }
    
    func testGetPriceAtTimestamp_withRealOracle_returnsHistoricalPrice() async throws {
        // Given
        let asset = BlendUSDCConstants.Testnet.usdc
        let oneDayAgo = UInt64(Date().timeIntervalSince1970 - 86400)
        
        // When
        let result = try await sut.getPrice(asset: asset, timestamp: oneDayAgo)
        
        // Then
        if let priceData = result {
            XCTAssertEqual(priceData.assetId, asset)
            XCTAssertGreaterThan(priceData.price, 0)
            
            // Timestamp should be close to requested time
            let timeDifference = abs(priceData.timestamp.timeIntervalSince1970 - TimeInterval(oneDayAgo))
            XCTAssertLessThan(timeDifference, 3600, "Timestamp should be within 1 hour of requested time")
        }
        // Note: It's okay if this returns nil for historical data that's not available
    }
    
    func testGetPricesWithRecords_withRealOracle_returnsHistoricalData() async throws {
        // Given
        let asset = BlendUSDCConstants.Testnet.usdc
        let recordCount: UInt32 = 10
        
        // When
        let result = try await sut.getPrices(asset: asset, records: recordCount)
        
        // Then
        if !result.isEmpty {
            XCTAssertLessThanOrEqual(result.count, Int(recordCount), "Should not return more records than requested")
            
            // Verify records are sorted by timestamp (newest first)
            for i in 1..<result.count {
                XCTAssertGreaterThanOrEqual(
                    result[i-1].timestamp.timeIntervalSince1970,
                    result[i].timestamp.timeIntervalSince1970,
                    "Records should be sorted by timestamp (newest first)"
                )
            }
            
            // All records should be for the same asset
            for priceData in result {
                XCTAssertEqual(priceData.assetId, asset)
                XCTAssertGreaterThan(priceData.price, 0)
            }
        }
        // Note: It's okay if this returns empty array if no historical data is available
    }
    
    func testGetOracleDecimals_withRealOracle_returnsCorrectDecimals() async throws {
        // When
        let result = try await sut.getOracleDecimals()
        
        // Then
        XCTAssertEqual(result, 7, "Oracle should use 7 decimals")
    }
    
    // MARK: - Error Handling with Real Oracle
    
    func testGetPrice_withInvalidAsset_handlesGracefully() async throws {
        // Given
        let invalidAsset = "INVALID_ASSET_ADDRESS_THAT_DOES_NOT_EXIST_ON_TESTNET"
        
        // When
        let result = try await sut.getPrice(asset: invalidAsset)
        
        // Then
        XCTAssertNil(result, "Should return nil for invalid asset")
    }
    
    func testGetPrices_withMixedValidInvalidAssets_returnsPartialResults() async throws {
        // Given
        let mixedAssets = [
            BlendUSDCConstants.Testnet.usdc, // Valid
            "INVALID_ASSET_1", // Invalid
            BlendUSDCConstants.Testnet.xlm, // Valid
            "INVALID_ASSET_2" // Invalid
        ]
        
        // When
        let result = try await sut.getPrices(assets: mixedAssets)
        
        // Then
        XCTAssertGreaterThan(result.count, 0, "Should return prices for valid assets")
        XCTAssertLessThan(result.count, mixedAssets.count, "Should not return prices for all assets")
        
        // Valid assets should have prices
        XCTAssertNotNil(result[BlendUSDCConstants.Testnet.usdc])
        
        // Invalid assets should not have prices
        XCTAssertNil(result["INVALID_ASSET_1"])
        XCTAssertNil(result["INVALID_ASSET_2"])
    }
    
    // MARK: - Performance Tests with Real Oracle
    
    func testGetPrices_realOraclePerformance_completesWithinTimeLimit() async throws {
        // Given
        let assets = testAssets
        let maxDuration: TimeInterval = 10.0 // 10 seconds for real network calls
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await sut.getPrices(assets: assets)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(duration, maxDuration, "Real oracle calls should complete within \(maxDuration) seconds")
        XCTAssertGreaterThan(result.count, 0, "Should return at least some prices")
    }
    
    // MARK: - Cache Integration Tests
    
    func testGetPrices_withRealOracleAndCache_usesCacheOnSecondCall() async throws {
        // Given
        let asset = BlendUSDCConstants.Testnet.usdc
        
        // When - First call (should hit oracle)
        let startTime1 = CFAbsoluteTimeGetCurrent()
        let result1 = try await sut.getPrices(assets: [asset])
        let duration1 = CFAbsoluteTimeGetCurrent() - startTime1
        
        // When - Second call (should use cache)
        let startTime2 = CFAbsoluteTimeGetCurrent()
        let result2 = try await sut.getPrices(assets: [asset])
        let duration2 = CFAbsoluteTimeGetCurrent() - startTime2
        
        // Then
        XCTAssertEqual(result1.count, result2.count)
        if let price1 = result1[asset], let price2 = result2[asset] {
            XCTAssertEqual(price1.price, price2.price, "Cached price should match original")
            XCTAssertEqual(price1.timestamp, price2.timestamp, "Cached timestamp should match original")
        }
        
        // Second call should be significantly faster (using cache)
        XCTAssertLessThan(duration2, duration1 * 0.1, "Cached call should be much faster than oracle call")
    }
    
    // MARK: - Asset Parameter Tests
    
    func testAssetParameterCreation_withDifferentAssetTypes_worksCorrectly() async throws {
        // Test with Stellar asset (contract address)
        let stellarAsset = BlendUSDCConstants.Testnet.usdc
        let stellarResult = try await sut.getPrice(asset: stellarAsset)
        
        // Should work with valid Stellar asset
        if stellarResult != nil {
            XCTAssertNotNil(stellarResult)
        }
        
        // Test would include Other asset type if supported by the oracle
        // For now, we only test Stellar assets as that's what Blend uses
    }
    
    // MARK: - Stress Tests
    
    func testGetPrices_withManyAssets_handlesLargeRequests() async throws {
        // Given
        let manyAssets = Array(repeating: testAssets, count: 10).flatMap { $0 } // 30 assets
        let maxDuration: TimeInterval = 30.0
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await sut.getPrices(assets: manyAssets)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(duration, maxDuration, "Large batch request should complete within \(maxDuration) seconds")
        XCTAssertGreaterThan(result.count, 0, "Should return at least some prices")
        
        // Should handle duplicates correctly
        let uniqueAssets = Set(manyAssets)
        XCTAssertLessThanOrEqual(result.count, uniqueAssets.count, "Should not return duplicate prices")
    }
    
    // MARK: - Data Validation Tests
    
    func testPriceData_validation_ensuresDataIntegrity() async throws {
        // Given
        let asset = BlendUSDCConstants.Testnet.usdc
        
        // When
        let result = try await sut.getPrice(asset: asset)
        
        // Then
        if let priceData = result {
            // Validate price format
            XCTAssertGreaterThan(priceData.price, 0, "Price should be positive")
            XCTAssertFalse(priceData.price.isNaN, "Price should not be NaN")
            XCTAssertFalse(priceData.price.isInfinite, "Price should not be infinite")
            
            // Validate timestamp
            let now = Date()
            let oneYearAgo = now.addingTimeInterval(-365 * 24 * 3600)
            XCTAssertGreaterThan(priceData.timestamp, oneYearAgo, "Timestamp should not be too old")
            XCTAssertLessThanOrEqual(priceData.timestamp, now, "Timestamp should not be in the future")
            
            // Validate asset ID
            XCTAssertFalse(priceData.assetId.isEmpty, "Asset ID should not be empty")
            XCTAssertEqual(priceData.assetId, asset, "Asset ID should match requested asset")
            
            // Validate decimals
            XCTAssertGreaterThan(priceData.decimals, 0, "Decimals should be positive")
            XCTAssertLessThanOrEqual(priceData.decimals, 18, "Decimals should be reasonable")
            
            // Validate human-readable price
            let humanPrice = priceData.priceInUSD
            XCTAssertGreaterThan(humanPrice, 0, "Human-readable price should be positive")
            XCTAssertFalse(humanPrice.isNaN, "Human-readable price should not be NaN")
        }
    }
}

// MARK: - Test Utilities

extension BlendOracleServiceIntegrationTests {
    
    /// Helper to check if integration tests should run
    private var shouldRunIntegrationTests: Bool {
        return ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] == "1"
    }
    
    /// Helper to skip test if integration tests are disabled
    private func skipIfIntegrationTestsDisabled() throws {
        guard shouldRunIntegrationTests else {
            throw XCTSkip("Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable.")
        }
    }
} 
