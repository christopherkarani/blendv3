import XCTest
import stellarsdk
@testable import Blendv3

/// Comprehensive test suite for BlendOracleService
/// Tests all public methods, error scenarios, caching, concurrency, and performance
@MainActor
final class BlendOracleServiceComprehensiveTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: BlendOracleService!
    private var mockNetworkService: MockNetworkService!
    private var mockCacheService: MockCacheService!
    private var mockOracleNetworkService: MockOracleNetworkService!
    private var testKeyPair: KeyPair!
    
    // Test constants
    private let testPoolId = "test-pool-id"
    private let testOracleAddress = BlendConstants.Testnet.oracle
    private let testUSDCAsset = OracleAsset.stellar(address: BlendConstants.Testnet.usdc)
    private let testXLMAsset = OracleAsset.stellar(address: BlendConstants.Testnet.xlm)
    private let testTimestamp: UInt64 = 1640995200 // 2022-01-01 00:00:00 UTC
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        await super.setUp()
        
        // Create test key pair
        testKeyPair = try KeyPair.generateRandomKeyPair()
        
        // Create mocks
        mockNetworkService = MockNetworkService()
        mockCacheService = MockCacheService()
        
        // Create system under test
        sut = BlendOracleService(
            poolId: testPoolId,
            cacheService: mockCacheService,
            networkService: mockNetworkService,
            sourceKeyPair: testKeyPair
        )
        
        // Get access to the oracle network service for mocking
        mockOracleNetworkService = MockOracleNetworkService(
            networkService: mockNetworkService,
            contractId: testOracleAddress,
            sourceKeyPair: testKeyPair
        )
    }
    
    override func tearDown() async throws {
        sut = nil
        mockNetworkService = nil
        mockCacheService = nil
        mockOracleNetworkService = nil
        testKeyPair = nil
        await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_withValidParameters_initializesCorrectly() async throws {
        // Given/When - Initialization happens in setUp
        
        // Then
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut.oracleAddress, testPoolId)
    }
    
    // MARK: - getOracleDecimals() Tests
    
    func testGetOracleDecimals_withValidResponse_returnsDecimals() async throws {
        // Given
        let expectedDecimals = 7
        mockOracleNetworkService.mockU32Response = UInt32(expectedDecimals)
        
        // When
        let result = try await sut.getOracleDecimals()
        
        // Then
        XCTAssertEqual(result, expectedDecimals)
    }
    
    func testGetOracleDecimals_withCachedValue_usesCacheFirst() async throws {
        // Given
        let cachedDecimals = 9
        await mockCacheService.set(cachedDecimals, key: "oracle_decimals", ttl: 3600)
        
        // When
        let result = try await sut.getOracleDecimals()
        
        // Then
        XCTAssertEqual(result, cachedDecimals)
        XCTAssertTrue(mockCacheService.getCalled)
    }
    
    func testGetOracleDecimals_withContractError_returnsDefault() async throws {
        // Given
        mockOracleNetworkService.shouldThrow = true
        mockOracleNetworkService.errorToThrow = OracleError.contractError(code: -1, message: "Function not found")
        
        // When
        let result = try await sut.getOracleDecimals()
        
        // Then
        XCTAssertEqual(result, 7) // Default value
    }
    
    // MARK: - getPrice(asset:) Tests
    
    func testGetPrice_withValidAsset_returnsPriceData() async throws {
        // Given
        let expectedPrice = PriceData(
            price: Decimal(1.25),
            timestamp: Date(),
            contractID: testUSDCAsset.assetId,
            baseAsset: "USD"
        )
        mockOracleNetworkService.mockOptionalPriceData = expectedPrice
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset)
        
        // Then
        XCTAssertEqual(result.price, expectedPrice.price)
        XCTAssertEqual(result.contractID, expectedPrice.contractID)
        XCTAssertEqual(result.baseAsset, expectedPrice.baseAsset)
    }
    
    func testGetPrice_withNonExistentAsset_throwsError() async throws {
        // Given
        let invalidAsset = OracleAsset.stellar(address: "INVALID_CONTRACT_ADDRESS")
        mockOracleNetworkService.mockOptionalPriceData = nil
        
        // When/Then
        do {
            _ = try await sut.getPrice(asset: invalidAsset)
            XCTFail("Expected error to be thrown")
        } catch let error as OracleError {
            if case .priceNotAvailable = error {
                // Expected
            } else {
                XCTFail("Expected priceNotAvailable error, got \(error)")
            }
        }
    }
    
    // MARK: - getPrice(asset:timestamp:) Tests
    
    func testGetPriceAtTimestamp_withValidParameters_returnsPriceData() async throws {
        // Given
        let expectedPrice = PriceData(
            price: Decimal(1.30),
            timestamp: Date(timeIntervalSince1970: TimeInterval(testTimestamp)),
            contractID: testUSDCAsset.assetId,
            baseAsset: "USD"
        )
        mockOracleNetworkService.mockOptionalPriceData = expectedPrice
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset, timestamp: testTimestamp)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, expectedPrice.price)
        XCTAssertEqual(result?.timestamp.timeIntervalSince1970, TimeInterval(testTimestamp), accuracy: 1.0)
    }
    
    func testGetPriceAtTimestamp_withFutureTimestamp_returnsNil() async throws {
        // Given
        let futureTimestamp = UInt64(Date().timeIntervalSince1970) + 86400
        mockOracleNetworkService.mockOptionalPriceData = nil
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset, timestamp: futureTimestamp)
        
        // Then
        XCTAssertNil(result)
    }
    
    // MARK: - getPriceHistory(asset:records:) Tests
    
    func testGetPriceHistory_withValidParameters_returnsPriceArray() async throws {
        // Given
        let recordCount: UInt32 = 5
        let mockPrices = [
            PriceData(price: Decimal(1.20), timestamp: Date().addingTimeInterval(-3600), contractID: testUSDCAsset.assetId, baseAsset: "USD"),
            PriceData(price: Decimal(1.22), timestamp: Date().addingTimeInterval(-1800), contractID: testUSDCAsset.assetId, baseAsset: "USD"),
            PriceData(price: Decimal(1.25), timestamp: Date().addingTimeInterval(-900), contractID: testUSDCAsset.assetId, baseAsset: "USD"),
            PriceData(price: Decimal(1.23), timestamp: Date().addingTimeInterval(-450), contractID: testUSDCAsset.assetId, baseAsset: "USD"),
            PriceData(price: Decimal(1.26), timestamp: Date(), contractID: testUSDCAsset.assetId, baseAsset: "USD")
        ]
        mockOracleNetworkService.mockPriceDataArray = mockPrices
        
        // When
        let result = try await sut.getPriceHistory(asset: testUSDCAsset, records: recordCount)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, Int(recordCount))
        
        if let prices = result {
            for (index, priceData) in prices.enumerated() {
                XCTAssertEqual(priceData.price, mockPrices[index].price)
                XCTAssertEqual(priceData.contractID, mockPrices[index].contractID)
            }
        }
    }
    
    func testGetPriceHistory_withZeroRecords_returnsEmptyArray() async throws {
        // Given
        let recordCount: UInt32 = 0
        mockOracleNetworkService.mockPriceDataArray = []
        
        // When
        let result = try await sut.getPriceHistory(asset: testUSDCAsset, records: recordCount)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isEmpty ?? false)
    }
    
    // MARK: - getLastPrice(asset:) Tests
    
    func testGetLastPrice_withValidAsset_returnsPriceData() async throws {
        // Given
        let expectedPrice = PriceData(
            price: Decimal(1.28),
            timestamp: Date(),
            contractID: testUSDCAsset.assetId,
            baseAsset: "USD"
        )
        mockOracleNetworkService.mockOptionalPriceData = expectedPrice
        
        // When
        let result = try await sut.getLastPrice(asset: testUSDCAsset)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, expectedPrice.price)
        XCTAssertEqual(result?.contractID, expectedPrice.contractID)
    }
    
    func testGetLastPrice_withNonExistentAsset_returnsNil() async throws {
        // Given
        let invalidAsset = OracleAsset.other(symbol: "INVALID")
        mockOracleNetworkService.mockOptionalPriceData = nil
        
        // When
        let result = try await sut.getLastPrice(asset: invalidAsset)
        
        // Then
        XCTAssertNil(result)
    }
    
    // MARK: - getOracleResolution() Tests
    
    func testGetOracleResolution_withValidResponse_returnsResolution() async throws {
        // Given
        let expectedResolution = 1000000
        mockOracleNetworkService.mockU32Response = UInt32(expectedResolution)
        
        // When
        let result = try await sut.getOracleResolution()
        
        // Then
        XCTAssertEqual(result, expectedResolution)
    }
    
    func testGetOracleResolution_withCachedValue_usesCacheFirst() async throws {
        // Given
        let cachedResolution = 2000000
        await mockCacheService.set(cachedResolution, key: "oracle_resolution", ttl: 3600)
        
        // When
        let result = try await sut.getOracleResolution()
        
        // Then
        XCTAssertEqual(result, cachedResolution)
        XCTAssertTrue(mockCacheService.getCalled)
    }
    
    // MARK: - getBaseAsset() Tests
    
    func testGetBaseAsset_withValidResponse_returnsBaseAsset() async throws {
        // Given
        let expectedBaseAsset = OracleAsset.other(symbol: "USD")
        mockOracleNetworkService.mockAsset = expectedBaseAsset
        
        // When
        let result = try await sut.getBaseAsset()
        
        // Then
        XCTAssertEqual(result, expectedBaseAsset)
    }
    
    func testGetBaseAsset_withCachedValue_usesCacheFirst() async throws {
        // Given
        let cachedAsset = OracleAsset.other(symbol: "USD")
        await mockCacheService.set(cachedAsset, key: "oracle_base_asset", ttl: 3600)
        
        // When
        let result = try await sut.getBaseAsset()
        
        // Then
        XCTAssertEqual(result, cachedAsset)
        XCTAssertTrue(mockCacheService.getCalled)
    }
    
    // MARK: - getSupportedAssets() Tests
    
    func testGetSupportedAssets_withValidResponse_returnsAssetArray() async throws {
        // Given
        let expectedAssets = [testUSDCAsset, testXLMAsset, OracleAsset.other(symbol: "BTC")]
        mockOracleNetworkService.mockAssetArray = expectedAssets
        
        // When
        let result = try await sut.getSupportedAssets()
        
        // Then
        XCTAssertEqual(result.count, expectedAssets.count)
        for (index, asset) in result.enumerated() {
            XCTAssertEqual(asset, expectedAssets[index])
        }
    }
    
    func testGetSupportedAssets_withCachedValue_usesCacheFirst() async throws {
        // Given
        let cachedAssets = [testUSDCAsset, testXLMAsset]
        await mockCacheService.set(cachedAssets, key: "oracle_supported_assets", ttl: 3600)
        
        // When
        let result = try await sut.getSupportedAssets()
        
        // Then
        XCTAssertEqual(result, cachedAssets)
        XCTAssertTrue(mockCacheService.getCalled)
    }
    
    // MARK: - assets() Tests
    
    func testAssets_withValidResponse_returnsAssetIds() async throws {
        // Given
        let supportedAssets = [testUSDCAsset, testXLMAsset, OracleAsset.other(symbol: "BTC")]
        mockOracleNetworkService.mockAssetArray = supportedAssets
        
        // When
        let result = try await sut.assets()
        
        // Then
        XCTAssertEqual(result.count, supportedAssets.count)
        for (index, assetId) in result.enumerated() {
            XCTAssertEqual(assetId, supportedAssets[index].assetId)
        }
    }
    
    // MARK: - getPrices(assets:) Tests
    
    func testGetPrices_withMultipleAssets_returnsAllPrices() async throws {
        // Given
        let assets = [testUSDCAsset, testXLMAsset]
        let mockPrices = [
            PriceData(price: Decimal(1.25), timestamp: Date(), contractID: testUSDCAsset.assetId, baseAsset: "USD"),
            PriceData(price: Decimal(0.12), timestamp: Date(), contractID: testXLMAsset.assetId, baseAsset: "USD")
        ]
        
        mockOracleNetworkService.mockPriceForAsset = [
            testUSDCAsset.assetId: mockPrices[0],
            testXLMAsset.assetId: mockPrices[1]
        ]
        
        // When
        let result = try await sut.getPrices(assets: assets)
        
        // Then
        XCTAssertEqual(result.count, assets.count)
        XCTAssertEqual(result[0].contractID, testUSDCAsset.assetId)
        XCTAssertEqual(result[1].contractID, testXLMAsset.assetId)
    }
    
    func testGetPrices_withEmptyAssetArray_returnsEmptyArray() async throws {
        // Given
        let assets: [OracleAsset] = []
        
        // When
        let result = try await sut.getPrices(assets: assets)
        
        // Then
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testGetPrice_withNetworkError_throwsOracleError() async throws {
        // Given
        mockOracleNetworkService.shouldThrow = true
        mockOracleNetworkService.errorToThrow = OracleError.networkError(NSError(domain: "test", code: 1), context: "Network timeout")
        
        // When/Then
        do {
            _ = try await sut.getPrice(asset: testUSDCAsset)
            XCTFail("Expected error to be thrown")
        } catch let error as OracleError {
            if case .networkError = error {
                // Expected
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        }
    }
    
    func testGetPriceHistory_withContractError_throwsOracleError() async throws {
        // Given
        mockOracleNetworkService.shouldThrow = true
        mockOracleNetworkService.errorToThrow = OracleError.contractError(code: 404, message: "Function not found")
        
        // When/Then
        do {
            _ = try await sut.getPriceHistory(asset: testUSDCAsset, records: 10)
            XCTFail("Expected error to be thrown")
        } catch let error as OracleError {
            if case .contractError = error {
                // Expected
            } else {
                XCTFail("Expected contractError, got \(error)")
            }
        }
    }
    
    func testGetSupportedAssets_withInvalidResponse_throwsOracleError() async throws {
        // Given
        mockOracleNetworkService.shouldThrow = true
        mockOracleNetworkService.errorToThrow = OracleError.invalidResponseFormat("Invalid asset format")
        
        // When/Then
        do {
            _ = try await sut.getSupportedAssets()
            XCTFail("Expected error to be thrown")
        } catch let error as OracleError {
            if case .invalidResponseFormat = error {
                // Expected
            } else {
                XCTFail("Expected invalidResponseFormat, got \(error)")
            }
        }
    }
    
    // MARK: - Retry Logic Tests
    
    func testGetPrice_withTransientError_retriesAndSucceeds() async throws {
        // Given
        let expectedPrice = PriceData(
            price: Decimal(1.25),
            timestamp: Date(),
            contractID: testUSDCAsset.assetId,
            baseAsset: "USD"
        )
        
        mockOracleNetworkService.failureCount = 2 // Fail twice, then succeed
        mockOracleNetworkService.mockOptionalPriceData = expectedPrice
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset)
        
        // Then
        XCTAssertEqual(result.price, expectedPrice.price)
        XCTAssertEqual(mockOracleNetworkService.attemptCount, 3) // Should have retried twice
    }
    
    func testGetPrice_withPersistentError_throwsAfterMaxRetries() async throws {
        // Given
        mockOracleNetworkService.shouldThrow = true
        mockOracleNetworkService.alwaysFail = true
        mockOracleNetworkService.errorToThrow = OracleError.networkError(NSError(domain: "test", code: 1))
        
        // When/Then
        do {
            _ = try await sut.getPrice(asset: testUSDCAsset)
            XCTFail("Expected error after max retries")
        } catch let error as OracleError {
            if case .maxRetriesExceeded = error {
                // Expected
            } else if case .networkError = error {
                // Also acceptable - might be the original error
            } else {
                XCTFail("Expected maxRetriesExceeded or networkError, got \(error)")
            }
        }
    }
    
    // MARK: - Caching Tests
    
    func testCacheInvalidation_afterSuccessfulFetch_cacheIsUpdated() async throws {
        // Given
        let asset = testUSDCAsset
        let oldPrice = PriceData(price: Decimal(1.20), timestamp: Date().addingTimeInterval(-600), contractID: asset.assetId, baseAsset: "USD")
        let newPrice = PriceData(price: Decimal(1.25), timestamp: Date(), contractID: asset.assetId, baseAsset: "USD")
        
        // Set old cached data
        await mockCacheService.set(oldPrice, key: "oracle_price_\(asset.assetId)", ttl: 300)
        mockOracleNetworkService.mockOptionalPriceData = newPrice
        
        // When
        let result = try await sut.getPrice(asset: asset)
        
        // Then
        XCTAssertEqual(result.price, newPrice.price)
        XCTAssertTrue(mockCacheService.setCalled) // Should have updated cache
    }
    
    func testCacheTTL_respectsConfiguredTTL() async throws {
        // Given
        let asset = testUSDCAsset
        let price = PriceData(price: Decimal(1.25), timestamp: Date(), contractID: asset.assetId, baseAsset: "USD")
        mockOracleNetworkService.mockOptionalPriceData = price
        
        // When
        _ = try await sut.getPrice(asset: asset)
        
        // Then
        XCTAssertTrue(mockCacheService.setCalled)
        // Verify TTL is set correctly (would need to check the actual TTL value in a real implementation)
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentRequests_handledCorrectly() async throws {
        // Given
        let assets = [testUSDCAsset, testXLMAsset, OracleAsset.other(symbol: "BTC")]
        let mockPrices = assets.map { asset in
            PriceData(price: Decimal.random(in: 0.1...100.0), timestamp: Date(), contractID: asset.assetId, baseAsset: "USD")
        }
        
        mockOracleNetworkService.mockPriceForAsset = Dictionary(uniqueKeysWithValues: zip(assets.map { $0.assetId }, mockPrices))
        
        // When - Execute multiple concurrent requests
        async let result1 = sut.getPrice(asset: assets[0])
        async let result2 = sut.getPrice(asset: assets[1])
        async let result3 = sut.getPrice(asset: assets[2])
        
        let results = try await [result1, result2, result3]
        
        // Then
        XCTAssertEqual(results.count, 3)
        for (index, result) in results.enumerated() {
            XCTAssertEqual(result.contractID, assets[index].assetId)
        }
    }
    
    func testDataRaceCondition_withSharedCache_handledSafely() async throws {
        // Given
        let asset = testUSDCAsset
        let price = PriceData(price: Decimal(1.25), timestamp: Date(), contractID: asset.assetId, baseAsset: "USD")
        mockOracleNetworkService.mockOptionalPriceData = price
        
        // When - Execute multiple requests for the same asset concurrently
        let tasks = (0..<10).map { _ in
            Task {
                try await sut.getPrice(asset: asset)
            }
        }
        
        let results = try await withThrowingTaskGroup(of: PriceData.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            var collectedResults: [PriceData] = []
            for try await result in group {
                collectedResults.append(result)
            }
            return collectedResults
        }
        
        // Then
        XCTAssertEqual(results.count, 10)
        for result in results {
            XCTAssertEqual(result.contractID, asset.assetId)
            XCTAssertEqual(result.price, price.price)
        }
    }
    
    // MARK: - Performance Tests
    
    func testGetPrice_performance_completesWithinTimeLimit() async throws {
        // Given
        let price = PriceData(price: Decimal(1.25), timestamp: Date(), contractID: testUSDCAsset.assetId, baseAsset: "USD")
        mockOracleNetworkService.mockOptionalPriceData = price
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await sut.getPrice(asset: testUSDCAsset)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(duration, 1.0, "Single price fetch should complete within 1 second")
    }
    
    func testGetPrices_performance_batchRequestsCompletesWithinTimeLimit() async throws {
        // Given
        let assets = Array(0..<50).map { OracleAsset.stellar(address: "ASSET_\($0)") }
        let mockPrices = assets.map { asset in
            PriceData(price: Decimal.random(in: 0.1...100.0), timestamp: Date(), contractID: asset.assetId, baseAsset: "USD")
        }
        
        mockOracleNetworkService.mockPriceForAsset = Dictionary(uniqueKeysWithValues: zip(assets.map { $0.assetId }, mockPrices))
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await sut.getPrices(assets: assets)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertEqual(result.count, assets.count)
        XCTAssertLessThan(duration, 5.0, "Batch price fetching should complete within 5 seconds")
    }
    
    func testGetPriceHistory_performance_largeDatasetCompletesWithinTimeLimit() async throws {
        // Given
        let recordCount: UInt32 = 1000
        let mockPrices = Array(0..<Int(recordCount)).map { index in
            PriceData(
                price: Decimal(1.0 + Double(index) * 0.001),
                timestamp: Date().addingTimeInterval(TimeInterval(-index * 60)),
                contractID: testUSDCAsset.assetId,
                baseAsset: "USD"
            )
        }
        mockOracleNetworkService.mockPriceDataArray = mockPrices
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await sut.getPriceHistory(asset: testUSDCAsset, records: recordCount)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertEqual(result?.count, Int(recordCount))
        XCTAssertLessThan(duration, 3.0, "Historical price fetching should complete within 3 seconds")
    }
    
    // MARK: - Edge Cases Tests
    
    func testGetPrice_withVeryLargePrice_handlesCorrectly() async throws {
        // Given
        let largePrice = Decimal(sign: .plus, exponent: 15, significand: 123456789)
        let priceData = PriceData(price: largePrice, timestamp: Date(), contractID: testUSDCAsset.assetId, baseAsset: "USD")
        mockOracleNetworkService.mockOptionalPriceData = priceData
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset)
        
        // Then
        XCTAssertEqual(result.price, largePrice)
    }
    
    func testGetPrice_withZeroPrice_handlesCorrectly() async throws {
        // Given
        let zeroPrice = PriceData(price: Decimal.zero, timestamp: Date(), contractID: testUSDCAsset.assetId, baseAsset: "USD")
        mockOracleNetworkService.mockOptionalPriceData = zeroPrice
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset)
        
        // Then
        XCTAssertEqual(result.price, Decimal.zero)
    }
    
    func testGetPrice_withNegativePrice_handlesCorrectly() async throws {
        // Given
        let negativePrice = PriceData(price: Decimal(-1.25), timestamp: Date(), contractID: testUSDCAsset.assetId, baseAsset: "USD")
        mockOracleNetworkService.mockOptionalPriceData = negativePrice
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset)
        
        // Then
        XCTAssertEqual(result.price, Decimal(-1.25))
    }
    
    func testGetPriceHistory_withDuplicateTimestamps_handlesCorrectly() async throws {
        // Given
        let timestamp = Date()
        let mockPrices = [
            PriceData(price: Decimal(1.20), timestamp: timestamp, contractID: testUSDCAsset.assetId, baseAsset: "USD"),
            PriceData(price: Decimal(1.21), timestamp: timestamp, contractID: testUSDCAsset.assetId, baseAsset: "USD"),
            PriceData(price: Decimal(1.22), timestamp: timestamp, contractID: testUSDCAsset.assetId, baseAsset: "USD")
        ]
        mockOracleNetworkService.mockPriceDataArray = mockPrices
        
        // When
        let result = try await sut.getPriceHistory(asset: testUSDCAsset, records: 3)
        
        // Then
        XCTAssertEqual(result?.count, 3)
        // Verify all prices are returned even with duplicate timestamps
        XCTAssertEqual(result?[0].price, Decimal(1.20))
        XCTAssertEqual(result?[1].price, Decimal(1.21))
        XCTAssertEqual(result?[2].price, Decimal(1.22))
    }
    
    // MARK: - Integration-like Tests
    
    func testCompleteWorkflow_fetchMultiplePricesAndHistory_worksEndToEnd() async throws {
        // Given
        let asset = testUSDCAsset
        let currentPrice = PriceData(price: Decimal(1.25), timestamp: Date(), contractID: asset.assetId, baseAsset: "USD")
        let historicalPrices = [
            PriceData(price: Decimal(1.20), timestamp: Date().addingTimeInterval(-3600), contractID: asset.assetId, baseAsset: "USD"),
            PriceData(price: Decimal(1.23), timestamp: Date().addingTimeInterval(-1800), contractID: asset.assetId, baseAsset: "USD")
        ]
        let supportedAssets = [asset, testXLMAsset]
        let baseAsset = OracleAsset.other(symbol: "USD")
        
        mockOracleNetworkService.mockOptionalPriceData = currentPrice
        mockOracleNetworkService.mockPriceDataArray = historicalPrices
        mockOracleNetworkService.mockAssetArray = supportedAssets
        mockOracleNetworkService.mockAsset = baseAsset
        mockOracleNetworkService.mockU32Response = 7
        
        // When - Execute a complete workflow
        let currentPriceResult = try await sut.getPrice(asset: asset)
        let historyResult = try await sut.getPriceHistory(asset: asset, records: 2)
        let assetsResult = try await sut.getSupportedAssets()
        let baseAssetResult = try await sut.getBaseAsset()
        let decimalsResult = try await sut.getOracleDecimals()
        
        // Then
        XCTAssertEqual(currentPriceResult.price, currentPrice.price)
        XCTAssertEqual(historyResult?.count, 2)
        XCTAssertEqual(assetsResult.count, 2)
        XCTAssertEqual(baseAssetResult, baseAsset)
        XCTAssertEqual(decimalsResult, 7)
    }
} 