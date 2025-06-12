//
//  BlendUSDCVaultTests.swift
//  Blendv3Tests
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import XCTest
import Combine
import stellarsdk
@testable import Blendv3

/// Unit tests for BlendUSDCVault
class BlendUSDCVaultTests: XCTestCase {
    
    var vault: BlendUSDCVault!
    var mockSigner: MockSigner!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Create a mock signer for testing
        mockSigner = MockSigner()
        
        // Initialize vault with testnet
        vault = BlendUSDCVault(signer: mockSigner, network: .testnet)
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        vault = nil
        mockSigner = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testVaultInitialization() {
        XCTAssertNotNil(vault)
        XCTAssertNil(vault.poolStats)
        XCTAssertFalse(vault.isLoading)
        XCTAssertNil(vault.error)
    }
    
    // MARK: - Constants Tests
    
    func testScalingFunctions() {
        // Test scaling up
        let amount: Decimal = 100.5
        let scaled = BlendUSDCConstants.scaleAmount(amount)
        
        // 100.5 * 10^7 = 1,005,000,000
        XCTAssertEqual(scaled.hi, 0)
        XCTAssertEqual(scaled.lo, 1_005_000_000)
        
        // Test scaling down
        let unscaled = BlendUSDCConstants.unscaleAmount(scaled)
        XCTAssertEqual(unscaled, amount)
        
        // Test with zero
        let zeroScaled = BlendUSDCConstants.scaleAmount(0)
        XCTAssertEqual(zeroScaled.hi, 0)
        XCTAssertEqual(zeroScaled.lo, 0)
        
        // Test with small amount
        let smallAmount: Decimal = 0.0000001 // Smallest unit
        let smallScaled = BlendUSDCConstants.scaleAmount(smallAmount)
        XCTAssertEqual(smallScaled.hi, 0)
        XCTAssertEqual(smallScaled.lo, 1)
    }
    
    func testRequestTypes() {
        XCTAssertEqual(BlendUSDCConstants.RequestType.supplyCollateral.rawValue, 0)
        XCTAssertEqual(BlendUSDCConstants.RequestType.withdrawCollateral.rawValue, 1)
        XCTAssertEqual(BlendUSDCConstants.RequestType.supply.rawValue, 2)
        XCTAssertEqual(BlendUSDCConstants.RequestType.withdraw.rawValue, 3)
    }
    
    // MARK: - Pool Stats Tests
    
    func testPoolStatsCalculations() {
        let poolData = PoolLevelData(
            totalValueLocked: 1_000_000,
            overallUtilization: 0.4,
            healthScore: 0.98,
            activeReserves: 1
        )
        
        let usdcReserveData = USDCReserveData(
            totalSupplied: 1_000_000,
            totalBorrowed: 400_000,
            utilizationRate: 0.4,
            supplyApr: 5.5,
            supplyApy: 5.5,
            borrowApr: 6.0,
            borrowApy: 6.0,
            collateralFactor: 0.95,
            liabilityFactor: 1.0526
        )
        
        let backstopData = BackstopData(
            totalBackstop: 50_000,
            backstopApr: 0.01,
            q4wPercentage: 14.75,
            takeRate: 0.10,
            blndAmount: 30_000,
            usdcAmount: 20_000
        )
        
        let stats = BlendPoolStats(
            poolData: poolData,
            usdcReserveData: usdcReserveData,
            backstopData: backstopData,
            lastUpdated: Date()
        )
        
        XCTAssertEqual(stats.usdcReserveData.utilizationRate, 0.4) // 40%
        XCTAssertEqual(stats.usdcReserveData.availableLiquidity, 600_000)
    }
    
    func testPoolStatsWithZeroSupply() {
        let poolData = PoolLevelData(
            totalValueLocked: 0,
            overallUtilization: 0,
            healthScore: 1.0,
            activeReserves: 0
        )
        
        let usdcReserveData = USDCReserveData(
            totalSupplied: 0,
            totalBorrowed: 0,
            utilizationRate: 0,
            supplyApr: 0,
            supplyApy: 0,
            borrowApr: 0,
            borrowApy: 0,
            collateralFactor: 0.95,
            liabilityFactor: 1.0526
        )
        
        let backstopData = BackstopData(
            totalBackstop: 0,
            backstopApr: 0,
            q4wPercentage: 0,
            takeRate: 0,
            blndAmount: 0,
            usdcAmount: 0
        )
        
        let stats = BlendPoolStats(
            poolData: poolData,
            usdcReserveData: usdcReserveData,
            backstopData: backstopData,
            lastUpdated: Date()
        )
        
        XCTAssertEqual(stats.usdcReserveData.utilizationRate, 0)
        XCTAssertEqual(stats.usdcReserveData.availableLiquidity, 0)
    }
    
    // MARK: - Async Tests
    
    func testRefreshPoolStats() async throws {
        // Test refreshing pool stats
        try await vault.refreshPoolStats()
        
        XCTAssertNotNil(vault.poolStats)
        // Note: These values will depend on the actual implementation
        // For now, just verify the structure is correct
        if let stats = vault.poolStats {
            XCTAssertNotNil(stats.usdcReserveData.totalSupplied)
            XCTAssertNotNil(stats.usdcReserveData.supplyApr)
        }
    }
    
    func testInvalidDepositAmount() async {
        do {
            _ = try await vault.deposit(amount: 0)
            XCTFail("Should throw error for zero amount")
        } catch {
            XCTAssertTrue(error is BlendVaultError)
            if let vaultError = error as? BlendVaultError {
                switch vaultError {
                case .invalidAmount:
                    // Expected error
                    break
                default:
                    XCTFail("Unexpected error type: \(vaultError)")
                }
            }
        }
    }
    
    func testInvalidWithdrawAmount() async {
        do {
            _ = try await vault.withdraw(amount: -10)
            XCTFail("Should throw error for negative amount")
        } catch {
            XCTAssertTrue(error is BlendVaultError)
            if let vaultError = error as? BlendVaultError {
                switch vaultError {
                case .invalidAmount:
                    // Expected error
                    break
                default:
                    XCTFail("Unexpected error type: \(vaultError)")
                }
            }
        }
    }
    
    // MARK: - Signer Tests
    
    func testKeyPairSigner() throws {
        // Test with a test keypair
        let testKeyPair = try KeyPair.generateRandomKeyPair()
        let signer = KeyPairSigner(keyPair: testKeyPair)
        
        XCTAssertEqual(signer.publicKey, testKeyPair.accountId)
        
        let retrievedKeyPair = try signer.getKeyPair()
        XCTAssertEqual(retrievedKeyPair.accountId, testKeyPair.accountId)
    }
    
    func testKeyPairSignerWithSecretSeed() throws {
        // Generate a test keypair and get its secret seed
        let testKeyPair = try KeyPair.generateRandomKeyPair()
        let secretSeed = testKeyPair.secretSeed
        
        // Create signer from secret seed
        let signer = try KeyPairSigner(secretSeed: secretSeed)
        
        XCTAssertEqual(signer.publicKey, testKeyPair.accountId)
    }
}

// MARK: - Mock Signer

/// Mock implementation of BlendSigner for testing
class MockSigner: BlendSigner {
    let mockKeyPair: KeyPair
    
    var publicKey: String {
        return mockKeyPair.accountId
    }
    
    init() {
        // Generate a random keypair for testing
        self.mockKeyPair = try! KeyPair.generateRandomKeyPair()
    }
    
    func sign(transaction: stellarsdk.Transaction, network: Network) async throws -> stellarsdk.Transaction {
        // In a real test, we would mock the signing
        // For now, just return the transaction as-is
        return transaction
    }
    
    func getKeyPair() throws -> KeyPair {
        return mockKeyPair
    }
} 