//
//  BlendParserTests.swift
//  Blendv3Tests
//
//  Unit tests for BlendParser demonstrating improved testability
//

import XCTest
@testable import Blendv3

final class BlendParserTests: XCTestCase {
    
    private var sut: BlendParser!
    
    override func setUp() {
        super.setUp()
        sut = BlendParser()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Generic Parsing Tests
    
    func testParseValidJSON() {
        // Given
        let json = """
        {
            "id": 123,
            "name": "Test Item",
            "is_active": true
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let result = sut.parse(data, type: TestItem.self)
        
        // Then
        switch result {
        case .success(let item):
            XCTAssertEqual(item.id, 123)
            XCTAssertEqual(item.name, "Test Item")
            XCTAssertTrue(item.isActive)
        case .failure:
            XCTFail("Parsing should succeed")
        }
    }
    
    func testParseMissingRequiredField() {
        // Given
        let json = """
        {
            "id": 123,
            "is_active": true
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let result = sut.parse(data, type: TestItem.self)
        
        // Then
        switch result {
        case .success:
            XCTFail("Parsing should fail")
        case .failure(let error):
            if case .missingRequiredField(let field) = error {
                XCTAssertEqual(field, "name")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    // MARK: - Contract Response Parsing Tests
    
    func testParseValidContractResponse() {
        // Given
        let json = """
        {
            "transaction_hash": "0x123abc",
            "block_number": 12345,
            "gas_used": 21000,
            "status": true
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let result = sut.parseContractResponse(data)
        
        // Then
        switch result {
        case .success(let response):
            XCTAssertEqual(response.transactionHash, "0x123abc")
            XCTAssertEqual(response.blockNumber, 12345)
            XCTAssertEqual(response.gasUsed, 21000)
            XCTAssertTrue(response.status)
        case .failure:
            XCTFail("Parsing should succeed")
        }
    }
    
    func testParseInvalidContractResponse() {
        // Given
        let json = """
        {
            "transaction_hash": "",
            "block_number": -1,
            "gas_used": -100,
            "status": false
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let result = sut.parseContractResponse(data)
        
        // Then
        switch result {
        case .success:
            XCTFail("Parsing should fail validation")
        case .failure(let error):
            if case .validationFailed = error {
                // Expected
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    // MARK: - Oracle Data Parsing Tests
    
    func testParseValidOracleData() {
        // Given
        let json = """
        {
            "timestamp": "2025-05-22T10:00:00.000Z",
            "value": 123.45,
            "source": "Chainlink",
            "confidence": 0.95
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let result = sut.parseOracleData(data)
        
        // Then
        switch result {
        case .success(let oracleData):
            XCTAssertEqual(oracleData.value, 123.45)
            XCTAssertEqual(oracleData.source, "Chainlink")
            XCTAssertEqual(oracleData.confidence, 0.95)
        case .failure:
            XCTFail("Parsing should succeed")
        }
    }
    
    func testParseOracleDataWithUnixTimestamp() {
        // Given
        let json = """
        {
            "timestamp": 1716372000,
            "value": 123.45,
            "source": "Chainlink",
            "confidence": 0.95
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let result = sut.parseOracleData(data)
        
        // Then
        switch result {
        case .success(let oracleData):
            XCTAssertEqual(oracleData.timestamp.timeIntervalSince1970, 1716372000)
        case .failure:
            XCTFail("Parsing should succeed")
        }
    }
    
    // MARK: - Transformation Tests
    
    func testTransformSuccess() {
        // Given
        let input = "0xFF"
        let transformer: (String) throws -> Int = { hex in
            guard hex.hasPrefix("0x") else {
                throw ParserError.invalidFormat("Not a hex string")
            }
            return Int(hex.dropFirst(2), radix: 16) ?? 0
        }
        
        // When
        let result = sut.transform(input, using: transformer)
        
        // Then
        switch result {
        case .success(let value):
            XCTAssertEqual(value, 255)
        case .failure:
            XCTFail("Transformation should succeed")
        }
    }
    
    func testHexToDecimalTransformer() {
        // Given
        let transformer = HexToDecimalTransformer()
        
        // When
        let result1 = try? transformer.transform("0xFF")
        let result2 = try? transformer.transform("0x100")
        
        // Then
        XCTAssertEqual(result1, 255)
        XCTAssertEqual(result2, 256)
    }
    
    func testWeiToEtherTransformer() {
        // Given
        let transformer = WeiToEtherTransformer()
        
        // When
        let result = try? transformer.transform("1000000000000000000")
        
        // Then
        XCTAssertEqual(result, 1.0) // 1 Ether
    }
    
    // MARK: - Validation Tests
    
    func testValidateSuccess() {
        // Given
        let price = 100.0
        
        // When
        let result = sut.validate(price, using: { $0 > 0 }, errorMessage: "Price must be positive")
        
        // Then
        switch result {
        case .success(let validatedPrice):
            XCTAssertEqual(validatedPrice, 100.0)
        case .failure:
            XCTFail("Validation should succeed")
        }
    }
    
    func testValidateFailure() {
        // Given
        let price = -10.0
        
        // When
        let result = sut.validate(price, using: { $0 > 0 }, errorMessage: "Price must be positive")
        
        // Then
        switch result {
        case .success:
            XCTFail("Validation should fail")
        case .failure(let error):
            if case .validationFailed(let message) = error {
                XCTAssertEqual(message, "Price must be positive")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testAddressValidator() {
        // Given
        let validator = AddressValidator()
        
        // When
        let validResult = validator.validate("0x1234567890abcdef1234567890abcdef12345678")
        let invalidResult1 = validator.validate("1234567890abcdef1234567890abcdef12345678")
        let invalidResult2 = validator.validate("0x123")
        
        // Then
        XCTAssertTrue(validResult.isValid)
        XCTAssertFalse(invalidResult1.isValid)
        XCTAssertFalse(invalidResult2.isValid)
    }
    
    func testTransactionHashValidator() {
        // Given
        let validator = TransactionHashValidator()
        
        // When
        let validResult = validator.validate("0x" + String(repeating: "a", count: 64))
        let invalidResult = validator.validate("0x123")
        
        // Then
        XCTAssertTrue(validResult.isValid)
        XCTAssertFalse(invalidResult.isValid)
    }
    
    // MARK: - Batch Operations Tests
    
    func testParseBatch() {
        // Given
        let json1 = """
        {"id": 1, "name": "Item 1", "is_active": true}
        """
        let json2 = """
        {"id": 2, "name": "Item 2", "is_active": false}
        """
        let dataArray = [
            json1.data(using: .utf8)!,
            json2.data(using: .utf8)!
        ]
        
        // When
        let results = sut.parseBatch(dataArray, type: TestItem.self)
        
        // Then
        XCTAssertEqual(results.count, 2)
        
        if case .success(let item1) = results[0] {
            XCTAssertEqual(item1.id, 1)
        } else {
            XCTFail("First item should parse successfully")
        }
        
        if case .success(let item2) = results[1] {
            XCTAssertEqual(item2.id, 2)
        } else {
            XCTFail("Second item should parse successfully")
        }
    }
}

// MARK: - Test Models

private struct TestItem: Decodable {
    let id: Int
    let name: String
    let isActive: Bool
}