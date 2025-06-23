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
        
        let utilization = try calculateUtilizationRate(usingAccruedInterest: true)
        guard utilization > 0 else { return 0 }
        
        let currentIR = try calculateKinkedInterestRate(utilization: utilization)
        
        let backstopTakeRateFloat = FixedMath.toFloat(value: backstopTakeRate, decimals: self.decimals)
        let supplyCapture = (1 - backstopTakeRateFloat) * utilization
        
        let supplyAPR = currentIR * supplyCapture
        
        let boundedAPR = min(supplyAPR, BlendFinancialConstants.maxAPR)
        return max(boundedAPR * 100, 0)
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
        
        let utilization = try calculateUtilizationRate(usingAccruedInterest: true)
        
        let currentIR = try calculateKinkedInterestRate(utilization: utilization)
        
        let boundedAPR = min(currentIR, BlendFinancialConstants.maxAPR)
        return max(boundedAPR * 100, 0)
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
        let aprDecimal = apr / 100
        
        guard aprDecimal > 0 else { return 0 }
        
        let apy = try convertAPRtoAPY(aprDecimal, compoundingPeriods: BlendFinancialConstants.supplyCompoundingPeriods)
        return apy * 100
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
        let aprDecimal = apr / 100
        
        guard aprDecimal > 0 else { return 0 }
        
        let apy = try convertAPRtoAPY(aprDecimal, compoundingPeriods: BlendFinancialConstants.borrowCompoundingPeriods)
        return apy * 100
    }
    
    // MARK: - Internal Implementation (for testing)
    
    /// Validates input parameters and asset data integrity
    /// - Parameter backstopTakeRate: Optional backstop rate to validate
    /// - Throws: BlendError.validation for invalid inputs
    internal func validateInputs(backstopTakeRate: Decimal?) throws {
        guard bSupply >= 0, dSupply >= 0 else {
            throw BlendError.validation(.invalidInput)
        }
        
        if let backstopRate = backstopTakeRate {
            guard backstopRate >= 0 && backstopRate <= FixedMath.scale(by: self.decimals) else {
                throw BlendError.validation(.outOfBounds)
            }
        }
    }
    
    /// Calculates utilization rate using total supplied and borrowed amounts
    /// - Parameter usingAccruedInterest: Whether to include accrued interest in calculation
    /// - Returns: Utilization rate as decimal (0.0 to 1.0)
    /// - Throws: BlendError.validation for calculation errors
    internal func calculateUtilizationRate(usingAccruedInterest: Bool = true) throws -> Decimal {
        guard bSupply > 0 else {
            return dSupply > 0 ? 1.0 : 0.0
        }
        
        let bSupplyFloat = FixedMath.toFloat(value: bSupply, decimals: self.decimals)
        let dSupplyFloat = FixedMath.toFloat(value: dSupply, decimals: self.decimals)
        
        let liabilities: Decimal
        if usingAccruedInterest {
            let dRateFloat = FixedMath.toFloat(value: dRate, decimals: 12)
            liabilities = dSupplyFloat * dRateFloat
        } else {
            liabilities = dSupplyFloat
        }
        
        let totalAssets = bSupplyFloat + liabilities
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
        guard utilization >= 0 else { throw BlendError.validation(.invalidInput) }
        
        let rBaseFloat = FixedMath.toFloat(value: rBase, decimals: self.decimals)
        guard utilization > 0 else { return rBaseFloat }
        
        let targetUtil = FixedMath.toFloat(value: utilTarget, decimals: self.decimals)
        let emergencyThreshold = BlendFinancialConstants.emergencyUtilizationThreshold
        
        let rateOne = FixedMath.toFloat(value: rOne, decimals: self.decimals)
        let rateTwo = FixedMath.toFloat(value: rTwo, decimals: self.decimals)
        let rateThree = FixedMath.toFloat(value: rThree, decimals: self.decimals)
        let irModifierFloat = FixedMath.toFloat(value: irModifier, decimals: self.decimals)
        
        var currentRate: Decimal
        
        if utilization <= targetUtil {
            let utilizationScalar = utilization / targetUtil
            let baseInterestRate = (utilizationScalar * rateOne) + rBaseFloat
            currentRate = baseInterestRate * irModifierFloat
        } else if utilization <= emergencyThreshold {
            let utilizationScalar = (utilization - targetUtil) / (emergencyThreshold - targetUtil)
            let baseInterestRate = (utilizationScalar * rateTwo) + rateOne + rBaseFloat
            currentRate = baseInterestRate * irModifierFloat
        } else {
            let utilizationScalar = (utilization - emergencyThreshold) / (1.0 - emergencyThreshold)
            let extraRate = utilizationScalar * rateThree
            let intersection = irModifierFloat * (rateTwo + rateOne + rBaseFloat)
            currentRate = extraRate + intersection
        }
        
        guard currentRate >= 0 else { throw BlendError.validation(.invalidInput) }
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
        guard apr >= 0, compoundingPeriods > 0 else { throw BlendError.validation(.invalidInput) }
        guard apr > 0 else { return 0 }

        if apr < 0.0001 { return apr }
        
        let aprDouble = Double(truncating: apr as NSNumber)
        let periodsDouble = Double(compoundingPeriods)
        
        let periodicRate = aprDouble / periodsDouble
        
        guard periodicRate < 1.0 else { return BlendFinancialConstants.maxAPY }
        
        let compoundedDouble = pow(1.0 + periodicRate, periodsDouble)
        
        guard compoundedDouble.isFinite && !compoundedDouble.isNaN else {
            throw BlendError.validation(.integerOverflow)
        }
        
        let apyDouble = compoundedDouble - 1.0
        
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
    static let calculationPrecision = 18        // Decimal places for intermediate calculations
} 

