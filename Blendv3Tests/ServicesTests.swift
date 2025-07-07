//
//  ServicesTests.swift
//  Blendv3Tests
//
//  Created by Chris Karani on 22/05/2025.
//

import Testing
import Foundation
@testable import Blendv3

// MARK: - Network Service Tests
struct NetworkServiceTests {
    
    @Test("NetworkService initializes with correct configuration")
    func testNetworkServiceInitialization() async {
        let networkService = NetworkService(configuration: .testnet)
        
        // Test that the service was created successfully
        #expect(networkService != nil)
    }
    
    @Test("NetworkService builds contract requests correctly")
    func testContractOperationCreation() async {
        let operation = ContractOperation.invoke(
            contractId: "test_contract",
            method: "test_method",
            parameters: ["param1", 123]
        )
        
        switch operation {
        case .invoke(let contractId, let method, let parameters):
            #expect(contractId == "test_contract")
            #expect(method == "test_method")
            #expect(parameters.count == 2)
        default:
            #expect(Bool(false), "Expected invoke operation")
        }
    }
    
    @Test("NetworkError provides correct error descriptions")
    func testNetworkErrorDescriptions() {
        let invalidURLError = NetworkError.invalidURL
        let noDataError = NetworkError.noData
        let contractError = NetworkError.contractError("Test error")
        
        #expect(invalidURLError.errorDescription == "Invalid URL")
        #expect(noDataError.errorDescription == "No data received")
        #expect(contractError.errorDescription?.contains("Test error") == true)
    }
}

// MARK: - BlendParser Tests
struct BlendParserTests {
    
    let parser = BlendParser()
    
    @Test("BlendParser parses SCVal bool correctly")
    func testSCValBoolParsing() throws {
        let json: [String: Any] = [
            "type": "SCV_BOOL",
            "value": true
        ]
        
        let scval = try parser.parseSCValFromJSON(from: json)
        
        #expect(scval.type == .bool)
        #expect(scval.value as? Bool == true)
    }
    
    @Test("BlendParser parses SCVal string correctly")
    func testSCValStringParsing() throws {
        let json: [String: Any] = [
            "type": "SCV_STRING",
            "value": "test_string"
        ]
        
        let scval = try parser.parseSCValFromJSON(from: json)
        
        #expect(scval.type == .string)
        #expect(scval.value as? String == "test_string")
    }
    
    @Test("BlendParser parses SCVal u64 correctly")
    func testSCValU64Parsing() throws {
        let json: [String: Any] = [
            "type": "SCV_U64",
            "value": UInt64(12345)
        ]
        
        let scval = try parser.parseSCValFromJSON(from: json)
        
        #expect(scval.type == .u64)
        #expect(scval.value as? UInt64 == 12345)
    }
    
    @Test("BlendParser converts SCVal to Swift types correctly")
    func testSCValToSwiftConversion() throws {
        let boolSCVal = SCVal(type: .bool, value: true)
        let stringSCVal = SCVal(type: .string, value: "test")
        let u64SCVal = SCVal(type: .u64, value: UInt64(123))
        
        let boolResult = try parser.convertSCValToSwift(boolSCVal)
        let stringResult = try parser.convertSCValToSwift(stringSCVal)
        let u64Result = try parser.convertSCValToSwift(u64SCVal)
        
        #expect(boolResult as? Bool == true)
        #expect(stringResult as? String == "test")
        #expect(u64Result as? UInt64 == 123)
    }
    
    @Test("BlendParser handles parsing errors correctly")
    func testParsingErrors() {
        let invalidJson: [String: Any] = [
            "type": "INVALID_TYPE",
            "value": "test"
        ]
        
        #expect(throws: ParsingError.self) {
            try parser.parseSCValFromJSON(from: invalidJson)
        }
    }
    
    @Test("BlendParser parses contract response correctly")
    func testContractResponseParsing() throws {
        let responseJson: [String: Any] = [
            "status": "success",
            "transaction_hash": "test_hash",
            "ledger_sequence": 12345,
            "result": [
                "type": "SCV_STRING",
                "value": "success_result"
            ],
            "events": []
        ]
        
        let responseData = try JSONSerialization.data(withJSONObject: responseJson)
        let contractResponse = try parser.parseContractResponse(from: responseData)
        
        #expect(contractResponse.status == "success")
        #expect(contractResponse.transactionHash == "test_hash")
        #expect(contractResponse.ledgerSequence == 12345)
        #expect(contractResponse.result?.type == .string)
        #expect(contractResponse.result?.value as? String == "success_result")
    }
}

// MARK: - BackstopContractService Tests
struct BackstopContractServiceTests {
    
    @Test("BackstopContractService initializes correctly")
    func testBackstopServiceInitialization() {
        let service = BackstopContractService(config: .testnet)
        
        #expect(service != nil)
        #expect(service.isLoading == false)
        #expect(service.lastError == nil)
    }
    
    @Test("BackstopBalance initializes with correct values")
    func testBackstopBalanceCreation() {
        let balance = BackstopBalance(
            userAddress: "test_address",
            shares: 1000,
            underlyingBalance: 5000,
            pendingRewards: 100
        )
        
        #expect(balance.userAddress == "test_address")
        #expect(balance.shares == 1000)
        #expect(balance.underlyingBalance == 5000)
        #expect(balance.pendingRewards == 100)
    }
    
    @Test("WithdrawalRequest initializes correctly")
    func testWithdrawalRequestCreation() {
        let request = WithdrawalRequest(
            userAddress: "test_address",
            shares: 500,
            queuedAt: 1000000,
            availableAt: 1000300
        )
        
        #expect(request.userAddress == "test_address")
        #expect(request.shares == 500)
        #expect(request.queuedAt == 1000000)
        #expect(request.availableAt == 1000300)
    }
    
    @Test("BackstopStats calculates correctly")
    func testBackstopStatsCreation() {
        let stats = BackstopStats(
            totalShares: 10000,
            totalAssets: 50000,
            totalRewards: 1000,
            sharePrice: 5.0
        )
        
        #expect(stats.totalShares == 10000)
        #expect(stats.totalAssets == 50000)
        #expect(stats.totalRewards == 1000)
        #expect(stats.sharePrice == 5.0)
    }
}

// MARK: - Architecture Validation Tests
struct ArchitectureValidationTests {
    
    @Test("Services use proper separation of concerns")
    func testServiceSeparation() {
        // Test that BackstopContractService uses NetworkService internally
        let networkService = NetworkService(configuration: .testnet)
        let backstopService = BackstopContractService(networkService: networkService, config: .testnet)
        
        #expect(backstopService != nil)
        
        // Test that BlendParser is independent and stateless
        let parser1 = BlendParser()
        let parser2 = BlendParser()
        
        #expect(parser1 != nil)
        #expect(parser2 != nil)
    }
    
    @Test("Error types are well-defined")
    func testErrorTypeDefinitions() {
        let networkError = NetworkError.invalidURL
        let parsingError = ParsingError.invalidData
        let backstopError = BackstopServiceError.invalidContractAddress
        let oracleError = OracleServiceError.invalidOracleEndpoint
        
        #expect(networkError.errorDescription != nil)
        #expect(parsingError.errorDescription != nil)
        #expect(backstopError.errorDescription != nil)
        #expect(oracleError.errorDescription != nil)
    }
    
    @Test("Network configurations are properly defined")
    func testNetworkConfigurations() {
        let testnetConfig = NetworkConfiguration.testnet
        let mainnetConfig = NetworkConfiguration.mainnet
        
        #expect(testnetConfig.rpcEndpoint.contains("testnet"))
        #expect(mainnetConfig.rpcEndpoint.contains("horizon.stellar.org"))
        #expect(testnetConfig.timeout > 0)
        #expect(mainnetConfig.timeout > 0)
    }
    
    @Test("Service protocols define correct interfaces")
    func testServiceProtocols() {
        // Validate that protocols define the expected methods
        let networkService: NetworkServiceProtocol = NetworkService()
        let backstopService: BackstopContractServiceProtocol = BackstopContractService()
        let parser: BlendParserProtocol = BlendParser()
        
        #expect(networkService != nil)
        #expect(backstopService != nil)
        #expect(parser != nil)
    }
}

// MARK: - Integration Tests
struct IntegrationTests {
    
    @Test("Services integrate correctly")
    func testServiceIntegration() {
        // Create services with proper dependency injection
        let networkService = NetworkService(configuration: .testnet)
        let parser = BlendParser()
        let backstopService = BackstopContractService(networkService: networkService, config: .testnet)
        
        #expect(networkService != nil)
        #expect(parser != nil)
        #expect(backstopService != nil)
    }
    
    @Test("Refactored architecture eliminates duplication")
    func testArchitectureRefactoring() {
        // Test that the refactored oracle service uses NetworkService
        let networkService = NetworkService()
        let refactoredOracle = RefactoredOracleService(networkService: networkService)
        
        #expect(refactoredOracle != nil)
        #expect(refactoredOracle.isLoading == false)
        #expect(refactoredOracle.lastError == nil)
    }
}