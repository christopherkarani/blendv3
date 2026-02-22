//
//  ValidationServiceTests.swift
//  Blendv3Tests
//
//  Unit tests for ValidationService
//

import XCTest
@testable import Blendv3

final class ValidationServiceTests: XCTestCase {
    
    var sut: ValidationService!
    
    override func setUp() {
        super.setUp()
        sut = ValidationService()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - User Input Validation Tests
    
    func testValidateUserInput_ValidDepositAmount_Succeeds() throws {
        // Given
        let amount = Decimal(100)
        let rules = ValidationRules.depositAmount
        
        // When/Then - Should not throw
        XCTAssertNoThrow(try sut.validateUserInput(amount, rules: rules))
    }
    
    func testValidateUserInput_BelowMinimum_ThrowsOutOfBounds() {
        // Given
        let amount = Decimal(0.001) // Below 0.01 minimum
        let rules = ValidationRules.depositAmount
        
        // When/Then
        XCTAssertThrowsError(try sut.validateUserInput(amount, rules: rules)) { error in
            guard let blendError = error as? BlendError,
                  case .validation(.outOfBounds) = blendError else {
                XCTFail("Expected validation out of bounds error")
                return
            }
        }
    }
    
    func testValidateUserInput_AboveMaximum_ThrowsOutOfBounds() {
        // Given
        let amount = Decimal(2_000_000) // Above 1M maximum
        let rules = ValidationRules.depositAmount
        
        // When/Then
        XCTAssertThrowsError(try sut.validateUserInput(amount, rules: rules)) { error in
            guard let blendError = error as? BlendError,
                  case .validation(.outOfBounds) = blendError else {
                XCTFail("Expected validation out of bounds error")
                return
            }
        }
    }
    
    // MARK: - I128 Validation Tests
    
    func testValidateI128_PositiveValue_ReturnsCorrectDecimal() throws {
        // Given
        let i128 = Int128PartsXDR(hi: 0, lo: 10_000_000) // 1 USDC
        
        // When
        let result = try sut.validateI128(i128)
        
        // Then
        XCTAssertEqual(result, Decimal(10_000_000))
    }
    
    func testValidateI128_NegativeValue_ReturnsCorrectDecimal() throws {
        // Given
        let i128 = Int128PartsXDR(hi: -1, lo: UInt64.max - 10_000_000 + 1)
        
        // When
        let result = try sut.validateI128(i128)
        
        // Then
        XCTAssertEqual(result, Decimal(-10_000_000))
    }
    
    func testValidateI128_Overflow_ThrowsIntegerOverflow() {
        // Given
        let i128 = Int128PartsXDR(hi: Int64.max, lo: UInt64.max)
        
        // When/Then
        XCTAssertThrowsError(try sut.validateI128(i128)) { error in
            guard let blendError = error as? BlendError,
                  case .validation(.integerOverflow) = blendError else {
                XCTFail("Expected integer overflow error")
                return
            }
        }
    }
    
    // MARK: - Price Data Validation Tests
    
    func testValidatePriceData_ValidData_Succeeds() throws {
        // Given
        let priceData = PriceData(
            assetId: "test",
            price: Decimal(1.5),
            timestamp: Date(),
            decimals: 7
        )
        
        // When/Then - Should not throw
        XCTAssertNoThrow(try sut.validateContractResponse(priceData, schema: .priceData))
    }
    
    func testValidatePriceData_NegativePrice_ThrowsInvalidResponse() {
        // Given
        let priceData = PriceData(
            assetId: "test",
            price: Decimal(-1),
            timestamp: Date(),
            decimals: 7
        )
        
        // When/Then
        XCTAssertThrowsError(try sut.validateContractResponse(priceData, schema: .priceData)) { error in
            guard let blendError = error as? BlendError,
                  case .validation(.invalidResponse) = blendError else {
                XCTFail("Expected invalid response error")
                return
            }
        }
    }
    
    func testValidatePriceData_FutureTimestamp_ThrowsInvalidResponse() {
        // Given
        let futureDate = Date().addingTimeInterval(3600) // 1 hour in future
        let priceData = PriceData(
            assetId: "test",
            price: Decimal(1),
            timestamp: futureDate,
            decimals: 7
        )
        
        // When/Then
        XCTAssertThrowsError(try sut.validateContractResponse(priceData, schema: .priceData)) { error in
            guard let blendError = error as? BlendError,
                  case .validation(.invalidResponse) = blendError else {
                XCTFail("Expected invalid response error")
                return
            }
        }
    }
    
    // MARK: - Reserve Data Validation Tests
    
    func testValidateReserveData_ValidData_Succeeds() throws {
        // Given
        let reserveData = ReserveDataResult(
            totalSupplied: Decimal(1_000_000),
            totalBorrowed: Decimal(500_000),
            supplyAPY: Decimal(5),
            borrowAPY: Decimal(8),
            utilizationRate: Decimal(0.5)
        )
        
        // When/Then - Should not throw
        XCTAssertNoThrow(try sut.validateContractResponse(reserveData, schema: .reserveData))
    }
    
    func testValidateReserveData_BorrowedExceedsSupplied_ThrowsInvalidResponse() {
        // Given
        let reserveData = ReserveDataResult(
            totalSupplied: Decimal(100_000),
            totalBorrowed: Decimal(200_000), // More than supplied
            supplyAPY: Decimal(5),
            borrowAPY: Decimal(8),
            utilizationRate: Decimal(2.0)
        )
        
        // When/Then
        XCTAssertThrowsError(try sut.validateContractResponse(reserveData, schema: .reserveData)) { error in
            guard let blendError = error as? BlendError,
                  case .validation(.invalidResponse) = blendError else {
                XCTFail("Expected invalid response error")
                return
            }
        }
    }
    
    func testValidateReserveData_InvalidUtilizationRate_ThrowsInvalidResponse() {
        // Given
        let reserveData = ReserveDataResult(
            totalSupplied: Decimal(100_000),
            totalBorrowed: Decimal(50_000),
            supplyAPY: Decimal(5),
            borrowAPY: Decimal(8),
            utilizationRate: Decimal(1.5) // > 1.0
        )
        
        // When/Then
        XCTAssertThrowsError(try sut.validateContractResponse(reserveData, schema: .reserveData)) { error in
            guard let blendError = error as? BlendError,
                  case .validation(.invalidResponse) = blendError else {
                XCTFail("Expected invalid response error")
                return
            }
        }
    }
    
    // MARK: - Transaction Result Validation Tests
    
    func testValidateTransactionResult_ValidHash_Succeeds() throws {
        // Given
        let txHash = "a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890"
        
        // When/Then - Should not throw
        XCTAssertNoThrow(try sut.validateContractResponse(txHash, schema: .transactionResult))
    }
    
    func testValidateTransactionResult_InvalidLength_ThrowsInvalidResponse() {
        // Given
        let txHash = "abc123" // Too short
        
        // When/Then
        XCTAssertThrowsError(try sut.validateContractResponse(txHash, schema: .transactionResult)) { error in
            guard let blendError = error as? BlendError,
                  case .validation(.invalidResponse) = blendError else {
                XCTFail("Expected invalid response error")
                return
            }
        }
    }
    
    func testValidateTransactionResult_InvalidCharacters_ThrowsInvalidResponse() {
        // Given
        let txHash = "xyz!@#$%^&*()_+xyz!@#$%^&*()_+xyz!@#$%^&*()_+xyz!@#$%^&*()_+xy"
        
        // When/Then
        XCTAssertThrowsError(try sut.validateContractResponse(txHash, schema: .transactionResult)) { error in
            guard let blendError = error as? BlendError,
                  case .validation(.invalidResponse) = blendError else {
                XCTFail("Expected invalid response error")
                return
            }
        }
    }
} 