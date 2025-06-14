//
//  BlendAssetData+FinancialCalculations.swift
//  Blendv3
//
//  Created by Chris Karani on 30/05/2025.
//

import Foundation

// MARK: - Financial Calculations Extension

extension BlendAssetData {
    
    // MARK: - Public API
    
    /// Calculate supply Annual Percentage Rate
    /// 
    /// Uses the Blend Protocol's three-slope kinked interest rate model with proper
    /// utilization calculation including accrued interest.
    ///
    /// Mathematical Formula:
    /// ```
    /// liabilities = totalBorrowed * dRate (includes accrued interest)
    /// utilization = liabilities / (totalSupplied + liabilities)
    /// currentIR = calculateKinkedInterestRate(utilization) (returns decimal)
    /// supplyCapture = (1 - backstopTakeRate) * utilization  
    /// supplyAPR = currentIR * supplyCapture
    /// ```
    ///
    /// - Parameter backstopTakeRate: Fixed-point scaled backstop rate (e.g., 2_000_000 for 20%)
    /// - Returns: Supply APR as percentage (e.g., 5.25 for 5.25%)
    /// - Throws: BlendError.validation for invalid inputs
    ///
    /// Example:
    /// ```swift
    /// let backstopRate = FixedMath.toFixed(value: 0.20, decimals: 7) // 20%
    /// let supplyAPR = try assetData.calculateSupplyAPR(backstopTakeRate: backstopRate)
    /// print("Supply APR: \(supplyAPR)%") // "Supply APR: 4.25%"
    /// ```
    public func calculateSupplyAPR(backstopTakeRate: Decimal) throws -> Decimal {
        try validateInputs(backstopTakeRate: backstopTakeRate)
        
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
        
        // Apply safety bounds and convert to percentage
        let boundedAPR = min(supplyAPR, BlendFinancialConstants.maxAPR)
        return max(boundedAPR * 100, 0) // Convert to percentage
    }
    
    /// Calculate borrow Annual Percentage Rate
    /// 
    /// Uses the Blend Protocol's three-slope kinked interest rate model with proper
    /// utilization calculation including accrued interest.
    ///
    /// Mathematical Formula:
    /// ```
    /// liabilities = totalBorrowed * dRate (includes accrued interest)
    /// utilization = liabilities / (totalSupplied + liabilities)
    /// borrowAPR = calculateKinkedInterestRate(utilization) (returns decimal)
    /// ```
    ///
    /// - Returns: Borrow APR as percentage (e.g., 8.75 for 8.75%)
    /// - Throws: BlendError.validation for invalid inputs
    ///
    /// Example:
    /// ```swift
    /// let borrowAPR = try assetData.calculateBorrowAPR()
    /// print("Borrow APR: \(borrowAPR)%") // "Borrow APR: 8.75%"
    /// ```
    public func calculateBorrowAPR() throws -> Decimal {
        try validateInputs(backstopTakeRate: nil)
        
        // Calculate utilization with accrued interest
        let utilization = try calculateUtilizationRate(usingAccruedInterest: true)
        
        // Always calculate fresh kinked rate (returns decimal, not percentage)
        let currentIR = try calculateKinkedInterestRate(utilization: utilization)
        
        // Apply safety bounds and convert to percentage
        let boundedAPR = min(currentIR, BlendFinancialConstants.maxAPR)
        return max(boundedAPR * 100, 0) // Convert to percentage
    }
    
    /// Calculate supply Annual Percentage Yield
    /// 
    /// Converts supply APR to APY using compound interest formula with weekly compounding.
    ///
    /// Mathematical Formula:
    /// ```
    /// APR = calculateSupplyAPR(backstopTakeRate)
    /// APY = (1 + APR/52)^52 - 1
    /// ```
    ///
    /// - Parameter backstopTakeRate: Fixed-point scaled backstop rate (e.g., 2_000_000 for 20%)
    /// - Returns: Supply APY as percentage (e.g., 5.38 for 5.38%)
    /// - Throws: BlendError.validation for invalid inputs
    ///
    /// Example:
    /// ```swift
    /// let backstopRate = FixedMath.toFixed(value: 0.20, decimals: 7) // 20%
    /// let supplyAPY = try assetData.calculateSupplyAPY(backstopTakeRate: backstopRate)
    /// print("Supply APY: \(supplyAPY)%") // "Supply APY: 5.38%"
    /// ```
    public func calculateSupplyAPY(backstopTakeRate: Decimal) throws -> Decimal {
        let apr = try calculateSupplyAPR(backstopTakeRate: backstopTakeRate)
        let aprDecimal = apr / 100 // Convert percentage back to decimal for calculation
        
        guard aprDecimal > 0 else { return 0 }
        
        do {
            let apy = try convertAPRtoAPY(aprDecimal, compoundingPeriods: BlendFinancialConstants.supplyCompoundingPeriods)
            return apy * 100 // Convert back to percentage
        } catch {
            // Fallback: for very small rates, APY ≈ APR
            return apr
        }
    }
    
    /// Calculate borrow Annual Percentage Yield
    /// 
    /// Converts borrow APR to APY using compound interest formula with daily compounding.
    ///
    /// Mathematical Formula:
    /// ```
    /// APR = calculateBorrowAPR()
    /// APY = (1 + APR/365)^365 - 1
    /// ```
    ///
    /// - Returns: Borrow APY as percentage (e.g., 9.12 for 9.12%)
    /// - Throws: BlendError.validation for invalid inputs
    ///
    /// Example:
    /// ```swift
    /// let borrowAPY = try assetData.calculateBorrowAPY()
    /// print("Borrow APY: \(borrowAPY)%") // "Borrow APY: 9.12%"
    /// ```
    public func calculateBorrowAPY() throws -> Decimal {
        let apr = try calculateBorrowAPR()
        let aprDecimal = apr / 100 // Convert percentage back to decimal for calculation
        
        guard aprDecimal > 0 else { return 0 }
        
        do {
            let apy = try convertAPRtoAPY(aprDecimal, compoundingPeriods: BlendFinancialConstants.borrowCompoundingPeriods)
            return apy * 100 // Convert back to percentage
        } catch {
            // Fallback: for very small rates, APY ≈ APR
            return apr
        }
    }
    
    // MARK: - Internal Implementation (for testing)
    
    /// Validates input parameters and asset data integrity
    /// - Parameter backstopTakeRate: Optional backstop rate to validate
    /// - Throws: BlendError.validation for invalid inputs
    internal func validateInputs(backstopTakeRate: Decimal?) throws {
        // Asset data validation - allow zero supplied for edge cases
        guard totalSupplied >= 0 else {
            throw BlendError.validation(.invalidInput)
        }
        
        guard totalBorrowed >= 0 else {
            throw BlendError.validation(.invalidInput)
        }
        
        // Backstop rate validation (if provided)
        if let backstopRate = backstopTakeRate {
            guard backstopRate >= 0 && backstopRate <= FixedMath.SCALAR_7 else {
                throw BlendError.validation(.outOfBounds)
            }
        }
        
        // Skip utilization bounds check since we're using real chain data
        // which might have edge cases we need to handle gracefully
    }
    
    /// Calculates utilization rate using total supplied and borrowed amounts
    /// - Parameter usingAccruedInterest: Whether to include accrued interest in calculation
    /// - Returns: Utilization rate as decimal (0.0 to 1.0)
    /// - Throws: BlendError.validation for calculation errors
    internal func calculateUtilizationRate(usingAccruedInterest: Bool = true) throws -> Decimal {
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
        return roundToCalculationPrecision(utilization)
    }
    
    /// Implements three-slope kinked interest rate model
    /// 
    /// The Blend Protocol uses a three-slope interest rate model:
    /// - Slope 1: 0% to target utilization
    /// - Slope 2: target utilization to 95%
    /// - Slope 3: 95% to 100% (emergency rates)
    ///
    /// - Parameter utilization: Current utilization rate (0.0 to 1.0)
    /// - Returns: Current interest rate as decimal (e.g., 0.08 for 8%)
    /// - Throws: BlendError.validation for invalid calculations
    internal func calculateKinkedInterestRate(utilization: Decimal) throws -> Decimal {
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
        let emergencyThreshold = BlendFinancialConstants.emergencyUtilizationThreshold
        
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
            let utilizationScalar = (utilization - emergencyThreshold) / (1.0 - emergencyThreshold)
            let extraRate = utilizationScalar * rateThree
            let intersection = irModifierFloat * (rateTwo + rateOne + baseRate)
            currentRate = extraRate + intersection
        }
        
        // Ensure non-negative rate
        guard currentRate >= 0 else {
            throw BlendError.validation(.invalidInput)
        }
        
        return roundToCalculationPrecision(currentRate)
    }
    
    /// Converts APR to APY using compound interest formula
    /// 
    /// Formula: APY = (1 + APR/n)^n - 1
    /// Where n is the number of compounding periods per year
    ///
    /// - Parameters:
    ///   - apr: Annual Percentage Rate as decimal (e.g., 0.05 for 5%)
    ///   - compoundingPeriods: Number of compounding periods per year
    /// - Returns: Annual Percentage Yield as decimal
    /// - Throws: BlendError.validation for invalid inputs or calculation errors
    internal func convertAPRtoAPY(_ apr: Decimal, compoundingPeriods: Int) throws -> Decimal {
        guard apr >= 0 else {
            throw BlendError.validation(.invalidInput)
        }
        
        guard compoundingPeriods > 0 else {
            throw BlendError.validation(.invalidInput)
        }
        
        // Handle zero APR
        guard apr > 0 else { return 0 }
        
        // Cap extremely high rates to prevent overflow
        let cappedAPR = min(apr, BlendFinancialConstants.maxAPR)
        
        // For very small rates, APY ≈ APR (no significant compounding effect)
        if cappedAPR < 0.0001 { // Less than 0.01%
            return cappedAPR
        }
        
        // Use Double for the exponential calculation to avoid Decimal overflow
        let aprDouble = Double(truncating: cappedAPR as NSNumber)
        let periodsDouble = Double(compoundingPeriods)
        
        // Calculate using the standard compound interest formula
        let periodicRate = aprDouble / periodsDouble
        
        // Additional safety check for extreme values
        guard periodicRate < 1.0 else {
            // If periodic rate >= 100%, cap the APY to maximum
            return BlendFinancialConstants.maxAPY
        }
        
        let compoundedDouble = pow(1.0 + periodicRate, periodsDouble)
        
        // Check for infinite or NaN results
        guard compoundedDouble.isFinite && !compoundedDouble.isNaN else {
            throw BlendError.validation(.integerOverflow)
        }
        
        let apyDouble = compoundedDouble - 1.0
        
        // Convert back to Decimal and apply bounds
        let apy = Decimal(apyDouble)
        let boundedAPY = min(apy, BlendFinancialConstants.maxAPY)
        
        return roundToCalculationPrecision(boundedAPY)
    }
    
    // MARK: - Private Helpers
    
    /// Rounds decimal to calculation precision using banker's rounding
    /// - Parameter value: Value to round
    /// - Returns: Rounded decimal value
    private func roundToCalculationPrecision(_ value: Decimal) -> Decimal {
        var rounded = Decimal()
        var mutableValue = value
        NSDecimalRound(&rounded, &mutableValue, BlendFinancialConstants.calculationPrecision, .bankers)
        return rounded
    }
}

// MARK: - Constants

private enum BlendFinancialConstants {
    // Utilization thresholds
    static let emergencyUtilizationThreshold: Decimal = 0.95  // 95%
    static let maxUtilizationThreshold: Decimal = 1.0         // 100%
    
    // Compounding periods
    static let supplyCompoundingPeriods = 52   // Weekly compounding
    static let borrowCompoundingPeriods = 365  // Daily compounding
    
    // Safety bounds
    static let maxAPR: Decimal = 5.0           // 500% cap (more reasonable)
    static let maxAPY: Decimal = 10.0          // 1000% cap (more reasonable)
    
    // Precision
    static let calculationPrecision = 8        // Decimal places for intermediate calculations
} 

