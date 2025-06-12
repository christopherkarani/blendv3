import Foundation

/// Enhanced Blend Protocol rate calculator with reactive rate modifier
public final class EnhancedBlendRateCalculator: BlendRateCalculatorProtocol {
    
    // MARK: - Constants
    
    /// Number of compounding periods per year for supply APY (weekly)
    private let supplyCompoundingPeriods = 52
    
    /// Number of compounding periods per year for borrow APY (daily)
    private let borrowCompoundingPeriods = 365
    
    /// Emergency utilization threshold (95%)
    private let emergencyUtilizationThreshold: Decimal = 0.95
    
    /// Maximum allowed interest rate (1000% APR)
    private let maxInterestRate: Decimal = FixedMath.toFixed(value: 10.0, decimals: 7)
    
    // MARK: - Properties
    
    private var rateModifierCache: [String: ReactiveRateModifier] = [:]
    private let cacheQueue = DispatchQueue(label: "com.blend.rateModifierCache", attributes: .concurrent)
    
    // MARK: - Initialization
    
    public init() {
        BlendLogger.info("Enhanced rate calculator initialized", category: BlendLogger.rateCalculation)
    }
    
    // MARK: - BlendRateCalculatorProtocol
    
    public func calculateSupplyAPR(curIr: Decimal, curUtil: Decimal, backstopTakeRate: Decimal) -> Decimal {
        BlendLogger.debug("Starting enhanced supply APR calculation", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateSupplyAPR", category: BlendLogger.rateCalculation) {
            // Validate inputs
            guard validateInputs(curIr: curIr, curUtil: curUtil, backstopTakeRate: backstopTakeRate) else {
                BlendLogger.error("Invalid inputs for supply APR calculation", category: BlendLogger.rateCalculation)
                return 0
            }
            
            // Calculate the portion captured by suppliers after backstop take
            let supplyCapture = FixedMath.mulFloor(
                FixedMath.SCALAR_7 - backstopTakeRate,
                curUtil,
                scalar: FixedMath.SCALAR_7
            )
            
            // Calculate supply APR
            let supplyAprFixed = FixedMath.mulFloor(curIr, supplyCapture, scalar: FixedMath.SCALAR_7)
            
            // Apply safety bounds
            let boundedSupplyApr = min(supplyAprFixed, maxInterestRate)
            
            // Convert to float representation
            let result = FixedMath.toFloat(value: boundedSupplyApr, decimals: 7)
            
            BlendLogger.rateCalculation(
                operation: "calculateSupplyAPR",
                inputs: [
                    "curIr": curIr,
                    "curUtil": curUtil,
                    "backstopTakeRate": backstopTakeRate,
                    "supplyCapture": supplyCapture,
                    "supplyAprFixed": supplyAprFixed,
                    "boundedSupplyApr": boundedSupplyApr
                ],
                result: result
            )
            
            return result
        }
    }
    
    public func calculateBorrowAPR(curIr: Decimal) -> Decimal {
        BlendLogger.debug("Starting enhanced borrow APR calculation", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateBorrowAPR", category: BlendLogger.rateCalculation) {
            // Validate input
            guard curIr >= 0 else {
                BlendLogger.error("Invalid negative interest rate: \(curIr)", category: BlendLogger.rateCalculation)
                return 0
            }
            
            // Apply safety bounds
            let boundedIr = min(curIr, maxInterestRate)
            
            // Convert fixed-point interest rate to float
            let result = FixedMath.toFloat(value: boundedIr, decimals: 7)
            
            BlendLogger.rateCalculation(
                operation: "calculateBorrowAPR",
                inputs: ["curIr": curIr, "boundedIr": boundedIr],
                result: result
            )
            
            return result
        }
    }
    
    public func convertAPRtoAPY(_ apr: Decimal, compoundingPeriods: Int) -> Decimal {
        BlendLogger.debug("Converting APR to APY with \(compoundingPeriods) compounding periods", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "convertAPRtoAPY", category: BlendLogger.rateCalculation) {
            // Validate inputs
            guard apr >= 0 && compoundingPeriods > 0 else {
                BlendLogger.error("Invalid APR (\(apr)) or compounding periods (\(compoundingPeriods))", category: BlendLogger.rateCalculation)
                return 0
            }
            
            // APY = (1 + APR/n)^n - 1, where n is compounding periods
            let aprDouble = NSDecimalNumber(decimal: apr).doubleValue
            let periods = Double(compoundingPeriods)
            
            // Handle edge cases
            if aprDouble == 0 {
                return 0
            }
            
            if aprDouble > 10 { // 1000% APR cap
                BlendLogger.warning("Extremely high APR detected: \(aprDouble), capping at 1000%", category: BlendLogger.rateCalculation)
                let cappedApy = pow(1 + 10.0 / periods, periods) - 1
                return Decimal(cappedApy)
            }
            
            let apy = pow(1 + aprDouble / periods, periods) - 1
            let result = Decimal(apy)
            
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
        BlendLogger.debug("Calculating enhanced kinked interest rate for utilization: \(utilization)", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateKinkedInterestRate", category: BlendLogger.rateCalculation) {
            // Validate inputs
            guard validateKinkedRateInputs(utilization: utilization, config: config) else {
                BlendLogger.error("Invalid inputs for kinked interest rate calculation", category: BlendLogger.rateCalculation)
                return 0
            }
            
            let baseRate: Decimal
            var slope: String
            var slopeNumber: Int
            
            if utilization <= config.targetUtilization {
                // First slope: 0% to target utilization
                slope = "first"
                slopeNumber = 1
                let utilizationScalar = utilization / config.targetUtilization
                baseRate = utilizationScalar * config.rOne + config.rBase
                
                BlendLogger.debug("Using first slope (0% to target)", category: BlendLogger.rateCalculation)
                
            } else if utilization <= emergencyUtilizationThreshold {
                // Second slope: target utilization to 95%
                slope = "second"
                slopeNumber = 2
                let utilizationScalar = (utilization - config.targetUtilization) / 
                                       (emergencyUtilizationThreshold - config.targetUtilization)
                baseRate = utilizationScalar * config.rTwo + config.rOne + config.rBase
                
                BlendLogger.debug("Using second slope (target to 95%)", category: BlendLogger.rateCalculation)
                
            } else {
                // Third slope: 95% to 100% (emergency rate)
                slope = "third"
                slopeNumber = 3
                let utilizationScalar = (utilization - emergencyUtilizationThreshold) / 
                                       (1 - emergencyUtilizationThreshold)
                let extraRate = utilizationScalar * config.rThree
                let intersection = config.interestRateModifier * (config.rTwo + config.rOne + config.rBase)
                let result = extraRate + intersection
                
                BlendLogger.warning("Using emergency third slope (95% to 100%)", category: BlendLogger.rateCalculation)
                BlendLogger.rateCalculation(
                    operation: "calculateKinkedInterestRate",
                    inputs: [
                        "utilization": utilization,
                        "slope": slope,
                        "slopeNumber": slopeNumber,
                        "utilizationScalar": utilizationScalar,
                        "extraRate": extraRate,
                        "intersection": intersection
                    ],
                    result: min(result, maxInterestRate)
                )
                
                return min(result, maxInterestRate)
            }
            
            // Apply interest rate modifier for non-emergency rates
            let result = baseRate * config.interestRateModifier / FixedMath.SCALAR_7
            let boundedResult = min(result, maxInterestRate)
            
            BlendLogger.rateCalculation(
                operation: "calculateKinkedInterestRate",
                inputs: [
                    "utilization": utilization,
                    "slope": slope,
                    "slopeNumber": slopeNumber,
                    "baseRate": baseRate,
                    "interestRateModifier": config.interestRateModifier,
                    "unboundedResult": result
                ],
                result: boundedResult
            )
            
            return boundedResult
        }
    }
    
    // MARK: - Enhanced Methods with Reactive Rate Modifier
    
    /// Calculate interest rate with reactive rate modifier
    /// - Parameters:
    ///   - utilization: Current pool utilization
    ///   - config: Interest rate configuration
    ///   - poolId: Pool identifier for caching rate modifier
    /// - Returns: Interest rate adjusted by reactive modifier
    public func calculateReactiveInterestRate(
        utilization: Decimal,
        config: InterestRateConfig,
        poolId: String
    ) -> Decimal {
        
        BlendLogger.info("Calculating reactive interest rate for pool: \(poolId)", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateReactiveInterestRate", category: BlendLogger.rateCalculation) {
            // Get or create rate modifier
            let rateModifier = getRateModifier(for: poolId, config: config)
            
            // Update rate modifier based on current utilization
            let updatedModifier = rateModifier.calculateNewModifier(currentUtilization: utilization)
            
            // Cache the updated modifier
            setRateModifier(updatedModifier, for: poolId)
            
            // Calculate base interest rate
            let baseConfig = InterestRateConfig(
                targetUtilization: config.targetUtilization,
                rBase: config.rBase,
                rOne: config.rOne,
                rTwo: config.rTwo,
                rThree: config.rThree,
                reactivity: config.reactivity,
                interestRateModifier: updatedModifier.currentModifier
            )
            
            let reactiveRate = calculateKinkedInterestRate(utilization: utilization, config: baseConfig)
            
            BlendLogger.rateCalculation(
                operation: "calculateReactiveInterestRate",
                inputs: [
                    "poolId": poolId,
                    "utilization": utilization,
                    "oldModifier": rateModifier.currentModifier,
                    "newModifier": updatedModifier.currentModifier,
                    "timeDelta": updatedModifier.timeSinceLastUpdate
                ],
                result: reactiveRate
            )
            
            return reactiveRate
        }
    }
    
    /// Validate three-slope model parameters
    /// - Parameter config: Interest rate configuration to validate
    /// - Returns: Validation result with detailed feedback
    public func validateThreeSlopeModel(_ config: InterestRateConfig) -> ThreeSlopeValidationResult {
        BlendLogger.info("Validating three-slope model configuration", category: BlendLogger.rateCalculation)
        
        var issues: [String] = []
        var warnings: [String] = []
        
        // Validate target utilization
        if config.targetUtilization <= 0 || config.targetUtilization >= 1 {
            issues.append("Target utilization must be between 0 and 1, got: \(config.targetUtilization)")
        }
        
        if config.targetUtilization > 0.9 {
            warnings.append("Target utilization above 90% may cause frequent emergency rate activation")
        }
        
        // Validate rate parameters
        if config.rBase < 0 {
            issues.append("Base rate (rBase) cannot be negative: \(config.rBase)")
        }
        
        if config.rOne < 0 {
            issues.append("First slope rate (rOne) cannot be negative: \(config.rOne)")
        }
        
        if config.rTwo < 0 {
            issues.append("Second slope rate (rTwo) cannot be negative: \(config.rTwo)")
        }
        
        if config.rThree < 0 {
            issues.append("Third slope rate (rThree) cannot be negative: \(config.rThree)")
        }
        
        // Validate rate progression
        if config.rOne < config.rBase {
            warnings.append("First slope rate is lower than base rate - unusual configuration")
        }
        
        if config.rTwo < config.rOne {
            warnings.append("Second slope rate is lower than first slope rate - unusual configuration")
        }
        
        // Validate reactivity
        if config.reactivity <= 0 {
            issues.append("Reactivity must be positive: \(config.reactivity)")
        }
        
        if config.reactivity > FixedMath.SCALAR_7 {
            warnings.append("High reactivity may cause rate instability")
        }
        
        // Validate interest rate modifier
        if config.interestRateModifier <= 0 {
            issues.append("Interest rate modifier must be positive: \(config.interestRateModifier)")
        }
        
        let isValid = issues.isEmpty
        let result = ThreeSlopeValidationResult(
            isValid: isValid,
            issues: issues,
            warnings: warnings,
            config: config
        )
        
        BlendLogger.rateCalculation(
            operation: "validateThreeSlopeModel",
            inputs: [
                "targetUtilization": config.targetUtilization,
                "rBase": config.rBase,
                "rOne": config.rOne,
                "rTwo": config.rTwo,
                "rThree": config.rThree,
                "reactivity": config.reactivity,
                "interestRateModifier": config.interestRateModifier
            ],
            result: "Valid: \(isValid), Issues: \(issues.count), Warnings: \(warnings.count)"
        )
        
        return result
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
    
    // MARK: - Private Methods
    
    private func validateInputs(curIr: Decimal, curUtil: Decimal, backstopTakeRate: Decimal) -> Bool {
        guard curIr >= 0 else {
            BlendLogger.error("Current interest rate cannot be negative: \(curIr)", category: BlendLogger.rateCalculation)
            return false
        }
        
        guard curUtil >= 0 && curUtil <= FixedMath.SCALAR_7 else {
            BlendLogger.error("Current utilization must be between 0 and SCALAR_7: \(curUtil)", category: BlendLogger.rateCalculation)
            return false
        }
        
        guard backstopTakeRate >= 0 && backstopTakeRate <= FixedMath.SCALAR_7 else {
            BlendLogger.error("Backstop take rate must be between 0 and SCALAR_7: \(backstopTakeRate)", category: BlendLogger.rateCalculation)
            return false
        }
        
        return true
    }
    
    private func validateKinkedRateInputs(utilization: Decimal, config: InterestRateConfig) -> Bool {
        guard utilization >= 0 && utilization <= FixedMath.SCALAR_7 else {
            BlendLogger.error("Utilization must be between 0 and SCALAR_7: \(utilization)", category: BlendLogger.rateCalculation)
            return false
        }
        
        guard config.targetUtilization > 0 && config.targetUtilization < FixedMath.SCALAR_7 else {
            BlendLogger.error("Target utilization must be between 0 and SCALAR_7: \(config.targetUtilization)", category: BlendLogger.rateCalculation)
            return false
        }
        
        return true
    }
    
    private func getRateModifier(for poolId: String, config: InterestRateConfig) -> ReactiveRateModifier {
        return cacheQueue.sync {
            if let cached = rateModifierCache[poolId] {
                return cached
            } else {
                let newModifier = ReactiveRateModifier(
                    targetUtilization: config.targetUtilization,
                    reactivity: config.reactivity
                )
                rateModifierCache[poolId] = newModifier
                BlendLogger.debug("Created new rate modifier for pool: \(poolId)", category: BlendLogger.rateCalculation)
                return newModifier
            }
        }
    }
    
    private func setRateModifier(_ modifier: ReactiveRateModifier, for poolId: String) {
        cacheQueue.async(flags: .barrier) {
            self.rateModifierCache[poolId] = modifier
            BlendLogger.debug("Updated rate modifier for pool: \(poolId)", category: BlendLogger.rateCalculation)
        }
    }
}

// MARK: - Supporting Types

/// Three-slope model validation result
public struct ThreeSlopeValidationResult {
    public let isValid: Bool
    public let issues: [String]
    public let warnings: [String]
    public let config: InterestRateConfig
    
    /// Get a formatted validation report
    public var report: String {
        var lines: [String] = []
        
        lines.append("Three-Slope Model Validation Report")
        lines.append("===================================")
        lines.append("Status: \(isValid ? "✅ VALID" : "❌ INVALID")")
        lines.append("")
        
        if !issues.isEmpty {
            lines.append("Issues:")
            for issue in issues {
                lines.append("  • \(issue)")
            }
            lines.append("")
        }
        
        if !warnings.isEmpty {
            lines.append("Warnings:")
            for warning in warnings {
                lines.append("  ⚠️ \(warning)")
            }
            lines.append("")
        }
        
        lines.append("Configuration:")
        lines.append("  Target Utilization: \(config.targetUtilization)")
        lines.append("  Base Rate: \(config.rBase)")
        lines.append("  First Slope: \(config.rOne)")
        lines.append("  Second Slope: \(config.rTwo)")
        lines.append("  Third Slope: \(config.rThree)")
        lines.append("  Reactivity: \(config.reactivity)")
        lines.append("  Rate Modifier: \(config.interestRateModifier)")
        
        return lines.joined(separator: "\n")
    }
} 