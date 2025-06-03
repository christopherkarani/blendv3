import Foundation

/// Concrete implementation of Blend Protocol rate calculations
public final class BlendRateCalculator: BlendRateCalculatorProtocol {
    
    // MARK: - Constants
    
    /// Number of compounding periods per year for supply APY (weekly)
    private let supplyCompoundingPeriods = 52
    
    /// Number of compounding periods per year for borrow APY (daily)
    private let borrowCompoundingPeriods = 365
    
    /// Emergency utilization threshold (95%)
    private let emergencyUtilizationThreshold: Decimal = 0.95
    
    // MARK: - Initialization
    
    public init() {
        BlendLogger.info("Rate calculator initialized", category: BlendLogger.rateCalculation)
    }
    
    // MARK: - BlendRateCalculatorProtocol
    
    public func calculateSupplyAPR(curIr: Decimal, curUtil: Decimal, backstopTakeRate: Decimal) -> Decimal {
        BlendLogger.debug("Starting supply APR calculation", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateSupplyAPR", category: BlendLogger.rateCalculation) {
            // Calculate the portion captured by suppliers after backstop take
            let supplyCapture = FixedMath.mulFloor(
                FixedMath.SCALAR_7 - backstopTakeRate,
                curUtil,
                scalar: FixedMath.SCALAR_7
            )
            
            // Calculate supply APR
            let supplyAprFixed = FixedMath.mulFloor(curIr, supplyCapture, scalar: FixedMath.SCALAR_7)
            
            // Convert to float representation
            let result = FixedMath.toFloat(value: supplyAprFixed, decimals: 7)
            
            BlendLogger.rateCalculation(
                operation: "calculateSupplyAPR",
                inputs: [
                    "curIr": curIr,
                    "curUtil": curUtil,
                    "backstopTakeRate": backstopTakeRate,
                    "supplyCapture": supplyCapture,
                    "supplyAprFixed": supplyAprFixed
                ],
                result: result
            )
            
            return result
        }
    }
    
    public func calculateBorrowAPR(curIr: Decimal) -> Decimal {
        BlendLogger.debug("Starting borrow APR calculation", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateBorrowAPR", category: BlendLogger.rateCalculation) {
            // Convert fixed-point interest rate to float
            let result = FixedMath.toFloat(value: curIr, decimals: 7)
            
            BlendLogger.rateCalculation(
                operation: "calculateBorrowAPR",
                inputs: ["curIr": curIr],
                result: result
            )
            
            return result
        }
    }
    
    public func convertAPRtoAPY(_ apr: Decimal, compoundingPeriods: Int) -> Decimal {
        BlendLogger.debug("Converting APR to APY with \(compoundingPeriods) compounding periods", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "convertAPRtoAPY", category: BlendLogger.rateCalculation) {
            // APY = (1 + APR/n)^n - 1, where n is compounding periods
            let aprDouble = NSDecimalNumber(decimal: apr).doubleValue
            let periods = max(1.0, Double(compoundingPeriods)) // Ensure non-zero denominator
            
            let apy = pow(1 + aprDouble / periods, periods) - 1
            let result = Decimal(string: String(format: "%.10f", apy)) ?? Decimal(0)
            
            BlendLogger.rateCalculation(
                operation: "convertAPRtoAPY",
                inputs: [
                    "apr": apr,
                    "compoundingPeriods": compoundingPeriods,
                    "aprDouble": aprDouble,
                    "periods": periods
                ],
                result: result
            )
            
            return result
        }
    }
    
    public func calculateKinkedInterestRate(utilization: Decimal, config: InterestRateConfig) -> Decimal {
        BlendLogger.debug("Calculating kinked interest rate for utilization: \(utilization)", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateKinkedInterestRate", category: BlendLogger.rateCalculation) {
            let baseRate: Decimal
            var slope: String
            
            if utilization <= config.targetUtilization {
                // First slope: 0% to target utilization
                slope = "first"
                let utilizationScalar = utilization / config.targetUtilization
                baseRate = utilizationScalar * config.rOne + config.rBase
                
                BlendLogger.debug("Using first slope (0% to target)", category: BlendLogger.rateCalculation)
                
            } else if utilization <= emergencyUtilizationThreshold {
                // Second slope: target utilization to 95%
                slope = "second"
                // Ensure non-zero denominator
                let denominator = max(0.00001, emergencyUtilizationThreshold - config.targetUtilization)
                let utilizationScalar = (utilization - config.targetUtilization) / denominator
                baseRate = utilizationScalar * config.rTwo + config.rOne + config.rBase
                
                BlendLogger.debug("Using second slope (target to 95%)", category: BlendLogger.rateCalculation)
                
            } else {
                // Third slope: 95% to 100% (emergency rate)
                slope = "third"
                // Ensure non-zero denominator
                let denominator = max(0.00001, 1 - emergencyUtilizationThreshold)
                let utilizationScalar = (utilization - emergencyUtilizationThreshold) / denominator
                let extraRate = utilizationScalar * config.rThree
                
                // Safely apply interest rate modifier using the same approach as other fixes in the project
                let baseRates = config.rTwo + config.rOne + config.rBase
                let modifierDouble = NSDecimalNumber(decimal: config.interestRateModifier).doubleValue
                let baseRatesDouble = NSDecimalNumber(decimal: baseRates).doubleValue
                let intersection = Decimal(modifierDouble * baseRatesDouble / NSDecimalNumber(decimal: FixedMath.SCALAR_7).doubleValue)
                
                let result = extraRate + intersection
                
                BlendLogger.warning("Using emergency third slope (95% to 100%)", category: BlendLogger.rateCalculation)
                BlendLogger.rateCalculation(
                    operation: "calculateKinkedInterestRate",
                    inputs: [
                        "utilization": utilization,
                        "slope": slope,
                        "utilizationScalar": utilizationScalar,
                        "extraRate": extraRate,
                        "intersection": intersection
                    ],
                    result: result
                )
                
                return result
            }
            
            // Apply interest rate modifier for non-emergency rates
            // Safely apply interest rate modifier using the same approach as other fixes in the project
            let baseRateDouble = NSDecimalNumber(decimal: baseRate).doubleValue
            let modifierDouble = NSDecimalNumber(decimal: config.interestRateModifier).doubleValue
            let scalarDouble = NSDecimalNumber(decimal: FixedMath.SCALAR_7).doubleValue
            
            let result = Decimal(baseRateDouble * modifierDouble / scalarDouble)
            
            BlendLogger.rateCalculation(
                operation: "calculateKinkedInterestRate",
                inputs: [
                    "utilization": utilization,
                    "slope": slope,
                    "baseRate": baseRate,
                    "interestRateModifier": config.interestRateModifier
                ],
                result: result
            )
            
            return result
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculate supply APY from supply APR
    public func calculateSupplyAPY(fromAPR apr: Decimal) -> Decimal {
        BlendLogger.debug("Calculating supply APY from APR: \(apr)", category: BlendLogger.rateCalculation)
        return convertAPRtoAPY(apr, compoundingPeriods: supplyCompoundingPeriods)
    }
    
    /// Calculate borrow APY from borrow APR
    public func calculateBorrowAPY(fromAPR apr: Decimal) -> Decimal {
        BlendLogger.debug("Calculating borrow APY from APR: \(apr)", category: BlendLogger.rateCalculation)
        return convertAPRtoAPY(apr, compoundingPeriods: borrowCompoundingPeriods)
    }
    
    // MARK: - APY Calculation from BlendAssetData
    
    /// Calculates APY from BlendAssetData
    /// - Parameter assetData: The blend asset data containing rates
    /// - Returns: Tuple containing (supplyAPY, borrowAPY)
    public func calculateAPY(from assetData: BlendAssetData) -> (supplyAPY: Decimal, borrowAPY: Decimal) {
        let supplyAPY = convertAPRtoAPY(assetData.supplyRate / 100, compoundingPeriods: supplyCompoundingPeriods)
        let borrowAPY = convertAPRtoAPY(assetData.borrowRate / 100, compoundingPeriods: borrowCompoundingPeriods)
        
        return (supplyAPY: supplyAPY * 100, borrowAPY: borrowAPY * 100)
    }
}
