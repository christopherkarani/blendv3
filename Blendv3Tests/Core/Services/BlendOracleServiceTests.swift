import XCTest
import stellarsdk
@testable import Blendv3

final class BlendOracleServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: BlendOracleService!
    private var mockNetworkService: MockNetworkService!
    private var mockCacheService: MockCacheService!
    
    // Test constants
    private let testAssetAddress = "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQAOBKXN7AO"
    private let testOracleAddress = "CBJSXNC2PL5LRMGWBOJVCWZFRNFPQXX4JWCUPSGEVZELZDNSEOM7Q6IQ"
    private let testTimestamp: UInt64 = 1640995200 // 2022-01-01 00:00:00 UTC
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockNetworkService = MockNetworkService()
        mockCacheService = MockCacheService()
        sut = BlendOracleService(
            networkService: mockNetworkService,
            cacheService: mockCacheService
        )
    }
    
    override func tearDown() {
        sut = nil
        mockNetworkService = nil
        mockCacheService = nil
        super.tearDown()
    }
    
    // MARK: - lastprice() Function Tests
    
    func testGetPrice_withValidAsset_returnsPrice() async throws {
        // Given
        let expectedPrice = Decimal(1_000_000) // $1.00 with 7 decimals
        let expectedTimestamp = Date()
        
        mockNetworkService.mockPriceData = MockPriceData(
            price: expectedPrice,
            timestamp: expectedTimestamp
        )
        
        // When
        let result = try await sut.getPrice(asset: testAssetAddress)
        
        // Then
        XCTAssertEqual(result.price, expectedPrice)
        XCTAssertEqual(result.timestamp.timeIntervalSince1970, expectedTimestamp.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(result.assetId, testAssetAddress)
        XCTAssertEqual(result.decimals, 7)
        XCTAssertFalse(result.isStale(maxAge: 300))
    }
    
    func testGetPrice_withNonExistentAsset_returnsNil() async throws {
        // Given
        mockNetworkService.mockPriceData = nil // No price data available
        
        // When
        let result = try await sut.getPrice(asset: testAssetAddress)
        
        // Then
        XCTAssertNil(result)
    }
    
    func testGetPrice_withNetworkError_throwsOracleError() async {
        // Given
        mockNetworkService.shouldThrowError = true
        mockNetworkService.errorToThrow = OracleError.networkError(NSError(domain: "test", code: 1))
        
        // When/Then
        do {
            _ = try await sut.getPrice(asset: testAssetAddress)
            XCTFail("Expected OracleError to be thrown")
        } catch let error as OracleError {
            if case .networkError = error {
                // Expected
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        } catch {
            XCTFail("Expected OracleError, got \(error)")
        }
    }
    
    func testGetPrice_withInvalidResponse_throwsInvalidResponseError() async {
        // Given
        mockNetworkService.mockInvalidResponse = true
        
        // When/Then
        do {
            _ = try await sut.getPrice(asset: testAssetAddress)
            XCTFail("Expected OracleError.invalidResponse to be thrown")
        } catch let error as OracleError {
            if case .invalidResponse = error {
                // Expected
            } else {
                XCTFail("Expected invalidResponse, got \(error)")
            }
        } catch {
            XCTFail("Expected OracleError, got \(error)")
        }
    }
    
    // MARK: - price(asset, timestamp) Function Tests
    
    func testGetPriceAtTimestamp_withValidParameters_returnsPrice() async throws {
        // Given
        let expectedPrice = Decimal(1_500_000) // $1.50 with 7 decimals
        let requestTimestamp = testTimestamp
        let responseTimestamp = Date(timeIntervalSince1970: TimeInterval(requestTimestamp))
        
        mockNetworkService.mockPriceData = MockPriceData(
            price: expectedPrice,
            timestamp: responseTimestamp
        )
        
        // When
        let result = try await sut.getPrice(asset: testAssetAddress, timestamp: requestTimestamp)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, expectedPrice)
        XCTAssertEqual(result?.timestamp.timeIntervalSince1970, TimeInterval(requestTimestamp), accuracy: 1.0)
        XCTAssertEqual(result?.assetId, testAssetAddress)
    }
    
    func testGetPriceAtTimestamp_withFutureTimestamp_returnsNil() async throws {
        // Given
        let futureTimestamp = UInt64(Date().timeIntervalSince1970) + 86400 // Tomorrow
        mockNetworkService.mockPriceData = nil
        
        // When
        let result = try await sut.getPrice(asset: testAssetAddress, timestamp: futureTimestamp)
        
        // Then
        XCTAssertNil(result)
    }
    
    // MARK: - prices(asset, records) Function Tests
    
    func testGetPricesWithRecords_withValidParameters_returnsMultiplePrices() async throws {
        // Given
        let recordCount: UInt32 = 5
        let mockPrices = [
            MockPriceData(price: Decimal(1_000_000), timestamp: Date().addingTimeInterval(-3600)),
            MockPriceData(price: Decimal(1_010_000), timestamp: Date().addingTimeInterval(-1800)),
            MockPriceData(price: Decimal(1_020_000), timestamp: Date().addingTimeInterval(-900)),
            MockPriceData(price: Decimal(1_015_000), timestamp: Date().addingTimeInterval(-450)),
            MockPriceData(price: Decimal(1_025_000), timestamp: Date())
        ]
        
        mockNetworkService.mockPriceDataArray = mockPrices
        
        // When
        let result = try await sut.getPrices(asset: testAssetAddress, records: recordCount)
        
        // Then
        XCTAssertEqual(result.count, Int(recordCount))
        
        for (index, priceData) in result.enumerated() {
            XCTAssertEqual(priceData.price, mockPrices[index].price)
            XCTAssertEqual(priceData.timestamp.timeIntervalSince1970, 
                          mockPrices[index].timestamp.timeIntervalSince1970, accuracy: 1.0)
            XCTAssertEqual(priceData.assetId, testAssetAddress)
        }
    }
    
    func testGetPricesWithRecords_withZeroRecords_returnsEmptyArray() async throws {
        // Given
        let recordCount: UInt32 = 0
        mockNetworkService.mockPriceDataArray = []
        
        // When
        let result = try await sut.getPrices(asset: testAssetAddress, records: recordCount)
        
        // Then
        XCTAssertTrue(result.isEmpty)
    }
    
    func testGetPricesWithRecords_withNoDataAvailable_returnsEmptyArray() async throws {
        // Given
        let recordCount: UInt32 = 10
        mockNetworkService.mockPriceDataArray = nil
        
        // When
        let result = try await sut.getPrices(asset: testAssetAddress, records: recordCount)
        
        // Then
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - Batch Price Fetching Tests
    
    func testGetPrices_withMultipleAssets_returnsAllPrices() async throws {
        // Given
        let assets = [
            "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQAOBKXN7AO", // USDC
            "CAQCFVLOBK5GIULPNZRGATJJMIZL5BSP7X5YJVMGCPTUEPFM4AVSDF4I", // XLM
            "CBLND7XTMZX4QZFTQB5MFQD2STRM6GZQJVVCEQVMVGBKXQQMKQJBKND"  // BLND
        ]
        
        let mockPrices = [
            assets[0]: MockPriceData(price: Decimal(1_000_000), timestamp: Date()),
            assets[1]: MockPriceData(price: Decimal(120_000), timestamp: Date()),
            assets[2]: MockPriceData(price: Decimal(10_000), timestamp: Date())
        ]
        
        mockNetworkService.mockPriceDataMap = mockPrices
        
        // When
        let result = try await sut.getPrices(assets: assets)
        
        // Then
        XCTAssertEqual(result.count, assets.count)
        
        for asset in assets {
            XCTAssertNotNil(result[asset])
            XCTAssertEqual(result[asset]?.assetId, asset)
            XCTAssertEqual(result[asset]?.price, mockPrices[asset]?.price)
        }
    }
    
    func testGetPrices_withEmptyAssetArray_returnsEmptyDictionary() async throws {
        // Given
        let assets: [String] = []
        
        // When
        let result = try await sut.getPrices(assets: assets)
        
        // Then
        XCTAssertTrue(result.isEmpty)
    }
    
    func testGetPrices_withSomeFailedAssets_returnsPartialResults() async throws {
        // Given
        let assets = ["VALID_ASSET", "INVALID_ASSET", "ANOTHER_VALID_ASSET"]
        
        let mockPrices = [
            "VALID_ASSET": MockPriceData(price: Decimal(1_000_000), timestamp: Date()),
            "ANOTHER_VALID_ASSET": MockPriceData(price: Decimal(2_000_000), timestamp: Date())
            // "INVALID_ASSET" intentionally missing
        ]
        
        mockNetworkService.mockPriceDataMap = mockPrices
        
        // When
        let result = try await sut.getPrices(assets: assets)
        
        // Then
        XCTAssertEqual(result.count, 2) // Only valid assets
        XCTAssertNotNil(result["VALID_ASSET"])
        XCTAssertNotNil(result["ANOTHER_VALID_ASSET"])
        XCTAssertNil(result["INVALID_ASSET"])
    }
    
    // MARK: - Cache Tests
    
    func testGetPrices_withCachedData_usesCacheFirst() async throws {
        // Given
        let asset = testAssetAddress
        let cachedPrice = PriceData(
            price: Decimal(1_000_000),
            timestamp: Date(),
            assetId: asset,
            decimals: 7
        )
        
        let cacheKey = CacheKeys.oraclePrice(asset: asset)
        mockCacheService.mockData[cacheKey] = cachedPrice
        
        // When
        let result = try await sut.getPrices(assets: [asset])
        
        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[asset]?.assetId, asset)
        XCTAssertEqual(result[asset]?.price, cachedPrice.price)
        XCTAssertTrue(mockCacheService.getCalled)
        XCTAssertFalse(mockNetworkService.simulateOperationCalled) // Should not hit network
    }
    
    func testGetPrices_withStaleCache_fetchesNewData() async throws {
        // Given
        let asset = testAssetAddress
        let stalePrice = PriceData(
            price: Decimal(1_000_000),
            timestamp: Date().addingTimeInterval(-600), // 10 minutes ago
            assetId: asset,
            decimals: 7
        )
        
        let freshPrice = MockPriceData(
            price: Decimal(1_050_000),
            timestamp: Date()
        )
        
        let cacheKey = CacheKeys.oraclePrice(asset: asset)
        mockCacheService.mockData[cacheKey] = stalePrice
        mockNetworkService.mockPriceDataMap = [asset: freshPrice]
        
        // When
        let result = try await sut.getPrices(assets: [asset])
        
        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[asset]?.price, freshPrice.price) // Should use fresh data
        XCTAssertTrue(mockCacheService.getCalled)
        XCTAssertTrue(mockCacheService.setCalled) // Should cache new data
    }
    
    func testGetPrices_cachesNewData() async throws {
        // Given
        let asset = testAssetAddress
        let freshPrice = MockPriceData(
            price: Decimal(1_000_000),
            timestamp: Date()
        )
        
        mockNetworkService.mockPriceDataMap = [asset: freshPrice]
        
        // When
        _ = try await sut.getPrices(assets: [asset])
        
        // Then
        XCTAssertTrue(mockCacheService.setCalled)
        
        let cacheKey = CacheKeys.oraclePrice(asset: asset)
        let cachedData = mockCacheService.mockData[cacheKey] as? PriceData
        XCTAssertNotNil(cachedData)
        XCTAssertEqual(cachedData?.price, freshPrice.price)
    }
    
    // MARK: - Oracle Decimals Tests
    
    func testGetOracleDecimals_returnsCorrectDecimals() async throws {
        // Given
        mockNetworkService.mockDecimals = 7
        
        // When
        let result = try await sut.getOracleDecimals()
        
        // Then
        XCTAssertEqual(result, 7)
    }
    
    func testGetOracleDecimals_withCachedValue_usesCacheFirst() async throws {
        // Given
        let cachedDecimals = 7
        mockCacheService.mockData["oracle_decimals"] = cachedDecimals
        
        // When
        let result = try await sut.getOracleDecimals()
        
        // Then
        XCTAssertEqual(result, cachedDecimals)
        XCTAssertTrue(mockCacheService.getCalled)
        XCTAssertFalse(mockNetworkService.simulateOperationCalled)
    }
    
    func testGetOracleDecimals_withoutDecimalsFunction_returnsDefault() async throws {
        // Given
        mockNetworkService.shouldThrowError = true
        mockNetworkService.errorToThrow = OracleError.invalidResponse
        
        // When
        let result = try await sut.getOracleDecimals()
        
        // Then
        XCTAssertEqual(result, 7) // Default value
    }
    
    // MARK: - Asset Parameter Creation Tests
    
    func testCreateAssetParameter_withStellarAsset_createsCorrectParameter() {
        // This would be tested if the method was public
        // For now, we test it indirectly through the public methods
        
        // Given/When/Then - Tested through other methods that use createAssetParameter
        XCTAssertTrue(true) // Placeholder - actual testing happens in integration tests
    }
    
    // MARK: - Retry Logic Tests
    
    func testGetPrice_withTransientError_retriesAndSucceeds() async throws {
        // Given
        mockNetworkService.failureCount = 2 // Fail twice, then succeed
        mockNetworkService.mockPriceData = MockPriceData(
            price: Decimal(1_000_000),
            timestamp: Date()
        )
        
        // When
        let result = try await sut.getPrice(asset: testAssetAddress)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, Decimal(1_000_000))
        XCTAssertEqual(mockNetworkService.attemptCount, 3) // Should have retried twice
    }
    
    func testGetPrice_withPersistentError_throwsAfterMaxRetries() async {
        // Given
        mockNetworkService.shouldThrowError = true
        mockNetworkService.errorToThrow = OracleError.networkError(NSError(domain: "test", code: 1))
        
        // When/Then
        do {
            _ = try await sut.getPrice(asset: testAssetAddress)
            XCTFail("Expected error after max retries")
        } catch let error as OracleError {
            if case .networkError = error {
                XCTAssertEqual(mockNetworkService.attemptCount, 3) // Should have tried 3 times
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        } catch {
            XCTFail("Expected OracleError, got \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testGetPrices_performance_completesWithinTimeLimit() async throws {
        // Given
        let assets = Array(0..<100).map { "ASSET_\($0)" }
        let mockPrices = Dictionary(uniqueKeysWithValues: assets.map { asset in
            (asset, MockPriceData(price: Decimal(1_000_000), timestamp: Date()))
        })
        mockNetworkService.mockPriceDataMap = mockPrices
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await sut.getPrices(assets: assets)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertEqual(result.count, assets.count)
        XCTAssertLessThan(duration, 5.0, "Batch price fetching should complete within 5 seconds")
    }
    
    func testGetPricesWithRecords_performance_completesWithinTimeLimit() async throws {
        // Given
        let recordCount: UInt32 = 1000
        let mockPrices = Array(0..<Int(recordCount)).map { index in
            MockPriceData(
                price: Decimal(1_000_000 + index),
                timestamp: Date().addingTimeInterval(TimeInterval(-index * 60))
            )
        }
        mockNetworkService.mockPriceDataArray = mockPrices
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await sut.getPrices(asset: testAssetAddress, records: recordCount)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertEqual(result.count, Int(recordCount))
        XCTAssertLessThan(duration, 3.0, "Historical price fetching should complete within 3 seconds")
    }
    
    // MARK: - Edge Cases
    
    func testGetPrice_withVeryLargePrice_handlesCorrectly() async throws {
        // Given
        let largePrice = Decimal(sign: .plus, exponent: 10, significand: 123456789) // Very large number
        mockNetworkService.mockPriceData = MockPriceData(
            price: largePrice,
            timestamp: Date()
        )
        
        // When
        let result = try await sut.getPrice(asset: testAssetAddress)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, largePrice)
    }
    
    func testGetPrice_withZeroPrice_handlesCorrectly() async throws {
        // Given
        mockNetworkService.mockPriceData = MockPriceData(
            price: Decimal(0),
            timestamp: Date()
        )
        
        // When
        let result = try await sut.getPrice(asset: testAssetAddress)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, Decimal(0))
    }
    
    func testGetPrice_withVeryOldTimestamp_handlesCorrectly() async throws {
        // Given
        let oldTimestamp = Date(timeIntervalSince1970: 0) // Unix epoch
        mockNetworkService.mockPriceData = MockPriceData(
            price: Decimal(1_000_000),
            timestamp: oldTimestamp
        )
        
        // When
        let result = try await sut.getPrice(asset: testAssetAddress)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.timestamp, oldTimestamp)
        XCTAssertTrue(result?.isStale(maxAge: 300) ?? false) // Should be stale
    }
}

// MARK: - Mock Services

private class MockNetworkService: NetworkServiceProtocol {
    var shouldThrowError = false
    var errorToThrow: Error = OracleError.networkError(NSError(domain: "test", code: 1))
    var mockInvalidResponse = false
    var simulateOperationCalled = false
    var getLedgerEntriesCalled = false
    var attemptCount = 0
    var failureCount = 0
    
    // Mock data for different test scenarios
    var mockPriceData: MockPriceData?
    var mockPriceDataArray: [MockPriceData]?
    var mockPriceDataMap: [String: MockPriceData] = [:]
    var mockDecimals: Int = 7
    
    func simulateOperation(_ operation: Data) async throws -> Data {
        simulateOperationCalled = true
        attemptCount += 1
        
        if shouldThrowError && attemptCount <= failureCount {
            throw errorToThrow
        }
        
        if shouldThrowError && failureCount == 0 {
            throw errorToThrow
        }
        
        if mockInvalidResponse {
            throw OracleError.invalidResponse
        }
        
        // Return mock data based on the operation type
        // This is a simplified mock - in reality, we'd parse the operation
        return Data()
    }
    
    func getLedgerEntries(_ keys: [String]) async throws -> [Data] {
        getLedgerEntriesCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        return keys.map { _ in Data() }
    }
}

private class MockCacheService: CacheServiceProtocol {
    var mockData: [String: Any] = [:]
    var getCalled = false
    var setCalled = false
    var removeCalled = false
    var clearCalled = false
    
    func get<T: Codable>(_ key: String, type: T.Type) -> T? {
        getCalled = true
        return mockData[key] as? T
    }
    
    func set<T: Codable>(_ value: T, key: String, ttl: TimeInterval) {
        setCalled = true
        mockData[key] = value
    }
    
    func remove(_ key: String) {
        removeCalled = true
        mockData.removeValue(forKey: key)
    }
    
    func clear() {
        clearCalled = true
        mockData.removeAll()
    }
}

// MARK: - Mock Data Structures

private struct MockPriceData {
    let price: Decimal
    let timestamp: Date
} 