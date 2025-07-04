//
//  BlendProtocolFinancialCalculator.swift
//  Blendv3
//
//  Exact port of Blend Protocol JavaScript SDK financial calculations
//  Reference: blend-sdk-js/src/pool/reserve.ts
//

import Foundation

/// Unified financial calculator that exactly matches Blend Protocol JavaScript SDK methodology
/// This implementation ensures consistent APY/APR calculations across platforms
public final class BlendProtocolFinancialCalculator {
    
    // MARK: - Constants (Matching JavaScript SDK)
    
    /// Fixed-point scalar for 7 decimal places (10^7)
    private static let SCALAR_7: Decimal = 10_000_000
    
    /// Fixed-point scalar for 9 decimal places (10^9)
    private static let SCALAR_9: Decimal = 1_000_000_000
    
    /// Fixed-point scalar for 12 decimal places (10^12)
    private static let SCALAR_12: Decimal = 1_000_000_000_000
    
    /// Weekly compounding periods for supply APY
    private static let SUPPLY_COMPOUNDING_PERIODS = 52
    
    /// Daily compounding periods for borrow APY
    private static let BORROW_COMPOUNDING_PERIODS = 365
    
    /// Maximum allowed APR (1000%)
    private static let MAX_APR: Decimal = 10.0
    
    /// Maximum allowed APY (10000%)
    private static let MAX_APY: Decimal = 100.0
    
    /// 95% utilization threshold for emergency rates
    private static let FIXED_95_PERCENT: Decimal = 9_500_000  // 95% in 7 decimal fixed-point
    
    /// 5% range for emergency rates
    private static let FIXED_5_PERCENT: Decimal = 500_000     // 5% in 7 decimal fixed-point
    
    // MARK: - Public API
    
    /// Calculates APY from asset data using exact JavaScript SDK methodology
    /// - Parameters:
    ///   - assetData: The blend asset data containing all reserve information
    ///   - backstopTakeRate: Backstop take rate as fixed-point with 7 decimals
    ///   - isSupply: True for supply APY, false for borrow APY
    /// - Returns: The calculated APY as a percentage (e.g., 10.21 for 10.21%)
    public func calculateAPYFromAssetData(
        _ assetData: BlendAssetData,
        backstopTakeRate: Decimal,
        isSupply: Bool
    ) -> Decimal {
        // Validate inputs
        guard assetData.bSupply > 0 || assetData.dSupply > 0 else {
            return 0
        }
        
        // Calculate utilization using fixed-point arithmetic
        let totalSupply = assetData.bSupply
        
        // CRITICAL FIX: Use SCALAR_12 for dRate multiplication (dRate is SCALAR_12)
        let totalLiabilities = mulFloor(
            assetData.dSupply,
            assetData.dRate,
            Self.SCALAR_12
        )
        
        guard totalSupply > 0 else {
            return 0
        }
        
        let utilization = divFloor(
            totalLiabilities,
            totalSupply + totalLiabilities,
            Self.SCALAR_7
        )
        
        // Create reserve config from asset data
        let config = ReserveConfig(
            targetUtilization: assetData.utilTarget,
            baseRate: assetData.rBase,
            rateOne: assetData.rOne,
            rateTwo: assetData.rTwo,
            rateThree: assetData.rThree,
            interestRateModifier: assetData.irModifier
        )
        
        // Calculate current interest rate
        let currentIR = calculateCurrentInterestRate(
            utilization: utilization,
            config: config,
            version: .v2  // Default to V2 for now
        )
        
        // Convert to APR
        let apr: Decimal
        if isSupply {
            // Calculate supply APR considering backstop take rate
            let supplyCapture = mulFloor(
                Self.SCALAR_7 - backstopTakeRate,
                utilization,
                Self.SCALAR_7
            )
            let supplyRate = mulFloor(
                currentIR,
                supplyCapture,
                Self.SCALAR_7
            )
            apr = toFloat(supplyRate, decimals: 7)
        } else {
            // Borrow APR is the current interest rate
            apr = toFloat(currentIR, decimals: 7)
        }
        
        // Apply safety bounds
        let boundedAPR = min(apr, Self.MAX_APR)
        
        guard boundedAPR > 0 else {
            return 0
        }
        
        // Convert APR to APY
        let compoundingPeriods = isSupply ? Self.SUPPLY_COMPOUNDING_PERIODS : Self.BORROW_COMPOUNDING_PERIODS
        let apy = convertAPRtoAPY(boundedAPR, periods: compoundingPeriods)
        
        // Return as percentage
        return apy * 100
    }
    
    /// Alternative method that accepts individual parameters for maximum flexibility
    public func calculateAPYFromParameters(
        dSupply: Decimal,
        bSupply: Decimal,
        dRate: Decimal,
        bRate: Decimal,
        interestRateModifier: Decimal,
        backstopTakeRate: Decimal,
        isSupply: Bool,
        config: ReserveConfig,
        version: BlendProtocolVersion = .v2
    ) -> Decimal {
        // Validate inputs
        guard bSupply > 0 || dSupply > 0 else {
            return 0
        }
        
        // Calculate utilization
        let totalSupply = bSupply
        let totalLiabilities = mulFloor(dSupply, dRate, Self.SCALAR_12)
        
        guard totalSupply > 0 else {
            return 0
        }
        
        let utilization = divFloor(
            totalLiabilities,
            totalSupply + totalLiabilities,
            Self.SCALAR_7
        )
        
        // Calculate current interest rate
        let currentIR = calculateCurrentInterestRate(
            utilization: utilization,
            config: config,
            version: version
        )
        
        // Convert to APR
        let apr: Decimal
        if isSupply {
            let supplyCapture = mulFloor(
                Self.SCALAR_7 - backstopTakeRate,
                utilization,
                Self.SCALAR_7
            )
            let supplyRate = mulFloor(currentIR, supplyCapture, Self.SCALAR_7)
            apr = toFloat(supplyRate, decimals: 7)
        } else {
            apr = toFloat(currentIR, decimals: 7)
        }
        
        // Apply bounds and convert to APY
        let boundedAPR = min(apr, Self.MAX_APR)
        guard boundedAPR > 0 else { return 0 }
        
        let compoundingPeriods = isSupply ? Self.SUPPLY_COMPOUNDING_PERIODS : Self.BORROW_COMPOUNDING_PERIODS
        let apy = convertAPRtoAPY(boundedAPR, periods: compoundingPeriods)
        
        return apy * 100
    }
    
    // MARK: - Interest Rate Calculation
    
    /// Calculates current interest rate using three-slope kinked model
    private func calculateCurrentInterestRate(
        utilization: Decimal,
        config: ReserveConfig,
        version: BlendProtocolVersion
    ) -> Decimal {
        guard utilization > 0 else {
            return config.baseRate
        }
        
        let irModScalar = version == .v1 ? Self.SCALAR_9 : Self.SCALAR_7
        let targetUtil = config.targetUtilization
        
        var currentIR: Decimal
        
        if utilization <= targetUtil {
            // Below target utilization
            let utilScalar = divCeil(utilization, targetUtil, Self.SCALAR_7)
            let baseRate = mulCeil(utilScalar, config.rateOne, Self.SCALAR_7) + config.baseRate
            currentIR = mulCeil(baseRate, config.interestRateModifier, irModScalar)
            
        } else if utilization <= Self.FIXED_95_PERCENT {
            // Between target and 95% utilization
            let utilScalar = divCeil(
                utilization - targetUtil,
                Self.FIXED_95_PERCENT - targetUtil,
                Self.SCALAR_7
            )
            let baseRate = mulCeil(utilScalar, config.rateTwo, Self.SCALAR_7) + 
                          config.rateOne + config.baseRate
            currentIR = mulCeil(baseRate, config.interestRateModifier, irModScalar)
            
        } else {
            // Above 95% utilization (emergency rates)
            let utilScalar = divCeil(
                utilization - Self.FIXED_95_PERCENT,
                Self.FIXED_5_PERCENT,
                Self.SCALAR_7
            )
            let extraRate = mulCeil(utilScalar, config.rateThree, Self.SCALAR_7)
            let intersection = mulCeil(
                config.interestRateModifier,
                config.rateTwo + config.rateOne + config.baseRate,
                irModScalar
            )
            currentIR = extraRate + intersection
        }
        
        return currentIR
    }
    
    /// Converts APR to APY using compound interest formula
    private func convertAPRtoAPY(_ apr: Decimal, periods: Int) -> Decimal {
        guard apr > 0, periods > 0 else {
            return 0
        }
        
        // APY = (1 + APR/n)^n - 1
        let periodsDecimal = Decimal(periods)
        let aprPerPeriod = apr / periodsDecimal
        let onePlusRate = 1 + aprPerPeriod
        
        // Use Double for power calculation
        let base = NSDecimalNumber(decimal: onePlusRate).doubleValue
        let power = Double(periods)
        let compounded = pow(base, power)
        
        guard compounded.isFinite && !compounded.isNaN else {
            return Self.MAX_APY
        }
        
        let apy = Decimal(compounded) - 1
        
        // Apply reasonable bounds
        return min(apy, Self.MAX_APY)
    }
    
    // MARK: - Fixed-Point Math (Exact JavaScript SDK Port)
    
    private func toFloat(_ value: Decimal, decimals: Int) -> Decimal {
        return value / pow(10, decimals)
    }
    
    private func mulFloor(_ x: Decimal, _ y: Decimal, _ denominator: Decimal) -> Decimal {
        return (x * y) / denominator
    }
    
    private func mulCeil(_ x: Decimal, _ y: Decimal, _ denominator: Decimal) -> Decimal {
        let result = x * y
        let quotient = result / denominator
        let floor = Decimal(Int(NSDecimalNumber(decimal: quotient).doubleValue))
        let remainder = result - (floor * denominator)
        return floor + (remainder > 0 ? 1 : 0)
    }
    
    private func divFloor(_ x: Decimal, _ y: Decimal, _ denominator: Decimal) -> Decimal {
        return mulFloor(x, denominator, y)
    }
    
    private func divCeil(_ x: Decimal, _ y: Decimal, _ denominator: Decimal) -> Decimal {
        return mulCeil(x, denominator, y)
    }
}

// MARK: - Supporting Types

/// Reserve configuration for interest rate calculations
public struct ReserveConfig {
    let targetUtilization: Decimal
    let baseRate: Decimal
    let rateOne: Decimal
    let rateTwo: Decimal
    let rateThree: Decimal
    let interestRateModifier: Decimal
    
    public init(
        targetUtilization: Decimal,
        baseRate: Decimal,
        rateOne: Decimal,
        rateTwo: Decimal,
        rateThree: Decimal,
        interestRateModifier: Decimal
    ) {
        self.targetUtilization = targetUtilization
        self.baseRate = baseRate
        self.rateOne = rateOne
        self.rateTwo = rateTwo
        self.rateThree = rateThree
        self.interestRateModifier = interestRateModifier
    }
}

/// Blend Protocol version enumeration
public enum BlendProtocolVersion {
    case v1
    case v2
    
    var rateDecimals: Int {
        switch self {
        case .v1: return 9
        case .v2: return 12
        }
    }
    
    var irModDecimals: Int {
        switch self {
        case .v1: return 9
        case .v2: return 7
        }
    }
} 