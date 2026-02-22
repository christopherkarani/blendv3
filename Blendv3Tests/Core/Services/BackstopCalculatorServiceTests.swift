import XCTest
@testable import Blendv3

final class BackstopCalculatorServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: BackstopCalculatorService!
    private var mockOracleService: MockBlendOracleService!
    private var mockCacheService: MockCacheService!
    private var testBackstopPool: BackstopPool!
    private var testEmissionsData: EmissionsData!
    private var testUserEmissionsState: UserEmissionsState!
    private var testAuctionData: AuctionData!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        setupMocks()
        setupTestData()
        sut = BackstopCalculatorService(oracleService: mockOracleService, cacheService: mockCacheService)
    }
    
    override func tearDown() {
        sut = nil
        mockOracleService = nil
        mockCacheService = nil
        testBackstopPool = nil
        testEmissionsData = nil
        testUserEmissionsState = nil
        testAuctionData = nil
        super.tearDown()
    }
    
    private func setupMocks() {
        mockOracleService = MockBlendOracleService()
        mockCacheService = MockCacheService()
    }
    
    private func setupTestData() {
        testBackstopPool = BackstopPool(
            poolId: "test_pool_1",
            backstopTokenAddress: "backstop_token_addr",
            lpTokenAddress: "lp_token_addr",
            minThreshold: FixedMath.toFixed(value: 100000, decimals: 7),
            maxCapacity: FixedMath.toFixed(value: 1000000, decimals: 7),
            takeRate: FixedMath.toFixed(value: 0.1, decimals: 7), // 10%
            totalBackstopTokens: FixedMath.toFixed(value: 500000, decimals: 7),
            totalLpTokens: FixedMath.toFixed(value: 500000, decimals: 7),
            totalValueUSD: 500000.0
        )
        
        testEmissionsData = EmissionsData(
            poolId: "test_pool_1",
            blndTokenAddress: "blnd_token_addr",
            emissionsPerSecond: FixedMath.toFixed(value: 0.1, decimals: 7),
            totalAllocated: FixedMath.toFixed(value: 1000000, decimals: 7),
            endTime: Date().addingTimeInterval(86400 * 365) // 1 year from now
        )
        
        testUserEmissionsState = UserEmissionsState(
            userAddress: "user_address_1",
            poolId: "test_pool_1",
            backstopTokenBalance: FixedMath.toFixed(value: 10000, decimals: 7),
            shareOfPool: 0.02, // 2%
            lastClaimTime: Date().addingTimeInterval(-3600), // 1 hour ago
            accruedEmissions: FixedMath.toFixed(value: 100, decimals: 7)
        )
        
        testAuctionData = AuctionData(
            poolId: "test_pool_1",
            auctionType: .badDebt,
            assetAddress: "asset_addr",
            assetAmount: FixedMath.toFixed(value: 1000, decimals: 7),
            startingBid: FixedMath.toFixed(value: 700, decimals: 7),
            minBidIncrement: FixedMath.toFixed(value: 10, decimals: 7),
            reservePrice: FixedMath.toFixed(value: 500, decimals: 7)
        )
    }
    
    // MARK: - Backstop APR Calculation Tests
    
    func testCalculateBackstopAPR_withValidInputs_returnsCorrectAPR() {
        // Given
        let totalInterestPerYear: Double = 50000 // $50k per year
        
        // When
        let result = sut.calculateBackstopAPR(
            backstopPool: testBackstopPool,
            totalInterestPerYear: totalInterestPerYear
        )
        
        // Then
        let expectedAPR = Decimal(50000.0 / 500000.0) // 10%
        XCTAssertEqual(result, expectedAPR, accuracy: 0.0001)
    }
    
    func testCalculateBackstopAPR_withZeroValue_returnsZero() {
        // Given
        let zeroValuePool = BackstopPool(
            poolId: "zero_pool",
            backstopTokenAddress: "backstop_token_addr",
            lpTokenAddress: "lp_token_addr",
            minThreshold: FixedMath.toFixed(value: 100000, decimals: 7),
            maxCapacity: FixedMath.toFixed(value: 1000000, decimals: 7),
            takeRate: FixedMath.toFixed(value: 0.1, decimals: 7),
            totalBackstopTokens: FixedMath.toFixed(value: 500000, decimals: 7),
            totalLpTokens: FixedMath.toFixed(value: 500000, decimals: 7),
            totalValueUSD: 0 // Zero value
        )
        
        // When
        let result = sut.calculateBackstopAPR(
            backstopPool: zeroValuePool,
            totalInterestPerYear: 50000
        )
        
        // Then
        XCTAssertEqual(result, 0)
    }
    
    func testCalculateBackstopAPRFromReserves_withValidReserves_calculatesCorrectly() async throws {
        // Given
        let reserves = [
            PoolReserveData(
                assetId: "USDC",
                totalBorrowed: FixedMath.toFixed(value: 100000, decimals: 6), // 100k USDC
                borrowAPR: FixedMath.toFixed(value: 0.05, decimals: 7) // 5%
            ),
            PoolReserveData(
                assetId: "XLM",
                totalBorrowed: FixedMath.toFixed(value: 50000, decimals: 7), // 50k XLM
                borrowAPR: FixedMath.toFixed(value: 0.08, decimals: 7) // 8%
            )
        ]
        
        // Mock oracle prices
        mockOracleService.mockPrices = [
            "USDC": PriceData(price: FixedMath.toFixed(value: 1.0, decimals: 7), timestamp: Date()),
            "XLM": PriceData(price: FixedMath.toFixed(value: 0.1, decimals: 7), timestamp: Date())
        ]
        
        // When
        let result = try await sut.calculateBackstopAPRFromReserves(
            backstopPool: testBackstopPool,
            poolReserves: reserves
        )
        
        // Then
        XCTAssertGreaterThan(result, 0)
        XCTAssertLessThan(result, 1) // Should be reasonable APR
    }
    
    func testCalculateBackstopAPRFromReserves_withMissingPrices_handlesGracefully() async throws {
        // Given
        let reserves = [
            PoolReserveData(
                assetId: "UNKNOWN_ASSET",
                totalBorrowed: FixedMath.toFixed(value: 100000, decimals: 7),
                borrowAPR: FixedMath.toFixed(value: 0.05, decimals: 7)
            )
        ]
        
        // Mock oracle with no prices
        mockOracleService.mockPrices = [:]
        
        // When
        let result = try await sut.calculateBackstopAPRFromReserves(
            backstopPool: testBackstopPool,
            poolReserves: reserves
        )
        
        // Then
        XCTAssertEqual(result, 0) // Should return 0 when no valid prices
    }
    
    // MARK: - Emissions Calculation Tests
    
    func testCalculateClaimableEmissions_withActiveEmissions_calculatesCorrectly() {
        // When
        let result = sut.calculateClaimableEmissions(
            userState: testUserEmissionsState,
            emissionsData: testEmissionsData,
            backstopPool: testBackstopPool
        )
        
        // Then
        XCTAssertGreaterThan(result.accruedEmissions, testUserEmissionsState.accruedEmissions)
        XCTAssertEqual(result.userAddress, testUserEmissionsState.userAddress)
        XCTAssertEqual(result.poolId, testUserEmissionsState.poolId)
    }
    
    func testCalculateClaimableEmissions_withInactiveEmissions_returnsUnchanged() {
        // Given
        let inactiveEmissions = EmissionsData(
            poolId: "test_pool_1",
            blndTokenAddress: "blnd_token_addr",
            emissionsPerSecond: FixedMath.toFixed(value: 0.1, decimals: 7),
            totalAllocated: FixedMath.toFixed(value: 1000000, decimals: 7),
            endTime: Date().addingTimeInterval(-86400), // Ended yesterday
            isActive: false
        )
        
        // When
        let result = sut.calculateClaimableEmissions(
            userState: testUserEmissionsState,
            emissionsData: inactiveEmissions,
            backstopPool: testBackstopPool
        )
        
        // Then
        XCTAssertEqual(result.accruedEmissions, testUserEmissionsState.accruedEmissions)
    }
    
    func testCalculateEmissionsAPR_withValidInputs_calculatesCorrectly() {
        // Given
        let blndPrice: Double = 0.5 // $0.50 per BLND
        
        // When
        let result = sut.calculateEmissionsAPR(
            emissionsData: testEmissionsData,
            backstopPool: testBackstopPool,
            blndPrice: blndPrice
        )
        
        // Then
        XCTAssertGreaterThan(result, 0)
        XCTAssertLessThan(result, 10) // Should be reasonable APR
    }
    
    func testCalculateEmissionsAPR_withZeroValue_returnsZero() {
        // Given
        let zeroValuePool = BackstopPool(
            poolId: "zero_pool",
            backstopTokenAddress: "backstop_token_addr",
            lpTokenAddress: "lp_token_addr",
            minThreshold: FixedMath.toFixed(value: 100000, decimals: 7),
            maxCapacity: FixedMath.toFixed(value: 1000000, decimals: 7),
            takeRate: FixedMath.toFixed(value: 0.1, decimals: 7),
            totalBackstopTokens: FixedMath.toFixed(value: 500000, decimals: 7),
            totalLpTokens: FixedMath.toFixed(value: 500000, decimals: 7),
            totalValueUSD: 0 // Zero value
        )
        
        // When
        let result = sut.calculateEmissionsAPR(
            emissionsData: testEmissionsData,
            backstopPool: zeroValuePool,
            blndPrice: 0.5
        )
        
        // Then
        XCTAssertEqual(result, 0)
    }
    
    // MARK: - Q4W Calculation Tests
    
    func testCalculateOptimalQueueDelay_withNormalConditions_returnsDefaultDelay() {
        // Given
        let normalUtilization: Double = 0.5 // 50%
        
        // When
        let result = sut.calculateOptimalQueueDelay(
            backstopPool: testBackstopPool,
            currentUtilization: normalUtilization
        )
        
        // Then
        XCTAssertEqual(result, 604800) // 7 days default
    }
    
    func testCalculateOptimalQueueDelay_withHighUtilization_extendsDelay() {
        // Given
        let highUtilization: Double = 0.95 // 95%
        
        // When
        let result = sut.calculateOptimalQueueDelay(
            backstopPool: testBackstopPool,
            currentUtilization: highUtilization
        )
        
        // Then
        XCTAssertGreaterThan(result, 604800) // Should be extended
    }
    
    func testCalculateOptimalQueueDelay_withEmergencyStatus_returnsMaxDelay() {
        // Given
        let emergencyPool = BackstopPool(
            poolId: "emergency_pool",
            backstopTokenAddress: "backstop_token_addr",
            lpTokenAddress: "lp_token_addr",
            minThreshold: FixedMath.toFixed(value: 100000, decimals: 7),
            maxCapacity: FixedMath.toFixed(value: 1000000, decimals: 7),
            takeRate: FixedMath.toFixed(value: 0.1, decimals: 7),
            totalBackstopTokens: FixedMath.toFixed(value: 500000, decimals: 7),
            totalLpTokens: FixedMath.toFixed(value: 500000, decimals: 7),
            totalValueUSD: 500000.0,
            status: .emergency
        )
        
        // When
        let result = sut.calculateOptimalQueueDelay(
            backstopPool: emergencyPool,
            currentUtilization: 0.5
        )
        
        // Then
        XCTAssertEqual(result, 604800) // Maximum delay (7 days)
    }
    
    func testCalculateWithdrawalImpact_withNormalWithdrawal_returnsLowImpact() {
        // Given
        let smallWithdrawal = QueuedWithdrawal(
            userAddress: "user_address_1",
            poolId: "test_pool_1",
            backstopTokenAmount: FixedMath.toFixed(value: 1000, decimals: 7), // Small amount
            lpTokenAmount: FixedMath.toFixed(value: 1000, decimals: 7)
        )
        
        // When
        let result = sut.calculateWithdrawalImpact(
            withdrawal: smallWithdrawal,
            backstopPool: testBackstopPool
        )
        
        // Then
        XCTAssertEqual(result.impactSeverity, .low)
        XCTAssertFalse(result.breachesMinThreshold)
        XCTAssertLessThan(result.newUtilization, result.currentUtilization)
    }
    
    func testCalculateWithdrawalImpact_withLargeWithdrawal_returnsCriticalImpact() {
        // Given
        let largeWithdrawal = QueuedWithdrawal(
            userAddress: "user_address_1",
            poolId: "test_pool_1",
            backstopTokenAmount: FixedMath.toFixed(value: 450000, decimals: 7), // Large amount
            lpTokenAmount: FixedMath.toFixed(value: 450000, decimals: 7)
        )
        
        // When
        let result = sut.calculateWithdrawalImpact(
            withdrawal: largeWithdrawal,
            backstopPool: testBackstopPool
        )
        
        // Then
        XCTAssertEqual(result.impactSeverity, .critical)
        XCTAssertTrue(result.breachesMinThreshold)
    }
    
    // MARK: - Auction Calculation Tests
    
    func testCalculateAuctionParameters_withBadDebtAuction_returnsCorrectParameters() {
        // Given
        let assetAmount = FixedMath.toFixed(value: 1000, decimals: 7)
        let assetPrice = FixedMath.toFixed(value: 1.0, decimals: 7)
        
        // When
        let result = sut.calculateAuctionParameters(
            auctionType: .badDebt,
            assetAmount: assetAmount,
            assetPrice: assetPrice,
            urgency: .normal
        )
        
        // Then
        XCTAssertEqual(result.auctionType, .badDebt)
        XCTAssertGreaterThan(result.startingBid, result.reservePrice)
        XCTAssertEqual(result.duration, 86400) // 24 hours for normal urgency
        XCTAssertGreaterThan(result.minBidIncrement, 0)
    }
    
    func testCalculateAuctionParameters_withLiquidationAuction_returnsHigherStartingBid() {
        // Given
        let assetAmount = FixedMath.toFixed(value: 1000, decimals: 7)
        let assetPrice = FixedMath.toFixed(value: 1.0, decimals: 7)
        
        // When
        let badDebtParams = sut.calculateAuctionParameters(
            auctionType: .badDebt,
            assetAmount: assetAmount,
            assetPrice: assetPrice
        )
        
        let liquidationParams = sut.calculateAuctionParameters(
            auctionType: .liquidation,
            assetAmount: assetAmount,
            assetPrice: assetPrice
        )
        
        // Then
        XCTAssertGreaterThan(liquidationParams.startingBid, badDebtParams.startingBid)
    }
    
    func testCalculateAuctionParameters_withHighUrgency_reducesDuration() {
        // Given
        let assetAmount = FixedMath.toFixed(value: 1000, decimals: 7)
        let assetPrice = FixedMath.toFixed(value: 1.0, decimals: 7)
        
        // When
        let normalParams = sut.calculateAuctionParameters(
            auctionType: .badDebt,
            assetAmount: assetAmount,
            assetPrice: assetPrice,
            urgency: .normal
        )
        
        let highUrgencyParams = sut.calculateAuctionParameters(
            auctionType: .badDebt,
            assetAmount: assetAmount,
            assetPrice: assetPrice,
            urgency: .high
        )
        
        // Then
        XCTAssertLessThan(highUrgencyParams.duration, normalParams.duration)
    }
    
    func testValidateAuctionBid_withValidBid_returnsValid() {
        // Given
        let validBidAmount = FixedMath.toFixed(value: 750, decimals: 7) // Above current bid + increment
        let bidder = "bidder_address_1"
        
        // When
        let result = sut.validateAuctionBid(
            auction: testAuctionData,
            bidAmount: validBidAmount,
            bidder: bidder
        )
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.issues.isEmpty)
    }
    
    func testValidateAuctionBid_withLowBid_returnsInvalid() {
        // Given
        let lowBidAmount = FixedMath.toFixed(value: 650, decimals: 7) // Below minimum
        let bidder = "bidder_address_1"
        
        // When
        let result = sut.validateAuctionBid(
            auction: testAuctionData,
            bidAmount: lowBidAmount,
            bidder: bidder
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.issues.isEmpty)
        XCTAssertTrue(result.issues.first?.contains("below minimum") ?? false)
    }
    
    func testValidateAuctionBid_withInactiveAuction_returnsInvalid() {
        // Given
        let inactiveAuction = AuctionData(
            poolId: "test_pool_1",
            auctionType: .badDebt,
            assetAddress: "asset_addr",
            assetAmount: FixedMath.toFixed(value: 1000, decimals: 7),
            startingBid: FixedMath.toFixed(value: 700, decimals: 7),
            status: .completed,
            minBidIncrement: FixedMath.toFixed(value: 10, decimals: 7),
            reservePrice: FixedMath.toFixed(value: 500, decimals: 7)
        )
        
        let validBidAmount = FixedMath.toFixed(value: 750, decimals: 7)
        let bidder = "bidder_address_1"
        
        // When
        let result = sut.validateAuctionBid(
            auction: inactiveAuction,
            bidAmount: validBidAmount,
            bidder: bidder
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains("Auction is not active"))
    }
    
    func testValidateAuctionBid_withSameBidder_returnsInvalid() {
        // Given
        let auctionWithBidder = AuctionData(
            poolId: "test_pool_1",
            auctionType: .badDebt,
            assetAddress: "asset_addr",
            assetAmount: FixedMath.toFixed(value: 1000, decimals: 7),
            startingBid: FixedMath.toFixed(value: 700, decimals: 7),
            currentBid: FixedMath.toFixed(value: 750, decimals: 7),
            currentBidder: "bidder_address_1",
            minBidIncrement: FixedMath.toFixed(value: 10, decimals: 7),
            reservePrice: FixedMath.toFixed(value: 500, decimals: 7)
        )
        
        let bidAmount = FixedMath.toFixed(value: 800, decimals: 7)
        let sameBidder = "bidder_address_1"
        
        // When
        let result = sut.validateAuctionBid(
            auction: auctionWithBidder,
            bidAmount: bidAmount,
            bidder: sameBidder
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains("Cannot bid against yourself"))
    }
    
    func testValidateAuctionBid_reportGeneration_worksCorrectly() {
        // Given
        let lowBidAmount = FixedMath.toFixed(value: 650, decimals: 7)
        let bidder = "bidder_address_1"
        
        // When
        let result = sut.validateAuctionBid(
            auction: testAuctionData,
            bidAmount: lowBidAmount,
            bidder: bidder
        )
        
        let report = result.report
        
        // Then
        XCTAssertTrue(report.contains("Auction Bid Validation Report"))
        XCTAssertTrue(report.contains("❌ INVALID"))
        XCTAssertTrue(report.contains("Issues:"))
        XCTAssertTrue(report.contains(bidder))
    }
    
    // MARK: - Edge Cases Tests
    
    func testCalculateClaimableEmissions_withZeroBackstopTokens_handlesGracefully() {
        // Given
        let zeroTokenPool = BackstopPool(
            poolId: "zero_token_pool",
            backstopTokenAddress: "backstop_token_addr",
            lpTokenAddress: "lp_token_addr",
            minThreshold: FixedMath.toFixed(value: 100000, decimals: 7),
            maxCapacity: FixedMath.toFixed(value: 1000000, decimals: 7),
            takeRate: FixedMath.toFixed(value: 0.1, decimals: 7),
            totalBackstopTokens: 0, // Zero tokens
            totalLpTokens: 0,
            totalValueUSD: 0
        )
        
        // When
        let result = sut.calculateClaimableEmissions(
            userState: testUserEmissionsState,
            emissionsData: testEmissionsData,
            backstopPool: zeroTokenPool
        )
        
        // Then
        XCTAssertEqual(result.shareOfPool, 0)
        XCTAssertEqual(result.accruedEmissions, testUserEmissionsState.accruedEmissions)
    }
    
    // MARK: - Performance Tests
    
    func testBackstopCalculations_performance() {
        measure {
            for _ in 0..<100 {
                _ = sut.calculateBackstopAPR(
                    backstopPool: testBackstopPool,
                    totalInterestPerYear: 50000
                )
                
                _ = sut.calculateClaimableEmissions(
                    userState: testUserEmissionsState,
                    emissionsData: testEmissionsData,
                    backstopPool: testBackstopPool
                )
                
                _ = sut.calculateOptimalQueueDelay(
                    backstopPool: testBackstopPool,
                    currentUtilization: 0.5
                )
            }
        }
    }
}

// MARK: - Mock Services

private class MockBlendOracleService: BlendOracleServiceProtocol {
    var mockPrices: [String: PriceData] = [:]
    
    func getPrice(asset: String) async throws -> PriceData {
        guard let price = mockPrices[asset] else {
            throw OracleError.priceNotFound(asset: asset)
        }
        return price
    }
    
    func getPrices(assets: [String]) async throws -> [String: PriceData] {
        var result: [String: PriceData] = [:]
        for asset in assets {
            if let price = mockPrices[asset] {
                result[asset] = price
            }
        }
        return result
    }
}

private class MockCacheService: CacheServiceProtocol {
    private var cache: [String: Any] = [:]
    
    func get<T>(_ key: String, as type: T.Type) -> T? {
        return cache[key] as? T
    }
    
    func set<T>(_ value: T, forKey key: String, ttl: TimeInterval) {
        cache[key] = value
    }
    
    func remove(_ key: String) {
        cache.removeValue(forKey: key)
    }
    
    func clear() {
        cache.removeAll()
    }
} 