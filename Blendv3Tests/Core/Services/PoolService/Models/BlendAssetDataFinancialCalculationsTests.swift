//
//  BlendAssetDataFinancialCalculationsTests.swift
//  Blendv3Tests
//
//  Created by Chris Karani on 30/05/2025.
//

import XCTest
@testable import Blendv3

final class BlendAssetDataFinancialCalculationsTests: XCTestCase {
    
    // MARK: - Properties
    
    private var testAssetData: BlendAssetData!
    private let testTimeout: TimeInterval = 5.0
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        testAssetData = createTestAssetData()
    }
    
    override func tearDown() {
        testAssetData = nil
        super.tearDown()
    }
    
    // MARK: - Supply APR Tests
    
    func testCalculateSupplyAPR_withValidInputs_returnsCorrectRate() throws {
        // Given
        let backstopRate = FixedMath.toFixed(value: 0.20, decimals: 7) // 20%
        
        // When
        let result = try testAssetData.calculateSupplyAPR(backstopTakeRate: backstopRate)
        
        // Then
        XCTAssertGreaterThan(result, 0, "Supply APR should be positive")
        XCTAssertLessThan(result, 1000, "Supply APR should be reasonable (< 1000%)")
    }
    
    func testCalculateSupplyAPR_withZeroUtilization_returnsZero() throws {
        // Given
        let zeroUtilizationAsset = createTestAssetData(totalBorrowed: 0)
        let backstopRate = FixedMath.toFixed(value: 0.20, decimals: 7)
        
        // When
        let result = try zeroUtilizationAsset.calculateSupplyAPR(backstopTakeRate: backstopRate)
        
        // Then
        XCTAssertEqual(result, 0, "Supply APR should be zero with no utilization")
    }
    
    func testCalculateSupplyAPR_withHighUtilization_returnsHigherRate() throws {
        // Given
        let lowUtilAsset = createTestAssetData(totalSupplied: 1000, totalBorrowed: 200) // 20% util
        let highUtilAsset = createTestAssetData(totalSupplied: 1000, totalBorrowed: 800) // 80% util
        let backstopRate = FixedMath.toFixed(value: 0.20, decimals: 7)
        
        // When
        let lowUtilAPR = try lowUtilAsset.calculateSupplyAPR(backstopTakeRate: backstopRate)
        let highUtilAPR = try highUtilAsset.calculateSupplyAPR(backstopTakeRate: backstopRate)
        
        // Then
        XCTAssertGreaterThan(highUtilAPR, lowUtilAPR, "Higher utilization should yield higher supply APR")
    }
    
    func testCalculateSupplyAPR_withInvalidBackstopRate_throwsError() {
        // Given
        let invalidBackstopRate = FixedMath.SCALAR_7 + 1 // > 100%
        
        // When/Then
        XCTAssertThrowsError(try testAssetData.calculateSupplyAPR(backstopTakeRate: invalidBackstopRate)) { error in
            XCTAssertTrue(error is BlendError)
            if case .validation(.outOfBounds) = error as? BlendError {
                // Expected error
            } else {
                XCTFail("Expected validation.outOfBounds error")
            }
        }
    }
    
    func testCalculateSupplyAPR_withNegativeBackstopRate_throwsError() {
        // Given
        let negativeBackstopRate: Decimal = -1000
        
        // When/Then
        XCTAssertThrowsError(try testAssetData.calculateSupplyAPR(backstopTakeRate: negativeBackstopRate)) { error in
            XCTAssertTrue(error is BlendError)
            if case .validation(.outOfBounds) = error as? BlendError {
                // Expected error
            } else {
                XCTFail("Expected validation.outOfBounds error")
            }
        }
    }
    
    // MARK: - Borrow APR Tests
    
    func testCalculateBorrowAPR_withValidInputs_returnsCorrectRate() throws {
        // When
        let result = try testAssetData.calculateBorrowAPR()
        
        // Then
        XCTAssertGreaterThan(result, 0, "Borrow APR should be positive")
        XCTAssertLessThan(result, 1000, "Borrow APR should be reasonable (< 1000%)")
    }
    
    func testCalculateBorrowAPR_withZeroUtilization_returnsBaseRate() throws {
        // Given
        let zeroUtilizationAsset = createTestAssetData(totalBorrowed: 0)
        
        // When
        let result = try zeroUtilizationAsset.calculateBorrowAPR()
        
        // Then
        let expectedBaseRate = FixedMath.toFloat(value: zeroUtilizationAsset.rBase, decimals: 7) * 100
        XCTAssertEqual(result, expectedBaseRate, accuracy: 0.01, "Should return base rate with zero utilization")
    }
    
    func testCalculateBorrowAPR_withHighUtilization_returnsHigherRate() throws {
        // Given
        let lowUtilAsset = createTestAssetData(totalSupplied: 1000, totalBorrowed: 200) // 20% util
        let highUtilAsset = createTestAssetData(totalSupplied: 1000, totalBorrowed: 800) // 80% util
        
        // When
        let lowUtilAPR = try lowUtilAsset.calculateBorrowAPR()
        let highUtilAPR = try highUtilAsset.calculateBorrowAPR()
        
        // Then
        XCTAssertGreaterThan(highUtilAPR, lowUtilAPR, "Higher utilization should yield higher borrow APR")
    }
    
    // MARK: - Supply APY Tests
    
    func testCalculateSupplyAPY_withValidInputs_returnsHigherThanAPR() throws {
        // Given
        let backstopRate = FixedMath.toFixed(value: 0.20, decimals: 7)
        
        // When
        let apr = try testAssetData.calculateSupplyAPR(backstopTakeRate: backstopRate)
        let apy = try testAssetData.calculateSupplyAPY(backstopTakeRate: backstopRate)
        
        // Then
        XCTAssertGreaterThan(apy, apr, "APY should be higher than APR due to compounding")
    }
    
    func testCalculateSupplyAPY_withZeroAPR_returnsZero() throws {
        // Given
        let zeroUtilizationAsset = createTestAssetData(totalBorrowed: 0)
        let backstopRate = FixedMath.toFixed(value: 0.20, decimals: 7)
        
        // When
        let result = try zeroUtilizationAsset.calculateSupplyAPY(backstopTakeRate: backstopRate)
        
        // Then
        XCTAssertEqual(result, 0, "APY should be zero when APR is zero")
    }
    
    // MARK: - Borrow APY Tests
    
    func testCalculateBorrowAPY_withValidInputs_returnsHigherThanAPR() throws {
        // When
        let apr = try testAssetData.calculateBorrowAPR()
        let apy = try testAssetData.calculateBorrowAPY()
        
        // Then
        XCTAssertGreaterThan(apy, apr, "APY should be higher than APR due to compounding")
    }
    
    func testCalculateBorrowAPY_withZeroUtilization_returnsCompoundedBaseRate() throws {
        // Given
        let zeroUtilizationAsset = createTestAssetData(totalBorrowed: 0)
        
        // When
        let apr = try zeroUtilizationAsset.calculateBorrowAPR()
        let apy = try zeroUtilizationAsset.calculateBorrowAPY()
        
        // Then
        XCTAssertGreaterThan(apy, apr, "APY should be higher than APR even at base rate")
    }
    
    // MARK: - Validation Tests
    
    func testValidateInputs_withZeroTotalSupplied_throwsError() {
        // Given
        let invalidAsset = createTestAssetData(totalSupplied: 0)
        
        // When/Then
        XCTAssertThrowsError(try invalidAsset.validateInputs(backstopTakeRate: nil)) { error in
            XCTAssertTrue(error is BlendError)
            if case .validation(.invalidInput) = error as? BlendError {
                // Expected error
            } else {
                XCTFail("Expected validation.invalidInput error")
            }
        }
    }
    
    func testValidateInputs_withNegativeTotalBorrowed_throwsError() {
        // Given
        let invalidAsset = createTestAssetData(totalBorrowed: -100)
        
        // When/Then
        XCTAssertThrowsError(try invalidAsset.validateInputs(backstopTakeRate: nil)) { error in
            XCTAssertTrue(error is BlendError)
            if case .validation(.invalidInput) = error as? BlendError {
                // Expected error
            } else {
                XCTFail("Expected validation.invalidInput error")
            }
        }
    }
    
    func testValidateInputs_withExcessiveUtilization_throwsError() {
        // Given - Create asset with > 100% utilization (impossible but for testing)
        let invalidAsset = createTestAssetData(totalSupplied: 100, totalBorrowed: 200)
        
        // When/Then
        XCTAssertThrowsError(try invalidAsset.validateInputs(backstopTakeRate: nil)) { error in
            XCTAssertTrue(error is BlendError)
            if case .validation(.outOfBounds) = error as? BlendError {
                // Expected error
            } else {
                XCTFail("Expected validation.outOfBounds error")
            }
        }
    }
    
    // MARK: - Utilization Rate Tests
    
    func testCalculateUtilizationRate_withValidData_returnsCorrectRate() throws {
        // Given
        let asset = createTestAssetData(totalSupplied: 1000, totalBorrowed: 250)
        
        // When
        let utilization = try asset.calculateUtilizationRate()
        
        // Then
        let expectedUtilization: Decimal = 250 / (1000 + 250) // 0.2 or 20%
        XCTAssertEqual(utilization, expectedUtilization, accuracy: 0.001, "Utilization should be 20%")
    }
    
    func testCalculateUtilizationRate_withZeroBorrowed_returnsZero() throws {
        // Given
        let asset = createTestAssetData(totalSupplied: 1000, totalBorrowed: 0)
        
        // When
        let utilization = try asset.calculateUtilizationRate()
        
        // Then
        XCTAssertEqual(utilization, 0, "Utilization should be zero with no borrowing")
    }
    
    func testCalculateUtilizationRate_withZeroTotal_returnsZero() throws {
        // Given
        let asset = createTestAssetData(totalSupplied: 0, totalBorrowed: 0)
        
        // When
        let utilization = try asset.calculateUtilizationRate()
        
        // Then
        XCTAssertEqual(utilization, 0, "Utilization should be zero with no assets")
    }
    
    // MARK: - Kinked Interest Rate Tests
    
    func testCalculateKinkedInterestRate_firstSlope_calculatesCorrectly() throws {
        // Given - Low utilization (below target)
        let lowUtilization: Decimal = 0.4 // 40%
        
        // When
        let result = try testAssetData.calculateKinkedInterestRate(utilization: lowUtilization)
        
        // Then
        XCTAssertGreaterThan(result, 0, "Interest rate should be positive")
        
        // Should be in first slope range
        let baseRate = FixedMath.toFloat(value: testAssetData.rBase, decimals: 7)
        let maxFirstSlope = baseRate + FixedMath.toFloat(value: testAssetData.rOne, decimals: 7)
        XCTAssertLessThanOrEqual(result, maxFirstSlope, "Should be within first slope range")
    }
    
    func testCalculateKinkedInterestRate_secondSlope_calculatesCorrectly() throws {
        // Given - Medium utilization (above target, below emergency)
        let mediumUtilization: Decimal = 0.85 // 85%
        
        // When
        let result = try testAssetData.calculateKinkedInterestRate(utilization: mediumUtilization)
        
        // Then
        XCTAssertGreaterThan(result, 0, "Interest rate should be positive")
        
        // Should be higher than first slope maximum
        let baseRate = FixedMath.toFloat(value: testAssetData.rBase, decimals: 7)
        let firstSlopeMax = baseRate + FixedMath.toFloat(value: testAssetData.rOne, decimals: 7)
        XCTAssertGreaterThan(result, firstSlopeMax, "Should be higher than first slope")
    }
    
    func testCalculateKinkedInterestRate_thirdSlope_calculatesCorrectly() throws {
        // Given - High utilization (emergency level)
        let highUtilization: Decimal = 0.98 // 98%
        
        // When
        let result = try testAssetData.calculateKinkedInterestRate(utilization: highUtilization)
        
        // Then
        XCTAssertGreaterThan(result, 0, "Interest rate should be positive")
        
        // Should be significantly higher due to emergency rates
        let baseRate = FixedMath.toFloat(value: testAssetData.rBase, decimals: 7)
        let secondSlopeMax = baseRate + FixedMath.toFloat(value: testAssetData.rOne, decimals: 7) + FixedMath.toFloat(value: testAssetData.rTwo, decimals: 7)
        XCTAssertGreaterThan(result, secondSlopeMax, "Should be in emergency rate territory")
    }
    
    func testCalculateKinkedInterestRate_withZeroUtilization_returnsBaseRate() throws {
        // Given
        let zeroUtilization: Decimal = 0
        
        // When
        let result = try testAssetData.calculateKinkedInterestRate(utilization: zeroUtilization)
        
        // Then
        let expectedBaseRate = FixedMath.toFloat(value: testAssetData.rBase, decimals: 7)
        XCTAssertEqual(result, expectedBaseRate, accuracy: 0.0001, "Should return base rate for zero utilization")
    }
    
    func testCalculateKinkedInterestRate_withNegativeUtilization_throwsError() {
        // Given
        let negativeUtilization: Decimal = -0.1
        
        // When/Then
        XCTAssertThrowsError(try testAssetData.calculateKinkedInterestRate(utilization: negativeUtilization)) { error in
            XCTAssertTrue(error is BlendError)
            if case .validation(.invalidInput) = error as? BlendError {
                // Expected error
            } else {
                XCTFail("Expected validation.invalidInput error")
            }
        }
    }
    
    // MARK: - APR to APY Conversion Tests
    
    func testConvertAPRtoAPY_withValidInputs_returnsCorrectAPY() throws {
        // Given
        let apr: Decimal = 0.05 // 5%
        let compoundingPeriods = 52 // Weekly
        
        // When
        let result = try testAssetData.convertAPRtoAPY(apr, compoundingPeriods: compoundingPeriods)
        
        // Then
        XCTAssertGreaterThan(result, apr, "APY should be higher than APR")
        XCTAssertLessThan(result, 0.06, "APY should be reasonable for 5% APR")
    }
    
    func testConvertAPRtoAPY_withZeroAPR_returnsZero() throws {
        // Given
        let apr: Decimal = 0
        let compoundingPeriods = 52
        
        // When
        let result = try testAssetData.convertAPRtoAPY(apr, compoundingPeriods: compoundingPeriods)
        
        // Then
        XCTAssertEqual(result, 0, "APY should be zero when APR is zero")
    }
    
    func testConvertAPRtoAPY_withHighAPR_appliesCap() throws {
        // Given
        let extremeAPR: Decimal = 50 // 5000%
        let compoundingPeriods = 365
        
        // When
        let result = try testAssetData.convertAPRtoAPY(extremeAPR, compoundingPeriods: compoundingPeriods)
        
        // Then
        XCTAssertLessThanOrEqual(result, 100, "APY should be capped at 10000%")
    }
    
    func testConvertAPRtoAPY_withNegativeAPR_throwsError() {
        // Given
        let negativeAPR: Decimal = -0.05
        let compoundingPeriods = 52
        
        // When/Then
        XCTAssertThrowsError(try testAssetData.convertAPRtoAPY(negativeAPR, compoundingPeriods: compoundingPeriods)) { error in
            XCTAssertTrue(error is BlendError)
            if case .validation(.invalidInput) = error as? BlendError {
                // Expected error
            } else {
                XCTFail("Expected validation.invalidInput error")
            }
        }
    }
    
    func testConvertAPRtoAPY_withZeroCompoundingPeriods_throwsError() {
        // Given
        let apr: Decimal = 0.05
        let invalidPeriods = 0
        
        // When/Then
        XCTAssertThrowsError(try testAssetData.convertAPRtoAPY(apr, compoundingPeriods: invalidPeriods)) { error in
            XCTAssertTrue(error is BlendError)
            if case .validation(.invalidInput) = error as? BlendError {
                // Expected error
            } else {
                XCTFail("Expected validation.invalidInput error")
            }
        }
    }
    
    // MARK: - Mathematical Accuracy Tests
    
    func testMathematicalAccuracy_compoundInterestFormula() throws {
        // Given - Known values for verification
        let apr: Decimal = 0.05 // 5%
        let periods = 12 // Monthly compounding
        
        // When
        let calculatedAPY = try testAssetData.convertAPRtoAPY(apr, compoundingPeriods: periods)
        
        // Then - Manual calculation: (1 + 0.05/12)^12 - 1 ≈ 0.051162
        let expectedAPY: Decimal = 0.051162
        XCTAssertEqual(calculatedAPY, expectedAPY, accuracy: 0.0001, "APY calculation should match manual calculation")
    }
    
    func testMathematicalAccuracy_utilizationCalculation() throws {
        // Given
        let asset = createTestAssetData(totalSupplied: 800, totalBorrowed: 200)
        
        // When
        let utilization = try asset.calculateUtilizationRate()
        
        // Then - Manual calculation: 200 / (800 + 200) = 0.2
        XCTAssertEqual(utilization, 0.2, accuracy: 0.0001, "Utilization should be exactly 20%")
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_calculateSupplyAPY() {
        // Given
        let backstopRate = FixedMath.toFixed(value: 0.20, decimals: 7)
        
        // When/Then
        measure {
            for _ in 0..<100 {
                _ = try! testAssetData.calculateSupplyAPY(backstopTakeRate: backstopRate)
            }
        }
    }
    
    func testPerformance_calculateBorrowAPY() {
        // When/Then
        measure {
            for _ in 0..<100 {
                _ = try! testAssetData.calculateBorrowAPY()
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEdgeCase_veryLowUtilization() throws {
        // Given
        let asset = createTestAssetData(totalSupplied: 1_000_000, totalBorrowed: 1) // ~0.0001% utilization
        let backstopRate = FixedMath.toFixed(value: 0.20, decimals: 7)
        
        // When
        let supplyAPR = try asset.calculateSupplyAPR(backstopTakeRate: backstopRate)
        let borrowAPR = try asset.calculateBorrowAPR()
        
        // Then
        XCTAssertGreaterThan(supplyAPR, 0, "Supply APR should be positive even with very low utilization")
        XCTAssertGreaterThan(borrowAPR, 0, "Borrow APR should be positive even with very low utilization")
    }
    
    func testEdgeCase_nearMaxUtilization() throws {
        // Given
        let asset = createTestAssetData(totalSupplied: 1000, totalBorrowed: 949) // 94.9% utilization
        let backstopRate = FixedMath.toFixed(value: 0.20, decimals: 7)
        
        // When
        let supplyAPR = try asset.calculateSupplyAPR(backstopTakeRate: backstopRate)
        let borrowAPR = try asset.calculateBorrowAPR()
        
        // Then
        XCTAssertGreaterThan(supplyAPR, 0, "Supply APR should handle near-max utilization")
        XCTAssertGreaterThan(borrowAPR, 0, "Borrow APR should handle near-max utilization")
        XCTAssertLessThan(supplyAPR, 1000, "Supply APR should be reasonable even at high utilization")
        XCTAssertLessThan(borrowAPR, 1000, "Borrow APR should be reasonable even at high utilization")
    }
    
    // MARK: - Helper Methods
    
    private func createTestAssetData(
        totalSupplied: Decimal = 25324.25,
        totalBorrowed: Decimal = 18957,
        rBase: Decimal = 50_000, // 0.5%
        rOne: Decimal = 400_000, // 4%
        rTwo: Decimal = 2_000_000, // 20%
        rThree: Decimal = 10_000_000, // 100%
        utilTarget: Decimal = 0.75, // 75%
        maxUtil: Decimal = 0.95, // 95%
        irModifier: Decimal = 3_003_262 // ~30%
    ) -> BlendAssetData {
        return BlendAssetData(
            assetId: "test_asset_id",
            scalar: 10_000_000, // 1e7
            decimals: 7,
            enabled: true,
            index: 0,
            cFactor: 0.95,
            lFactor: 0.95,
            maxUtil: maxUtil,
            rBase: rBase,
            rOne: rOne,
            rTwo: rTwo,
            rThree: rThree,
            reactivity: 100_000,
            supplyCap: 1_000_000,
            utilTarget: utilTarget,
            totalSupplied: totalSupplied,
            totalBorrowed: totalBorrowed,
            borrowRate: 8.5, // Not used in calculations
            supplyRate: 4.2, // Not used in calculations
            backstopCredit: 2.1138979,
            irModifier: irModifier,
            lastUpdate: Date()
        )
    }
} 