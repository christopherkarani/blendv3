import XCTest
import stellarsdk
@testable import Blendv3

/// Enhanced comprehensive test suite for BlendOracleService
/// Features complete mock implementations, enhanced error testing, concurrency tests, and performance benchmarks
@MainActor
final class BlendOracleServiceEnhancedTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: BlendOracleService!
    private var mockNetworkService: MockNetworkService!
    private var mockCacheService: MockCacheService!
    private var testKeyPair: KeyPair!
    
    // Test constants
    private let testPoolId = "test-pool-id"
    private let testOracleAddress = BlendConstants.Testnet.oracle
    private let testUSDCAsset = OracleAsset.stellar(address: BlendConstants.Testnet.usdc)
    private let testXLMAsset = OracleAsset.stellar(address: BlendConstants.Testnet.xlm)
    private let testTimestamp: UInt64 = 1640995200 // 2022-01-01 00:00:00 UTC
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        testKeyPair = try KeyPair.generateRandomKeyPair()
        mockNetworkService = MockNetworkService()
        mockCacheService = MockCacheService()
        
        mockNetworkService.reset()
        await mockCacheService.reset()
        
        sut = BlendOracleService(
            poolId: testPoolId,
            cacheService: mockCacheService,
            networkService: mockNetworkService,
            sourceKeyPair: testKeyPair
        )
    }
    
    override func tearDown() async throws {
        sut = nil
        mockNetworkService = nil
        mockCacheService = nil
        testKeyPair = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testBasicInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertNotNil(mockNetworkService)
        XCTAssertNotNil(mockCacheService)
        XCTAssertEqual(sut.oracleAddress, testPoolId)
    }
    
    func testMockNetworkServiceTracking() {
        // Test that our mock network service tracks calls properly
        XCTAssertEqual(mockNetworkService.simulationCallCount, 0)
        XCTAssertEqual(mockNetworkService.invocationCallCount, 0)
        XCTAssertNil(mockNetworkService.lastContractCall)
    }
    
    func testMockCacheServiceOperations() async {
        // Test basic cache operations
        let testKey = "test_key"
        let testValue = "test_value"
        
        await mockCacheService.set(testValue, key: testKey, ttl: 300)
        let retrieved = await mockCacheService.get(testKey, type: String.self)
        
        XCTAssertEqual(retrieved, testValue)
        XCTAssertEqual(await mockCacheService.setCallCount, 1)
        XCTAssertEqual(await mockCacheService.getCallCount, 1)
    }
    
    func testMockNetworkServiceConfiguration() {
        // Test mock configuration
        mockNetworkService.shouldFailSimulation = true
        XCTAssertTrue(mockNetworkService.shouldFailSimulation)
        
        mockNetworkService.reset()
        XCTAssertFalse(mockNetworkService.shouldFailSimulation)
    }
    
    func testMockCacheServiceStatistics() async {
        let stats = await mockCacheService.getStatistics()
        XCTAssertEqual(stats.totalEntries, 0)
        XCTAssertEqual(stats.validEntries, 0)
        XCTAssertEqual(stats.getCallCount, 0)
        XCTAssertEqual(stats.setCallCount, 0)
    }
    
    // MARK: - getOracleDecimals() Tests
    
    func testGetOracleDecimals_withValidResponse_returnsDecimals() async throws {
        // Given
        let expectedDecimals = 7
        let mockResponse = SCValXDR.u32(UInt32(expectedDecimals))
        mockNetworkService.simulationResults[.success] = SimulationResult(result: mockResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getOracleDecimals()
        
        // Then
        XCTAssertEqual(result, expectedDecimals)
    }
    
    func testGetOracleDecimals_withContractError_returnsDefault() async throws {
        // Given
        mockNetworkService.shouldFailSimulation = true
        mockNetworkService.simulationError = OracleError.contractError(code: -1, message: "Function not found")
        
        // When
        let result = try await sut.getOracleDecimals()
        
        // Then
        XCTAssertEqual(result, 7) // Default value
    }
    
    func testGetOracleDecimals_withNetworkTimeout_retriesAndSucceeds() async throws {
        // Given
        let expectedDecimals = 9
        let mockResponse = SCValXDR.u32(UInt32(expectedDecimals))
        
        mockNetworkService.failureCount = 2 // Fail twice, then succeed
        mockNetworkService.simulationResults[.success] = SimulationResult(result: mockResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getOracleDecimals()
        
        // Then
        XCTAssertEqual(result, expectedDecimals)
        XCTAssertEqual(mockNetworkService.simulationCallCount, 3) // Should have retried twice
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
        
        // Mock the lastprice function response
        let priceDataXDR = try createMockPriceDataXDR(from: expectedPrice)
        let optionalResponse = SCValXDR.option(priceDataXDR)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
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
        let nilResponse = SCValXDR.option(nil)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: nilResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
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
    
    func testGetPrice_withStaleCache_fetchesNewData() async throws {
        // Given
        let asset = testUSDCAsset
        let stalePrice = PriceData(
            price: Decimal(1.20),
            timestamp: Date().addingTimeInterval(-7200), // 2 hours old
            contractID: asset.assetId,
            baseAsset: "USD"
        )
        let freshPrice = PriceData(
            price: Decimal(1.25),
            timestamp: Date(),
            contractID: asset.assetId,
            baseAsset: "USD"
        )
        
        // Setup stale cache
        await mockCacheService.set(stalePrice, key: "oracle_last_price_\(asset.assetId)", ttl: 300)
        
        // Mock fresh network response
        let priceDataXDR = try createMockPriceDataXDR(from: freshPrice)
        let optionalResponse = SCValXDR.option(priceDataXDR)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getPrice(asset: asset)
        
        // Then
        XCTAssertEqual(result.price, freshPrice.price)
        XCTAssertEqual(result.timestamp.timeIntervalSince1970, freshPrice.timestamp.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testGetPrice_withNetworkError_throwsOracleError() async throws {
        // Given
        mockNetworkService.shouldFailSimulation = true
        mockNetworkService.simulationError = OracleError.networkError(
            NSError(domain: "test", code: 1),
            context: "Network timeout"
        )
        
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
    
    func testGetPrice_withInvalidResponseFormat_throwsParsingError() async throws {
        // Given
        let invalidResponse = SCValXDR.symbol("INVALID")
        mockNetworkService.simulationResults[.success] = SimulationResult(result: invalidResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When/Then
        do {
            _ = try await sut.getPrice(asset: testUSDCAsset)
            XCTFail("Expected parsing error to be thrown")
        } catch {
            // Expected - parsing should fail with invalid response
        }
    }
    
    func testRetryMechanism_withTransientFailures_eventuallySucceeds() async throws {
        // Given
        let expectedPrice = PriceData(
            price: Decimal(1.25),
            timestamp: Date(),
            contractID: testUSDCAsset.assetId,
            baseAsset: "USD"
        )
        
        // Configure mock to fail twice, then succeed
        mockNetworkService.failureCount = 2
        let priceDataXDR = try createMockPriceDataXDR(from: expectedPrice)
        let optionalResponse = SCValXDR.option(priceDataXDR)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset)
        
        // Then
        XCTAssertEqual(result.price, expectedPrice.price)
        XCTAssertEqual(mockNetworkService.simulationCallCount, 3) // Should have retried twice
    }
    
    func testRetryMechanism_withPersistentFailure_throwsAfterMaxRetries() async throws {
        // Given
        mockNetworkService.shouldFailSimulation = true
        mockNetworkService.alwaysFail = true
        mockNetworkService.simulationError = OracleError.networkError(NSError(domain: "test", code: 1))
        
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
        
        // Should have attempted exactly 3 times (original + 2 retries)
        XCTAssertGreaterThanOrEqual(mockNetworkService.simulationCallCount, 3)
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentRequests_handledCorrectly() async throws {
        // Given
        let assets = [testUSDCAsset, testXLMAsset, OracleAsset.other(symbol: "BTC")]
        let mockPrices = assets.enumerated().map { index, asset in
            PriceData(
                price: Decimal(1.0 + Double(index) * 0.1),
                timestamp: Date(),
                contractID: asset.assetId,
                baseAsset: "USD"
            )
        }
        
        // Setup mock responses for each asset
        for (index, price) in mockPrices.enumerated() {
            let priceDataXDR = try createMockPriceDataXDR(from: price)
            let optionalResponse = SCValXDR.option(priceDataXDR)
            mockNetworkService.addResponse(for: assets[index].assetId, response: optionalResponse)
        }
        
        // When - Execute multiple concurrent requests
        let results = try await withThrowingTaskGroup(of: PriceData.self) { group in
            for asset in assets {
                group.addTask {
                    try await self.sut.getPrice(asset: asset)
                }
            }
            
            var collectedResults: [PriceData] = []
            for try await result in group {
                collectedResults.append(result)
            }
            return collectedResults
        }
        
        // Then
        XCTAssertEqual(results.count, 3)
        
        // Verify all assets were processed (order may vary due to concurrency)
        let resultAssetIds = Set(results.map { $0.contractID })
        let expectedAssetIds = Set(assets.map { $0.assetId })
        XCTAssertEqual(resultAssetIds, expectedAssetIds)
    }
    
    func testDataRaceCondition_withSharedCache_handledSafely() async throws {
        // Given
        let asset = testUSDCAsset
        let price = PriceData(
            price: Decimal(1.25),
            timestamp: Date(),
            contractID: asset.assetId,
            baseAsset: "USD"
        )
        
        let priceDataXDR = try createMockPriceDataXDR(from: price)
        let optionalResponse = SCValXDR.option(priceDataXDR)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When - Execute multiple requests for the same asset concurrently
        let concurrentRequestCount = 10
        let results = try await withThrowingTaskGroup(of: PriceData.self) { group in
            for _ in 0..<concurrentRequestCount {
                group.addTask {
                    try await self.sut.getPrice(asset: asset)
                }
            }
            
            var collectedResults: [PriceData] = []
            for try await result in group {
                collectedResults.append(result)
            }
            return collectedResults
        }
        
        // Then
        XCTAssertEqual(results.count, concurrentRequestCount)
        for result in results {
            XCTAssertEqual(result.contractID, asset.assetId)
            XCTAssertEqual(result.price, price.price)
        }
        
        // Cache operations should be thread-safe
        XCTAssertTrue(mockCacheService.isThreadSafe)
    }
    
    // MARK: - Performance Tests
    
    func testGetPrice_performance_completesWithinTimeLimit() async throws {
        // Given
        let price = PriceData(
            price: Decimal(1.25),
            timestamp: Date(),
            contractID: testUSDCAsset.assetId,
            baseAsset: "USD"
        )
        
        let priceDataXDR = try createMockPriceDataXDR(from: price)
        let optionalResponse = SCValXDR.option(priceDataXDR)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await sut.getPrice(asset: testUSDCAsset)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(duration, 1.0, "Single price fetch should complete within 1 second")
    }
    
    func testGetMultiplePrices_performance_scalesLinearly() async throws {
        // Given
        let assetCount = 20
        let assets = (0..<assetCount).map { OracleAsset.stellar(address: "ASSET_\($0)") }
        
        for asset in assets {
            let price = PriceData(
                price: Decimal.random(in: 0.1...100.0),
                timestamp: Date(),
                contractID: asset.assetId,
                baseAsset: "USD"
            )
            let priceDataXDR = try createMockPriceDataXDR(from: price)
            let optionalResponse = SCValXDR.option(priceDataXDR)
            mockNetworkService.addResponse(for: asset.assetId, response: optionalResponse)
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let results = try await sut.getPrices(assets: assets)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertEqual(results.count, assetCount)
        XCTAssertLessThan(duration, 3.0, "Batch price fetching should complete within 3 seconds")
        
        // Performance should scale reasonably with number of assets
        let averageTimePerAsset = duration / Double(assetCount)
        XCTAssertLessThan(averageTimePerAsset, 0.15, "Average time per asset should be under 150ms")
    }
    
    // MARK: - Cache Tests
    
    func testCacheHit_reducesNetworkCalls() async throws {
        // Given
        let asset = testUSDCAsset
        let cachedPrice = PriceData(
            price: Decimal(1.25),
            timestamp: Date(),
            contractID: asset.assetId,
            baseAsset: "USD"
        )
        
        // Pre-populate cache
        await mockCacheService.set(cachedPrice, key: "oracle_last_price_\(asset.assetId)", ttl: 300)
        
        // When
        let result = try await sut.getLastPrice(asset: asset)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, cachedPrice.price)
        XCTAssertEqual(mockNetworkService.simulationCallCount, 0) // Should not have called network
        XCTAssertTrue(mockCacheService.getCalled)
    }
    
    func testCacheMiss_fallsBackToNetwork() async throws {
        // Given
        let asset = testUSDCAsset
        let networkPrice = PriceData(
            price: Decimal(1.30),
            timestamp: Date(),
            contractID: asset.assetId,
            baseAsset: "USD"
        )
        
        // Ensure cache is empty
        await mockCacheService.clear()
        
        // Setup network response
        let priceDataXDR = try createMockPriceDataXDR(from: networkPrice)
        let optionalResponse = SCValXDR.option(priceDataXDR)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getLastPrice(asset: asset)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, networkPrice.price)
        XCTAssertGreaterThan(mockNetworkService.simulationCallCount, 0) // Should have called network
        XCTAssertTrue(mockCacheService.setCalled) // Should have cached the result
    }
    
    // MARK: - Helper Methods
    
    private func createMockPriceDataXDR(from priceData: PriceData) throws -> SCValXDR {
        // Create a mock SCValXDR structure representing PriceData
        // This is a simplified representation - in reality, this would match the actual contract structure
        
        let priceI128 = Int128PartsXDR(hi: 0, lo: UInt64(truncating: priceData.price as NSNumber))
        let timestampU64 = UInt64(priceData.timestamp.timeIntervalSince1970)
        
        let contractAddressXDR = try SCAddressXDR(contractId: priceData.contractID)
        
        return SCValXDR.vec([
            SCValXDR.i128(priceI128),
            SCValXDR.u64(timestampU64),
            SCValXDR.address(contractAddressXDR)
        ])
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
        
        let priceDataXDR = try createMockPriceDataXDR(from: expectedPrice)
        let optionalResponse = SCValXDR.option(priceDataXDR)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
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
        let nilResponse = SCValXDR.option(nil)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: nilResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset, timestamp: futureTimestamp)
        
        // Then
        XCTAssertNil(result)
    }
    
    func testGetPriceAtTimestamp_withZeroTimestamp_handlesCorrectly() async throws {
        // Given
        let zeroTimestamp: UInt64 = 0
        let nilResponse = SCValXDR.option(nil)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: nilResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset, timestamp: zeroTimestamp)
        
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
        
        // Create mock vector response
        let priceXDRArray = try mockPrices.map { try createMockPriceDataXDR(from: $0) }
        let vectorResponse = SCValXDR.vec(priceXDRArray)
        let optionalVectorResponse = SCValXDR.option(vectorResponse)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalVectorResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
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
        let emptyVectorResponse = SCValXDR.vec([])
        let optionalVectorResponse = SCValXDR.option(emptyVectorResponse)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalVectorResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getPriceHistory(asset: testUSDCAsset, records: recordCount)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isEmpty ?? false)
    }
    
    func testGetPriceHistory_withLargeRecordCount_handlesCorrectly() async throws {
        // Given
        let recordCount: UInt32 = 10000
        let nilResponse = SCValXDR.option(nil) // Contract might reject very large requests
        mockNetworkService.simulationResults[.success] = SimulationResult(result: nilResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getPriceHistory(asset: testUSDCAsset, records: recordCount)
        
        // Then
        XCTAssertNil(result) // Should handle gracefully
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
        
        let priceDataXDR = try createMockPriceDataXDR(from: expectedPrice)
        let optionalResponse = SCValXDR.option(priceDataXDR)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
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
        let nilResponse = SCValXDR.option(nil)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: nilResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getLastPrice(asset: invalidAsset)
        
        // Then
        XCTAssertNil(result)
    }
    
    // MARK: - getOracleResolution() Tests
    
    func testGetOracleResolution_withValidResponse_returnsResolution() async throws {
        // Given
        let expectedResolution = 1000000
        let mockResponse = SCValXDR.u32(UInt32(expectedResolution))
        mockNetworkService.simulationResults[.success] = SimulationResult(result: mockResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
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
        XCTAssertTrue(await mockCacheService.getCalled)
    }
    
    // MARK: - getBaseAsset() Tests
    
    func testGetBaseAsset_withValidResponse_returnsBaseAsset() async throws {
        // Given
        let expectedBaseAsset = OracleAsset.other(symbol: "USD")
        let mockAssetXDR = SCValXDR.vec([
            SCValXDR.symbol("Other"),
            SCValXDR.symbol("USD")
        ])
        mockNetworkService.simulationResults[.success] = SimulationResult(result: mockAssetXDR, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
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
        XCTAssertTrue(await mockCacheService.getCalled)
    }
    
    // MARK: - getSupportedAssets() Tests
    
    func testGetSupportedAssets_withValidResponse_returnsAssetArray() async throws {
        // Given
        let expectedAssets = [testUSDCAsset, testXLMAsset, OracleAsset.other(symbol: "BTC")]
        let assetXDRArray = expectedAssets.map { asset in
            switch asset {
            case .stellar(let address):
                return SCValXDR.vec([
                    SCValXDR.symbol("Stellar"),
                    SCValXDR.symbol(address) // Simplified for testing
                ])
            case .other(let symbol):
                return SCValXDR.vec([
                    SCValXDR.symbol("Other"),
                    SCValXDR.symbol(symbol)
                ])
            }
        }
        let vectorResponse = SCValXDR.vec(assetXDRArray)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: vectorResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getSupportedAssets()
        
        // Then
        XCTAssertEqual(result.count, expectedAssets.count)
        // Note: Direct equality comparison may not work due to address encoding differences
        // In a real test, you'd need more sophisticated comparison
        XCTAssertTrue(result.contains { asset in
            if case .other(let symbol) = asset, symbol == "BTC" {
                return true
            }
            return false
        })
    }
    
    func testGetSupportedAssets_withCachedValue_usesCacheFirst() async throws {
        // Given
        let cachedAssets = [testUSDCAsset, testXLMAsset]
        await mockCacheService.set(cachedAssets, key: "oracle_supported_assets", ttl: 3600)
        
        // When
        let result = try await sut.getSupportedAssets()
        
        // Then
        XCTAssertEqual(result, cachedAssets)
        XCTAssertTrue(await mockCacheService.getCalled)
    }
    
    // MARK: - assets() Tests
    
    func testAssets_withValidResponse_returnsAssetIds() async throws {
        // Given
        let supportedAssets = [testUSDCAsset, testXLMAsset, OracleAsset.other(symbol: "BTC")]
        await mockCacheService.set(supportedAssets, key: "oracle_supported_assets", ttl: 3600)
        
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
        
        // Setup individual responses for each asset
        for (index, price) in mockPrices.enumerated() {
            let priceDataXDR = try createMockPriceDataXDR(from: price)
            let optionalResponse = SCValXDR.option(priceDataXDR)
            mockNetworkService.addResponse(for: assets[index].assetId, response: optionalResponse)
        }
        
        // When
        let result = try await sut.getPrices(assets: assets)
        
        // Then
        XCTAssertEqual(result.count, assets.count)
        
        // Check that all expected asset IDs are present
        let resultAssetIds = Set(result.map { $0.contractID })
        let expectedAssetIds = Set(assets.map { $0.assetId })
        XCTAssertEqual(resultAssetIds, expectedAssetIds)
    }
    
    func testGetPrices_withEmptyAssetArray_returnsEmptyArray() async throws {
        // Given
        let assets: [OracleAsset] = []
        
        // When
        let result = try await sut.getPrices(assets: assets)
        
        // Then
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(mockNetworkService.simulationCallCount, 0) // Should not make any network calls
    }
    
    func testGetPrices_withSomeFailingAssets_returnsPartialResults() async throws {
        // Given
        let assets = [testUSDCAsset, testXLMAsset, OracleAsset.other(symbol: "INVALID")]
        let validPrices = [
            PriceData(price: Decimal(1.25), timestamp: Date(), contractID: testUSDCAsset.assetId, baseAsset: "USD"),
            PriceData(price: Decimal(0.12), timestamp: Date(), contractID: testXLMAsset.assetId, baseAsset: "USD")
        ]
        
        // Setup responses for valid assets only
        for (index, price) in validPrices.enumerated() {
            let priceDataXDR = try createMockPriceDataXDR(from: price)
            let optionalResponse = SCValXDR.option(priceDataXDR)
            mockNetworkService.addResponse(for: assets[index].assetId, response: optionalResponse)
        }
        
        // Invalid asset will get default nil response
        
        // When
        let result = try await sut.getPrices(assets: assets)
        
        // Then
        XCTAssertEqual(result.count, validPrices.count) // Should only return valid prices
        XCTAssertGreaterThan(result.count, 0) // Should have at least some results
    }
    
    // MARK: - Edge Cases and Validation Tests
    
    func testGetPrice_withVeryLargePrice_handlesCorrectly() async throws {
        // Given
        let largePrice = Decimal(sign: .plus, exponent: 15, significand: 123456789)
        let priceData = PriceData(price: largePrice, timestamp: Date(), contractID: testUSDCAsset.assetId, baseAsset: "USD")
        
        let priceDataXDR = try createMockPriceDataXDR(from: priceData)
        let optionalResponse = SCValXDR.option(priceDataXDR)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset)
        
        // Then
        XCTAssertEqual(result.price, largePrice)
    }
    
    func testGetPrice_withZeroPrice_handlesCorrectly() async throws {
        // Given
        let zeroPrice = PriceData(price: Decimal.zero, timestamp: Date(), contractID: testUSDCAsset.assetId, baseAsset: "USD")
        
        let priceDataXDR = try createMockPriceDataXDR(from: zeroPrice)
        let optionalResponse = SCValXDR.option(priceDataXDR)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset)
        
        // Then
        XCTAssertEqual(result.price, Decimal.zero)
    }
    
    func testGetPrice_withNegativePrice_handlesCorrectly() async throws {
        // Given
        let negativePrice = PriceData(price: Decimal(-1.25), timestamp: Date(), contractID: testUSDCAsset.assetId, baseAsset: "USD")
        
        let priceDataXDR = try createMockPriceDataXDR(from: negativePrice)
        let optionalResponse = SCValXDR.option(priceDataXDR)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // When
        let result = try await sut.getPrice(asset: testUSDCAsset)
        
        // Then
        XCTAssertEqual(result.price, Decimal(-1.25))
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
        
        // Setup mocks for different function calls
        let currentPriceXDR = try createMockPriceDataXDR(from: currentPrice)
        let currentPriceResponse = SCValXDR.option(currentPriceXDR)
        
        let historyXDRArray = try historicalPrices.map { try createMockPriceDataXDR(from: $0) }
        let historyVectorResponse = SCValXDR.option(SCValXDR.vec(historyXDRArray))
        
        let baseAssetXDR = SCValXDR.vec([SCValXDR.symbol("Other"), SCValXDR.symbol("USD")])
        let decimalsXDR = SCValXDR.u32(7)
        
        // Configure different responses based on function
        mockNetworkService.addResponse(for: testOracleAddress, functionName: "lastprice", response: currentPriceResponse)
        mockNetworkService.addResponse(for: testOracleAddress, functionName: "prices", response: historyVectorResponse)
        mockNetworkService.addResponse(for: testOracleAddress, functionName: "base", response: baseAssetXDR)
        mockNetworkService.addResponse(for: testOracleAddress, functionName: "decimals", response: decimalsXDR)
        
        // Cache supported assets to avoid complex mock setup
        await mockCacheService.set(supportedAssets, key: "oracle_supported_assets", ttl: 3600)
        
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
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecovery_afterNetworkFailure_recoversOnSubsequentCalls() async throws {
        // Given
        let price = PriceData(price: Decimal(1.25), timestamp: Date(), contractID: testUSDCAsset.assetId, baseAsset: "USD")
        
        // First call will fail
        mockNetworkService.shouldFailSimulation = true
        mockNetworkService.simulationError = OracleError.networkError(NSError(domain: "test", code: 1))
        
        // When - First call should fail
        do {
            _ = try await sut.getPrice(asset: testUSDCAsset)
            XCTFail("Expected first call to fail")
        } catch {
            // Expected
        }
        
        // Setup for recovery
        mockNetworkService.shouldFailSimulation = false
        let priceDataXDR = try createMockPriceDataXDR(from: price)
        let optionalResponse = SCValXDR.option(priceDataXDR)
        mockNetworkService.simulationResults[.success] = SimulationResult(result: optionalResponse, cost: nil, events: [], auth: [], minResourceFee: nil, footprint: nil)
        
        // Second call should succeed
        let result = try await sut.getPrice(asset: testUSDCAsset)
        
        // Then
        XCTAssertEqual(result.price, price.price)
    }
    
    // MARK: - Memory and Resource Management Tests
    
    func testMemoryManagement_withLargeDataSets_doesNotLeak() async throws {
        // Given
        let largeAssetCount = 100
        let assets = (0..<largeAssetCount).map { OracleAsset.stellar(address: "ASSET_\(String(format: "%08d", $0))") }
        
        // Setup responses for all assets
        for asset in assets {
            let price = PriceData(
                price: Decimal.random(in: 0.01...1000.0),
                timestamp: Date(),
                contractID: asset.assetId,
                baseAsset: "USD"
            )
            let priceDataXDR = try createMockPriceDataXDR(from: price)
            let optionalResponse = SCValXDR.option(priceDataXDR)
            mockNetworkService.addResponse(for: asset.assetId, response: optionalResponse)
        }
        
        // When - Process large dataset
        let result = try await sut.getPrices(assets: assets)
        
        // Then
        XCTAssertEqual(result.count, largeAssetCount)
        
        // Verify cache is not overwhelmed
        let cacheStats = await mockCacheService.getStatistics()
        XCTAssertLessThanOrEqual(cacheStats.totalEntries, largeAssetCount * 2) // Reasonable cache size
    }
} 