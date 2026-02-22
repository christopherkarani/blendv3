import XCTest
import stellarsdk
import Combine
@testable import Blendv3

final class BlendUSDCVaultTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: BlendUSDCVault!
    private var mockSigner: MockBlendSigner!
    private var cancellables: Set<AnyCancellable>!
    
    // Test constants
    private let testPublicKey = "GDQERENWDDSQZS7R7WKHZI3BSOYMV3FSWR7TFUYFTKQ447PIX6NREOJM"
    private let testSecretKey = "SDYH3V6ICEM463OTM7EEK7SNHYILXZRHPY45AYZOSK3N4NLF3NQUI4PQ"
    private let testAmount = Decimal(100.50) // $100.50 USDC
    private let testTimeout: TimeInterval = 10.0
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockSigner = MockBlendSigner(publicKey: testPublicKey, secretKey: testSecretKey)
        sut = BlendUSDCVault(signer: mockSigner, network: .testnet)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        sut = nil
        mockSigner = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_withValidSigner_initializesCorrectly() {
        // Given/When - Initialization happens in setUp
        
        // Then
        XCTAssertNotNil(sut)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        XCTAssertNil(sut.poolStats)
        XCTAssertNil(sut.comprehensivePoolStats)
        XCTAssertNil(sut.truePoolStats)
        XCTAssertNil(sut.poolConfig)
    }
    
    func testInit_withTestnetNetwork_setsCorrectConfiguration() {
        // Given
        let testnetVault = BlendUSDCVault(signer: mockSigner, network: .testnet)
        
        // Then
        XCTAssertNotNil(testnetVault)
        // Network configuration is internal, but we can verify it doesn't crash
    }
    
    func testInit_withMainnetNetwork_setsCorrectConfiguration() {
        // Given
        let mainnetVault = BlendUSDCVault(signer: mockSigner, network: .mainnet)
        
        // Then
        XCTAssertNotNil(mainnetVault)
        // Network configuration is internal, but we can verify it doesn't crash
    }
    
    // MARK: - Deposit Tests
    
    func testDeposit_withValidAmount_setsLoadingState() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Loading state changes")
        var loadingStates: [Bool] = []
        
        sut.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        mockSigner.shouldSucceed = false // Make it fail quickly to test loading state
        mockSigner.errorToThrow = BlendVaultError.notInitialized
        
        do {
            _ = try await sut.deposit(amount: testAmount)
        } catch {
            // Expected to fail for this test
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: testTimeout)
        XCTAssertEqual(loadingStates.first, false) // Initial state
        XCTAssertEqual(loadingStates.last, false) // Final state (after operation)
    }
    
    func testDeposit_withZeroAmount_throwsInvalidAmountError() async {
        // Given
        let zeroAmount = Decimal(0)
        
        // When/Then
        do {
            _ = try await sut.deposit(amount: zeroAmount)
            XCTFail("Expected BlendVaultError.invalidAmount to be thrown")
        } catch let error as BlendVaultError {
            if case .invalidAmount(let message) = error {
                XCTAssertTrue(message.contains("greater than zero"))
            } else {
                XCTFail("Expected invalidAmount error, got \(error)")
            }
        } catch {
            XCTFail("Expected BlendVaultError, got \(error)")
        }
    }
    
    func testDeposit_withNegativeAmount_throwsInvalidAmountError() async {
        // Given
        let negativeAmount = Decimal(-50.0)
        
        // When/Then
        do {
            _ = try await sut.deposit(amount: negativeAmount)
            XCTFail("Expected BlendVaultError.invalidAmount to be thrown")
        } catch let error as BlendVaultError {
            if case .invalidAmount = error {
                // Expected
            } else {
                XCTFail("Expected invalidAmount error, got \(error)")
            }
        } catch {
            XCTFail("Expected BlendVaultError, got \(error)")
        }
    }
    
    func testDeposit_withUninitializedClient_throwsNotInitializedError() async {
        // Given
        mockSigner.shouldSucceed = false
        mockSigner.errorToThrow = BlendVaultError.notInitialized
        
        // When/Then
        do {
            _ = try await sut.deposit(amount: testAmount)
            XCTFail("Expected BlendVaultError.notInitialized to be thrown")
        } catch let error as BlendVaultError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Expected notInitialized error, got \(error)")
            }
        } catch {
            XCTFail("Expected BlendVaultError, got \(error)")
        }
    }
    
    func testDeposit_withSuccessfulTransaction_returnsTransactionHash() async throws {
        // Given
        let expectedTxHash = "abc123def456"
        mockSigner.shouldSucceed = true
        mockSigner.mockTransactionHash = expectedTxHash
        
        // When
        let result = try await sut.deposit(amount: testAmount)
        
        // Then
        XCTAssertEqual(result, expectedTxHash)
        XCTAssertTrue(mockSigner.depositCalled)
        XCTAssertEqual(mockSigner.lastDepositAmount, testAmount)
    }
    
    func testDeposit_withNetworkError_setsErrorState() async {
        // Given
        let networkError = BlendVaultError.networkError("Connection failed")
        mockSigner.shouldSucceed = false
        mockSigner.errorToThrow = networkError
        
        let errorExpectation = XCTestExpectation(description: "Error state set")
        sut.$error
            .compactMap { $0 }
            .sink { error in
                errorExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        do {
            _ = try await sut.deposit(amount: testAmount)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }
        
        // Then
        await fulfillment(of: [errorExpectation], timeout: testTimeout)
        XCTAssertNotNil(sut.error)
        if case .networkError(let message) = sut.error {
            XCTAssertEqual(message, "Connection failed")
        } else {
            XCTFail("Expected networkError, got \(String(describing: sut.error))")
        }
    }
    
    // MARK: - Withdraw Tests
    
    func testWithdraw_withValidAmount_setsLoadingState() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Loading state changes")
        var loadingStates: [Bool] = []
        
        sut.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        mockSigner.shouldSucceed = false // Make it fail quickly to test loading state
        mockSigner.errorToThrow = BlendVaultError.notInitialized
        
        do {
            _ = try await sut.withdraw(amount: testAmount)
        } catch {
            // Expected to fail for this test
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: testTimeout)
        XCTAssertEqual(loadingStates.first, false) // Initial state
        XCTAssertEqual(loadingStates.last, false) // Final state (after operation)
    }
    
    func testWithdraw_withZeroAmount_throwsInvalidAmountError() async {
        // Given
        let zeroAmount = Decimal(0)
        
        // When/Then
        do {
            _ = try await sut.withdraw(amount: zeroAmount)
            XCTFail("Expected BlendVaultError.invalidAmount to be thrown")
        } catch let error as BlendVaultError {
            if case .invalidAmount(let message) = error {
                XCTAssertTrue(message.contains("greater than zero"))
            } else {
                XCTFail("Expected invalidAmount error, got \(error)")
            }
        } catch {
            XCTFail("Expected BlendVaultError, got \(error)")
        }
    }
    
    func testWithdraw_withSuccessfulTransaction_returnsTransactionHash() async throws {
        // Given
        let expectedTxHash = "def456abc123"
        mockSigner.shouldSucceed = true
        mockSigner.mockTransactionHash = expectedTxHash
        
        // When
        let result = try await sut.withdraw(amount: testAmount)
        
        // Then
        XCTAssertEqual(result, expectedTxHash)
        XCTAssertTrue(mockSigner.withdrawCalled)
        XCTAssertEqual(mockSigner.lastWithdrawAmount, testAmount)
    }
    
    func testWithdraw_withInsufficientBalance_throwsInsufficientBalanceError() async {
        // Given
        mockSigner.shouldSucceed = false
        mockSigner.errorToThrow = BlendVaultError.insufficientBalance
        
        // When/Then
        do {
            _ = try await sut.withdraw(amount: testAmount)
            XCTFail("Expected BlendVaultError.insufficientBalance to be thrown")
        } catch let error as BlendVaultError {
            if case .insufficientBalance = error {
                // Expected
            } else {
                XCTFail("Expected insufficientBalance error, got \(error)")
            }
        } catch {
            XCTFail("Expected BlendVaultError, got \(error)")
        }
    }
    
    // MARK: - Pool Stats Refresh Tests
    
    func testRefreshPoolStats_setsLoadingState() async {
        // Given
        let expectation = XCTestExpectation(description: "Loading state changes")
        var loadingStates: [Bool] = []
        
        sut.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        mockSigner.shouldSucceed = false // Make it fail quickly
        mockSigner.errorToThrow = BlendVaultError.notInitialized
        
        do {
            try await sut.refreshPoolStats()
        } catch {
            // Expected to fail for this test
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: testTimeout)
        XCTAssertEqual(loadingStates.first, false) // Initial state
        XCTAssertEqual(loadingStates.last, false) // Final state (after operation)
    }
    
    func testRefreshPoolStats_withUninitializedClient_throwsNotInitializedError() async {
        // Given
        mockSigner.shouldSucceed = false
        mockSigner.errorToThrow = BlendVaultError.notInitialized
        
        // When/Then
        do {
            try await sut.refreshPoolStats()
            XCTFail("Expected BlendVaultError.notInitialized to be thrown")
        } catch let error as BlendVaultError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Expected notInitialized error, got \(error)")
            }
        } catch {
            XCTFail("Expected BlendVaultError, got \(error)")
        }
    }
    
    func testRefreshPoolStats_withSuccessfulResponse_updatesPoolStats() async throws {
        // Given
        mockSigner.shouldSucceed = true
        mockSigner.mockPoolStats = createMockPoolStats()
        
        let statsExpectation = XCTestExpectation(description: "Pool stats updated")
        sut.$poolStats
            .compactMap { $0 }
            .sink { stats in
                statsExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        try await sut.refreshPoolStats()
        
        // Then
        await fulfillment(of: [statsExpectation], timeout: testTimeout)
        XCTAssertNotNil(sut.poolStats)
        XCTAssertEqual(sut.poolStats?.usdcReserveData.totalSupplied, Decimal(20200))
        XCTAssertEqual(sut.poolStats?.usdcReserveData.totalBorrowed, Decimal(19980))
    }
    
    func testRefreshPoolStats_withInvalidResponse_throwsInvalidResponseError() async {
        // Given
        mockSigner.shouldSucceed = false
        mockSigner.errorToThrow = BlendVaultError.invalidResponse
        
        // When/Then
        do {
            try await sut.refreshPoolStats()
            XCTFail("Expected BlendVaultError.invalidResponse to be thrown")
        } catch let error as BlendVaultError {
            if case .invalidResponse = error {
                // Expected
            } else {
                XCTFail("Expected invalidResponse error, got \(error)")
            }
        } catch {
            XCTFail("Expected BlendVaultError, got \(error)")
        }
    }
    
    // MARK: - Extended Pool Function Tests
    
    func testGetPoolStatus_withSuccessfulResponse_returnsPoolStatus() async throws {
        // Given
        mockSigner.shouldSucceed = true
        mockSigner.mockPoolStatusResult = PoolStatusResult(
            isActive: true,
            lastUpdate: Date(),
            blockHeight: 12345678
        )
        
        // When
        let result = try await sut.getPoolStatus()
        
        // Then
        XCTAssertTrue(result.isActive)
        XCTAssertEqual(result.blockHeight, 12345678)
        XCTAssertTrue(mockSigner.getPoolStatusCalled)
    }
    
    func testGetPoolConfig_withSuccessfulResponse_returnsPoolConfig() async throws {
        // Given
        mockSigner.shouldSucceed = true
        mockSigner.mockPoolConfigResult = PoolConfigResult(
            backstopTakeRate: Decimal(0.1),
            backstopId: "BACKSTOP123",
            maxPositions: 4
        )
        
        // When
        let result = try await sut.getPoolConfig()
        
        // Then
        XCTAssertEqual(result.backstopTakeRate, Decimal(0.1))
        XCTAssertEqual(result.backstopId, "BACKSTOP123")
        XCTAssertEqual(result.maxPositions, 4)
        XCTAssertTrue(mockSigner.getPoolConfigCalled)
    }
    
    func testGetUserPositions_withValidUser_returnsPositions() async throws {
        // Given
        let userAddress = testPublicKey
        mockSigner.shouldSucceed = true
        mockSigner.mockUserPositionsResult = UserPositionsResult(
            userAddress: userAddress,
            collateral: ["USDC": Decimal(1000)],
            liabilities: ["USDC": Decimal(500)],
            supply: ["USDC": Decimal(1500)]
        )
        
        // When
        let result = try await sut.getUserPositions(userAddress: userAddress)
        
        // Then
        XCTAssertEqual(result.userAddress, userAddress)
        XCTAssertEqual(result.collateral["USDC"], Decimal(1000))
        XCTAssertEqual(result.liabilities["USDC"], Decimal(500))
        XCTAssertEqual(result.supply["USDC"], Decimal(1500))
        XCTAssertTrue(mockSigner.getUserPositionsCalled)
    }
    
    func testGetUserEmissions_withValidUser_returnsEmissions() async throws {
        // Given
        let userAddress = testPublicKey
        mockSigner.shouldSucceed = true
        mockSigner.mockUserEmissionsResult = UserEmissionsResult(
            userAddress: userAddress,
            claimableEmissions: ["BLND": Decimal(100)],
            totalEmissions: Decimal(100)
        )
        
        // When
        let result = try await sut.getUserEmissions(userAddress: userAddress)
        
        // Then
        XCTAssertEqual(result.userAddress, userAddress)
        XCTAssertEqual(result.claimableEmissions["BLND"], Decimal(100))
        XCTAssertEqual(result.totalEmissions, Decimal(100))
        XCTAssertTrue(mockSigner.getUserEmissionsCalled)
    }
    
    // MARK: - True Pool Stats Tests
    
    func testRefreshTruePoolStats_setsLoadingState() async {
        // Given
        let expectation = XCTestExpectation(description: "Loading state changes")
        var loadingStates: [Bool] = []
        
        sut.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        mockSigner.shouldSucceed = false
        mockSigner.errorToThrow = BlendVaultError.notInitialized
        
        do {
            try await sut.refreshTruePoolStats()
        } catch {
            // Expected to fail for this test
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: testTimeout)
        XCTAssertEqual(loadingStates.first, false) // Initial state
        XCTAssertEqual(loadingStates.last, false) // Final state (after operation)
    }
    
    func testRefreshTruePoolStats_withSuccessfulResponse_updatesTruePoolStats() async throws {
        // Given
        mockSigner.shouldSucceed = true
        mockSigner.mockTruePoolStats = createMockTruePoolStats()
        
        let statsExpectation = XCTestExpectation(description: "True pool stats updated")
        sut.$truePoolStats
            .compactMap { $0 }
            .sink { stats in
                statsExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        try await sut.refreshTruePoolStats()
        
        // Then
        await fulfillment(of: [statsExpectation], timeout: testTimeout)
        XCTAssertNotNil(sut.truePoolStats)
        XCTAssertEqual(sut.truePoolStats?.totalSuppliedUSD, Decimal(111280))
        XCTAssertEqual(sut.truePoolStats?.totalBorrowedUSD, Decimal(55500))
    }
    
    func testGetPoolSummary_withValidStats_returnsSummary() {
        // Given
        sut.comprehensivePoolStats = createMockComprehensivePoolStats()
        
        // When
        let summary = sut.getPoolSummary()
        
        // Then
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.totalValueLocked, Decimal(111280))
        XCTAssertEqual(summary?.activeAssets, 3)
        XCTAssertEqual(summary?.topAssetByTVL, "USDC")
    }
    
    func testGetPoolSummary_withNoStats_returnsNil() {
        // Given
        sut.comprehensivePoolStats = nil
        
        // When
        let summary = sut.getPoolSummary()
        
        // Then
        XCTAssertNil(summary)
    }
    
    // MARK: - Error State Management Tests
    
    func testErrorState_clearsOnSuccessfulOperation() async throws {
        // Given - Set initial error state
        await MainActor.run {
            sut.error = BlendVaultError.networkError("Previous error")
        }
        XCTAssertNotNil(sut.error)
        
        // When - Perform successful operation
        mockSigner.shouldSucceed = true
        mockSigner.mockTransactionHash = "success123"
        _ = try await sut.deposit(amount: testAmount)
        
        // Then - Error should be cleared
        XCTAssertNil(sut.error)
    }
    
    func testLoadingState_resetsAfterOperation() async {
        // Given
        XCTAssertFalse(sut.isLoading)
        
        // When
        mockSigner.shouldSucceed = false
        mockSigner.errorToThrow = BlendVaultError.notInitialized
        
        do {
            _ = try await sut.deposit(amount: testAmount)
        } catch {
            // Expected
        }
        
        // Then
        XCTAssertFalse(sut.isLoading)
    }
    
    // MARK: - Performance Tests
    
    func testDeposit_performance_completesWithinTimeLimit() async throws {
        // Given
        mockSigner.shouldSucceed = true
        mockSigner.mockTransactionHash = "perf123"
        mockSigner.simulatedDelay = 0.1 // 100ms simulated network delay
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await sut.deposit(amount: testAmount)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(duration, 5.0, "Deposit should complete within 5 seconds")
    }
    
    func testRefreshPoolStats_performance_completesWithinTimeLimit() async throws {
        // Given
        mockSigner.shouldSucceed = true
        mockSigner.mockPoolStats = createMockPoolStats()
        mockSigner.simulatedDelay = 0.2 // 200ms simulated network delay
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        try await sut.refreshPoolStats()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(duration, 10.0, "Pool stats refresh should complete within 10 seconds")
    }
    
    // MARK: - Edge Cases
    
    func testDeposit_withVeryLargeAmount_handlesCorrectly() async throws {
        // Given
        let largeAmount = Decimal(sign: .plus, exponent: 10, significand: 123456789)
        mockSigner.shouldSucceed = true
        mockSigner.mockTransactionHash = "large123"
        
        // When
        let result = try await sut.deposit(amount: largeAmount)
        
        // Then
        XCTAssertEqual(result, "large123")
        XCTAssertEqual(mockSigner.lastDepositAmount, largeAmount)
    }
    
    func testWithdraw_withVerySmallAmount_handlesCorrectly() async throws {
        // Given
        let smallAmount = Decimal(0.000001) // 1 microUSDC
        mockSigner.shouldSucceed = true
        mockSigner.mockTransactionHash = "small123"
        
        // When
        let result = try await sut.withdraw(amount: smallAmount)
        
        // Then
        XCTAssertEqual(result, "small123")
        XCTAssertEqual(mockSigner.lastWithdrawAmount, smallAmount)
    }
    
    func testMultipleConcurrentOperations_handlesCorrectly() async throws {
        // Given
        mockSigner.shouldSucceed = true
        mockSigner.mockTransactionHash = "concurrent123"
        
        // When
        async let deposit1 = sut.deposit(amount: Decimal(100))
        async let deposit2 = sut.deposit(amount: Decimal(200))
        async let withdraw1 = sut.withdraw(amount: Decimal(50))
        
        let results = try await [deposit1, deposit2, withdraw1]
        
        // Then
        XCTAssertEqual(results.count, 3)
        results.forEach { result in
            XCTAssertEqual(result, "concurrent123")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockPoolStats() -> BlendPoolStats {
        let poolData = PoolLevelData(
            totalValueLocked: Decimal(111280),
            overallUtilization: Decimal(0.495),
            healthScore: Decimal(0.98),
            activeReserves: 3
        )
        
        let usdcReserveData = USDCReserveData(
            totalSupplied: Decimal(20200),
            totalBorrowed: Decimal(19980),
            utilizationRate: Decimal(0.989),
            supplyApr: Decimal(0.38),
            supplyApy: Decimal(0.38),
            borrowApr: Decimal(0.48),
            borrowApy: Decimal(0.48),
            collateralFactor: Decimal(0.95),
            liabilityFactor: Decimal(1.0526)
        )
        
        let backstopData = BackstopData(
            totalBackstop: Decimal(353750),
            backstopApr: Decimal(0.01),
            q4wPercentage: Decimal(14.75),
            takeRate: Decimal(0.10),
            blndAmount: Decimal(250000),
            usdcAmount: Decimal(103750)
        )
        
        return BlendPoolStats(
            poolData: poolData,
            usdcReserveData: usdcReserveData,
            backstopData: backstopData,
            lastUpdated: Date()
        )
    }
    
    private func createMockTruePoolStats() -> TruePoolStats {
        let reserves = [
            PoolReserveData(
                asset: BlendUSDCConstants.usdcAssetContractAddress,
                symbol: "USDC",
                totalSupplied: Decimal(100000),
                totalBorrowed: Decimal(50000),
                utilizationRate: Decimal(0.5),
                supplyAPY: Decimal(0.38),
                borrowAPY: Decimal(0.48),
                scalar: Decimal(10000000),
                price: Decimal(1.0)
            )
        ]
        
        return TruePoolStats(
            totalSuppliedUSD: Decimal(111280),
            totalBorrowedUSD: Decimal(55500),
            backstopBalanceUSD: Decimal(353750),
            overallUtilization: Decimal(0.497),
            backstopRate: Decimal(0.1),
            poolStatus: 0,
            reserves: reserves,
            lastUpdated: Date()
        )
    }
    
    private func createMockComprehensivePoolStats() -> ComprehensivePoolStats {
        let poolData = PoolLevelData(
            totalValueLocked: Decimal(111280),
            overallUtilization: Decimal(0.495),
            healthScore: Decimal(0.98),
            activeReserves: 3
        )
        
        let usdcReserve = AssetReserveData(
            symbol: "USDC",
            contractAddress: BlendUSDCConstants.usdcAssetContractAddress,
            totalSupplied: Decimal(100000),
            totalBorrowed: Decimal(50000),
            utilizationRate: Decimal(0.5),
            supplyApr: Decimal(0.38),
            supplyApy: Decimal(0.38),
            borrowApr: Decimal(0.48),
            borrowApy: Decimal(0.48),
            collateralFactor: Decimal(0.95),
            liabilityFactor: Decimal(1.0526)
        )
        
        let xlmReserve = AssetReserveData(
            symbol: "XLM",
            contractAddress: BlendUSDCConstants.Testnet.xlm,
            totalSupplied: Decimal(50000),
            totalBorrowed: Decimal(25000),
            utilizationRate: Decimal(0.5),
            supplyApr: Decimal(0.25),
            supplyApy: Decimal(0.25),
            borrowApr: Decimal(0.35),
            borrowApy: Decimal(0.35),
            collateralFactor: Decimal(0.85),
            liabilityFactor: Decimal(1.15)
        )
        
        let blndReserve = AssetReserveData(
            symbol: "BLND",
            contractAddress: BlendUSDCConstants.Testnet.blnd,
            totalSupplied: Decimal(25000),
            totalBorrowed: Decimal(10000),
            utilizationRate: Decimal(0.4),
            supplyApr: Decimal(0.15),
            supplyApy: Decimal(0.15),
            borrowApr: Decimal(0.25),
            borrowApy: Decimal(0.25),
            collateralFactor: Decimal(0.75),
            liabilityFactor: Decimal(1.25)
        )
        
        let allReserves = [
            "USDC": usdcReserve,
            "XLM": xlmReserve,
            "BLND": blndReserve
        ]
        
        let backstopData = BackstopData(
            totalBackstop: Decimal(353750),
            backstopApr: Decimal(0.01),
            q4wPercentage: Decimal(14.75),
            takeRate: Decimal(0.10),
            blndAmount: Decimal(250000),
            usdcAmount: Decimal(103750)
        )
        
        return ComprehensivePoolStats(
            poolData: poolData,
            allReserves: allReserves,
            backstopData: backstopData,
            lastUpdated: Date()
        )
    }
}

// MARK: - Mock BlendSigner

private class MockBlendSigner: BlendSigner {
    
    // MARK: - Properties
    
    var shouldSucceed = true
    var errorToThrow: Error = BlendVaultError.unknown("Mock error")
    var simulatedDelay: TimeInterval = 0.0
    
    // Mock return values
    var mockTransactionHash = "mock_tx_hash"
    var mockPoolStats: BlendPoolStats?
    var mockTruePoolStats: TruePoolStats?
    var mockPoolStatusResult: PoolStatusResult?
    var mockPoolConfigResult: PoolConfigResult?
    var mockUserPositionsResult: UserPositionsResult?
    var mockUserEmissionsResult: UserEmissionsResult?
    
    // Call tracking
    var depositCalled = false
    var withdrawCalled = false
    var getPoolStatusCalled = false
    var getPoolConfigCalled = false
    var getUserPositionsCalled = false
    var getUserEmissionsCalled = false
    
    // Parameter tracking
    var lastDepositAmount: Decimal?
    var lastWithdrawAmount: Decimal?
    
    // MARK: - Initialization
    
    init(publicKey: String, secretKey: String) {
        super.init(publicKey: publicKey)
        // Override with test keys
    }
    
    // MARK: - Mock Implementation
    
    override func getKeyPair() throws -> KeyPair {
        if !shouldSucceed {
            throw errorToThrow
        }
        return try KeyPair(secretSeed: "SDYH3V6ICEM463OTM7EEK7SNHYILXZRHPY45AYZOSK3N4NLF3NQUI4PQ")
    }
    
    // Mock deposit operation
    func mockDeposit(amount: Decimal) async throws -> String {
        depositCalled = true
        lastDepositAmount = amount
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw errorToThrow
        }
        
        return mockTransactionHash
    }
    
    // Mock withdraw operation
    func mockWithdraw(amount: Decimal) async throws -> String {
        withdrawCalled = true
        lastWithdrawAmount = amount
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw errorToThrow
        }
        
        return mockTransactionHash
    }
    
    // Mock pool stats refresh
    func mockRefreshPoolStats() async throws -> BlendPoolStats {
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw errorToThrow
        }
        
        guard let stats = mockPoolStats else {
            throw BlendVaultError.invalidResponse
        }
        
        return stats
    }
    
    // Mock true pool stats refresh
    func mockRefreshTruePoolStats() async throws -> TruePoolStats {
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw errorToThrow
        }
        
        guard let stats = mockTruePoolStats else {
            throw BlendVaultError.invalidResponse
        }
        
        return stats
    }
    
    // Mock pool status
    func mockGetPoolStatus() async throws -> PoolStatusResult {
        getPoolStatusCalled = true
        
        if !shouldSucceed {
            throw errorToThrow
        }
        
        guard let result = mockPoolStatusResult else {
            throw BlendVaultError.invalidResponse
        }
        
        return result
    }
    
    // Mock pool config
    func mockGetPoolConfig() async throws -> PoolConfigResult {
        getPoolConfigCalled = true
        
        if !shouldSucceed {
            throw errorToThrow
        }
        
        guard let result = mockPoolConfigResult else {
            throw BlendVaultError.invalidResponse
        }
        
        return result
    }
    
    // Mock user positions
    func mockGetUserPositions(userAddress: String) async throws -> UserPositionsResult {
        getUserPositionsCalled = true
        
        if !shouldSucceed {
            throw errorToThrow
        }
        
        guard let result = mockUserPositionsResult else {
            throw BlendVaultError.invalidResponse
        }
        
        return result
    }
    
    // Mock user emissions
    func mockGetUserEmissions(userAddress: String) async throws -> UserEmissionsResult {
        getUserEmissionsCalled = true
        
        if !shouldSucceed {
            throw errorToThrow
        }
        
        guard let result = mockUserEmissionsResult else {
            throw BlendVaultError.invalidResponse
        }
        
        return result
    }
} 