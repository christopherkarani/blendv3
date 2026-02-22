import XCTest
@testable import Blendv3

final class OraclePriceTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        // Given
        let price = Decimal(string: "1.25")!
        let timestamp = Date()
        let decimals = 6
        let resolution = 10
        
        // When
        let oraclePrice = OraclePrice(
            price: price,
            timestamp: timestamp,
            decimals: decimals,
            resolution: resolution
        )
        
        // Then
        XCTAssertEqual(oraclePrice.price, price)
        XCTAssertEqual(oraclePrice.timestamp, timestamp)
        XCTAssertEqual(oraclePrice.decimals, decimals)
        XCTAssertEqual(oraclePrice.resolution, resolution)
    }
    
    func testScaledPrice() {
        // Given - price with decimals = 6, resolution = 10
        let oraclePrice = OraclePrice(
            price: Decimal(string: "1.25")!,
            timestamp: Date(),
            decimals: 6,
            resolution: 10
        )
        
        // When
        let scaled = oraclePrice.scaledPrice
        
        // Then - should be 1.25 * 10^6 * 10 = 12,500,000
        XCTAssertEqual(scaled, 12_500_000)
        
        // Given - different decimals and resolution
        let oraclePrice2 = OraclePrice(
            price: Decimal(string: "0.005")!,
            timestamp: Date(),
            decimals: 3,
            resolution: 100
        )
        
        // When
        let scaled2 = oraclePrice2.scaledPrice
        
        // Then - should be 0.005 * 10^3 * 100 = 500
        XCTAssertEqual(scaled2, 500)
    }
    
    func testConversionToI128() {
        // Given
        let oraclePrice = OraclePrice(
            price: Decimal(string: "1.25")!,
            timestamp: Date(),
            decimals: 6,
            resolution: 10
        )
        
        // When
        let i128Value = oraclePrice.toI128()
        
        // Then
        // For Int128, we expect it to be properly scaled by decimals and resolution
        XCTAssertEqual(i128Value.hi, 0) // High bits should be 0 for small numbers
        XCTAssertEqual(i128Value.lo, 12_500_000) // Low bits should contain our value
    }
    
    func testLargeNumberConversion() {
        // Given - a large number that would use high bits in i128
        let largePrice = OraclePrice(
            price: Decimal(string: "10000000000.0")!, // 10 billion
            timestamp: Date(),
            decimals: 6,
            resolution: 10
        )
        
        // When
        let i128Value = largePrice.toI128()
        
        // Then
        // 10 billion * 10^6 * 10 = 10^17
        // This would still fit in the low bits of i128
        XCTAssertEqual(i128Value.hi, 0)
        XCTAssertEqual(i128Value.lo, 100_000_000_000_000_000)
    }
    
    func testFromI128() {
        // Given
        let i128Parts = Int128PartsXDR(hi: 0, lo: 12_500_000)
        let timestamp = UInt64(Date().timeIntervalSince1970)
        let decimals = 6
        let resolution = 10
        
        // When
        let oraclePrice = OraclePrice.fromI128(
            price: i128Parts,
            timestamp: timestamp,
            decimals: decimals,
            resolution: resolution
        )
        
        // Then
        XCTAssertEqual(oraclePrice.price, Decimal(string: "1.25"))
        XCTAssertEqual(oraclePrice.decimals, decimals)
        XCTAssertEqual(oraclePrice.resolution, resolution)
    }
    
    func testDisplayFormatting() {
        // Given
        let price = OraclePrice(
            price: Decimal(string: "1234.5678")!,
            timestamp: Date(),
            decimals: 4,
            resolution: 10
        )
        
        // When & Then
        XCTAssertEqual(price.formattedPrice, "$1,234.57")
        
        // Given - price with different decimals
        let price2 = OraclePrice(
            price: Decimal(string: "0.00123")!,
            timestamp: Date(),
            decimals: 6,
            resolution: 100
        )
        
        // When & Then
        XCTAssertEqual(price2.formattedPrice, "$0.00123")
    }
}
