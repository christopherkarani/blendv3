//import Foundation
//
//// MARK: - Protocol Definitions
//
///// Protocol defining the core financial calculation capabilities
//protocol FinancialCalculator {
//    /// Calculates APY from asset data
//    /// - Parameters:
//    ///   - assetData: Asset reserve data
//    ///   - backstopTakeRate: Backstop take rate as a fixed-point decimal
//    ///   - isSupply: True for supply APY, false for borrow APY
//    /// - Returns: The calculated APY as a Decimal
//    func calculateAPY(from assetData: ReserveData, backstopTakeRate: Decimal, isSupply: Bool) -> Decimal
//    
//    /// Converts APR to APY
//    /// - Parameters:
//    ///   - apr: Annual Percentage Rate
//    ///   - periods: Number of compounding periods per year
//    /// - Returns: Annual Percentage Yield
//    func convertAPRtoAPY(_ apr: Decimal, periods: Int) -> Decimal
//    
//    /// Calculates current interest rate based on utilization
//    /// - Parameters:
//    ///   - utilization: Current utilization rate
//    ///   - assetData: Asset reserve data
//    ///   - config: Reserve configuration
//    /// - Returns: The calculated interest rate
//    func calculateCurrentInterestRate(utilization: Decimal, assetData: ReserveData, config: ReserveConfig) -> Decimal
//}
//
//// MARK: - Data Structures
//
///// Reserve configuration data
//struct ReserveConfig {
//    let index: Int
//    let decimals: Int
//    let collateralFactor: Decimal // c_factor
//    let liabilityFactor: Decimal  // l_factor
//    let targetUtilization: Decimal // util
//    let maxUtilization: Decimal   // max_util
//    let baseRate: Decimal         // r_base
//    let rateOne: Decimal          // r_one
//    let rateTwo: Decimal          // r_two
//    let rateThree: Decimal        // r_three
//    let reactivity: Decimal
//    
//    // Optional V2 fields
//    let supplyCap: Decimal?
//    let isEnabled: Bool?
//    
//    // Converts from the JavaScript ReserveConfig
//    static func fromJSConfig(
//        index: Int,
//        decimals: Int,
//        cFactor: Decimal,
//        lFactor: Decimal,
//        util: Decimal,
//        maxUtil: Decimal,
//        rBase: Decimal,
//        rOne: Decimal,
//        rTwo: Decimal,
//        rThree: Decimal,
//        reactivity: Decimal,
//        supplyCap: Decimal? = nil,
//        enabled: Bool? = nil
//    ) -> ReserveConfig {
//        return ReserveConfig(
//            index: index,
//            decimals: decimals,
//            collateralFactor: cFactor,
//            liabilityFactor: lFactor,
//            targetUtilization: util,
//            maxUtilization: maxUtil,
//            baseRate: rBase,
//            rateOne: rOne,
//            rateTwo: rTwo,
//            rateThree: rThree,
//            reactivity: reactivity,
//            supplyCap: supplyCap,
//            isEnabled: enabled
//        )
//    }
//}
//
///// Reserve data containing current state of a reserve
//struct ReserveData {
//    let dRate: Decimal
//    let bRate: Decimal
//    let interestRateModifier: Decimal
//    let dSupply: Decimal
//    let bSupply: Decimal
//    let backstopCredit: Decimal
//    let lastTime: TimeInterval
//    
//    // Version-specific data
//    let version: BlendProtocolVersion
//    
//    init(
//        dRate: Decimal,
//        bRate: Decimal,
//        interestRateModifier: Decimal,
//        dSupply: Decimal,
//        bSupply: Decimal,
//        backstopCredit: Decimal,
//        lastTime: TimeInterval,
//        version: BlendProtocolVersion = .v2
//    ) {
//        self.dRate = dRate
//        self.bRate = bRate
//        self.interestRateModifier = interestRateModifier
//        self.dSupply = dSupply
//        self.bSupply = bSupply
//        self.backstopCredit = backstopCredit
//        self.lastTime = lastTime
//        self.version = version
//    }
//}
//
///// Enum representing Blend Protocol versions
//enum BlendProtocolVersion {
//    case v1
//    case v2
//    
//    var rateDecimals: Int {
//        switch self {
//        case .v1: return 9
//        case .v2: return 12
//        }
//    }
//    
//    var irModDecimals: Int {
//        switch self {
//        case .v1: return 9
//        case .v2: return 7
//        }
//    }
//}
//
//// MARK: - Fixed-point Math Utils
//
///// Utilities for fixed-point arithmetic calculations
//struct FixedPointMath {
//    static let scalar7: Decimal = pow(10, 7)
//    static let scalar9: Decimal = pow(10, 9)
//    static let scalar12: Decimal = pow(10, 12)
//    
//    /// Converts a floating-point number to a fixed-point representation
//    /// - Parameters:
//    ///   - value: Value to convert
//    ///   - decimals: Number of decimal places
//    /// - Returns: Fixed-point representation as a Decimal
//    static func toFixed(_ value: Decimal, decimals: Int = 7) -> Decimal {
//        return value * pow(10, decimals)
//    }
//    
//    /// Converts a fixed-point number to a floating-point representation
//    /// - Parameters:
//    ///   - value: Fixed-point value to convert
//    ///   - decimals: Number of decimal places
//    /// - Returns: Floating-point representation as a Decimal
//    static func toFloat(_ value: Decimal, decimals: Int = 7) -> Decimal {
//        return value / pow(10, decimals)
//    }
//    
//    /// Multiplies two fixed-point numbers and applies floor division
//    /// - Parameters:
//    ///   - x: First value
//    ///   - y: Second value
//    ///   - denominator: Denominator for the fixed-point format
//    /// - Returns: Result as fixed-point Decimal
//    static func mulFloor(_ x: Decimal, _ y: Decimal, _ denominator: Decimal) -> Decimal {
//        return mulDivFloor(x, y, denominator)
//    }
//    
//    /// Multiplies two fixed-point numbers and applies ceiling division
//    /// - Parameters:
//    ///   - x: First value
//    ///   - y: Second value
//    ///   - denominator: Denominator for the fixed-point format
//    /// - Returns: Result as fixed-point Decimal
//    static func mulCeil(_ x: Decimal, _ y: Decimal, _ denominator: Decimal) -> Decimal {
//        return mulDivCeil(x, y, denominator)
//    }
//    
//    /// Divides fixed-point numbers with floor
//    /// - Parameters:
//    ///   - x: Numerator
//    ///   - y: Denominator
//    ///   - denominator: Denominator for the fixed-point format
//    /// - Returns: Result as fixed-point Decimal
//    static func divFloor(_ x: Decimal, _ y: Decimal, _ denominator: Decimal) -> Decimal {
//        return mulDivFloor(x, denominator, y)
//    }
//    
//    /// Divides fixed-point numbers with ceiling
//    /// - Parameters:
//    ///   - x: Numerator
//    ///   - y: Denominator
//    ///   - denominator: Denominator for the fixed-point format
//    /// - Returns: Result as fixed-point Decimal
//    static func divCeil(_ x: Decimal, _ y: Decimal, _ denominator: Decimal) -> Decimal {
//        return mulDivCeil(x, denominator, y)
//    }
//    
//    /// Performs floor(x * y / z)
//    /// - Parameters:
//    ///   - x: First value
//    ///   - y: Second value
//    ///   - z: Divisor
//    /// - Returns: Result as Decimal
//    private static func mulDivFloor(_ x: Decimal, _ y: Decimal, _ z: Decimal) -> Decimal {
//        let result = x * y
//        let floorDiv = (result / z).rounded(.down)
//        return floorDiv
//    }
//    
//    /// Performs ceil(x * y / z)
//    /// - Parameters:
//    ///   - x: First value
//    ///   - y: Second value
//    ///   - z: Divisor
//    /// - Returns: Result as Decimal
//    private static func mulDivCeil(_ x: Decimal, _ y: Decimal, _ z: Decimal) -> Decimal {
//        let result = x * y
//        let remainder = result.truncatingRemainder(dividingBy: z)
//        return result / z + (remainder > 0 ? 1 : 0)
//    }
//}
//
//// MARK: - Core Financial Calculator Implementation
//
///// Main implementation of the FinancialCalculator protocol
//struct BlendFinancialCalculator: FinancialCalculator {
//    
//    /// Calculates APY from asset data using the Blend Protocol methodology
//    /// - Parameters:
//    ///   - assetData: Asset reserve data
//    ///   - backstopTakeRate: Backstop take rate as a fixed-point decimal
//    ///   - isSupply: True for supply APY, false for borrow APY
//    /// - Returns: The calculated APY as a Decimal
//    func calculateAPY(from assetData: ReserveData, backstopTakeRate: Decimal, isSupply: Bool) -> Decimal {
//        // Validate inputs
//        if assetData.bSupply <= 0 && assetData.dSupply <= 0 {
//            return 0
//        }
//        
//        // Calculate utilization using fixed-point arithmetic
//        let totalSupply = assetData.bSupply
//        let totalLiabilities = FixedPointMath.mulFloor(
//            assetData.dSupply,
//            assetData.dRate,
//            FixedPointMath.scalar9
//        )
//        
//        if totalSupply <= 0 {
//            return 0
//        }
//        
//        let utilization = FixedPointMath.divFloor(
//            totalLiabilities,
//            totalSupply + totalLiabilities,
//            FixedPointMath.scalar7
//        )
//        
//        // Mock reserve config for interest rate calculation
//        // In a real implementation, this would come from the asset's config
//        let config = ReserveConfig(
//            index: 0,
//            decimals: 7,
//            collateralFactor: 0.9,
//            liabilityFactor: 0.9,
//            targetUtilization: 0.8,
//            maxUtilization: 0.95,
//            baseRate: 0.02,
//            rateOne: 0.08,
//            rateTwo: 0.2,
//            rateThree: 2,
//            reactivity: 0.5,
//            supplyCap: nil,
//            isEnabled: nil
//        )
//        
//        // Calculate current interest rate
//        let currentIR = calculateCurrentInterestRate(
//            utilization: utilization,
//            assetData: assetData,
//            config: config
//        )
//        
//        // Convert to APR
//        let apr: Decimal
//        if isSupply {
//            // Calculate supply APR considering backstop take rate
//            let supplyCapture = FixedPointMath.mulFloor(
//                FixedPointMath.scalar7 - backstopTakeRate,
//                utilization,
//                FixedPointMath.scalar7
//            )
//            let supplyRate = FixedPointMath.mulFloor(
//                currentIR,
//                supplyCapture,
//                FixedPointMath.scalar7
//            )
//            apr = FixedPointMath.toFloat(supplyRate, decimals: 7)
//        } else {
//            // Borrow APR is the current interest rate
//            apr = FixedPointMath.toFloat(currentIR, decimals: 7)
//        }
//        
//        // Apply safety bounds to prevent unrealistic rates
//        let maxAPR: Decimal = 10.0 // 1000% max APR
//        let boundedAPR = min(apr, maxAPR)
//        
//        if boundedAPR <= 0 {
//            return 0
//        }
//        
//        // Convert APR to APY using precise calculation
//        let compoundingPeriods = isSupply ? 52 : 365 // Weekly for supply, daily for borrow
//        let apy = convertAPRtoAPY(boundedAPR, periods: compoundingPeriods)
//        
//        return apy
//    }
//    
//    /// Calculate the current interest rate based on utilization and asset data
//    /// - Parameters:
//    ///   - utilization: Current utilization as fixed-point number
//    ///   - assetData: The reserve data
//    ///   - config: Reserve configuration
//    /// - Returns: Current interest rate as fixed-point Decimal
//    func calculateCurrentInterestRate(utilization: Decimal, assetData: ReserveData, config: ReserveConfig) -> Decimal {
//        if utilization <= 0 {
//            return config.baseRate
//        }
//        
//        let irModScalar = FixedPointMath.toFixed(1, decimals: assetData.version.irModDecimals)
//        let targetUtil = config.targetUtilization
//        let fixed95Percent: Decimal = FixedPointMath.toFixed(0.95, decimals: 7) // 95% in 7 decimal fixed-point
//        let fixed5Percent: Decimal = FixedPointMath.toFixed(0.05, decimals: 7)  // 5% in 7 decimal fixed-point
//        
//        var currentIR: Decimal
//        
//        if utilization <= targetUtil {
//            // Below target utilization
//            let utilScalar = FixedPointMath.divCeil(
//                utilization,
//                targetUtil,
//                FixedPointMath.scalar7
//            )
//            let baseRate = FixedPointMath.mulCeil(
//                utilScalar,
//                config.rateOne,
//                FixedPointMath.scalar7
//            ) + config.baseRate
//            
//            currentIR = FixedPointMath.mulCeil(
//                baseRate,
//                assetData.interestRateModifier,
//                irModScalar
//            )
//        } else if utilization <= fixed95Percent {
//            // Between target and 95% utilization
//            let utilScalar = FixedPointMath.divCeil(
//                utilization - targetUtil,
//                fixed95Percent - targetUtil,
//                FixedPointMath.scalar7
//            )
//            let baseRate = FixedPointMath.mulCeil(
//                utilScalar,
//                config.rateTwo,
//                FixedPointMath.scalar7
//            ) + config.rateOne + config.baseRate
//            
//            currentIR = FixedPointMath.mulCeil(
//                baseRate,
//                assetData.interestRateModifier,
//                irModScalar
//            )
//        } else {
//            // Above 95% utilization
//            let utilScalar = FixedPointMath.divCeil(
//                utilization - fixed95Percent,
//                fixed5Percent,
//                FixedPointMath.scalar7
//            )
//            let extraRate = FixedPointMath.mulCeil(
//                utilScalar,
//                config.rateThree,
//                FixedPointMath.scalar7
//            )
//            let intersection = FixedPointMath.mulCeil(
//                assetData.interestRateModifier,
//                config.rateTwo + config.rateOne + config.baseRate,
//                irModScalar
//            )
//            currentIR = extraRate + intersection
//        }
//        
//        return currentIR
//    }
//    
//    /// Convert APR to APY using compound interest formula
//    /// - Parameters:
//    ///   - apr: Annual Percentage Rate
//    ///   - periods: Number of compounding periods per year
//    /// - Returns: Annual Percentage Yield
//    func convertAPRtoAPY(_ apr: Decimal, periods: Int) -> Decimal {
//        if apr < 0 || periods <= 0 {
//            return 0
//        }
//        
//        // Handle edge case of zero APR
//        if apr == 0 {
//            return 0
//        }
//        
//        // APY = (1 + APR/n)^n - 1
//        let periodsDecimal = Decimal(periods)
//        let aprPerPeriod = apr / periodsDecimal
//        let onePlusRate = 1 + aprPerPeriod
//        
//        // Use NSDecimalNumber for precise power calculation
//        let base = NSDecimalNumber(decimal: onePlusRate)
//        let power = NSDecimalNumber(decimal: periodsDecimal)
//        let compounded = pow(base, power.intValue)
//        
//        let apy = compounded.decimalValue - 1
//        
//        // Apply reasonable bounds (max 10000% APY)
//        let maxAPY: Decimal = 100.0
//        return min(apy, maxAPY)
//    }
//}
//
//// MARK: - Financial Metrics Container
//
///// Struct containing various financial metrics and calculations
//struct FinancialMetrics {
//    private let calculator: FinancialCalculator
//    
//    init(calculator: FinancialCalculator = BlendFinancialCalculator()) {
//        self.calculator = calculator
//    }
//    
//    // MARK: - APY Calculations
//    
//    /// Calculate the supply APY
//    /// - Parameters:
//    ///   - assetData: Reserve data for the asset
//    ///   - backstopTakeRate: The backstop take rate as a decimal
//    /// - Returns: The supply APY as a decimal
//    func calculateSupplyAPY(assetData: ReserveData, backstopTakeRate: Decimal) -> Decimal {
//        return calculator.calculateAPY(from: assetData, backstopTakeRate: backstopTakeRate, isSupply: true)
//    }
//    
//    /// Calculate the borrow APY
//    /// - Parameters:
//    ///   - assetData: Reserve data for the asset
//    ///   - backstopTakeRate: The backstop take rate as a decimal
//    /// - Returns: The borrow APY as a decimal
//    func calculateBorrowAPY(assetData: ReserveData, backstopTakeRate: Decimal) -> Decimal {
//        return calculator.calculateAPY(from: assetData, backstopTakeRate: backstopTakeRate, isSupply: false)
//    }
//    
//    // MARK: - Asset Calculations
//    
//    /// Calculate total liabilities for a reserve
//    /// - Parameter assetData: Reserve data
//    /// - Returns: Total liabilities as a Decimal
//    func totalLiabilities(assetData: ReserveData) -> Decimal {
//        return FixedPointMath.mulFloor(
//            assetData.dSupply,
//            assetData.dRate,
//            FixedPointMath.scalar9
//        )
//    }
//    
//    /// Calculate total supply for a reserve
//    /// - Parameter assetData: Reserve data
//    /// - Returns: Total supply as a Decimal
//    func totalSupply(assetData: ReserveData) -> Decimal {
//        return assetData.bSupply
//    }
//    
//    /// Calculate utilization rate for a reserve
//    /// - Parameter assetData: Reserve data
//    /// - Returns: Utilization rate as a Decimal between 0 and 1
//    func utilizationRate(assetData: ReserveData) -> Decimal {
//        let liabilities = totalLiabilities(assetData: assetData)
//        let supply = totalSupply(assetData: assetData)
//        
//        if supply <= 0 {
//            return 0
//        }
//        
//        return min(liabilities / (supply + liabilities), 1.0)
//    }
//    
//    // MARK: - Helper Methods
//    
//    /// Converts a percentage value to a human-readable string
//    /// - Parameters:
//    ///   - value: The decimal value to format
//    ///   - decimals: Number of decimal places to show
//    /// - Returns: Formatted percentage string
//    func formatPercentage(_ value: Decimal, decimals: Int = 2) -> String {
//        let formatter = NumberFormatter()
//        formatter.numberStyle = .percent
//        formatter.minimumFractionDigits = decimals
//        formatter.maximumFractionDigits = decimals
//        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value * 100)%"
//    }
//}
