//
//  BlendModelsTests.swift
//  Blendv3Tests
//
//  Unit tests for Blend protocol models
//

import Testing
@testable import Blendv3

struct BlendModelsTests {
    
    @Test func lendingPoolDisplayName() async throws {
        // Test with name
        let poolWithName = LendingPool(
            id: "12345678",
            name: "USDC Pool",
            poolAddress: "GABC...",
            backstopAddress: "GDEF...",
            oracleId: "oracle1",
            supportedAssets: [],
            totalValueLocked: 100000,
            isActive: true
        )
        #expect(poolWithName.displayName == "USDC Pool")
        
        // Test without name
        let poolWithoutName = LendingPool(
            id: "87654321",
            name: "",
            poolAddress: "GABC...",
            backstopAddress: "GDEF...",
            oracleId: "oracle1",
            supportedAssets: [],
            totalValueLocked: 100000,
            isActive: true
        )
        #expect(poolWithoutName.displayName == "Pool 87654321")
    }
    
    @Test func poolAssetCalculations() async throws {
        let asset = PoolAsset(
            id: "asset1",
            assetCode: "USDC",
            assetIssuer: "GISSUER...",
            totalSupply: 10000,
            totalBorrowed: 6000,
            utilizationRate: 0.6,
            supplyAPY: 0.05,
            borrowAPY: 0.08,
            reserveFactor: 0.1
        )        
        #expect(asset.availableLiquidity == 4000)
        #expect(asset.isNative == false)
        
        // Test native asset
        let nativeAsset = PoolAsset(
            id: "native",
            assetCode: "XLM",
            assetIssuer: nil,
            totalSupply: 50000,
            totalBorrowed: 10000,
            utilizationRate: 0.2,
            supplyAPY: 0.02,
            borrowAPY: 0.04,
            reserveFactor: 0.05
        )
        #expect(nativeAsset.isNative == true)
    }
    
    @Test func userPositionHealthCheck() async throws {
        let position = UserPosition(
            id: "pos1",
            poolId: "pool1",
            userAddress: "GUSER...",
            suppliedAssets: [
                SuppliedAsset(
                    id: "s1",
                    assetCode: "USDC",
                    amount: 1000,
                    valueInUSD: 1000,
                    apy: 0.05,
                    isCollateral: true
                )
            ],
            borrowedAssets: [
                BorrowedAsset(
                    id: "b1",
                    assetCode: "XLM",
                    amount: 500,
                    valueInUSD: 100,
                    apy: 0.08,
                    accruedInterest: 2.5
                )
            ],
            healthFactor: 1.5,
            netAPY: 0.03
        )
        
        #expect(position.isHealthy == true)
        #expect(position.totalSuppliedValue == 1000)
        #expect(position.totalBorrowedValue == 100)
    }
}