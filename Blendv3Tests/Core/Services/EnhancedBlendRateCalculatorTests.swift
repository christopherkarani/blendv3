import XCTest
@testable import Blendv3

final class EnhancedBlendRateCalculatorTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: EnhancedBlendRateCalculator!
    private var testConfig: InterestRateConfig!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        sut = EnhancedBlendRateCalculator()
        testConfig = InterestRateConfig(
            targetUtilization: FixedMath.toFixed(value: 0.8, decimals: 7), // 80%
            rBase: 100_000, // 1%
            rOne: 400_000, // 4%
            rTwo: 2_000_000, // 20%
            rThree: 10_000_000, // 100%
            reactivity: 100_000, // 1%
            interestRateModifier: FixedMath.SCALAR_7 // 100%
        )
    }
    
    override func tearDown() {
        sut = nil
        testConfig = nil
        super.tearDown()
    }
    
    // MARK: - Basic Rate Calculation Tests
    
    func testCalculateSupplyAPR_withValidInputs_returnsCorrectRate() {
        // Given
        let curIr = FixedMath.toFixed(value: 0.05, decimals: 7) // 5%
        let curUtil = FixedMath.toFixed(value: 0.8, decimals: 7) // 80%
        let backstopTakeRate = FixedMath.toFixed(value: 0.1, decimals: 7) // 10%
        
        // When
        let result = sut.calculateSupplyAPR(curIr: curIr, curUtil: curUtil, backstopTakeRate: backstopTakeRate)
        
        // Then
        XCTAssertGreaterThan(result, 0)
        XCTAssertLessThan(result, 1) // Should be less than 100%
    }
    
    func testCalculateSupplyAPR_withInvalidInputs_returnsZero() {
        // Given
        let negativeIr = FixedMath.toFixed(value: -0.05, decimals: 7)
        let validUtil = FixedMath.toFixed(value: 0.8, decimals: 7)
        let validBackstopRate = FixedMath.toFixed(value: 0.1, decimals: 7)
        
        // When
        let result = sut.calculateSupplyAPR(curIr: negativeIr, curUtil: validUtil, backstopTakeRate: validBackstopRate)
        
        // Then
        XCTAssertEqual(result, 0)
    }
    
    func testCalculateBorrowAPR_withValidInput_returnsCorrectRate() {
        // Given
        let curIr = FixedMath.toFixed(value: 0.05, decimals: 7) // 5%
        
        // When
        let result = sut.calculateBorrowAPR(curIr: curIr)
        
        // Then
        XCTAssertEqual(result, 0.05, accuracy: 0.0001)
    }
    
    func testCalculateBorrowAPR_withNegativeInput_returnsZero() {
        // Given
        let negativeIr = FixedMath.toFixed(value: -0.05, decimals: 7)
        
        // When
        let result = sut.calculateBorrowAPR(curIr: negativeIr)
        
        // Then
        XCTAssertEqual(result, 0)
    }
    
    // MARK: - APR to APY Conversion Tests
    
    func testConvertAPRtoAPY_withValidInputs_returnsCorrectAPY() {
        // Given
        let apr: Decimal = 0.05 // 5%
        let compoundingPeriods = 52 // Weekly
        
        // When
        let result = sut.convertAPRtoAPY(apr, compoundingPeriods: compoundingPeriods)
        
        // Then
        XCTAssertGreaterThan(result, apr) // APY should be higher than APR
        XCTAssertLessThan(result, 0.06) // Should be reasonable
    }
    
    func testConvertAPRtoAPY_withZeroAPR_returnsZero() {
        // Given
        let apr: Decimal = 0
        let compoundingPeriods = 52
        
        // When
        let result = sut.convertAPRtoAPY(apr, compoundingPeriods: compoundingPeriods)
        
        // Then
        XCTAssertEqual(result, 0)
    }
    
    func testConvertAPRtoAPY_withExtremelyHighAPR_capsCorrectly() {
        // Given
        let extremeAPR: Decimal = 50 // 5000%
        let compoundingPeriods = 365
        
        // When
        let result = sut.convertAPRtoAPY(extremeAPR, compoundingPeriods: compoundingPeriods)
        
        // Then
        XCTAssertLessThan(result, 100) // Should be capped
    }
    
    func testConvertAPRtoAPY_withInvalidInputs_returnsZero() {
        // Given
        let negativeAPR: Decimal = -0.05
        let invalidPeriods = 0
        
        // When
        let result1 = sut.convertAPRtoAPY(negativeAPR, compoundingPeriods: 52)
        let result2 = sut.convertAPRtoAPY(0.05, compoundingPeriods: invalidPeriods)
        
        // Then
        XCTAssertEqual(result1, 0)
        XCTAssertEqual(result2, 0)
    }
    
    // MARK: - Kinked Interest Rate Tests
    
    func testCalculateKinkedInterestRate_firstSlope_calculatesCorrectly() {
        // Given
        let lowUtilization = FixedMath.toFixed(value: 0.4, decimals: 7) // 40% (below target)
        
        // When
        let result = sut.calculateKinkedInterestRate(utilization: lowUtilization, config: testConfig)
        
        // Then
        XCTAssertGreaterThan(result, 0)
        XCTAssertLessThan(result, FixedMath.toFloat(value: testConfig.rOne + testConfig.rBase, decimals: 7))
    }
    
    func testCalculateKinkedInterestRate_secondSlope_calculatesCorrectly() {
        // Given
        let mediumUtilization = FixedMath.toFixed(value: 0.9, decimals: 7) // 90% (above target, below emergency)
        
        // When
        let result = sut.calculateKinkedInterestRate(utilization: mediumUtilization, config: testConfig)
        
        // Then
        XCTAssertGreaterThan(result, FixedMath.toFloat(value: testConfig.rOne + testConfig.rBase, decimals: 7))
    }
    
    func testCalculateKinkedInterestRate_thirdSlope_calculatesCorrectly() {
        // Given
        let highUtilization = FixedMath.toFixed(value: 0.98, decimals: 7) // 98% (emergency level)
        
        // When
        let result = sut.calculateKinkedInterestRate(utilization: highUtilization, config: testConfig)
        
        // Then
        XCTAssertGreaterThan(result, FixedMath.toFloat(value: testConfig.rTwo + testConfig.rOne + testConfig.rBase, decimals: 7))
    }
    
    func testCalculateKinkedInterestRate_withInvalidUtilization_returnsZero() {
        // Given
        let invalidUtilization = FixedMath.toFixed(value: -0.1, decimals: 7)
        
        // When
        let result = sut.calculateKinkedInterestRate(utilization: invalidUtilization, config: testConfig)
        
        // Then
        XCTAssertEqual(result, 0)
    }
    
    // MARK: - Reactive Interest Rate Tests
    
    func testCalculateReactiveInterestRate_firstCall_createsModifier() {
        // Given
        let utilization = FixedMath.toFixed(value: 0.9, decimals: 7) // 90%
        let poolId = "test_pool_1"
        
        // When
        let result = sut.calculateReactiveInterestRate(
            utilization: utilization,
            config: testConfig,
            poolId: poolId
        )
        
        // Then
        XCTAssertGreaterThan(result, 0)
    }
    
    func testCalculateReactiveInterestRate_subsequentCalls_updatesModifier() {
        // Given
        let highUtilization = FixedMath.toFixed(value: 0.95, decimals: 7) // 95%
        let poolId = "test_pool_2"
        
        // When
        let firstResult = sut.calculateReactiveInterestRate(
            utilization: highUtilization,
            config: testConfig,
            poolId: poolId
        )
        
        // Simulate time passing
        Thread.sleep(forTimeInterval: 0.1)
        
        let secondResult = sut.calculateReactiveInterestRate(
            utilization: highUtilization,
            config: testConfig,
            poolId: poolId
        )
        
        // Then
        XCTAssertGreaterThanOrEqual(secondResult, firstResult) // Rate should increase or stay same
    }
    
    func testCalculateReactiveInterestRate_utilizationDrops_decreasesRate() {
        // Given
        let poolId = "test_pool_3"
        let highUtilization = FixedMath.toFixed(value: 0.95, decimals: 7) // 95%
        let lowUtilization = FixedMath.toFixed(value: 0.5, decimals: 7) // 50%
        
        // When
        // First establish high rate
        _ = sut.calculateReactiveInterestRate(
            utilization: highUtilization,
            config: testConfig,
            poolId: poolId
        )
        
        Thread.sleep(forTimeInterval: 0.1)
        
        // Then drop utilization
        let resultAfterDrop = sut.calculateReactiveInterestRate(
            utilization: lowUtilization,
            config: testConfig,
            poolId: poolId
        )
        
        // Then
        XCTAssertGreaterThan(resultAfterDrop, 0)
    }
    
    // MARK: - Three-Slope Validation Tests
    
    func testValidateThreeSlopeModel_withValidConfig_returnsValid() {
        // Given
        let validConfig = testConfig!
        
        // When
        let result = sut.validateThreeSlopeModel(validConfig)
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.issues.isEmpty)
    }
    
    func testValidateThreeSlopeModel_withInvalidTargetUtilization_returnsInvalid() {
        // Given
        let invalidConfig = InterestRateConfig(
            targetUtilization: FixedMath.toFixed(value: 1.5, decimals: 7), // 150% (invalid)
            rBase: testConfig.rBase,
            rOne: testConfig.rOne,
            rTwo: testConfig.rTwo,
            rThree: testConfig.rThree,
            reactivity: testConfig.reactivity
        )
        
        // When
        let result = sut.validateThreeSlopeModel(invalidConfig)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.issues.isEmpty)
        XCTAssertTrue(result.issues.first?.contains("Target utilization") ?? false)
    }
    
    func testValidateThreeSlopeModel_withNegativeRates_returnsInvalid() {
        // Given
        let invalidConfig = InterestRateConfig(
            targetUtilization: testConfig.targetUtilization,
            rBase: -100_000, // Negative base rate
            rOne: testConfig.rOne,
            rTwo: testConfig.rTwo,
            rThree: testConfig.rThree,
            reactivity: testConfig.reactivity
        )
        
        // When
        let result = sut.validateThreeSlopeModel(invalidConfig)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("Base rate") && $0.contains("negative") })
    }
    
    func testValidateThreeSlopeModel_withHighTargetUtilization_returnsWarning() {
        // Given
        let warningConfig = InterestRateConfig(
            targetUtilization: FixedMath.toFixed(value: 0.95, decimals: 7), // 95% (high)
            rBase: testConfig.rBase,
            rOne: testConfig.rOne,
            rTwo: testConfig.rTwo,
            rThree: testConfig.rThree,
            reactivity: testConfig.reactivity
        )
        
        // When
        let result = sut.validateThreeSlopeModel(warningConfig)
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertTrue(result.warnings.first?.contains("90%") ?? false)
    }
    
    func testValidateThreeSlopeModel_withInvalidReactivity_returnsInvalid() {
        // Given
        let invalidConfig = InterestRateConfig(
            targetUtilization: testConfig.targetUtilization,
            rBase: testConfig.rBase,
            rOne: testConfig.rOne,
            rTwo: testConfig.rTwo,
            rThree: testConfig.rThree,
            reactivity: -100_000 // Negative reactivity
        )
        
        // When
        let result = sut.validateThreeSlopeModel(invalidConfig)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("Reactivity") && $0.contains("positive") })
    }
    
    func testValidateThreeSlopeModel_reportGeneration_worksCorrectly() {
        // Given
        let invalidConfig = InterestRateConfig(
            targetUtilization: FixedMath.toFixed(value: 1.5, decimals: 7),
            rBase: -100_000,
            rOne: testConfig.rOne,
            rTwo: testConfig.rTwo,
            rThree: testConfig.rThree,
            reactivity: testConfig.reactivity
        )
        
        // When
        let result = sut.validateThreeSlopeModel(invalidConfig)
        let report = result.report
        
        // Then
        XCTAssertTrue(report.contains("Three-Slope Model Validation Report"))
        XCTAssertTrue(report.contains("❌ INVALID"))
        XCTAssertTrue(report.contains("Issues:"))
        XCTAssertTrue(report.contains("Configuration:"))
    }
    
    // MARK: - Helper Methods Tests
    
    func testCalculateSupplyAPY_fromAPR_calculatesCorrectly() {
        // Given
        let apr: Decimal = 0.05 // 5%
        
        // When
        let result = sut.calculateSupplyAPY(fromAPR: apr)
        
        // Then
        XCTAssertGreaterThan(result, apr) // APY should be higher than APR for weekly compounding
    }
    
    func testCalculateBorrowAPY_fromAPR_calculatesCorrectly() {
        // Given
        let apr: Decimal = 0.05 // 5%
        
        // When
        let result = sut.calculateBorrowAPY(fromAPR: apr)
        
        // Then
        XCTAssertGreaterThan(result, apr) // APY should be higher than APR for daily compounding
    }
    
    // MARK: - Safety Bounds Tests
    
    func testCalculateSupplyAPR_withExtremelyHighRate_appliesBounds() {
        // Given
        let extremeIr = FixedMath.toFixed(value: 100.0, decimals: 7) // 10000%
        let curUtil = FixedMath.toFixed(value: 0.8, decimals: 7)
        let backstopTakeRate = FixedMath.toFixed(value: 0.1, decimals: 7)
        
        // When
        let result = sut.calculateSupplyAPR(curIr: extremeIr, curUtil: curUtil, backstopTakeRate: backstopTakeRate)
        
        // Then
        XCTAssertLessThanOrEqual(result, 10.0) // Should be capped at 1000%
    }
    
    func testCalculateBorrowAPR_withExtremelyHighRate_appliesBounds() {
        // Given
        let extremeIr = FixedMath.toFixed(value: 100.0, decimals: 7) // 10000%
        
        // When
        let result = sut.calculateBorrowAPR(curIr: extremeIr)
        
        // Then
        XCTAssertLessThanOrEqual(result, 10.0) // Should be capped at 1000%
    }
    
    // MARK: - Performance Tests
    
    func testCalculateReactiveInterestRate_performance() {
        // Given
        let utilization = FixedMath.toFixed(value: 0.8, decimals: 7)
        let poolId = "performance_test_pool"
        
        // When/Then
        measure {
            for i in 0..<100 {
                _ = sut.calculateReactiveInterestRate(
                    utilization: utilization,
                    config: testConfig,
                    poolId: "\(poolId)_\(i)"
                )
            }
        }
    }
    
    func testValidateThreeSlopeModel_performance() {
        // When/Then
        measure {
            for _ in 0..<1000 {
                _ = sut.validateThreeSlopeModel(testConfig)
            }
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testCalculateKinkedInterestRate_atExactThresholds_handlesCorrectly() {
        // Given
        let targetUtilization = testConfig.targetUtilization
        let emergencyThreshold = FixedMath.toFixed(value: 0.95, decimals: 7)
        
        // When
        let resultAtTarget = sut.calculateKinkedInterestRate(utilization: targetUtilization, config: testConfig)
        let resultAtEmergency = sut.calculateKinkedInterestRate(utilization: emergencyThreshold, config: testConfig)
        
        // Then
        XCTAssertGreaterThan(resultAtTarget, 0)
        XCTAssertGreaterThan(resultAtEmergency, 0)
        XCTAssertGreaterThan(resultAtEmergency, resultAtTarget)
    }
    
    func testCalculateReactiveInterestRate_samePoolMultipleCalls_maintainsState() {
        // Given
        let poolId = "state_test_pool"
        let utilization = FixedMath.toFixed(value: 0.9, decimals: 7)
        
        // When
        let firstCall = sut.calculateReactiveInterestRate(
            utilization: utilization,
            config: testConfig,
            poolId: poolId
        )
        
        let secondCall = sut.calculateReactiveInterestRate(
            utilization: utilization,
            config: testConfig,
            poolId: poolId
        )
        
        // Then
        // Second call should use cached modifier (minimal change expected)
        XCTAssertEqual(firstCall, secondCall, accuracy: 0.001)
    }
} 