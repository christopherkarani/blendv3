import Foundation

/// Reactive rate modifier for dynamic interest rate adjustments
public struct ReactiveRateModifier {
    
    // MARK: - Constants
    
    /// Minimum rate modifier (10% of base rate)
    public static let minModifier: Decimal = FixedMath.SCALAR_7 / 10
    
    /// Maximum rate modifier (10x base rate)
    public static let maxModifier: Decimal = FixedMath.SCALAR_7 * 10
    
    /// Default rate modifier (100% of base rate)
    public static let defaultModifier: Decimal = FixedMath.SCALAR_7
    
    // MARK: - Properties
    
    /// Current rate modifier value (fixed-point with 7 decimals)
    public let currentModifier: Decimal
    
    /// Last update timestamp
    public let lastUpdateTime: Date
    
    /// Target utilization for the pool
    public let targetUtilization: Decimal
    
    /// Reactivity parameter controlling adjustment speed
    public let reactivity: Decimal
    
    // MARK: - Initialization
    
    public init(
        currentModifier: Decimal = ReactiveRateModifier.defaultModifier,
        lastUpdateTime: Date = Date(),
        targetUtilization: Decimal,
        reactivity: Decimal
    ) {
        self.currentModifier = max(
            ReactiveRateModifier.minModifier,
            min(ReactiveRateModifier.maxModifier, currentModifier)
        )
        self.lastUpdateTime = lastUpdateTime
        self.targetUtilization = targetUtilization
        self.reactivity = reactivity
        
        BlendLogger.debug(
            "ReactiveRateModifier initialized with modifier: \(self.currentModifier), target: \(targetUtilization)",
            category: BlendLogger.rateCalculation
        )
    }
    
    // MARK: - Rate Modifier Calculations
    
    /// Calculate new rate modifier based on current utilization and time elapsed
    /// - Parameters:
    ///   - currentUtilization: Current pool utilization (0-1)
    ///   - currentTime: Current timestamp
    /// - Returns: New ReactiveRateModifier with updated values
    public func calculateNewModifier(
        currentUtilization: Decimal,
        currentTime: Date = Date()
    ) -> ReactiveRateModifier {
        
        let deltaTime = currentTime.timeIntervalSince(lastUpdateTime)
        
        BlendLogger.debug(
            "Calculating rate modifier update - utilization: \(currentUtilization), deltaTime: \(deltaTime)s",
            category: BlendLogger.rateCalculation
        )
        
        // Convert time delta to fixed-point (seconds)
        let deltaTimeFixed = FixedMath.toFixed(value: deltaTime, decimals: 7)
        
        let newModifier: Decimal
        
        if currentUtilization > targetUtilization {
            // Utilization above target - increase modifier
            newModifier = calculateIncreaseModifier(
                currentUtilization: currentUtilization,
                deltaTime: deltaTimeFixed
            )
            
            BlendLogger.info(
                "Utilization above target (\(currentUtilization) > \(targetUtilization)), increasing modifier",
                category: BlendLogger.rateCalculation
            )
            
        } else if currentUtilization < targetUtilization {
            // Utilization below target - decrease modifier
            newModifier = calculateDecreaseModifier(
                currentUtilization: currentUtilization,
                deltaTime: deltaTimeFixed
            )
            
            BlendLogger.info(
                "Utilization below target (\(currentUtilization) < \(targetUtilization)), decreasing modifier",
                category: BlendLogger.rateCalculation
            )
            
        } else {
            // Utilization at target - no change
            newModifier = currentModifier
            
            BlendLogger.debug(
                "Utilization at target, maintaining current modifier",
                category: BlendLogger.rateCalculation
            )
        }
        
        let boundedModifier = max(
            ReactiveRateModifier.minModifier,
            min(ReactiveRateModifier.maxModifier, newModifier)
        )
        
        BlendLogger.rateCalculation(
            operation: "calculateNewModifier",
            inputs: [
                "currentUtilization": currentUtilization,
                "targetUtilization": targetUtilization,
                "deltaTime": deltaTime,
                "oldModifier": currentModifier,
                "unboundedNewModifier": newModifier
            ],
            result: boundedModifier
        )
        
        return ReactiveRateModifier(
            currentModifier: boundedModifier,
            lastUpdateTime: currentTime,
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateIncreaseModifier(
        currentUtilization: Decimal,
        deltaTime: Decimal
    ) -> Decimal {
        
        // Calculate utilization excess as a ratio
        let utilizationExcess = currentUtilization - targetUtilization
        let maxExcess = FixedMath.SCALAR_7 - targetUtilization
        
        let excessRatio = FixedMath.divCeil(
            utilizationExcess,
            maxExcess,
            scalar: FixedMath.SCALAR_7
        )
        
        // Calculate modifier delta based on reactivity and time
        let modifierDelta = FixedMath.mulCeil(
            FixedMath.mulCeil(
                excessRatio,
                reactivity,
                scalar: FixedMath.SCALAR_7
            ),
            deltaTime,
            scalar: FixedMath.SCALAR_7
        )
        
        let newModifier = currentModifier + modifierDelta
        
        BlendLogger.debug(
            "Increase calculation - excess: \(utilizationExcess), ratio: \(excessRatio), delta: \(modifierDelta)",
            category: BlendLogger.rateCalculation
        )
        
        return newModifier
    }
    
    private func calculateDecreaseModifier(
        currentUtilization: Decimal,
        deltaTime: Decimal
    ) -> Decimal {
        
        // Calculate utilization deficit as a ratio
        let utilizationDeficit = targetUtilization - currentUtilization
        let deficitRatio = FixedMath.divCeil(
            utilizationDeficit,
            targetUtilization,
            scalar: FixedMath.SCALAR_7
        )
        
        // Calculate modifier delta based on reactivity and time
        let modifierDelta = FixedMath.mulCeil(
            FixedMath.mulCeil(
                deficitRatio,
                reactivity,
                scalar: FixedMath.SCALAR_7
            ),
            deltaTime,
            scalar: FixedMath.SCALAR_7
        )
        
        let newModifier = max(
            ReactiveRateModifier.minModifier,
            currentModifier - modifierDelta
        )
        
        BlendLogger.debug(
            "Decrease calculation - deficit: \(utilizationDeficit), ratio: \(deficitRatio), delta: \(modifierDelta)",
            category: BlendLogger.rateCalculation
        )
        
        return newModifier
    }
    
    // MARK: - Utility Methods
    
    /// Get the modifier as a floating-point multiplier
    public var modifierAsFloat: Double {
        return NSDecimalNumber(decimal: FixedMath.toFloat(value: currentModifier, decimals: 7)).doubleValue
    }
    
    /// Check if the modifier is at its bounds
    public var isAtMinimum: Bool {
        return currentModifier <= ReactiveRateModifier.minModifier
    }
    
    public var isAtMaximum: Bool {
        return currentModifier >= ReactiveRateModifier.maxModifier
    }
    
    /// Get time since last update in seconds
    public var timeSinceLastUpdate: TimeInterval {
        return Date().timeIntervalSince(lastUpdateTime)
    }
}

// MARK: - Codable Conformance

extension ReactiveRateModifier: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case currentModifier
        case lastUpdateTime
        case targetUtilization
        case reactivity
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let currentModifier = try container.decode(Decimal.self, forKey: .currentModifier)
        let lastUpdateTime = try container.decode(Date.self, forKey: .lastUpdateTime)
        let targetUtilization = try container.decode(Decimal.self, forKey: .targetUtilization)
        let reactivity = try container.decode(Decimal.self, forKey: .reactivity)
        
        self.init(
            currentModifier: currentModifier,
            lastUpdateTime: lastUpdateTime,
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(currentModifier, forKey: .currentModifier)
        try container.encode(lastUpdateTime, forKey: .lastUpdateTime)
        try container.encode(targetUtilization, forKey: .targetUtilization)
        try container.encode(reactivity, forKey: .reactivity)
    }
}

// MARK: - Equatable Conformance

extension ReactiveRateModifier: Equatable {
    public static func == (lhs: ReactiveRateModifier, rhs: ReactiveRateModifier) -> Bool {
        return lhs.currentModifier == rhs.currentModifier &&
               lhs.lastUpdateTime == rhs.lastUpdateTime &&
               lhs.targetUtilization == rhs.targetUtilization &&
               lhs.reactivity == rhs.reactivity
    }
} 