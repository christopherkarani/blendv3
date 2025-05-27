import Foundation

/// Protocol defining interest rate and APR/APY calculation methods for Blend Protocol
public protocol BlendRateCalculatorProtocol {
    
    /// Calculate supply APR considering backstop take rate
    /// - Parameters:
    ///   - curIr: Current interest rate (fixed-point with 7 decimals)
    ///   - curUtil: Current utilization (fixed-point with 7 decimals)
    ///   - backstopTakeRate: Backstop take rate (fixed-point with 7 decimals)
    /// - Returns: Supply APR as decimal (e.g., 0.1 for 10%)
    func calculateSupplyAPR(curIr: Decimal, curUtil: Decimal, backstopTakeRate: Decimal) -> Decimal
    
    /// Calculate borrow APR
    /// - Parameter curIr: Current interest rate (fixed-point with 7 decimals)
    /// - Returns: Borrow APR as decimal (e.g., 0.1 for 10%)
    func calculateBorrowAPR(curIr: Decimal) -> Decimal
    
    /// Convert APR to APY with specified compounding periods
    /// - Parameters:
    ///   - apr: Annual percentage rate as decimal
    ///   - compoundingPeriods: Number of compounding periods per year
    /// - Returns: Annual percentage yield as decimal
    func convertAPRtoAPY(_ apr: Decimal, compoundingPeriods: Int) -> Decimal
    
    /// Calculate kinked interest rate based on utilization
    /// - Parameters:
    ///   - utilization: Current utilization ratio (0-1)
    ///   - config: Interest rate configuration
    /// - Returns: Interest rate (fixed-point with 7 decimals)
    func calculateKinkedInterestRate(utilization: Decimal, config: InterestRateConfig) -> Decimal
    
    /// Calculate supply APY from supply APR
    /// - Parameter apr: Supply APR as decimal
    /// - Returns: Supply APY as decimal
    func calculateSupplyAPY(fromAPR apr: Decimal) -> Decimal
    
    /// Calculate borrow APY from borrow APR
    /// - Parameter apr: Borrow APR as decimal
    /// - Returns: Borrow APY as decimal
    func calculateBorrowAPY(fromAPR apr: Decimal) -> Decimal
}


