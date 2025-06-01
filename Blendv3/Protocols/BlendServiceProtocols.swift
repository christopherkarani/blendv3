//
//  BlendServiceProtocols.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import Combine
import stellarsdk

// MARK: - Network Connectivity Service

/// Protocol for network connectivity monitoring and management
protocol NetworkConnectivityServiceProtocol: AnyObject {
    var connectionState: Published<ConnectionState>.Publisher { get }
    var connectionFailures: Int { get }
    var connectionSuccesses: Int { get }
    
    func checkConnectivity() async -> ConnectionState
    func startMonitoring()
    func stopMonitoring()
}

// MARK: - Soroban Client Service

/// Protocol for Soroban client management and contract interactions
protocol SorobanClientServiceProtocol: AnyObject {
    var isInitialized: Bool { get }
    
    func initialize() async throws
    func invokeContract<T>(_ method: String, args: [Any]) async throws -> T
    func simulateTransaction(_ operation: Data) async throws -> Data
}

// MARK: - Pool Statistics Service

/// Protocol for pool statistics fetching and calculation
protocol PoolStatisticsServiceProtocol: AnyObject {
    var poolStats: Published<BlendPoolStats?>.Publisher { get }
    var comprehensiveStats: Published<ComprehensivePoolStats?>.Publisher { get }
    var truePoolStats: Published<TruePoolStats?>.Publisher { get }
    
    func refreshStats() async throws
    func getReserveList() async throws -> [String]
    func getPoolConfig() async throws -> PoolConfig
    func diagnosePoolStats() async throws
}

// MARK: - Transaction Execution Service


// MARK: - State Management Service

/// Protocol for centralized state management across services
protocol StateManagementServiceProtocol: AnyObject {
    var initStatePublisher: Published<VaultInitState>.Publisher { get }
    var isLoading: Published<Bool>.Publisher { get }
    var error: Published<BlendVaultError?>.Publisher { get }
    
    func setInitState(_ state: VaultInitState) async
    func setLoading(_ loading: Bool) async
    func setError(_ error: BlendVaultError?) async
    func clearError() async
}

// MARK: - Data Transformation Service

/// Protocol for data parsing and transformation operations
protocol DataTransformationServiceProtocol: AnyObject {
    func parsePoolConfig(_ result: SCValXDR) throws -> PoolConfig
    func convertRateToAPR(_ rate: Int128PartsXDR) -> Decimal
    func transformReserveData(_ data: SCValXDR) throws -> ReserveData
    func calculateRealAPY(supplyRate: Decimal, borrowRate: Decimal, utilization: Decimal) -> (supply: Decimal, borrow: Decimal)
    func parseReserveList(_ result: SCValXDR) throws -> [String]
}

// MARK: - Diagnostics Service

/// Protocol for diagnostics, monitoring and health checks
public protocol DiagnosticsServiceProtocol: AnyObject {
    func logNetworkEvent(_ event: NetworkEvent)
    func logTransactionEvent(_ event: TransactionEvent)
    func performHealthCheck() async -> HealthCheckResult
    func getPerformanceMetrics() -> PerformanceMetrics
    func trackOperationTiming(operation: String, duration: TimeInterval) async
}

// MARK: - Configuration Service

/// Protocol for configuration management across different environments
public protocol ConfigurationServiceProtocol: AnyObject {
    var networkType: BlendUSDCConstants.NetworkType { get }
    var contractAddresses: ContractAddresses { get }
    var rpcEndpoint: String { get }
    
    func getRetryConfiguration() -> RetryConfiguration
    func getTimeoutConfiguration() -> TimeoutConfiguration
    func getCacheConfiguration() -> CacheConfiguration
}

// MARK: - Error Boundary Service

/// Protocol for centralized error handling and recovery
protocol ErrorBoundaryServiceProtocol: AnyObject {
    func handle<T>(_ operation: () async throws -> T) async -> Result<T, BlendError>
    func handleWithRetry<T>(_ operation: () async throws -> T, maxRetries: Int) async -> Result<T, BlendError>
    func logError(_ error: Error, context: ErrorContext)
}

// MARK: - Validation Service

/// Protocol for input/output validation and sanitization
protocol ValidationServiceProtocol: AnyObject {
    func validateContractResponse<T>(_ response: T, schema: ValidationSchema) throws
    func validateUserInput<T>(_ input: T, rules: ValidationRules) throws
    func sanitizeOutput<T>(_ output: T) -> T
    func validateI128(_ value: Int128PartsXDR) throws -> Decimal
}

// MARK: - Batching Service

/// Protocol for request batching and optimization
public protocol BatchingServiceProtocol: AnyObject {
    func batch<T>(_ requests: [BatchableRequest]) async throws -> [T]
    func configureBatching(maxBatchSize: Int, maxWaitTime: TimeInterval) async
}

// MARK: - Transaction Service

/// Protocol for managing all transaction operations
protocol TransactionServiceProtocol: AnyObject {
    func deposit(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError>
    func withdraw(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError>
    func borrow(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError>
    func repay(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError>
    func claimEmissions(userAccount: KeyPair) async -> Result<String, BlendError>
}

// MARK: - Network Service

/// Protocol for enhanced network operations
public protocol BlendNetworkServiceProtocol: AnyObject {
    func initialize() async throws
    func getAccount(accountId: String) async throws -> Account
    func submitTransaction(_ transaction: Transaction) async throws -> TransactionResponse
    func invokeContractFunction(contractId: String, functionName: String, args: [SCValXDR]) async throws -> SCValXDR
    func simulateOperation(_ operation: stellarsdk.Operation) async throws -> SimulationResult
    func getLedgerEntries(keys: [String]) async throws -> [String: Any]
}

// MARK: - Data Service

/// Protocol for data fetching and management
protocol DataServiceProtocol: AnyObject {
    func fetchPoolStats() async throws
    func fetchUserPosition(userId: String) async throws 
}

class BlendDataService: DataServiceProtocol {
    let client: SorobanClient
    let poolService: PoolServiceProtocol
    let oracleService: BlendOracleServiceProtocol
    let assetService: BlendAssetServiceProtocol
    
    
    init(client: SorobanClient,
         poolService: PoolServiceProtocol,
         oracleService: BlendOracleServiceProtocol,
         assetService: BlendAssetServiceProtocol
    ) {
        self.client = client
        self.poolService = poolService
        self.oracleService = oracleService
        self.assetService = assetService
    }
    
    func fetchPoolStats() async throws  {
        let config = try await poolService.fetchPoolConfig()
        let assetsInPool = try await assetService.getAssets()
        let priceData = try await oracleService.getPrices(assets: assetsInPool)
        let assetDataData = try await assetService.getAll(assets: assetsInPool)
        let configBackstop = BackstopContractService.testnetConfig()
        let cache = CacheService()
        let cetConfig = ConfigurationService(networkType: BlendUSDCConstants.NetworkType.testnet)
        
        
        // Initialize infrastructure services
        let n = NetworkService(configuration: cetConfig)
        let network = NetworkService(configuration: cetConfig)
        let backstop = BackstopContractService.init(networkService: network, cacheService: cache, config: configBackstop)
        var pricedAssets: [BlendAssetData] = []
        for asset in assetDataData {
            for price in priceData {
                if asset.assetId == price.contractID {
                    var a = asset
                    a.pricePerToken = price.price
                    pricedAssets.append(a)
                }
            }
        }
        
        var totalBorrowed: Decimal = 0
        var totalSupplied: Decimal = 0
        
        
        for asset in pricedAssets {
            totalBorrowed += asset.totalBorrowedUSD
            totalSupplied += asset.totalSuppliedUSD
            let calculator = BlendRateCalculator()
            let supplyBorrow = calculator.calculateAPY(from: asset)
           // dump(asset)
            if let assetContract = try? StellarContractID.toStrKey(asset.assetId) {
                print("Asset: \(assetContract) \n Suuply \(supplyBorrow.supplyAPY) \n Borrow \(supplyBorrow.borrowAPY)")
            }
            
        }
        
        let result = try await backstop.getPoolData(pool: BlendUSDCConstants.Testnet.xlmUsdcPool)
        let token = try await backstop.getBackstopToken()
//        let backstopTokenPrice = try await oracleService.getLastPrice(asset: .stellar(address: token))
        
       // let ass = try await oracleService.assets()
        //print("assets: ", ass)
       // print("TOKEN Price: ", backstopTokenPrice)
        
        dump(result)
  
        
        print("Total Borrowed: $", totalBorrowed)
        print("Total Supplied: $", totalSupplied)
    }
    

    
    func fetchUserPosition(userId: String) async throws  {
        
    }
   
    func printPoolStatsVariables(
        config: Any,
        assetsInPool: Any,
        price: Any,
        assetDataCollection: Any
    ) {
        print("=== POOL STATS SUMMARY ===")
        
        // Pool Configuration
        print("\n📊 POOL CONFIG:")
        print("  • Backstop Rate: 1,000,000")
        print("  • Max Positions: 8")
        print("  • Min Collateral: 0")
        print("  • Status: Active (0)")
        print("  • Oracle ID: 532bb45a...22399f8")
        
        // Assets Overview
        print("\n🪙 ASSETS IN POOL (\(getAssetCount(from: assetsInPool)) assets):")
        printAssetIds(assetsInPool)
        
        // Price Data
        print("\n💰 CURRENT PRICES:")
        printPriceData(price)
        
        // Asset Details
        print("\n📈 ASSET DETAILS:")
        printAssetDataSummary(assetDataCollection)
        
        print("\n" + String(repeating: "=", count: 50))
    }

    // Helper functions for better parsing
    func getAssetCount(from assets: Any) -> Int {
        if let assetArray = assets as? [Any] {
            return assetArray.count
        }
        return 0
    }

    func printAssetIds(_ assets: Any) {
        let assetString = String(describing: assets)
        let pattern = "Stellar\\(([a-f0-9]{64})\\)"
        
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: assetString, range: NSRange(assetString.startIndex..., in: assetString))
            
            for (index, match) in matches.enumerated() {
                if let range = Range(match.range(at: 1), in: assetString) {
                    let id = String(assetString[range])
                    let shortId = String(id.prefix(8)) + "..." + String(id.suffix(8))
                    print("  Asset \(index + 1): \(shortId)")
                }
            }
        }
    }

    func printPriceData(_ priceData: Any) {
        let priceString = String(describing: priceData)
        
        // Extract price information using string parsing
        let lines = priceString.components(separatedBy: "PriceData(")
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip first empty part
            
            if let priceRange = line.range(of: "price: "),
               let commaRange = line.range(of: ", timestamp:") {
                let priceSubstring = line[priceRange.upperBound..<commaRange.lowerBound]
                let price = String(priceSubstring)
                print("  Asset \(index): $\(price)")
            }
        }
    }

    func printAssetDataSummary(_ assetData: Any) {
        let dataString = String(describing: assetData)
        let assets = dataString.components(separatedBy: "BlendAssetData(")
        
        for (index, asset) in assets.enumerated() {
            if index == 0 { continue } // Skip first empty part
            
            var supplied = "N/A"
            var borrowed = "N/A"
            var utilization = "N/A"
            
            // Extract totalSupplied
            if let suppliedRange = asset.range(of: "totalSupplied: "),
               let commaRange = asset.range(of: ", totalBorrowed:", range: suppliedRange.upperBound..<asset.endIndex) {
                supplied = String(asset[suppliedRange.upperBound..<commaRange.lowerBound])
            }
            
            // Extract totalBorrowed
            if let borrowedRange = asset.range(of: "totalBorrowed: "),
               let commaRange = asset.range(of: ", borrowRate:", range: borrowedRange.upperBound..<asset.endIndex) {
                borrowed = String(asset[borrowedRange.upperBound..<commaRange.lowerBound])
            }
            
            // Calculate utilization if we have both values
            if let suppliedDouble = Double(supplied),
               let borrowedDouble = Double(borrowed),
               suppliedDouble > 0 {
                let util: Double = (borrowedDouble / suppliedDouble) * 100
                utilization = String(format: "%.1f%%", util)
            }
            
            print("  Asset \(index):")
            print("    └─ Supplied: \(supplied)")
            print("    └─ Borrowed: \(borrowed)")
            print("    └─ Utilization: \(utilization)")
            print("")
        }
    }

    
}
//func mergePrices(
//    assets: [BlendAssetData],
//    quotes: [PriceData]
//) -> [BlendAssetData.Priced] {
//
//    // 1️⃣  Index the quotes by contractId  – O(m)
//    let quoteById = Dictionary(uniqueKeysWithValues: quotes.map { ($0.contractId, $0.priceUSD) })
//
//    // 2️⃣  Walk the assets – O(n)
//    return assets.map { asset in
//        var out = asset.priced            // copy with `price = nil`
//        out.price = quoteById[asset.assetId]   // nil if no match
//        return out
//    }
//}
