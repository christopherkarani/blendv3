import XCTest
import stellarsdk
@testable import Blendv3

@MainActor
final class BackstopContractServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var mockNetworkService: MockNetworkService!
    private var mockCacheService: MockCacheService!
    private var backstopService: BackstopContractService!
    private var testConfig: BackstopServiceConfig!
    
    // MARK: - Test Constants
    
    private let testContractAddress = "CAQPKRMOGXHLF7NHPQ6YNVGPQPWJ4JSMZEBIPUQ3LT7GMDGTCKDKTGJK"
    private let testUserAddress = "GA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLTJJFC7MGXUA74P7UJVSGZ"
    private let testPoolAddress = "GDGPVOKHGQHS2JTZFV6HNPSKXBDLC6RJZLTYSNL55J5EJABSUHVDVBZT"
    private let testAmount = Decimal(1000.50)
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockNetworkService = MockNetworkService()
        mockCacheService = MockCacheService()
        
        testConfig = BackstopServiceConfig(
            contractAddress: BlendUSDCConstants.Testnet.backstop,
            rpcUrl: "https://soroban-testnet.stellar.org",
            network: .testnet
        )
        
        backstopService = BackstopContractService(
            networkService: mockNetworkService,
            cacheService: mockCacheService,
            config: testConfig
        )
    }
    
    override func tearDown() async throws {
        mockNetworkService = nil
        mockCacheService = nil
        backstopService = nil
        testConfig = nil
        try await super.tearDown()
    }
}

// MARK: - Core Function Tests

extension BackstopContractServiceTests {
    
    func testDeposit_Success() async throws {
        // Arrange
        let expectedShares = Int128(1000)
        mockNetworkService.mockContractSimulationResponse = createMockI128Response(expectedShares)
        
        // Act
        let result = try await backstopService.deposit(
            from: testUserAddress,
            poolAddress: testPoolAddress,
            amount: testAmount
        )
        
        // Assert
        XCTAssertEqual(result.sharesReceived, expectedShares)
        XCTAssertEqual(mockNetworkService.simulationCallCount, 1)
    }
    
    func testQueueWithdrawal_Success() async throws {
        // Arrange
        let expectedShares = Int128(500)
        mockNetworkService.mockContractSimulationResponse = createMockI128Response(expectedShares)
        
        // Act
        let result = try await backstopService.queueWithdrawal(
            from: testUserAddress,
            poolAddress: testPoolAddress,
            amount: testAmount
        )
        
        // Assert
        XCTAssertEqual(result.sharesQueued, expectedShares)
        XCTAssertEqual(mockNetworkService.simulationCallCount, 1)
    }
    
    func testWithdraw_Success() async throws {
        // Arrange
        let expectedAmount = Int128(1000)
        mockNetworkService.mockContractSimulationResponse = createMockI128Response(expectedAmount)
        
        // Act
        let result = try await backstopService.withdraw(
            from: testUserAddress,
            poolAddress: testPoolAddress,
            amount: testAmount
        )
        
        // Assert
        XCTAssertEqual(result.amountWithdrawn, expectedAmount)
        XCTAssertEqual(mockNetworkService.simulationCallCount, 1)
    }
    
    func testGetUserBalance_Success() async throws {
        // Arrange
        let expectedBalance = UserBalance(
            shares: Int128(1000),
            q4w: Q4W(
                amount: Int128(500),
                epoch: 10
            )
        )
        mockNetworkService.mockContractSimulationResponse = createMockUserBalanceResponse(expectedBalance)
        
        // Act
        let result = try await backstopService.getUserBalance(
            pool: testPoolAddress,
            user: testUserAddress
        )
        
        // Assert
        XCTAssertEqual(result.shares, expectedBalance.shares)
        XCTAssertEqual(result.q4w.amount, expectedBalance.q4w.amount)
        XCTAssertEqual(result.q4w.epoch, expectedBalance.q4w.epoch)
        XCTAssertEqual(mockNetworkService.simulationCallCount, 1)
    }
    
    func testGetPoolData_Success() async throws {
        // Arrange
        let expectedPoolData = PoolBackstopData(
            balance: PoolBalance(
                shares: Int128(5000),
                tokens: Int128(4800)
            ),
            emissions: BackstopEmissionsData(
                index: Int128(1000),
                lastTime: 1699123456
            ),
            q4w: PoolBalance(
                shares: Int128(100),
                tokens: Int128(95)
            )
        )
        mockNetworkService.mockContractSimulationResponse = createMockPoolDataResponse(expectedPoolData)
        
        // Act
        let result = try await backstopService.getPoolData(pool: testPoolAddress)
        
        // Assert
        XCTAssertEqual(result.balance.shares, expectedPoolData.balance.shares)
        XCTAssertEqual(result.balance.tokens, expectedPoolData.balance.tokens)
        XCTAssertEqual(result.emissions.index, expectedPoolData.emissions.index)
        XCTAssertEqual(result.emissions.lastTime, expectedPoolData.emissions.lastTime)
        XCTAssertEqual(mockNetworkService.simulationCallCount, 1)
    }
    
    func testGetBackstopToken_Success() async throws {
        // Arrange
        let expectedTokenAddress = "CAUQHVD2K4IKFHHG3HN4RY6HXVKQXB3OLU24BYG6E6FQLH6AS4W5KSTP"
        mockNetworkService.mockContractSimulationResponse = createMockAddressResponse(expectedTokenAddress)
        
        // Act
        let result = try await backstopService.getBackstopToken()
        
        // Assert
        XCTAssertEqual(result, expectedTokenAddress)
        XCTAssertEqual(mockNetworkService.simulationCallCount, 1)
    }
}

// MARK: - Error Handling Tests

extension BackstopContractServiceTests {
    
    func testDeposit_InvalidAmount() async throws {
        // Act & Assert
        await XCTAssertThrowsError(
            try await backstopService.deposit(
                from: testUserAddress,
                poolAddress: testPoolAddress,
                amount: -100
            )
        ) { error in
            guard case BackstopError.invalidAmount = error else {
                XCTFail("Expected BackstopError.invalidAmount, got \(error)")
                return
            }
        }
    }
    
    func testDeposit_InvalidAddress() async throws {
        // Act & Assert
        await XCTAssertThrowsError(
            try await backstopService.deposit(
                from: "invalid-address",
                poolAddress: testPoolAddress,
                amount: testAmount
            )
        ) { error in
            guard case BackstopError.invalidAddress = error else {
                XCTFail("Expected BackstopError.invalidAddress, got \(error)")
                return
            }
        }
    }
    
    func testNetworkError() async throws {
        // Arrange
        mockNetworkService.shouldFailSimulation = true
        mockNetworkService.simulationError = NSError(
            domain: "TestError",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Network error"]
        )
        
        // Act & Assert
        await XCTAssertThrowsError(
            try await backstopService.deposit(
                from: testUserAddress,
                poolAddress: testPoolAddress,
                amount: testAmount
            )
        ) { error in
            guard case BackstopError.simulationError = error else {
                XCTFail("Expected BackstopError.simulationError, got \(error)")
                return
            }
        }
    }
    
    func testContractError() async throws {
        // Arrange
        mockNetworkService.mockContractSimulationResponse = createMockErrorResponse(
            BackstopContractError.insufficientFunds
        )
        
        // Act & Assert
        await XCTAssertThrowsError(
            try await backstopService.deposit(
                from: testUserAddress,
                poolAddress: testPoolAddress,
                amount: testAmount
            )
        ) { error in
            guard case BackstopError.contractError(let contractError) = error,
                  contractError == .insufficientFunds else {
                XCTFail("Expected BackstopError.contractError(.insufficientFunds), got \(error)")
                return
            }
        }
    }
}

// MARK: - Batch Operations Tests

extension BackstopContractServiceTests {
    
    func testGetUserBalancesBatch() async throws {
        // Arrange
        let pools = [testPoolAddress, "GDXE5NVZPKPBCKLVPZ4ENPWEWDW6CM7LH5NVJHXDAEB2A3VXA7C6LHZQ"]
        let expectedBalance = UserBalance(
            shares: Int128(1000),
            q4w: Q4W(amount: Int128(0), epoch: 0)
        )
        mockNetworkService.mockContractSimulationResponse = createMockUserBalanceResponse(expectedBalance)
        
        // Act
        let results = try await backstopService.getUserBalances(
            user: testUserAddress,
            pools: pools
        )
        
        // Assert
        XCTAssertEqual(results.count, 2)
        XCTAssertNotNil(results[testPoolAddress])
        XCTAssertEqual(results[testPoolAddress]?.shares, expectedBalance.shares)
        XCTAssertEqual(mockNetworkService.simulationCallCount, 2) // One call per pool
    }
    
    func testGetPoolDataBatch() async throws {
        // Arrange
        let pools = [testPoolAddress, "GDXE5NVZPKPBCKLVPZ4ENPWEWDW6CM7LH5NVJHXDAEB2A3VXA7C6LHZQ"]
        let expectedPoolData = PoolBackstopData(
            balance: PoolBalance(shares: Int128(1000), tokens: Int128(950)),
            emissions: BackstopEmissionsData(index: Int128(100), lastTime: 1699123456),
            q4w: PoolBalance(shares: Int128(0), tokens: Int128(0))
        )
        mockNetworkService.mockContractSimulationResponse = createMockPoolDataResponse(expectedPoolData)
        
        // Act
        let results = try await backstopService.getPoolDataBatch(pools: pools)
        
        // Assert
        XCTAssertEqual(results.count, 2)
        XCTAssertNotNil(results[testPoolAddress])
        XCTAssertEqual(results[testPoolAddress]?.balance.shares, expectedPoolData.balance.shares)
        XCTAssertEqual(mockNetworkService.simulationCallCount, 2)
    }
}

// MARK: - Configuration Tests

extension BackstopContractServiceTests {
    
    func testTestnetConfig() {
        // Act
        let config = BackstopContractService.testnetConfig()
        
        // Assert
        XCTAssertEqual(config.network, .testnet)
        XCTAssertFalse(config.contractAddress.isEmpty)
        XCTAssertTrue(config.rpcUrl.contains("testnet"))
    }
    
    func testMainnetConfig() {
        // Act
        let config = BackstopContractService.mainnetConfig()
        
        // Assert
        XCTAssertEqual(config.network, .public)
        XCTAssertFalse(config.contractAddress.isEmpty)
        XCTAssertFalse(config.rpcUrl.contains("testnet"))
    }
    
    func testCreateTestnetService() {
        // Act
        let service = BackstopContractService.createTestnetService(
            networkService: mockNetworkService,
            cacheService: mockCacheService
        )
        
        // Assert
        XCTAssertNotNil(service)
        XCTAssertEqual(service.config.network, .testnet)
    }
}

// MARK: - Mock Response Helpers

extension BackstopContractServiceTests {
    
    private func createMockI128Response(_ value: Int128) -> SCValXDR {
        let parts = Int128PartsXDR(
            hi: Int64(value >> 64),
            lo: UInt64(value & 0xFFFFFFFFFFFFFFFF)
        )
        return SCValXDR.i128(parts)
    }
    
    private func createMockAddressResponse(_ address: String) -> SCValXDR {
        let contractAddressXdr = try! SCAddressXDR(contractId: address)
        return SCValXDR.address(contractAddressXdr)
    }
    
    private func createMockUserBalanceResponse(_ balance: UserBalance) -> SCValXDR {
        let sharesParts = Int128PartsXDR(
            hi: Int64(balance.shares >> 64),
            lo: UInt64(balance.shares & 0xFFFFFFFFFFFFFFFF)
        )
        let amountParts = Int128PartsXDR(
            hi: Int64(balance.q4w.amount >> 64),
            lo: UInt64(balance.q4w.amount & 0xFFFFFFFFFFFFFFFF)
        )
        
        return SCValXDR.map([
            SCValXDR.symbol("shares"): SCValXDR.i128(sharesParts),
            SCValXDR.symbol("q4w"): SCValXDR.map([
                SCValXDR.symbol("amount"): SCValXDR.i128(amountParts),
                SCValXDR.symbol("epoch"): SCValXDR.u32(UInt32(balance.q4w.epoch))
            ])
        ])
    }
    
    private func createMockPoolDataResponse(_ poolData: PoolBackstopData) -> SCValXDR {
        let balanceSharesParts = Int128PartsXDR(
            hi: Int64(poolData.balance.shares >> 64),
            lo: UInt64(poolData.balance.shares & 0xFFFFFFFFFFFFFFFF)
        )
        let balanceTokensParts = Int128PartsXDR(
            hi: Int64(poolData.balance.tokens >> 64),
            lo: UInt64(poolData.balance.tokens & 0xFFFFFFFFFFFFFFFF)
        )
        let emissionIndexParts = Int128PartsXDR(
            hi: Int64(poolData.emissions.index >> 64),
            lo: UInt64(poolData.emissions.index & 0xFFFFFFFFFFFFFFFF)
        )
        
        return SCValXDR.map([
            SCValXDR.symbol("balance"): SCValXDR.map([
                SCValXDR.symbol("shares"): SCValXDR.i128(balanceSharesParts),
                SCValXDR.symbol("tokens"): SCValXDR.i128(balanceTokensParts)
            ]),
            SCValXDR.symbol("emissions"): SCValXDR.map([
                SCValXDR.symbol("index"): SCValXDR.i128(emissionIndexParts),
                SCValXDR.symbol("last_time"): SCValXDR.u64(poolData.emissions.lastTime)
            ]),
            SCValXDR.symbol("q4w"): SCValXDR.map([
                SCValXDR.symbol("shares"): SCValXDR.i128(Int128PartsXDR(hi: 0, lo: 0)),
                SCValXDR.symbol("tokens"): SCValXDR.i128(Int128PartsXDR(hi: 0, lo: 0))
            ])
        ])
    }
    
    private func createMockErrorResponse(_ error: BackstopContractError) -> SCValXDR {
        return SCValXDR.error(SCErrorXDR.contractError(UInt32(error.rawValue)))
    }
}
