import XCTest
@testable import Blendv3

final class BlendRateCalculatorTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: BlendRateCalculator!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        sut = BlendRateCalculator()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Supply APR Tests
    
    func testCalculateSupplyAPR_withZeroUtilization_returnsZero() {
        // Given
        let curIr: Decimal = 1_000_000 // 10% interest rate
        let curUtil: Decimal = 0 // 0% utilization
        let backstopTakeRate: Decimal = 1_000_000 // 10% backstop rate
        
        // When
        let result = sut.calculateSupplyAPR(curIr: curIr, curUtil: curUtil, backstopTakeRate: backstopTakeRate)
        
        // Then
        XCTAssertEqual(result, 0, accuracy: 0.0001)
    }
    
    func testCalculateSupplyAPR_withFullUtilization_returnsCorrectValue() {
        // Given
        let curIr: Decimal = 1_000_000 // 10% interest rate
        let curUtil: Decimal = FixedMath.SCALAR_7 // 100% utilization
        let backstopTakeRate: Decimal = 1_000_000 // 10% backstop rate
        
        // When
        let result = sut.calculateSupplyAPR(curIr: curIr, curUtil: curUtil, backstopTakeRate: backstopTakeRate)
        
        // Then
        // Expected: 10% * (1 - 0.1) * 1.0 = 9%
        XCTAssertEqual(result, 0.09, accuracy: 0.0001)
    }
    
    // MARK: - Borrow APR Tests
    
    func testCalculateBorrowAPR_convertsFixedPointCorrectly() {
        // Given
        let curIr: Decimal = 1_500_000 // 15% interest rate
        
        // When
        let result = sut.calculateBorrowAPR(curIr: curIr)
        
        // Then
        XCTAssertEqual(result, 0.15, accuracy: 0.0001)
    }
    
    // MARK: - APR to APY Conversion Tests
    
    func testConvertAPRtoAPY_withWeeklyCompounding_returnsCorrectValue() {
        // Given
        let apr: Decimal = 0.10 // 10% APR
        let compoundingPeriods = 52 // Weekly
        
        // When
        let result = sut.convertAPRtoAPY(apr, compoundingPeriods: compoundingPeriods)
        
        // Then
        // Expected: (1 + 0.10/52)^52 - 1 ≈ 10.506%
        XCTAssertEqual(result, 0.10506, accuracy: 0.00001)
    }
    
    func testConvertAPRtoAPY_withDailyCompounding_returnsCorrectValue() {
        // Given
        let apr: Decimal = 0.10 // 10% APR
        let compoundingPeriods = 365 // Daily
        
        // When
        let result = sut.convertAPRtoAPY(apr, compoundingPeriods: compoundingPeriods)
        
        // Then
        // Expected: (1 + 0.10/365)^365 - 1 ≈ 10.516%
        XCTAssertEqual(result, 0.10516, accuracy: 0.00001)
    }
    
    // MARK: - Kinked Interest Rate Tests
    
    func testCalculateKinkedInterestRate_firstSlope_returnsCorrectValue() {
        // Given
        let utilization: Decimal = 0.5 // 50% utilization
        let config = InterestRateConfig(
            targetUtilization: 0.8,
            rBase: 100_000, // 1% base
            rOne: 400_000,  // 4% slope 1
            rTwo: 2_000_000, // 20% slope 2
            rThree: 10_000_000, // 100% slope 3
            reactivity: 100_000
        )
        
        // When
        let result = sut.calculateKinkedInterestRate(utilization: utilization, config: config)
        
        // Then
        // Expected: (0.5/0.8) * 4% + 1% = 3.5%
        let expected = FixedMath.toFixed(value: 0.035, decimals: 7)
        XCTAssertEqual(result, expected, accuracy: 100)
    }
    
    func testCalculateKinkedInterestRate_secondSlope_returnsCorrectValue() {
        // Given
        let utilization: Decimal = 0.9 // 90% utilization
        let config = InterestRateConfig(
            targetUtilization: 0.8,
            rBase: 100_000, // 1% base
            rOne: 400_000,  // 4% slope 1
            rTwo: 2_000_000, // 20% slope 2
            rThree: 10_000_000, // 100% slope 3
            reactivity: 100_000
        )
        
        // When
        let result = sut.calculateKinkedInterestRate(utilization: utilization, config: config)
        
        // Then
        // Expected: ((0.9-0.8)/(0.95-0.8)) * 20% + 4% + 1% = 18.33%
        let expected = FixedMath.toFixed(value: 0.1833, decimals: 7)
        XCTAssertEqual(result, expected, accuracy: 10000)
    }
    
    func testCalculateKinkedInterestRate_thirdSlope_returnsCorrectValue() {
        // Given
        let utilization: Decimal = 0.98 // 98% utilization
        let config = InterestRateConfig(
            targetUtilization: 0.8,
            rBase: 100_000, // 1% base
            rOne: 400_000,  // 4% slope 1
            rTwo: 2_000_000, // 20% slope 2
            rThree: 10_000_000, // 100% slope 3
            reactivity: 100_000
        )
        
        // When
        let result = sut.calculateKinkedInterestRate(utilization: utilization, config: config)
        
        // Then
        // Emergency rate calculation
        let utilizationScalar = (utilization - 0.95) / 0.05
        let extraRate = utilizationScalar * FixedMath.toFloat(value: config.rThree, decimals: 7)
        let intersection = FixedMath.toFloat(value: config.rTwo + config.rOne + config.rBase, decimals: 7)
        let expected = FixedMath.toFixed(value: extraRate + intersection, decimals: 7)
        XCTAssertEqual(result, expected, accuracy: 10000)
    }
    
    // MARK: - Helper Method Tests
    
    func testCalculateSupplyAPY_usesWeeklyCompounding() {
        // Given
        let apr: Decimal = 0.10 // 10% APR
        
        // When
        let result = sut.calculateSupplyAPY(fromAPR: apr)
        
        // Then
        XCTAssertEqual(result, 0.10506, accuracy: 0.00001)
    }
    
    func testCalculateBorrowAPY_usesDailyCompounding() {
        // Given
        let apr: Decimal = 0.10 // 10% APR
        
        // When
        let result = sut.calculateBorrowAPY(fromAPR: apr)
        
        // Then
        XCTAssertEqual(result, 0.10516, accuracy: 0.00001)
    }
} 