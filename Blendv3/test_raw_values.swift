#!/usr/bin/env xcrun swift

import Foundation

// Define error enum for testing
enum BlendError: Error {
    case validation(ValidationError)
    
    enum ValidationError {
        case invalidInput
        case outOfBounds
        case integerOverflow
    }
}

// Define FixedMath utilities
enum FixedMath {
    static let SCALAR_7: Decimal = 10_000_000
    static let SCALAR_9: Decimal = 1_000_000_000
    static let SCALAR_12: Decimal = 1_000_000_000_000
    
    static func toFloat(value: Decimal, decimals: Int) -> Decimal {
        let scalar = pow(10.0, Double(decimals))
        return value / Decimal(scalar)
    }
}

// Define BlendAssetData struct
struct BlendAssetData {
    let assetId: String
    let scalar: Decimal
    let decimals: Int
    let enabled: Bool
    let index: Int
    let cFactor: Decimal
    let lFactor: Decimal
    let maxUtil: Decimal
    let rBase: Decimal
    let rOne: Decimal
    let rTwo: Decimal
    let rThree: Decimal
    let reactivity: Decimal
    let supplyCap: Decimal
    let utilTarget: Decimal
    let totalSupplied: Decimal
    let totalBorrowed: Decimal
    let borrowRate: Decimal
    let supplyRate: Decimal
    let dRate: Decimal
    let backstopCredit: Decimal
    let irModifier: Decimal
    let lastUpdate: Date
    var pricePerToken: Decimal
    
    // Helper methods to get human-readable values
    var suppliedHuman: Decimal {
        return FixedMath.toFloat(value: totalSupplied, decimals: 7)
    }
    
    var borrowedHuman: Decimal {
        return FixedMath.toFloat(value: totalBorrowed, decimals: 7)
    }
    
    // Financial calculations
    func calculateUtilizationRate(usingAccruedInterest: Bool = true) throws -> Decimal {
        // Handle edge case where there's no supply
        guard totalSupplied > 0 else {
            return totalBorrowed > 0 ? 1.0 : 0.0
        }
        
        // Convert raw fixed-point values to human-readable for calculation
        // totalSupplied and totalBorrowed are raw fixed-point values with SCALAR_7 (1e7)
        let totalSuppliedFloat = FixedMath.toFloat(value: totalSupplied, decimals: 7)
        let totalBorrowedFloat = FixedMath.toFloat(value: totalBorrowed, decimals: 7)
        
        let liabilities: Decimal
        if usingAccruedInterest {
            // TypeScript: liabilities = dSupply * dRate
            // Swift: liabilities = totalBorrowed * dRate (scaled properly)
            
            // dRate is scaled by SCALAR_12 (1e12)
            let dRateFloat = FixedMath.toFloat(value: dRate, decimals: 12)
            
            // Calculate liabilities with all values in native units
            liabilities = totalBorrowedFloat * dRateFloat
        } else {
            // Traditional calculation without accrued interest
            liabilities = totalBorrowedFloat
        }
        
        let totalAssets = totalSuppliedFloat + liabilities
        let utilization = liabilities / totalAssets
        return utilization
    }
    
    func calculateKinkedInterestRate(utilization: Decimal) throws -> Decimal {
        guard utilization >= 0 else {
            throw BlendError.validation(.invalidInput)
        }
        
        // Handle zero utilization
        guard utilization > 0 else {
            // rBase is a raw fixed-point value with SCALAR_7 (1e7)
            return FixedMath.toFloat(value: rBase, decimals: 7)
        }
        
                 // utilTarget is a raw fixed-point value with SCALAR_7 (1e7)
         let targetUtil = FixedMath.toFloat(value: utilTarget, decimals: 7)
         let emergencyThreshold = Decimal(0.95) // 95%
        
        // Convert raw fixed-point rates to float for calculation (all use SCALAR_7 = 1e7)
        let baseRate = FixedMath.toFloat(value: rBase, decimals: 7)
        let rateOne = FixedMath.toFloat(value: rOne, decimals: 7)
        let rateTwo = FixedMath.toFloat(value: rTwo, decimals: 7)
        let rateThree = FixedMath.toFloat(value: rThree, decimals: 7)
        let irModifierFloat = FixedMath.toFloat(value: irModifier, decimals: 7)
        
        var currentRate: Decimal
        
        if utilization <= targetUtil {
            // First slope: 0% to target utilization
            let utilizationScalar = utilization / targetUtil
            let baseInterestRate = (utilizationScalar * rateOne) + baseRate
            currentRate = baseInterestRate * irModifierFloat
        } else if utilization <= emergencyThreshold {
            // Second slope: target utilization to 95%
            let utilizationScalar = (utilization - targetUtil) / (emergencyThreshold - targetUtil)
            let baseInterestRate = (utilizationScalar * rateTwo) + rateOne + baseRate
            currentRate = baseInterestRate * irModifierFloat
        } else {
            // Third slope: 95% to 100% (emergency rates)
                         let utilizationScalar = (utilization - emergencyThreshold) / (Decimal(1.0) - emergencyThreshold)
            let extraRate = utilizationScalar * rateThree
            let intersection = irModifierFloat * (rateTwo + rateOne + baseRate)
            currentRate = extraRate + intersection
        }
        
        return currentRate
    }
    
    func calculateBorrowAPR() throws -> Decimal {
        // Calculate utilization with accrued interest
        let utilization = try calculateUtilizationRate(usingAccruedInterest: true)
        
        // Always calculate fresh kinked rate (returns decimal, not percentage)
        let currentIR = try calculateKinkedInterestRate(utilization: utilization)
        
        // Convert to percentage
        return currentIR * 100
    }
    
    func calculateSupplyAPR(backstopTakeRate: Decimal) throws -> Decimal {
        // Calculate utilization with accrued interest
        let utilization = try calculateUtilizationRate(usingAccruedInterest: true)
        guard utilization > 0 else { return 0 }
        
        // Always calculate fresh kinked rate (returns decimal, not percentage)
        let currentIR = try calculateKinkedInterestRate(utilization: utilization)
        
        // Calculate supply capture: (1 - backstopTakeRate) * utilization
        let backstopTakeRateFloat = FixedMath.toFloat(value: backstopTakeRate, decimals: 7)
        let supplyCapture = (1 - backstopTakeRateFloat) * utilization
        
        // Apply backstop to fresh kinked rate
        let supplyAPR = currentIR * supplyCapture
        
        // Convert to percentage
        return supplyAPR * 100
    }
    
    // Simple APY conversion for testing
    func calculateBorrowAPY() throws -> Decimal {
        let apr = try calculateBorrowAPR() / 100 // Convert to decimal
        return ((1 + apr/365).power(365) - 1) * 100 // Convert back to percentage
    }
    
    func calculateSupplyAPY(backstopTakeRate: Decimal) throws -> Decimal {
        let apr = try calculateSupplyAPR(backstopTakeRate: backstopTakeRate) / 100 // Convert to decimal
        return ((1 + apr/52).power(52) - 1) * 100 // Convert back to percentage
    }
}

// Add power method to Decimal
extension Decimal {
    func power(_ exponent: Int) -> Decimal {
        guard exponent > 0 else { return 1 }
        var result = self
        for _ in 1..<exponent {
            result *= self
        }
        return result
    }
}

// Run the test
func testRawFixedPointCalculations() {
    print("Starting test with raw fixed-point values...")
    
    // Create a BlendAssetData instance with the raw values from the provided data
    let assetData = BlendAssetData(
        assetId: "2022d56e0aba64516f6e62604d296232be864ffdfb84d58613e7423cace02b28",
        scalar: 10_000_000, // 1e7
        decimals: 7,
        enabled: true,
        index: 3,
        cFactor: 9_500_000, // 0.95 as raw fixed-point
        lFactor: 9_500_000, // 0.95 as raw fixed-point
        maxUtil: 9_500_000, // 0.95 as raw fixed-point
        rBase: 5_000, // 0.0005 as raw fixed-point
        rOne: 300_000, // 0.03 as raw fixed-point
        rTwo: 1_000_000, // 0.1 as raw fixed-point
        rThree: 10_000_000, // 1.0 as raw fixed-point
        reactivity: 100, // 0.00001 as raw fixed-point
        supplyCap: Decimal(string: "92233720368547758070000000000000000000000000000000000000000000000000000000000000000")!,
        utilTarget: 7_500_000, // 0.75 as raw fixed-point
        totalSupplied: 253_242_521_580, // 25324.252158 * 1e7
        totalBorrowed: 189_569_995_217, // 18956.9995217 * 1e7
        borrowRate: 1_001_278_311_027, // Raw from chain
        supplyRate: 0,
        dRate: 1_002_192_732_109, // Raw from chain (SCALAR_12)
        backstopCredit: 21_705_254, // 2.1705254 * 1e7
        irModifier: 2_995_478, // 0.2995478 as raw fixed-point
        lastUpdate: Date(timeIntervalSince1970: 1718328188), // 2025-06-14 03:23:08 +0000
        pricePerToken: 0
    )
    
    // Set backstopTakeRate to 0.1 (10%)
    let backstopTakeRate: Decimal = 1_000_000 // 0.1 as raw fixed-point (10%)
    
    print("Raw Data Test Results:")
    print("----------------------")
    
    do {
        // Calculate utilization rate
        let utilization = try assetData.calculateUtilizationRate(usingAccruedInterest: true)
        print("Utilization: \(utilization * 100)%")
        
        // Calculate kinked interest rate
        let kinkedRate = try assetData.calculateKinkedInterestRate(utilization: utilization)
        print("Kinked Rate: \(kinkedRate * 100)%")
        
        // Calculate APR and APY
        let borrowAPR = try assetData.calculateBorrowAPR()
        let borrowAPY = try assetData.calculateBorrowAPY()
        let supplyAPR = try assetData.calculateSupplyAPR(backstopTakeRate: backstopTakeRate)
        let supplyAPY = try assetData.calculateSupplyAPY(backstopTakeRate: backstopTakeRate)
        
        print("Borrow APR: \(borrowAPR)%")
        print("Borrow APY: \(borrowAPY)%")
        print("Supply APR: \(supplyAPR)%")
        print("Supply APY: \(supplyAPY)%")
        
        // Add raw data for reference
        print("\nRaw Data:")
        print("totalSupplied: \(assetData.totalSupplied)")
        print("totalBorrowed: \(assetData.totalBorrowed)")
        print("dRate: \(assetData.dRate)")
        print("Human-readable values:")
        print("totalSupplied (human): \(assetData.suppliedHuman)")
        print("totalBorrowed (human): \(assetData.borrowedHuman)")
        print("dRate (human): \(FixedMath.toFloat(value: assetData.dRate, decimals: 12))")
        
    } catch {
        print("Error in calculations: \(error)")
    }
}

// Run the test
testRawFixedPointCalculations() 