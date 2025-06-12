import XCTest
import stellarsdk
@testable import Blendv3

final class PriceDataTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        // Given
        let price = Decimal(string: "1.25")!
        let timestamp = Date()
        let asset = OracleAsset.stellar(address: "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD")
        let decimals = 6
        let resolution = 10
        
        // When
        let priceData = PriceData(
            price: price,
            timestamp: timestamp,
            asset: asset,
            decimals: decimals,
            resolution: resolution
        )
        
        // Then
        XCTAssertEqual(priceData.price, price)
        XCTAssertEqual(priceData.timestamp, timestamp)
        XCTAssertEqual(priceData.asset, asset)
        XCTAssertEqual(priceData.decimals, decimals)
        XCTAssertEqual(priceData.resolution, resolution)
    }
    
    func testLegacyInitialization() {
        // Given
        let price = Decimal(string: "1.25")!
        let timestamp = Date()
        let assetId = "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD"
        let decimals = 6
        
        // When
        let priceData = PriceData(
            price: price,
            timestamp: timestamp,
            assetId: assetId,
            decimals: decimals
        )
        
        // Then
        XCTAssertEqual(priceData.price, price)
        XCTAssertEqual(priceData.timestamp, timestamp)
        if case .stellar(let address) = priceData.asset {
            XCTAssertEqual(address, assetId)
        } else {
            XCTFail("Expected stellar asset")
        }
        XCTAssertEqual(priceData.decimals, decimals)
        XCTAssertEqual(priceData.resolution, 1) // Default resolution
        XCTAssertEqual(priceData.assetId, assetId) // Legacy accessor
    }
    
    func testFromContractPriceData() {
        // Given
        let priceI128 = Int128PartsXDR(hi: 0, lo: 12_500_000)
        let timestamp: UInt64 = 1714381985 // May 29, 2024
        let asset = OracleAsset.stellar(address: "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD")
        let decimals = 6
        let resolution = 10
        
        // When
        let priceData = PriceData.fromContractData(
            price: priceI128,
            timestamp: timestamp,
            asset: asset,
            decimals: decimals,
            resolution: resolution
        )
        
        // Then
        XCTAssertEqual(priceData.price, Decimal(string: "1.25"))
        XCTAssertEqual(priceData.timestamp, Date(timeIntervalSince1970: TimeInterval(timestamp)))
        XCTAssertEqual(priceData.asset, asset)
        XCTAssertEqual(priceData.decimals, decimals)
        XCTAssertEqual(priceData.resolution, resolution)
    }
    
    func testToContractPriceData() {
        // Given
        let priceData = PriceData(
            price: Decimal(string: "1.25")!,
            timestamp: Date(timeIntervalSince1970: 1714381985),
            asset: OracleAsset.stellar(address: "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD"),
            decimals: 6,
            resolution: 10
        )
        
        // When
        let (price, timestamp) = priceData.toContractData()
        
        // Then
        XCTAssertEqual(price.hi, 0)
        XCTAssertEqual(price.lo, 12_500_000)
        XCTAssertEqual(timestamp, UInt64(priceData.timestamp.timeIntervalSince1970))
    }
    
    func testCodable() {
        // Given
        let priceData = PriceData(
            price: Decimal(string: "1.25")!,
            timestamp: Date(timeIntervalSince1970: 1714381985),
            asset: OracleAsset.stellar(address: "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD"),
            decimals: 6,
            resolution: 10
        )
        
        // When
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Then
        do {
            let encodedData = try encoder.encode(priceData)
            let decodedPriceData = try decoder.decode(PriceData.self, from: encodedData)
            
            XCTAssertEqual(decodedPriceData.price, priceData.price)
            XCTAssertEqual(decodedPriceData.timestamp.timeIntervalSince1970,
                          priceData.timestamp.timeIntervalSince1970, accuracy: 0.001)
            XCTAssertEqual(decodedPriceData.asset, priceData.asset)
            XCTAssertEqual(decodedPriceData.decimals, priceData.decimals)
            XCTAssertEqual(decodedPriceData.resolution, priceData.resolution)
        } catch {
            XCTFail("Failed to encode/decode PriceData: \(error)")
        }
    }
    
    func testPriceInUSD() {
        // Given
        let priceData = PriceData(
            price: Decimal(string: "1.25")!,
            timestamp: Date(),
            asset: OracleAsset.stellar(address: "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD"),
            decimals: 6,
            resolution: 10
        )
        
        // When & Then
        XCTAssertEqual(priceData.priceInUSD, Decimal(string: "1.25"))
    }
    
    func testIsStale() {
        // Given
        let oldTimestamp = Date(timeIntervalSinceNow: -600) // 10 minutes ago
        let priceData = PriceData(
            price: Decimal(string: "1.25")!,
            timestamp: oldTimestamp,
            asset: OracleAsset.stellar(address: "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD"),
            decimals: 6,
            resolution: 10
        )
        
        // When & Then
        XCTAssertTrue(priceData.isStale(maxAge: 300)) // 5 minutes
        XCTAssertFalse(priceData.isStale(maxAge: 900)) // 15 minutes
    }
}
