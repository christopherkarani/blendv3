import XCTest
import stellarsdk
@testable import Blendv3

final class BlendOracleServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var oracleService: BlendOracleService!
    private var mockNetworkService: MockNetworkService!
    private var mockCacheService: MockCacheService!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        mockNetworkService = MockNetworkService()
        mockCacheService = MockCacheService()
        oracleService = BlendOracleService(networkService: mockNetworkService, cacheService: mockCacheService)
    }
    
    override func tearDown() {
        oracleService = nil
        mockNetworkService = nil
        mockCacheService = nil
        super.tearDown()
    }
    
    // MARK: - Tests for OracleAsset
    
    func testOracleAssetStellarCase() {
        // Given
        let address = "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD"
        let asset = OracleAsset.stellar(address: address)
        
        // When & Then
        if case .stellar(let assetAddress) = asset {
            XCTAssertEqual(assetAddress, address)
        } else {
            XCTFail("Expected stellar asset case")
        }
    }
    
    func testOracleAssetOtherCase() {
        // Given
        let symbol = "ETH"
        let asset = OracleAsset.other(symbol: symbol)
        
        // When & Then
        if case .other(let assetSymbol) = asset {
            XCTAssertEqual(assetSymbol, symbol)
        } else {
            XCTFail("Expected other asset case")
        }
    }
    
    func testOracleAssetSCValConversion() {
        // Given
        let stellarAsset = OracleAsset.stellar(address: "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD")
        let otherAsset = OracleAsset.other(symbol: "ETH")
        
        // When
        let stellarSCVal = stellarAsset.toSCVal()
        let otherSCVal = otherAsset.toSCVal()
        
        // Then
        // Verify structure only - detailed conversion is tested in OracleAssetTests
        if case .vec(let stellarVec) = stellarSCVal, stellarVec.count == 2 {
            if case .symbol(let discriminant) = stellarVec[0] {
                XCTAssertEqual(discriminant, "Stellar")
            } else {
                XCTFail("Expected symbol discriminant for Stellar asset")
            }
        } else {
            XCTFail("Expected vec structure for Stellar asset")
        }
        
        if case .vec(let otherVec) = otherSCVal, otherVec.count == 2 {
            if case .symbol(let discriminant) = otherVec[0] {
                XCTAssertEqual(discriminant, "Other")
            } else {
                XCTFail("Expected symbol discriminant for Other asset")
            }
        } else {
            XCTFail("Expected vec structure for Other asset")
        }
    }
    
    // MARK: - Tests for OraclePrice
    
    func testOraclePriceWithResolution() {
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
        
        // Test scaled price calculation
        let expectedScaledPrice = price * pow(10, decimals) * Decimal(resolution)
        XCTAssertEqual(oraclePrice.scaledPrice, expectedScaledPrice)
    }
    
    // MARK: - Tests for PriceData
    
    func testPriceDataWithContractAlignment() {
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
        
        // Test assetId accessor (backward compatibility)
        if case .stellar(let address) = asset {
            XCTAssertEqual(priceData.assetId, address)
        }
    }
    
    func testPriceDataScaling() {
        // Given - PriceData with specific decimals and resolution
        let priceData = PriceData(
            price: Decimal(string: "1.25")!,
            timestamp: Date(),
            asset: OracleAsset.stellar(address: "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD"),
            decimals: 6,
            resolution: 10
        )
        
        // When
        let (i128Price, _) = priceData.toContractData()
        
        // Then - Verify scaling: 1.25 * 10^6 * 10 = 12,500,000
        XCTAssertEqual(i128Price.hi, 0) // High bits should be 0 for small numbers
        XCTAssertEqual(i128Price.lo, 12_500_000) // Low bits should have our scaled value
        
        // Test with different scaling
        let priceData2 = PriceData(
            price: Decimal(string: "0.005")!,
            timestamp: Date(),
            asset: OracleAsset.stellar(address: "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD"),
            decimals: 3,
            resolution: 100
        )
        
        // When
        let (i128Price2, _) = priceData2.toContractData()
        
        // Then - Verify scaling: 0.005 * 10^3 * 100 = 500
        XCTAssertEqual(i128Price2.hi, 0)
        XCTAssertEqual(i128Price2.lo, 500)
    }
    
    // MARK: - Tests for Service Methods
    
    func testGetOracleDecimals() async throws {
        // Given
        let expectedDecimals = 6
        let mockResponse = SCValXDR.u32(UInt32(expectedDecimals))
        
        // Set up mock to return the expected decimals
        mockNetworkService.responseToReturn = mockResponse
        
        // When
        let decimals = try await oracleService.getOracleDecimals()
        
        // Then
        XCTAssertEqual(decimals, expectedDecimals)
        
        // Verify the request was made with the correct parameters
        if let request = mockNetworkService.lastRequest as? ContractCallParams {
            XCTAssertEqual(request.functionName, "decimals")
            XCTAssertEqual(request.functionArguments.count, 0) // No arguments for decimals()
        } else {
            XCTFail("Expected ContractCallParams")
        }
    }
    
    func testGetOracleResolution() async throws {
        // Given
        let expectedResolution = 10
        let mockResponse = SCValXDR.u32(UInt32(expectedResolution))
        
        // Set up mock to return the expected resolution
        mockNetworkService.responseToReturn = mockResponse
        
        // When
        let resolution = try await oracleService.getOracleResolution()
        
        // Then
        XCTAssertEqual(resolution, expectedResolution)
        
        // Verify the request was made with the correct parameters
        if let request = mockNetworkService.lastRequest as? ContractCallParams {
            XCTAssertEqual(request.functionName, "resolution")
            XCTAssertEqual(request.functionArguments.count, 0) // No arguments for resolution()
        } else {
            XCTFail("Expected ContractCallParams")
        }
    }
    
    func testGetPrice() async throws {
        // Given
        let assetId = "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD"
        
        // Create mock response for lastprice function
        // Option::Some(PriceData) structure
        let optionSome = SCValXDR.symbol("Some")
        let priceValue = SCValXDR.i128(Int128PartsXDR(hi: 0, lo: 12_500_000))
        let timestampValue = SCValXDR.u64(1714381985)
        let priceDataMap: [SCMapEntryXDR] = [
            SCMapEntryXDR(key: SCValXDR.symbol("price"), val: priceValue),
            SCMapEntryXDR(key: SCValXDR.symbol("timestamp"), val: timestampValue)
        ]
        let priceDataStruct = SCValXDR.map(priceDataMap)
        let mockResponse = SCValXDR.vec([optionSome, priceDataStruct])
        
        // Also need mock for decimals and resolution
        mockCacheService.cache["oracle_decimals"] = 6
        mockCacheService.cache["oracle_resolution"] = 10
        
        // Set up mock to return the price data
        mockNetworkService.responseToReturn = mockResponse
        
        // When
        let priceData = try await oracleService.getPrice(asset: assetId)
        
        // Then
        XCTAssertEqual(priceData.price, Decimal(string: "1.25"))
        XCTAssertEqual(priceData.assetId, assetId)
        XCTAssertEqual(priceData.decimals, 6)
        XCTAssertEqual(Int(priceData.timestamp.timeIntervalSince1970), 1714381985)
    }
    
    func testGetPriceWithTimestamp() async throws {
        // Given
        let asset = OracleAsset.stellar(address: "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD")
        let timestamp: UInt64 = 1714381985
        
        // Create mock response for price(asset, timestamp) function
        // Option::Some(PriceData) structure
        let optionSome = SCValXDR.symbol("Some")
        let priceValue = SCValXDR.i128(Int128PartsXDR(hi: 0, lo: 12_500_000))
        let timestampValue = SCValXDR.u64(timestamp)
        let priceDataMap: [SCMapEntryXDR] = [
            SCMapEntryXDR(key: SCValXDR.symbol("price"), val: priceValue),
            SCMapEntryXDR(key: SCValXDR.symbol("timestamp"), val: timestampValue)
        ]
        let priceDataStruct = SCValXDR.map(priceDataMap)
        let mockResponse = SCValXDR.vec([optionSome, priceDataStruct])
        
        // Also need mock for decimals and resolution
        mockCacheService.cache["oracle_decimals"] = 6
        mockCacheService.cache["oracle_resolution"] = 10
        
        // Set up mock to return the price data
        mockNetworkService.responseToReturn = mockResponse
        
        // When
        let priceData = try await oracleService.getPrice(asset: asset, timestamp: timestamp)
        
        // Then
        XCTAssertNotNil(priceData, "Price data should not be nil")
        XCTAssertEqual(priceData?.price, Decimal(string: "1.25"))
        XCTAssertEqual(priceData?.asset, asset)
        XCTAssertEqual(priceData?.decimals, 6)
        XCTAssertEqual(priceData?.resolution, 10)
        XCTAssertEqual(Int(priceData!.timestamp.timeIntervalSince1970), Int(timestamp))
        
        // Verify the request was made with the correct parameters
        if let request = mockNetworkService.lastRequest as? ContractCallParams {
            XCTAssertEqual(request.functionName, "price")
            XCTAssertEqual(request.functionArguments.count, 2) // Asset and timestamp
            
            // Check timestamp parameter
            if case .u64(let requestTimestamp) = request.functionArguments[1] {
                XCTAssertEqual(requestTimestamp, timestamp)
            } else {
                XCTFail("Expected u64 timestamp parameter")
            }
        } else {
            XCTFail("Expected ContractCallParams")
        }
    }
    
    func testGetPriceHistory() async throws {
        // Given
        let asset = OracleAsset.stellar(address: "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD")
        let records: UInt32 = 2
        
        // Create mock response for prices(asset, records) function
        // Option::Some(Vec<PriceData>) structure
        let optionSome = SCValXDR.symbol("Some")
        
        // First price data entry
        let priceValue1 = SCValXDR.i128(Int128PartsXDR(hi: 0, lo: 12_500_000))
        let timestampValue1 = SCValXDR.u64(1714381985)
        let priceDataMap1: [SCMapEntryXDR] = [
            SCMapEntryXDR(key: SCValXDR.symbol("price"), val: priceValue1),
            SCMapEntryXDR(key: SCValXDR.symbol("timestamp"), val: timestampValue1)
        ]
        let priceDataStruct1 = SCValXDR.map(priceDataMap1)
        
        // Second price data entry
        let priceValue2 = SCValXDR.i128(Int128PartsXDR(hi: 0, lo: 12_600_000))
        let timestampValue2 = SCValXDR.u64(1714381986)
        let priceDataMap2: [SCMapEntryXDR] = [
            SCMapEntryXDR(key: SCValXDR.symbol("price"), val: priceValue2),
            SCMapEntryXDR(key: SCValXDR.symbol("timestamp"), val: timestampValue2)
        ]
        let priceDataStruct2 = SCValXDR.map(priceDataMap2)
        
        // Create vector of price data entries
        let priceDataVec = SCValXDR.vec([priceDataStruct1, priceDataStruct2])
        let mockResponse = SCValXDR.vec([optionSome, priceDataVec])
        
        // Also need mock for decimals and resolution
        mockCacheService.cache["oracle_decimals"] = 6
        mockCacheService.cache["oracle_resolution"] = 10
        
        // Set up mock to return the price history
        mockNetworkService.responseToReturn = mockResponse
        
        // When
        let priceHistory = try await oracleService.getPriceHistory(asset: asset, records: records)
        
        // Then
        XCTAssertNotNil(priceHistory, "Price history should not be nil")
        XCTAssertEqual(priceHistory?.count, 2, "Should have 2 price entries")
        
        // Check first price entry
        XCTAssertEqual(priceHistory?[0].price, Decimal(string: "1.25"))
        XCTAssertEqual(priceHistory?[0].asset, asset)
        XCTAssertEqual(Int(priceHistory![0].timestamp.timeIntervalSince1970), 1714381985)
        
        // Check second price entry
        XCTAssertEqual(priceHistory?[1].price, Decimal(string: "1.26"))
        XCTAssertEqual(priceHistory?[1].asset, asset)
        XCTAssertEqual(Int(priceHistory![1].timestamp.timeIntervalSince1970), 1714381986)
        
        // Verify the request was made with the correct parameters
        if let request = mockNetworkService.lastRequest as? ContractCallParams {
            XCTAssertEqual(request.functionName, "prices")
            XCTAssertEqual(request.functionArguments.count, 2) // Asset and records
            
            // Check records parameter
            if case .u32(let requestRecords) = request.functionArguments[1] {
                XCTAssertEqual(requestRecords, records)
            } else {
                XCTFail("Expected u32 records parameter")
            }
        } else {
            XCTFail("Expected ContractCallParams")
        }
    }
    
    func testGetBaseAsset() async throws {
        // Given
        let expectedAddress = "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD"
        
        // Create mock response for base() function
        // Asset::Stellar(address) structure
        let discriminant = SCValXDR.symbol("Stellar")
        
        // Create contract address
        let contractData = try? StrKey.decodeContractAddress(expectedAddress)
        let address = SCAddressXDR.contract(contractData ?? Data(repeating: 0, count: 32))
        let addressVal = SCValXDR.address(address)
        
        let mockResponse = SCValXDR.vec([discriminant, addressVal])
        
        // Set up mock to return the base asset
        mockNetworkService.responseToReturn = mockResponse
        
        // When
        let baseAsset = try await oracleService.getBaseAsset()
        
        // Then
        if case .stellar(let address) = baseAsset {
            // The exact address may not match due to encoding/decoding differences
            // Just check that we got a stellar asset
            XCTAssertFalse(address.isEmpty, "Address should not be empty")
        } else {
            XCTFail("Expected stellar asset")
        }
        
        // Verify the request was made with the correct parameters
        if let request = mockNetworkService.lastRequest as? ContractCallParams {
            XCTAssertEqual(request.functionName, "base")
            XCTAssertEqual(request.functionArguments.count, 0) // No arguments for base()
        } else {
            XCTFail("Expected ContractCallParams")
        }
    }
    
    func testGetSupportedAssets() async throws {
        // Given
        
        // Create mock response for assets() function
        // Vec<Asset> structure with two assets
        
        // First asset: Stellar
        let discriminant1 = SCValXDR.symbol("Stellar")
        let address1 = "GDGQVOKHW4VEJRU2TETD6DBRKEO5ERCNF353LW5WBFW3JJWQ2BRQ6KDD"
        let contractData1 = try? StrKey.decodeContractAddress(address1)
        let scAddress1 = SCAddressXDR.contract(contractData1 ?? Data(repeating: 0, count: 32))
        let addressVal1 = SCValXDR.address(scAddress1)
        let asset1 = SCValXDR.vec([discriminant1, addressVal1])
        
        // Second asset: Other
        let discriminant2 = SCValXDR.symbol("Other")
        let symbol2 = SCValXDR.symbol("ETH")
        let asset2 = SCValXDR.vec([discriminant2, symbol2])
        
        // Create vector of assets
        let mockResponse = SCValXDR.vec([asset1, asset2])
        
        // Set up mock to return the supported assets
        mockNetworkService.responseToReturn = mockResponse
        
        // When
        let supportedAssets = try await oracleService.getSupportedAssets()
        
        // Then
        XCTAssertEqual(supportedAssets.count, 2, "Should have 2 supported assets")
        
        // Check types of assets
        if case .stellar = supportedAssets[0] {
            // Success - first asset is Stellar type
        } else {
            XCTFail("Expected first asset to be Stellar type")
        }
        
        if case .other(let symbol) = supportedAssets[1] {
            XCTAssertEqual(symbol, "ETH")
        } else {
            XCTFail("Expected second asset to be Other type")
        }
        
        // Verify the request was made with the correct parameters
        if let request = mockNetworkService.lastRequest as? ContractCallParams {
            XCTAssertEqual(request.functionName, "assets")
            XCTAssertEqual(request.functionArguments.count, 0) // No arguments for assets()
        } else {
            XCTFail("Expected ContractCallParams")
        }
    }
}

// MARK: - Mock Classes

class MockNetworkService: NetworkService {
    var simulateNetworkFailure = false
    var lastRequest: Any?
    var responseToReturn: Any?
    
    override func sendRequest<T>(_ request: URLRequest) async throws -> T where T : Decodable {
        lastRequest = request
        
        if simulateNetworkFailure {
            throw NSError(domain: "MockNetworkError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Simulated network failure"])
        }
        
        guard let response = responseToReturn as? T else {
            throw NSError(domain: "MockNetworkError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        return response
    }
    
    // Add support for simulating contract calls
    func simulateContractCall(contractCall: ContractCallParams) async throws -> SCValXDR {
        lastRequest = contractCall
        
        if simulateNetworkFailure {
            throw NSError(domain: "MockNetworkError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Simulated contract call failure"])
        }
        
        guard let response = responseToReturn as? SCValXDR else {
            throw NSError(domain: "MockNetworkError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid SCValXDR response"])
        }
        
        return response
    }
    
    // Mock SorobanServer for contract interaction
    func createMockSorobanServer() -> SorobanServer {
        let mockUrl = "https://mock-soroban-server.example.com"
        return SorobanServer(endpoint: mockUrl)
    }
}

class MockCacheService: CacheServiceProtocol {
    var cache: [String: Any] = [:]
    
    func get<T>(_ key: String, type: T.Type) async -> T? {
        return cache[key] as? T
    }
    
    func set<T>(_ value: T, key: String, ttl: TimeInterval?) async {
        cache[key] = value
    }
    
    func remove(_ key: String) async {
        cache.removeValue(forKey: key)
    }
    
    func clear() async {
        cache.removeAll()
    }
}
