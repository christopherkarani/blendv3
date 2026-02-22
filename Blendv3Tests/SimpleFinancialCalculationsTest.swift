//
//  SimpleFinancialCalculationsTest.swift
//  Blendv3Tests
//
//  Created by Chris Karani on 30/05/2025.
//

import XCTest
@testable import Blendv3

final class SimpleFinancialCalculationsTest: XCTestCase {
    
    func testBasicFinancialCalculations() throws {
        // Create a simple test asset
        let testAsset = BlendAssetData(
            assetId: "test_asset",
            scalar: 10_000_000, // 1e7
            decimals: 7,
            enabled: true,
            index: 0,
            cFactor: 0.95,
            lFactor: 0.95,
            maxUtil: 0.95,
            rBase: 50_000, // 0.5%
            rOne: 400_000, // 4%
            rTwo: 2_000_000, // 20%
            rThree: 10_000_000, // 100%
            reactivity: 100_000,
            supplyCap: 1_000_000,
            utilTarget: 0.75, // 75%
            totalSupplied: 1000,
            totalBorrowed: 500, // 50% utilization
            borrowRate: 8.5,
            supplyRate: 4.2,
            backstopCredit: 2.1,
            irModifier: 3_003_262, // ~30%
            lastUpdate: Date()
        )
        
        // Test supply APR calculation
        let backstopRate = FixedMath.toFixed(value: 0.20, decimals: 7) // 20%
        let supplyAPR = try testAsset.calculateSupplyAPR(backstopTakeRate: backstopRate)
        
        XCTAssertGreaterThan(supplyAPR, 0, "Supply APR should be positive")
        XCTAssertLessThan(supplyAPR, 100, "Supply APR should be reasonable")
        
        // Test borrow APR calculation
        let borrowAPR = try testAsset.calculateBorrowAPR()
        
        XCTAssertGreaterThan(borrowAPR, 0, "Borrow APR should be positive")
        XCTAssertLessThan(borrowAPR, 100, "Borrow APR should be reasonable")
        XCTAssertGreaterThan(borrowAPR, supplyAPR, "Borrow APR should be higher than supply APR")
        
        // Test APY calculations
        let supplyAPY = try testAsset.calculateSupplyAPY(backstopTakeRate: backstopRate)
        let borrowAPY = try testAsset.calculateBorrowAPY()
        
        XCTAssertGreaterThan(supplyAPY, supplyAPR, "APY should be higher than APR due to compounding")
        XCTAssertGreaterThan(borrowAPY, borrowAPR, "APY should be higher than APR due to compounding")
        
        print("✅ Supply APR: \(supplyAPR)%")
        print("✅ Supply APY: \(supplyAPY)%")
        print("✅ Borrow APR: \(borrowAPR)%")
        print("✅ Borrow APY: \(borrowAPY)%")
    }
    
    func testUtilizationCalculation() throws {
        let testAsset = BlendAssetData(
            assetId: "test_asset",
            scalar: 10_000_000,
            decimals: 7,
            enabled: true,
            index: 0,
            cFactor: 0.95,
            lFactor: 0.95,
            maxUtil: 0.95,
            rBase: 50_000,
            rOne: 400_000,
            rTwo: 2_000_000,
            rThree: 10_000_000,
            reactivity: 100_000,
            supplyCap: 1_000_000,
            utilTarget: 0.75,
            totalSupplied: 800,
            totalBorrowed: 200, // 20% utilization
            borrowRate: 8.5,
            supplyRate: 4.2,
            backstopCredit: 2.1,
            irModifier: 3_003_262,
            lastUpdate: Date()
        )
        
        let utilization = try testAsset.calculateUtilizationRate()
        let expectedUtilization: Decimal = 200 / (800 + 200) // 0.2 or 20%
        
        XCTAssertEqual(utilization, expectedUtilization, accuracy: 0.001, "Utilization should be exactly 20%")
        print("✅ Utilization: \(utilization * 100)%")
    }
} 