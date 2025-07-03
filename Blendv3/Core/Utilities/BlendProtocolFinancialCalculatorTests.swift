//
//  BlendProtocolFinancialCalculatorTests.swift
//  Blendv3
//
//  Test cases to validate APY/APR calculations match expected values
//

import Foundation

/// Quick validation tests for the financial calculator
public struct BlendProtocolFinancialCalculatorTests {
    
    private let calculator = BlendProtocolFinancialCalculator()
    
    /// Run all validation tests
    public func runAllTests() {
        print("\n🧪 Running BlendProtocolFinancialCalculator Validation Tests\n")
        
        testUSDCCalculations()
        testXLMCalculations()
        testWETHCalculations()
        
        print("\n✅ All tests completed\n")
    }
    
    /// Test USDC calculations - should show ~10.21% supply APY
    private func testUSDCCalculations() {
        print("📊 Testing USDC Calculations")
        print("Expected: Supply APY ~10.21%, Borrow APY ~12.80%")
        
        // USDC test data based on your provided values
        let assetData = createTestAssetData(
            symbol: "USDC",
            dSupply: 47366478284124635,  // ~473,664.78 USDC (7 decimals)
            bSupply: 52633521715875365,  // ~526,335.22 USDC (7 decimals)
            dRate: 1_020_000_000,        // 1.02 (9 decimals)
            utilTarget: 8_000_000,       // 80% (7 decimals)
            rBase: 200_000,              // 2% (7 decimals)
            rOne: 800_000,               // 8% (7 decimals)
            rTwo: 2_000_000,             // 20% (7 decimals)
            rThree: 20_000_000,          // 200% (7 decimals)
            irModifier: 10_000_000       // 1.0 (7 decimals)
        )
        
        let backstopRate: Decimal = 2_000_000  // 20% (7 decimals)
        
        let supplyAPY = calculator.calculateAPYFromAssetData(assetData, backstopTakeRate: backstopRate, isSupply: true)
        let borrowAPY = calculator.calculateAPYFromAssetData(assetData, backstopTakeRate: backstopRate, isSupply: false)
        
        print("Result: Supply APY = \(String(format: "%.2f", Double(truncating: supplyAPY as NSNumber)))%")
        print("Result: Borrow APY = \(String(format: "%.2f", Double(truncating: borrowAPY as NSNumber)))%")
        print("✅ USDC test completed\n")
    }
    
    /// Test XLM calculations
    private func testXLMCalculations() {
        print("📊 Testing XLM Calculations")
        
        let assetData = createTestAssetData(
            symbol: "XLM",
            dSupply: 25010428107825,      // ~25,010.43 XLM (7 decimals)
            bSupply: 352594538645000,     // ~352,594.54 XLM (7 decimals)
            dRate: 1_001_000_000,         // 1.001 (9 decimals)
            utilTarget: 8_000_000,        // 80% (7 decimals)
            rBase: 100_000,               // 1% (7 decimals)
            rOne: 400_000,                // 4% (7 decimals)
            rTwo: 1_000_000,              // 10% (7 decimals)
            rThree: 10_000_000,           // 100% (7 decimals)
            irModifier: 10_000_000        // 1.0 (7 decimals)
        )
        
        let backstopRate: Decimal = 2_000_000  // 20% (7 decimals)
        
        let supplyAPY = calculator.calculateAPYFromAssetData(assetData, backstopTakeRate: backstopRate, isSupply: true)
        let borrowAPY = calculator.calculateAPYFromAssetData(assetData, backstopTakeRate: backstopRate, isSupply: false)
        
        print("Result: Supply APY = \(String(format: "%.2f", Double(truncating: supplyAPY as NSNumber)))%")
        print("Result: Borrow APY = \(String(format: "%.2f", Double(truncating: borrowAPY as NSNumber)))%")
        print("✅ XLM test completed\n")
    }
    
    /// Test wETH calculations
    private func testWETHCalculations() {
        print("📊 Testing wETH Calculations")
        
        let assetData = createTestAssetData(
            symbol: "wETH",
            dSupply: 316934204319971827,  // ~0.316934 wETH (18 decimals scaled to 7)
            bSupply: 683065795680028173,  // ~0.683066 wETH (18 decimals scaled to 7)
            dRate: 1_050_000_000,         // 1.05 (9 decimals)
            utilTarget: 8_000_000,        // 80% (7 decimals)
            rBase: 150_000,               // 1.5% (7 decimals)
            rOne: 600_000,                // 6% (7 decimals)
            rTwo: 1_500_000,              // 15% (7 decimals)
            rThree: 15_000_000,           // 150% (7 decimals)
            irModifier: 10_000_000        // 1.0 (7 decimals)
        )
        
        let backstopRate: Decimal = 2_000_000  // 20% (7 decimals)
        
        let supplyAPY = calculator.calculateAPYFromAssetData(assetData, backstopTakeRate: backstopRate, isSupply: true)
        let borrowAPY = calculator.calculateAPYFromAssetData(assetData, backstopTakeRate: backstopRate, isSupply: false)
        
        print("Result: Supply APY = \(String(format: "%.2f", Double(truncating: supplyAPY as NSNumber)))%")
        print("Result: Borrow APY = \(String(format: "%.2f", Double(truncating: borrowAPY as NSNumber)))%")
        print("✅ wETH test completed\n")
    }
    
    /// Helper to create test asset data with correct BlendAssetData structure
    private func createTestAssetData(
        symbol: String,
        dSupply: Decimal,
        bSupply: Decimal,
        dRate: Decimal,
        utilTarget: Decimal,
        rBase: Decimal,
        rOne: Decimal,
        rTwo: Decimal,
        rThree: Decimal,
        irModifier: Decimal
    ) -> BlendAssetData {
        return BlendAssetData(
            assetId: "test_\(symbol)_contract_id",
            scalar: 10_000_000,           // Standard Blend scalar (1e7)
            decimals: 7,
            enabled: true,
            index: 0,
            cFactor: 9_000_000,           // 90% collateral factor (7 decimals)
            lFactor: 9_000_000,           // 90% liability factor (7 decimals)
            maxUtil: 9_500_000,           // 95% max utilization (7 decimals)
            rBase: rBase,
            rOne: rOne,
            rTwo: rTwo,
            rThree: rThree,
            reactivity: 5_000_000,        // 50% reactivity (7 decimals)
            supplyCap: 100_000_000_000_000, // Large supply cap
            utilTarget: utilTarget,
            bSupply: bSupply,
            dSupply: dSupply,
            borrowRate: 0,                // Not used in calculator
            supplyRate: 0,                // Not used in calculator
            dRate: dRate,
            backstopCredit: 0,            // No backstop credit for test
            irModifier: irModifier,
            lastUpdate: Date(),
            pricePerToken: 1.0            // $1 USD for test
        )
    }
}

// Extension to run tests
extension BlendProtocolFinancialCalculator {
    /// Run validation tests
    public static func runValidationTests() {
        let tests = BlendProtocolFinancialCalculatorTests()
        tests.runAllTests()
    }
} 