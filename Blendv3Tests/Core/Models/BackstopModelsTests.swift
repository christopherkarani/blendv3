import XCTest
@testable import Blendv3

final class BackstopModelsTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var testBackstopPool: BackstopPool!
    private var testQueuedWithdrawal: QueuedWithdrawal!
    private var testEmissionsData: EmissionsData!
    private var testUserEmissionsState: UserEmissionsState!
    private var testAuctionData: AuctionData!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        setupTestData()
    }
    
    override func tearDown() {
        testBackstopPool = nil
        testQueuedWithdrawal = nil
        testEmissionsData = nil
        testUserEmissionsState = nil
        testAuctionData = nil
        super.tearDown()
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
        
        testQueuedWithdrawal = QueuedWithdrawal(
            userAddress: "user_address_1",
            poolId: "test_pool_1",
            backstopTokenAmount: FixedMath.toFixed(value: 1000, decimals: 7),
            lpTokenAmount: FixedMath.toFixed(value: 1000, decimals: 7)
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
    
    // MARK: - BackstopPool Tests
    
    func testBackstopPool_initialization_setsPropertiesCorrectly() {
        // Then
        XCTAssertEqual(testBackstopPool.poolId, "test_pool_1")
        XCTAssertEqual(testBackstopPool.backstopTokenAddress, "backstop_token_addr")
        XCTAssertEqual(testBackstopPool.lpTokenAddress, "lp_token_addr")
        XCTAssertEqual(testBackstopPool.status, .active)
    }
    
    func testBackstopPool_utilization_calculatesCorrectly() {
        // When
        let utilization = testBackstopPool.utilization
        
        // Then
        XCTAssertEqual(utilization, 0.5, accuracy: 0.001) // 500k / 1M = 50%
    }
    
    func testBackstopPool_availableCapacity_calculatesCorrectly() {
        // When
        let availableCapacity = testBackstopPool.availableCapacity
        
        // Then
        let expectedCapacity = FixedMath.toFixed(value: 500000, decimals: 7) // 1M - 500k
        XCTAssertEqual(availableCapacity, expectedCapacity)
    }
    
    func testBackstopPool_exchangeRate_calculatesCorrectly() {
        // When
        let exchangeRate = testBackstopPool.exchangeRate
        
        // Then
        let expectedRate = FixedMath.SCALAR_7 // 1:1 ratio
        XCTAssertEqual(exchangeRate, expectedRate)
    }
    
    func testBackstopPool_isAboveMinThreshold_returnsCorrectValue() {
        // Then
        XCTAssertTrue(testBackstopPool.isAboveMinThreshold)
        
        // Given - pool below threshold
        let belowThresholdPool = BackstopPool(
            poolId: "test_pool_2",
            backstopTokenAddress: "backstop_token_addr",
            lpTokenAddress: "lp_token_addr",
            minThreshold: FixedMath.toFixed(value: 600000, decimals: 7),
            maxCapacity: FixedMath.toFixed(value: 1000000, decimals: 7),
            takeRate: FixedMath.toFixed(value: 0.1, decimals: 7),
            totalBackstopTokens: FixedMath.toFixed(value: 500000, decimals: 7),
            totalLpTokens: FixedMath.toFixed(value: 500000, decimals: 7),
            totalValueUSD: 500000.0
        )
        
        // Then
        XCTAssertFalse(belowThresholdPool.isAboveMinThreshold)
    }
    
    // MARK: - BackstopStatus Tests
    
    func testBackstopStatus_canDeposit_returnsCorrectValues() {
        XCTAssertTrue(BackstopStatus.active.canDeposit)
        XCTAssertFalse(BackstopStatus.paused.canDeposit)
        XCTAssertFalse(BackstopStatus.emergency.canDeposit)
        XCTAssertFalse(BackstopStatus.liquidation.canDeposit)
    }
    
    func testBackstopStatus_canWithdraw_returnsCorrectValues() {
        XCTAssertTrue(BackstopStatus.active.canWithdraw)
        XCTAssertTrue(BackstopStatus.paused.canWithdraw)
        XCTAssertFalse(BackstopStatus.emergency.canWithdraw)
        XCTAssertFalse(BackstopStatus.liquidation.canWithdraw)
    }
    
    // MARK: - QueuedWithdrawal Tests
    
    func testQueuedWithdrawal_initialization_setsPropertiesCorrectly() {
        // Then
        XCTAssertEqual(testQueuedWithdrawal.userAddress, "user_address_1")
        XCTAssertEqual(testQueuedWithdrawal.poolId, "test_pool_1")
        XCTAssertEqual(testQueuedWithdrawal.status, .queued)
        XCTAssertNil(testQueuedWithdrawal.cancelledAt)
        XCTAssertNil(testQueuedWithdrawal.executedAt)
    }
    
    func testQueuedWithdrawal_isExecutable_returnsFalseForNewWithdrawal() {
        // Then
        XCTAssertFalse(testQueuedWithdrawal.isExecutable) // Should not be executable immediately
    }
    
    func testQueuedWithdrawal_isExecutable_returnsTrueAfterDelay() {
        // Given - withdrawal that was queued in the past
        let pastWithdrawal = QueuedWithdrawal(
            userAddress: "user_address_1",
            poolId: "test_pool_1",
            backstopTokenAmount: FixedMath.toFixed(value: 1000, decimals: 7),
            lpTokenAmount: FixedMath.toFixed(value: 1000, decimals: 7),
            queuedAt: Date().addingTimeInterval(-604800), // 7 days ago
            queueDelay: 604800 // 7 days
        )
        
        // Then
        XCTAssertTrue(pastWithdrawal.isExecutable)
    }
    
    func testQueuedWithdrawal_isPending_returnsCorrectValue() {
        // Then
        XCTAssertTrue(testQueuedWithdrawal.isPending)
        
        // Given - executed withdrawal
        let executedWithdrawal = QueuedWithdrawal(
            userAddress: "user_address_1",
            poolId: "test_pool_1",
            backstopTokenAmount: FixedMath.toFixed(value: 1000, decimals: 7),
            lpTokenAmount: FixedMath.toFixed(value: 1000, decimals: 7),
            status: .executed,
            executedAt: Date()
        )
        
        // Then
        XCTAssertFalse(executedWithdrawal.isPending)
    }
    
    func testQueuedWithdrawal_timeUntilExecutable_calculatesCorrectly() {
        // When
        let timeUntilExecutable = testQueuedWithdrawal.timeUntilExecutable
        
        // Then
        XCTAssertGreaterThan(timeUntilExecutable, 604700) // Should be close to 7 days
        XCTAssertLessThan(timeUntilExecutable, 604800)
    }
    
    // MARK: - EmissionsData Tests
    
    func testEmissionsData_initialization_setsPropertiesCorrectly() {
        // Then
        XCTAssertEqual(testEmissionsData.poolId, "test_pool_1")
        XCTAssertEqual(testEmissionsData.blndTokenAddress, "blnd_token_addr")
        XCTAssertTrue(testEmissionsData.isActive)
        XCTAssertFalse(testEmissionsData.hasEnded)
    }
    
    func testEmissionsData_remainingEmissions_calculatesCorrectly() {
        // When
        let remainingEmissions = testEmissionsData.remainingEmissions
        
        // Then
        let expectedRemaining = FixedMath.toFixed(value: 1000000, decimals: 7) // totalAllocated - totalClaimed (0)
        XCTAssertEqual(remainingEmissions, expectedRemaining)
    }
    
    func testEmissionsData_emissionsPerYear_calculatesCorrectly() {
        // When
        let emissionsPerYear = testEmissionsData.emissionsPerYear
        
        // Then
        let expectedPerYear = FixedMath.toFixed(value: 0.1 * 31536000, decimals: 7) // 0.1 * seconds in year
        XCTAssertEqual(emissionsPerYear, expectedPerYear)
    }
    
    func testEmissionsData_hasEnded_returnsTrueForPastEndTime() {
        // Given - emissions that ended in the past
        let endedEmissions = EmissionsData(
            poolId: "test_pool_1",
            blndTokenAddress: "blnd_token_addr",
            emissionsPerSecond: FixedMath.toFixed(value: 0.1, decimals: 7),
            totalAllocated: FixedMath.toFixed(value: 1000000, decimals: 7),
            endTime: Date().addingTimeInterval(-86400) // 1 day ago
        )
        
        // Then
        XCTAssertTrue(endedEmissions.hasEnded)
    }
    
    func testEmissionsData_timeRemaining_calculatesCorrectly() {
        // When
        let timeRemaining = testEmissionsData.timeRemaining
        
        // Then
        XCTAssertGreaterThan(timeRemaining, 86400 * 364) // Should be close to 1 year
        XCTAssertLessThan(timeRemaining, 86400 * 365)
    }
    
    // MARK: - UserEmissionsState Tests
    
    func testUserEmissionsState_initialization_setsPropertiesCorrectly() {
        // Then
        XCTAssertEqual(testUserEmissionsState.userAddress, "user_address_1")
        XCTAssertEqual(testUserEmissionsState.poolId, "test_pool_1")
        XCTAssertEqual(testUserEmissionsState.shareOfPool, 0.02, accuracy: 0.001)
    }
    
    func testUserEmissionsState_claimableEmissions_returnsAccruedAmount() {
        // When
        let claimableEmissions = testUserEmissionsState.claimableEmissions
        
        // Then
        let expectedClaimable = FixedMath.toFixed(value: 100, decimals: 7)
        XCTAssertEqual(claimableEmissions, expectedClaimable)
    }
    
    func testUserEmissionsState_hasClaimableEmissions_returnsCorrectValue() {
        // Then
        XCTAssertTrue(testUserEmissionsState.hasClaimableEmissions)
        
        // Given - user with no accrued emissions
        let noEmissionsUser = UserEmissionsState(
            userAddress: "user_address_2",
            poolId: "test_pool_1",
            backstopTokenBalance: FixedMath.toFixed(value: 1000, decimals: 7),
            shareOfPool: 0.01,
            accruedEmissions: 0
        )
        
        // Then
        XCTAssertFalse(noEmissionsUser.hasClaimableEmissions)
    }
    
    func testUserEmissionsState_timeSinceLastClaim_calculatesCorrectly() {
        // When
        let timeSinceLastClaim = testUserEmissionsState.timeSinceLastClaim
        
        // Then
        XCTAssertGreaterThan(timeSinceLastClaim, 0)
        XCTAssertLessThan(timeSinceLastClaim, 10) // Should be very recent
    }
    
    // MARK: - AuctionData Tests
    
    func testAuctionData_initialization_setsPropertiesCorrectly() {
        // Then
        XCTAssertEqual(testAuctionData.poolId, "test_pool_1")
        XCTAssertEqual(testAuctionData.auctionType, .badDebt)
        XCTAssertEqual(testAuctionData.assetAddress, "asset_addr")
        XCTAssertEqual(testAuctionData.status, .active)
        XCTAssertNil(testAuctionData.currentBidder)
    }
    
    func testAuctionData_isActive_returnsTrueForActiveAuction() {
        // Then
        XCTAssertTrue(testAuctionData.isActive)
    }
    
    func testAuctionData_isActive_returnsFalseForCompletedAuction() {
        // Given - completed auction
        let completedAuction = AuctionData(
            poolId: "test_pool_1",
            auctionType: .badDebt,
            assetAddress: "asset_addr",
            assetAmount: FixedMath.toFixed(value: 1000, decimals: 7),
            startingBid: FixedMath.toFixed(value: 700, decimals: 7),
            status: .completed,
            minBidIncrement: FixedMath.toFixed(value: 10, decimals: 7),
            reservePrice: FixedMath.toFixed(value: 500, decimals: 7)
        )
        
        // Then
        XCTAssertFalse(completedAuction.isActive)
    }
    
    func testAuctionData_hasEnded_returnsFalseForActiveAuction() {
        // Then
        XCTAssertFalse(testAuctionData.hasEnded)
    }
    
    func testAuctionData_hasEnded_returnsTrueForPastEndTime() {
        // Given - auction that ended in the past
        let pastAuction = AuctionData(
            poolId: "test_pool_1",
            auctionType: .badDebt,
            assetAddress: "asset_addr",
            assetAmount: FixedMath.toFixed(value: 1000, decimals: 7),
            startingBid: FixedMath.toFixed(value: 700, decimals: 7),
            startTime: Date().addingTimeInterval(-86500), // Started 1 day + 100 seconds ago
            duration: 86400, // 24 hours
            minBidIncrement: FixedMath.toFixed(value: 10, decimals: 7),
            reservePrice: FixedMath.toFixed(value: 500, decimals: 7)
        )
        
        // Then
        XCTAssertTrue(pastAuction.hasEnded)
    }
    
    func testAuctionData_timeRemaining_calculatesCorrectly() {
        // When
        let timeRemaining = testAuctionData.timeRemaining
        
        // Then
        XCTAssertGreaterThan(timeRemaining, 86300) // Should be close to 24 hours
        XCTAssertLessThan(timeRemaining, 86400)
    }
    
    func testAuctionData_reserveMet_returnsFalseForLowBid() {
        // Then
        XCTAssertTrue(testAuctionData.reserveMet) // Starting bid (700) > reserve (500)
    }
    
    func testAuctionData_reserveMet_returnsTrueForHighBid() {
        // Given - auction with bid below reserve
        let lowBidAuction = AuctionData(
            poolId: "test_pool_1",
            auctionType: .badDebt,
            assetAddress: "asset_addr",
            assetAmount: FixedMath.toFixed(value: 1000, decimals: 7),
            startingBid: FixedMath.toFixed(value: 300, decimals: 7), // Below reserve
            minBidIncrement: FixedMath.toFixed(value: 10, decimals: 7),
            reservePrice: FixedMath.toFixed(value: 500, decimals: 7)
        )
        
        // Then
        XCTAssertFalse(lowBidAuction.reserveMet)
    }
    
    func testAuctionData_nextMinBid_calculatesCorrectly() {
        // When
        let nextMinBid = testAuctionData.nextMinBid
        
        // Then
        let expectedMinBid = FixedMath.toFixed(value: 710, decimals: 7) // 700 + 10
        XCTAssertEqual(nextMinBid, expectedMinBid)
    }
    
    // MARK: - Auction Type Tests
    
    func testAuctionType_description_returnsCorrectValues() {
        XCTAssertEqual(AuctionType.badDebt.description, "Bad Debt Auction")
        XCTAssertEqual(AuctionType.liquidation.description, "Liquidation Auction")
        XCTAssertEqual(AuctionType.interest.description, "Interest Auction")
    }
    
    // MARK: - Auction Status Tests
    
    func testAuctionStatus_description_returnsCorrectValues() {
        XCTAssertEqual(AuctionStatus.pending.description, "Pending")
        XCTAssertEqual(AuctionStatus.active.description, "Active")
        XCTAssertEqual(AuctionStatus.completed.description, "Completed")
        XCTAssertEqual(AuctionStatus.cancelled.description, "Cancelled")
        XCTAssertEqual(AuctionStatus.failed.description, "Failed")
    }
    
    // MARK: - Withdrawal Status Tests
    
    func testWithdrawalStatus_description_returnsCorrectValues() {
        XCTAssertEqual(WithdrawalStatus.queued.description, "Queued")
        XCTAssertEqual(WithdrawalStatus.executed.description, "Executed")
        XCTAssertEqual(WithdrawalStatus.cancelled.description, "Cancelled")
        XCTAssertEqual(WithdrawalStatus.expired.description, "Expired")
    }
    
    // MARK: - Codable Tests
    
    func testBackstopPool_codable_encodesAndDecodesCorrectly() throws {
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(testBackstopPool)
        
        let decoder = JSONDecoder()
        let decodedPool = try decoder.decode(BackstopPool.self, from: data)
        
        // Then
        XCTAssertEqual(decodedPool, testBackstopPool)
    }
    
    func testQueuedWithdrawal_codable_encodesAndDecodesCorrectly() throws {
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(testQueuedWithdrawal)
        
        let decoder = JSONDecoder()
        let decodedWithdrawal = try decoder.decode(QueuedWithdrawal.self, from: data)
        
        // Then
        XCTAssertEqual(decodedWithdrawal, testQueuedWithdrawal)
    }
    
    func testEmissionsData_codable_encodesAndDecodesCorrectly() throws {
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(testEmissionsData)
        
        let decoder = JSONDecoder()
        let decodedEmissions = try decoder.decode(EmissionsData.self, from: data)
        
        // Then
        XCTAssertEqual(decodedEmissions, testEmissionsData)
    }
    
    func testUserEmissionsState_codable_encodesAndDecodesCorrectly() throws {
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(testUserEmissionsState)
        
        let decoder = JSONDecoder()
        let decodedUserState = try decoder.decode(UserEmissionsState.self, from: data)
        
        // Then
        XCTAssertEqual(decodedUserState, testUserEmissionsState)
    }
    
    func testAuctionData_codable_encodesAndDecodesCorrectly() throws {
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(testAuctionData)
        
        let decoder = JSONDecoder()
        let decodedAuction = try decoder.decode(AuctionData.self, from: data)
        
        // Then
        XCTAssertEqual(decodedAuction, testAuctionData)
    }
    
    // MARK: - Edge Cases Tests
    
    func testBackstopPool_zeroCapacity_handlesGracefully() {
        // Given - pool with zero capacity
        let zeroCapacityPool = BackstopPool(
            poolId: "zero_pool",
            backstopTokenAddress: "backstop_token_addr",
            lpTokenAddress: "lp_token_addr",
            minThreshold: 0,
            maxCapacity: 0,
            takeRate: FixedMath.toFixed(value: 0.1, decimals: 7),
            totalBackstopTokens: 0,
            totalLpTokens: 0,
            totalValueUSD: 0
        )
        
        // Then
        XCTAssertEqual(zeroCapacityPool.utilization, 0)
        XCTAssertEqual(zeroCapacityPool.availableCapacity, 0)
    }
    
    func testBackstopPool_zeroBackstopTokens_handlesExchangeRate() {
        // Given - pool with zero backstop tokens
        let zeroTokensPool = BackstopPool(
            poolId: "zero_tokens_pool",
            backstopTokenAddress: "backstop_token_addr",
            lpTokenAddress: "lp_token_addr",
            minThreshold: FixedMath.toFixed(value: 1000, decimals: 7),
            maxCapacity: FixedMath.toFixed(value: 10000, decimals: 7),
            takeRate: FixedMath.toFixed(value: 0.1, decimals: 7),
            totalBackstopTokens: 0,
            totalLpTokens: FixedMath.toFixed(value: 5000, decimals: 7),
            totalValueUSD: 5000
        )
        
        // Then
        XCTAssertEqual(zeroTokensPool.exchangeRate, FixedMath.SCALAR_7) // Should default to 1:1
    }
    
    // MARK: - Performance Tests
    
    func testBackstopModels_performance() {
        measure {
            for _ in 0..<1000 {
                let pool = BackstopPool(
                    poolId: "perf_test_pool",
                    backstopTokenAddress: "backstop_token_addr",
                    lpTokenAddress: "lp_token_addr",
                    minThreshold: FixedMath.toFixed(value: 100000, decimals: 7),
                    maxCapacity: FixedMath.toFixed(value: 1000000, decimals: 7),
                    takeRate: FixedMath.toFixed(value: 0.1, decimals: 7),
                    totalBackstopTokens: FixedMath.toFixed(value: 500000, decimals: 7),
                    totalLpTokens: FixedMath.toFixed(value: 500000, decimals: 7),
                    totalValueUSD: 500000.0
                )
                
                _ = pool.utilization
                _ = pool.availableCapacity
                _ = pool.exchangeRate
                _ = pool.isAboveMinThreshold
            }
        }
    }
} 