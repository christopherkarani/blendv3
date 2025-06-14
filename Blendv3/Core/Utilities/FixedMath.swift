import Foundation

/// Fixed-point arithmetic utilities for precise financial calculations
/// Uses 7 decimal places for Blend Protocol compatibility
public enum FixedMath {
    
    // MARK: - Constants
    
    /// Scale factor for 7 decimal places (10^7)
    public static let SCALAR_7: Decimal = 10_000_000
    
    /// Scale factor for 9 decimal places (10^9)
    public static let SCALAR_9: Decimal = 1_000_000_000
    
    /// Scale factor for 12 decimal places (10^12)
    public static let SCALAR_12: Decimal = 1_000_000_000_000
    
    // MARK: - Multiplication
    
    /// Multiply two fixed-point numbers with ceiling rounding
    /// - Parameters:
    ///   - a: First operand
    ///   - b: Second operand
    ///   - scalar: Scale factor
    /// - Returns: Result with ceiling rounding
    public static func mulCeil(_ a: Decimal, _ b: Decimal, scalar: Decimal) -> Decimal {
        var result = (a * b + scalar - 1) / scalar
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 0, .up)
        return rounded
    }
    
    /// Multiply two fixed-point numbers with floor rounding
    /// - Parameters:
    ///   - a: First operand
    ///   - b: Second operand
    ///   - scalar: Scale factor
    /// - Returns: Result with floor rounding
    public static func mulFloor(_ a: Decimal, _ b: Decimal, scalar: Decimal) -> Decimal {
        var result = (a * b) / scalar
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 0, .down)
        return rounded
    }
    
    // MARK: - Division
    
    /// Divide two fixed-point numbers with ceiling rounding
    /// - Parameters:
    ///   - a: Numerator
    ///   - b: Denominator
    ///   - scalar: Scale factor
    /// - Returns: Result with ceiling rounding
    public static func divCeil(_ a: Decimal, _ b: Decimal, scalar: Decimal) -> Decimal {
        guard b != 0 else { return Decimal.zero }
        var result = (a * scalar + b - 1) / b
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 0, .up)
        return rounded
    }
    
    // MARK: - Conversion
    
    /// Convert floating-point value to fixed-point representation
    /// - Parameters:
    ///   - value: Floating-point value
    ///   - decimals: Number of decimal places
    /// - Returns: Fixed-point representation
    public static func toFixed(value: Double, decimals: Int) -> Decimal {
        let scalar = pow(10.0, Double(decimals))
        return Decimal(value * scalar)
    }
    
    /// Convert fixed-point value to floating-point representation
    /// - Parameters:
    ///   - value: Fixed-point value
    ///   - decimals: Number of decimal places
    /// - Returns: Floating-point representation
    public static func toFloat(value: Decimal, decimals: Int) -> Decimal {
        let scalar = Decimal(pow(10.0, Double(decimals)))
        return value / scalar
    }
} 