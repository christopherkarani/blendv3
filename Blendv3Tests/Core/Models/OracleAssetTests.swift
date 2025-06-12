import XCTest
import stellarsdk
@testable import Blendv3

final class OracleAssetTests: XCTestCase {
    
    // Test constant values
    private let stellarAddress = "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD"
    private let otherSymbol = "ETH"
    
    // MARK: - Initialization Tests
    
    func testStellarAssetInitialization() {
        // Given & When
        let asset = OracleAsset.stellar(address: stellarAddress)
        
        // Then
        if case .stellar(let address) = asset {
            XCTAssertEqual(address, stellarAddress)
        } else {
            XCTFail("Expected stellar asset case")
        }
    }
    
    func testOtherAssetInitialization() {
        // Given & When
        let asset = OracleAsset.other(symbol: otherSymbol)
        
        // Then
        if case .other(let symbol) = asset {
            XCTAssertEqual(symbol, otherSymbol)
        } else {
            XCTFail("Expected other asset case")
        }
    }
    
    // MARK: - Codable Tests
    
    func testCodableConformance() {
        // Given
        let stellarAsset = OracleAsset.stellar(address: stellarAddress)
        let otherAsset = OracleAsset.other(symbol: otherSymbol)
        
        // When
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Then - Test Stellar asset
        do {
            let encodedData = try encoder.encode(stellarAsset)
            let decodedAsset = try decoder.decode(OracleAsset.self, from: encodedData)
            
            if case .stellar(let address) = decodedAsset {
                XCTAssertEqual(address, stellarAddress)
            } else {
                XCTFail("Expected stellar asset case after decoding")
            }
        } catch {
            XCTFail("Failed to encode/decode stellar asset: \(error)")
        }
        
        // Then - Test Other asset
        do {
            let encodedData = try encoder.encode(otherAsset)
            let decodedAsset = try decoder.decode(OracleAsset.self, from: encodedData)
            
            if case .other(let symbol) = decodedAsset {
                XCTAssertEqual(symbol, otherSymbol)
            } else {
                XCTFail("Expected other asset case after decoding")
            }
        } catch {
            XCTFail("Failed to encode/decode other asset: \(error)")
        }
    }
    
    // MARK: - SCValXDR Conversion Tests
    
    func testStellarAssetToSCVal() {
        // Given
        let asset = OracleAsset.stellar(address: stellarAddress)
        
        // When
        let scVal = asset.toSCVal()
        
        // Then
        if case .vec(let vec) = scVal {
            XCTAssertEqual(vec.count, 2)
            
            if case .symbol(let discriminant) = vec[0] {
                XCTAssertEqual(discriminant, "Stellar")
            } else {
                XCTFail("Expected symbol discriminant")
            }
            
            if case .address(let address) = vec[1] {
                // Check that the address is correctly encoded in the SCVal
                XCTAssertEqual(address.discriminant, SCAddressXDR.Discriminant.contract)
            } else {
                XCTFail("Expected address value")
            }
        } else {
            XCTFail("Expected SCVal of type vec")
        }
    }
    
    func testOtherAssetToSCVal() {
        // Given
        let asset = OracleAsset.other(symbol: otherSymbol)
        
        // When
        let scVal = asset.toSCVal()
        
        // Then
        if case .vec(let vec) = scVal {
            XCTAssertEqual(vec.count, 2)
            
            if case .symbol(let discriminant) = vec[0] {
                XCTAssertEqual(discriminant, "Other")
            } else {
                XCTFail("Expected symbol discriminant")
            }
            
            if case .symbol(let symbol) = vec[1] {
                XCTAssertEqual(symbol, otherSymbol)
            } else {
                XCTFail("Expected symbol value")
            }
        } else {
            XCTFail("Expected SCVal of type vec")
        }
    }
    
    func testAssetFromSCVal() {
        // Test Stellar asset
        do {
            // Given
            let address = SCAddressXDR.contract(Data(repeating: 0, count: 32))
            let vecValues: [SCValXDR] = [.symbol("Stellar"), .address(address)]
            let scVal = SCValXDR.vec(vecValues)
            
            // When
            let asset = try OracleAsset.fromSCVal(scVal)
            
            // Then
            if case .stellar = asset {
                // Success - we're just checking the case, not the exact address here
            } else {
                XCTFail("Expected stellar asset case")
            }
        } catch {
            XCTFail("Failed to create OracleAsset from SCVal: \(error)")
        }
        
        // Test Other asset
        do {
            // Given
            let vecValues: [SCValXDR] = [.symbol("Other"), .symbol(otherSymbol)]
            let scVal = SCValXDR.vec(vecValues)
            
            // When
            let asset = try OracleAsset.fromSCVal(scVal)
            
            // Then
            if case .other(let symbol) = asset {
                XCTAssertEqual(symbol, otherSymbol)
            } else {
                XCTFail("Expected other asset case")
            }
        } catch {
            XCTFail("Failed to create OracleAsset from SCVal: \(error)")
        }
    }
    
    // MARK: - String Representation Tests
    
    func testStringRepresentation() {
        // Given
        let stellarAsset = OracleAsset.stellar(address: stellarAddress)
        let otherAsset = OracleAsset.other(symbol: otherSymbol)
        
        // When & Then
        XCTAssertEqual(stellarAsset.description, "Stellar(\(stellarAddress))")
        XCTAssertEqual(otherAsset.description, "Other(\(otherSymbol))")
    }
    
    // MARK: - Equatable Tests
    
    func testEquality() {
        // Given
        let asset1 = OracleAsset.stellar(address: stellarAddress)
        let asset2 = OracleAsset.stellar(address: stellarAddress)
        let asset3 = OracleAsset.stellar(address: "DIFFERENT_ADDRESS")
        let asset4 = OracleAsset.other(symbol: otherSymbol)
        
        // When & Then
        XCTAssertEqual(asset1, asset2)
        XCTAssertNotEqual(asset1, asset3)
        XCTAssertNotEqual(asset1, asset4)
    }
}
