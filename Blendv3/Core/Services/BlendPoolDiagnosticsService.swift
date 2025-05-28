//
//  BlendPoolDiagnosticsService.swift
//  Blendv3
//
//  Created on 2025-05-27.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Combine
import stellarsdk

// No typealias needed - we'll use PoolConfig directly

/// Diagnostic level for pool analysis
public enum DiagnosticsLevel {
    case basic          // Basic connectivity and contract access
    case advanced       // Deeper analysis of pool data and assets
    case comprehensive  // Full diagnostic suite including experimental features
}

/// Structured report from diagnostics
public struct DiagnosticsReport {
    public let timestamp: Date
    public let level: DiagnosticsLevel
    public let networkConnected: Bool
    public let clientInitialized: Bool
    public let poolAccessible: Bool
    public let reserveCount: Int
    public let assetSymbols: [String]
    public let errors: [DiagnosticsError]
    public let backstopData: BackstopData?
    public let poolConfig: PoolConfig?
    public let advancedMetrics: [String: Any]?
    
    public var isHealthy: Bool {
        return networkConnected && clientInitialized && poolAccessible && errors.isEmpty
    }
}

/// Diagnostics-specific error type
public struct DiagnosticsError: Error {
    public let component: String
    public let message: String
    public let underlyingError: Error?
    
    public init(component: String, message: String, error: Error? = nil) {
        self.component = component
        self.message = message
        self.underlyingError = error
    }
}

/// Service dedicated to diagnosing and testing the Blend Pool
public class BlendPoolDiagnosticsService {
    // MARK: - Properties
    
    private let logger: DebugLogger
    private let networkType: BlendUSDCConstants.NetworkType
    private var sorobanClient: SorobanClient?
    private let sorobanServer: SorobanServer
    private let signer: BlendSigner
    
    // MARK: - Initialization
    
    public init(
        signer: BlendSigner,
        networkType: BlendUSDCConstants.NetworkType = .testnet
    ) {
        self.signer = signer
        self.networkType = networkType
        self.logger = DebugLogger(subsystem: "com.blendv3.diagnostics", category: "PoolDiagnostics")
        
        // Initialize Soroban server with appropriate endpoint
        let rpcUrl = networkType == .testnet ? BlendUSDCConstants.RPC.testnet : BlendUSDCConstants.RPC.mainnet
        self.sorobanServer = SorobanServer(endpoint: rpcUrl)
    }
    
    // MARK: - Public Interface
    
    /// Run diagnostics at the specified level
    public func runDiagnostics(level: DiagnosticsLevel = .basic) async throws -> DiagnosticsReport {
        logger.info("🔍 Starting pool diagnostics at level: \(level)")
        
        // Initialize diagnostics report
        var report = DiagnosticsReport(
            timestamp: Date(),
            level: level,
            networkConnected: false,
            clientInitialized: false,
            poolAccessible: false,
            reserveCount: 0,
            assetSymbols: [],
            errors: [],
            backstopData: nil,
            poolConfig: nil,
            advancedMetrics: nil as [String: Any]?
        )
        
        // Step 1: Check network connectivity
        let (isConnected, networkError) = await checkNetworkConnectivity()
        report = DiagnosticsReport(
            timestamp: report.timestamp,
            level: report.level,
            networkConnected: isConnected,
            clientInitialized: report.clientInitialized,
            poolAccessible: report.poolAccessible,
            reserveCount: report.reserveCount,
            assetSymbols: report.assetSymbols,
            errors: networkError != nil ? [DiagnosticsError(component: "Network", message: "Network connectivity issue", error: networkError)] : [],
            backstopData: report.backstopData,
            poolConfig: report.poolConfig,
            advancedMetrics: report.advancedMetrics
        )
        
        guard isConnected else {
            logger.error("❌ Network connectivity check failed")
            return report
        }
        
        // Step 2: Initialize Soroban client
        do {
            self.sorobanClient = try await initializeSorobanClient()
            report = DiagnosticsReport(
                timestamp: report.timestamp,
                level: report.level,
                networkConnected: report.networkConnected,
                clientInitialized: true,
                poolAccessible: report.poolAccessible,
                reserveCount: report.reserveCount,
                assetSymbols: report.assetSymbols,
                errors: report.errors,
                backstopData: report.backstopData,
                poolConfig: report.poolConfig,
                advancedMetrics: report.advancedMetrics
            )
        } catch {
            logger.error("❌ Soroban client initialization failed: \(error.localizedDescription)")
            let updatedErrors = report.errors + [DiagnosticsError(component: "Client", message: "Failed to initialize Soroban client", error: error)]
            report = DiagnosticsReport(
                timestamp: report.timestamp,
                level: report.level,
                networkConnected: report.networkConnected,
                clientInitialized: false,
                poolAccessible: report.poolAccessible,
                reserveCount: report.reserveCount,
                assetSymbols: report.assetSymbols,
                errors: updatedErrors,
                backstopData: report.backstopData,
                poolConfig: report.poolConfig,
                advancedMetrics: report.advancedMetrics
            )
            return report
        }
        
        // Step 3: Check pool accessibility
        do {
            let assetAddresses = try await getReserveList()
            report = DiagnosticsReport(
                timestamp: report.timestamp,
                level: report.level,
                networkConnected: report.networkConnected,
                clientInitialized: report.clientInitialized,
                poolAccessible: true,
                reserveCount: assetAddresses.count,
                assetSymbols: assetAddresses.map { getAssetSymbol(for: $0) },
                errors: report.errors,
                backstopData: report.backstopData,
                poolConfig: report.poolConfig,
                advancedMetrics: report.advancedMetrics
            )
            
            // Continue with level-specific diagnostics
            switch level {
            case .basic:
                // Basic level already completed
                break
                
            case .advanced:
                report = try await runAdvancedDiagnostics(baseReport: report)
                
            case .comprehensive:
                report = try await runComprehensiveDiagnostics(baseReport: report)
            }
            
        } catch {
            logger.error("❌ Pool accessibility check failed: \(error.localizedDescription)")
            let updatedErrors = report.errors + [DiagnosticsError(component: "Pool", message: "Failed to access pool contract", error: error)]
            report = DiagnosticsReport(
                timestamp: report.timestamp,
                level: report.level,
                networkConnected: report.networkConnected,
                clientInitialized: report.clientInitialized,
                poolAccessible: false,
                reserveCount: report.reserveCount,
                assetSymbols: report.assetSymbols,
                errors: updatedErrors,
                backstopData: report.backstopData,
                poolConfig: report.poolConfig,
                advancedMetrics: report.advancedMetrics
            )
        }
        
        logger.info("✅ Diagnostics completed. Health status: \(report.isHealthy ? "Healthy" : "Unhealthy")")
        return report
    }
    
    // MARK: - Advanced Diagnostics
    
    /// Run advanced level diagnostics
    private func runAdvancedDiagnostics(baseReport: DiagnosticsReport) async throws -> DiagnosticsReport {
        logger.info("🔍 Running advanced diagnostics")
        
        var report = baseReport
        var errors = report.errors
        var advancedMetrics: [String: Any] = report.advancedMetrics ?? [:]
        
        // Get pool configuration
        do {
            let poolConfig = try await getPoolConfig()
            report = DiagnosticsReport(
                timestamp: report.timestamp,
                level: report.level,
                networkConnected: report.networkConnected,
                clientInitialized: report.clientInitialized,
                poolAccessible: report.poolAccessible,
                reserveCount: report.reserveCount,
                assetSymbols: report.assetSymbols,
                errors: errors,
                backstopData: report.backstopData,
                poolConfig: poolConfig,
                advancedMetrics: advancedMetrics
            )
        } catch {
            logger.error("❌ Failed to get pool configuration: \(error.localizedDescription)")
            errors.append(DiagnosticsError(component: "PoolConfig", message: "Failed to get pool configuration", error: error))
        }
        
        // Get backstop data
        do {
            let backstopData = try await getBackstopData()
            report = DiagnosticsReport(
                timestamp: report.timestamp,
                level: report.level,
                networkConnected: report.networkConnected,
                clientInitialized: report.clientInitialized,
                poolAccessible: report.poolAccessible,
                reserveCount: report.reserveCount,
                assetSymbols: report.assetSymbols,
                errors: errors,
                backstopData: backstopData,
                poolConfig: report.poolConfig,
                advancedMetrics: advancedMetrics
            )
        } catch {
            logger.error("❌ Failed to get backstop data: \(error.localizedDescription)")
            errors.append(DiagnosticsError(component: "Backstop", message: "Failed to get backstop data", error: error))
        }
        
        // Update errors in the report
        return DiagnosticsReport(
            timestamp: report.timestamp,
            level: report.level,
            networkConnected: report.networkConnected,
            clientInitialized: report.clientInitialized,
            poolAccessible: report.poolAccessible,
            reserveCount: report.reserveCount,
            assetSymbols: report.assetSymbols,
            errors: errors,
            backstopData: report.backstopData,
            poolConfig: report.poolConfig,
            advancedMetrics: advancedMetrics
        )
    }
    
    /// Run comprehensive level diagnostics
    private func runComprehensiveDiagnostics(baseReport: DiagnosticsReport) async throws -> DiagnosticsReport {
        logger.info("🔍 Running comprehensive diagnostics")
        
        // First run advanced diagnostics
        var report = try await runAdvancedDiagnostics(baseReport: baseReport)
        var errors = report.errors
        var advancedMetrics = report.advancedMetrics ?? [:]
        
        // Add comprehensive tests
        
        // Test asset address mapping
        do {
            let assetMappingResults = try await testAssetAddressMapping()
            advancedMetrics["assetMapping"] = assetMappingResults
        } catch {
            logger.error("❌ Asset address mapping test failed: \(error.localizedDescription)")
            errors.append(DiagnosticsError(component: "AssetMapping", message: "Asset address mapping test failed", error: error))
        }
        
        // Test specific critical assets (WETH, WBTC)
        do {
            let criticalAssetResults = try await testCriticalAssetProcessing()
            advancedMetrics["criticalAssets"] = criticalAssetResults
        } catch {
            logger.error("❌ Critical asset processing test failed: \(error.localizedDescription)")
            errors.append(DiagnosticsError(component: "CriticalAssets", message: "Critical asset processing test failed", error: error))
        }
        
        // Test pool factory functions
        do {
            let factoryResults = try await testPoolFactoryFunctions()
            advancedMetrics["poolFactory"] = factoryResults
        } catch {
            logger.error("❌ Pool factory functions test failed: \(error.localizedDescription)")
            errors.append(DiagnosticsError(component: "PoolFactory", message: "Pool factory functions test failed", error: error))
        }
        
        // Update the report with comprehensive test results
        return DiagnosticsReport(
            timestamp: report.timestamp,
            level: report.level,
            networkConnected: report.networkConnected,
            clientInitialized: report.clientInitialized,
            poolAccessible: report.poolAccessible,
            reserveCount: report.reserveCount,
            assetSymbols: report.assetSymbols,
            errors: errors,
            backstopData: report.backstopData,
            poolConfig: report.poolConfig,
            advancedMetrics: advancedMetrics
        )
    }
    
    // MARK: - Helper Methods
    
    /// Initialize the Soroban client
    private func initializeSorobanClient() async throws -> SorobanClient {
        logger.info("Initializing Soroban client for diagnostics")
        
        let keyPair = try signer.getKeyPair()
        
        // Create client options
        let clientOptions = ClientOptions(
            sourceAccountKeyPair: keyPair,
            contractId: BlendUSDCConstants.poolContractAddress,
            network: networkType == .testnet ? Network.testnet : Network.public,
            rpcUrl: networkType == .testnet ? BlendUSDCConstants.RPC.testnet : BlendUSDCConstants.RPC.mainnet,
            enableServerLogging: true
        )
        
        // Create the client
        return try await SorobanClient.forClientOptions(options: clientOptions)
    }
    
    /// Check network connectivity
    private func checkNetworkConnectivity() async -> (isConnected: Bool, error: Error?) {
        logger.debug("Checking network connectivity for diagnostics...")
        
        do {
            // First, check if we can reach the RPC endpoint with a simple health check
            let healthResult = await sorobanServer.getHealth()
            
            switch healthResult {
            case .success:
                logger.info("✅ Network connectivity check passed")
                return (true, nil)
            case .failure(let error):
                logger.warning("⚠️ Health check failed: \(error)")
                return (false, NSError(domain: "com.blendv3.diagnostics", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Health check failed: \(error)"]))
            }
        } catch {
            logger.error("❌ Network connectivity check failed: \(error.localizedDescription)")
            return (false, error)
        }
    }
    
    /// Get list of reserve assets from the pool
    private func getReserveList() async throws -> [String] {
        guard let client = sorobanClient else {
            throw NSError(domain: "com.blendv3.diagnostics", code: 1002, userInfo: [NSLocalizedDescriptionKey: "SorobanClient not initialized"])
        }
        
        let result = try await client.invokeMethod(
            name: "get_reserves",
            args: []
        )
        
        // Parse the result (expected to be a vector of strings)
        guard case .vec(let itemsOptional) = result, let items = itemsOptional else {
            throw NSError(domain: "com.blendv3.diagnostics", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format from get_reserves"])
        }
        
        // Extract asset addresses from the vector
        let assetAddresses = items.compactMap { item -> String? in
            if case .address(let address) = item, let contractId = address.contractId {
                return contractId
            }
            return nil
        }
        
        logger.info("✅ Retrieved \(assetAddresses.count) reserve assets from pool")
        return assetAddresses
    }
    
    /// Get pool configuration
    private func getPoolConfig() async throws -> PoolConfig {
        guard let client = sorobanClient else {
            throw NSError(domain: "com.blendv3.diagnostics", code: 1004, userInfo: [NSLocalizedDescriptionKey: "SorobanClient not initialized"])
        }
        
        let result = try await client.invokeMethod(
            name: "get_config",
            args: []
        )
        
        // Parse the result (expected to be a map)
        guard case .map(let mapOptional) = result, let map = mapOptional else {
            throw NSError(domain: "com.blendv3.diagnostics", code: 1005, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format from get_config"])
        }
        
        // Extract configuration values from the map
        var backstopRate: UInt32 = 0
        var maxPositions: UInt32 = 0
        var minCollateral: Decimal = 0
        var oracle: String = ""
        var status: UInt32 = 0
        
        for entry in map {
            if case .symbol(let key) = entry.key {
                switch key {
                case "backstop_rate":
                    if case .u32(let value) = entry.val {
                        backstopRate = value
                    }
                case "max_positions":
                    if case .u32(let value) = entry.val {
                        maxPositions = value
                    }
                case "min_collateral":
                    if case .i128(let value) = entry.val {
                        minCollateral = parseI128ToDecimal(value)
                    }
                case "oracle":
                    if case .address(let value) = entry.val, let contractId = value.contractId {
                        oracle = contractId
                    }
                case "status":
                    if case .u32(let value) = entry.val {
                        status = value
                    }
                default:
                    break
                }
            }
        }
        
        return PoolConfig(
            backstopRate: backstopRate,
            maxPositions: maxPositions,
            minCollateral: minCollateral,
            oracle: oracle,
            status: status
        )
    }
    
    /// Get backstop data
    private func getBackstopData() async throws -> BackstopData {
        // Use network-aware address resolution
        let addresses = BlendUSDCConstants.addresses(for: networkType)
        
        guard let client = sorobanClient else {
            throw NSError(domain: "com.blendv3.diagnostics", code: 1006, userInfo: [NSLocalizedDescriptionKey: "SorobanClient not initialized"])
        }
        
        // Create a new client for the backstop contract
        let backstopOptions = ClientOptions(
            sourceAccountKeyPair: try signer.getKeyPair(),
            contractId: addresses.backstop,
            network: networkType == .testnet ? Network.testnet : Network.public,
            rpcUrl: networkType == .testnet ? BlendUSDCConstants.RPC.testnet : BlendUSDCConstants.RPC.mainnet,
            enableServerLogging: true
        )
        
        let backstopClient = try await SorobanClient.forClientOptions(options: backstopOptions)
        
        // Call the get_total_backstop method
        let result = try await backstopClient.invokeMethod(
            name: "get_total_backstop",
            args: []
        )
        
        // Parse the result to get the total backstop amount
        guard case .i128(let totalBackstopI128) = result else {
            throw NSError(domain: "com.blendv3.diagnostics", code: 1007, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format from get_total_backstop"])
        }
        
        let totalBackstop = parseI128ToDecimal(totalBackstopI128)
        
        // For now, we'll return a basic BackstopData object
        return BackstopData(
            totalBackstop: totalBackstop,
            backstopApr: Decimal(0), // This would need to be calculated or fetched
            q4wPercentage: Decimal(0), // This would need to be calculated or fetched
            takeRate: Decimal(0.10), // Default 10% take rate
            blndAmount: totalBackstop * Decimal(0.7), // Assume 70% BLND
            usdcAmount: totalBackstop * Decimal(0.3) // Assume 30% USDC
        )
    }
    
    /// Test asset address mapping
    private func testAssetAddressMapping() async throws -> [String: String] {
        logger.info("🔍 Testing asset address mapping")
        
        // Test all known asset addresses
        let knownAssets = [
            "USDC": BlendUSDCConstants.Testnet.usdc,
            "wBTC": BlendUSDCConstants.Testnet.wbtc,
            "wETH": BlendUSDCConstants.Testnet.weth,
            "XLM": BlendUSDCConstants.Testnet.xlm
        ]
        
        var results: [String: String] = [:]
        
        for (symbol, address) in knownAssets {
            let mappedSymbol = getAssetSymbol(for: address)
            results[address] = "\(symbol) -> \(mappedSymbol)"
            logger.info("🔍 Asset mapping: \(address) = \(symbol) -> \(mappedSymbol)")
        }
        
        return results
    }
    
    /// Test critical asset processing (WETH, WBTC)
    private func testCriticalAssetProcessing() async throws -> [String: Any] {
        logger.info("🔍 Testing critical asset processing")
        
        let criticalAssets = [
            BlendUSDCConstants.Testnet.weth,
            BlendUSDCConstants.Testnet.wbtc
        ]
        
        var results: [String: Any] = [:]
        
        for assetAddress in criticalAssets {
            let symbol = getAssetSymbol(for: assetAddress)
            logger.info("🔍 Testing critical asset: \(symbol) (\(assetAddress))")
            
            // Try to get reserve data for this asset
            do {
                guard let client = sorobanClient else {
                    throw NSError(domain: "com.blendv3.diagnostics", code: 1008, userInfo: [NSLocalizedDescriptionKey: "SorobanClient not initialized"])
                }
                
                let result = try await client.invokeMethod(
                    name: "get_reserve",
                    args: [
                        try SCValXDR.address(SCAddressXDR(contractId: assetAddress))
                    ]
                )
                
                // Just check if we got a valid response
                if case .map = result {
                    results[symbol] = "Reserve data retrieved successfully"
                } else {
                    results[symbol] = "Unexpected response format: \(result)"
                }
            } catch {
                results[symbol] = "Error: \(error.localizedDescription)"
            }
        }
        
        return results
    }
    
    /// Test pool factory functions
    private func testPoolFactoryFunctions() async throws -> [String: Any] {
        logger.info("🔍 Testing pool factory functions")
        
        var results: [String: Any] = [:]
        
        do {
            let keyPair = try signer.getKeyPair()
            let accountId = keyPair.accountId
            
            // Get factory address
            let factoryAddress = networkType == .testnet ? 
                BlendUSDCConstants.Testnet.poolFactory :
                BlendUSDCConstants.Mainnet.poolFactory
            
            // Create a new client for the factory contract
            let factoryOptions = ClientOptions(
                sourceAccountKeyPair: keyPair,
                contractId: factoryAddress,
                network: networkType == .testnet ? Network.testnet : Network.public,
                rpcUrl: networkType == .testnet ? BlendUSDCConstants.RPC.testnet : BlendUSDCConstants.RPC.mainnet,
                enableServerLogging: true
            )
            
            let factoryClient = try await SorobanClient.forClientOptions(options: factoryOptions)
            
            // Call get_pool to check if it works
            let result = try await factoryClient.invokeMethod(
                name: "get_pool",
                args: []
            )
            
            // Just check if we got a valid response
            if case .address(let address) = result, let contractId = address.contractId {
                results["get_pool"] = "Success: \(contractId)"
            } else {
                results["get_pool"] = "Unexpected response format: \(result)"
            }
        } catch {
            results["factory_test"] = "Error: \(error.localizedDescription)"
        }
        
        return results
    }
    
    /// Get human-readable symbol for an asset address
    private func getAssetSymbol(for address: String) -> String {
        switch address {
        case BlendUSDCConstants.Testnet.usdc, BlendUSDCConstants.Mainnet.usdc:
            return "USDC"
        case BlendUSDCConstants.Testnet.wbtc, BlendUSDCConstants.Testnet.wbtc:
            return "wBTC"
        case BlendUSDCConstants.Testnet.weth, BlendUSDCConstants.Testnet.weth:
            return "wETH"
        case BlendUSDCConstants.Testnet.xlm, BlendUSDCConstants.Mainnet.xlm:
            return "XLM"
        default:
            // Return a shortened version of the address for unknown assets
            let start = address.prefix(6)
            let end = address.suffix(4)
            return "Asset_\(start)...\(end)"
        }
    }
    
    /// Parse Int128PartsXDR to Decimal
    private func parseI128ToDecimal(_ value: Int128PartsXDR) -> Decimal {
        // Convert to string representation
        let hiPart = Int64(value.hi)
        let loPart = UInt64(value.lo)
        
        // Handle the sign
        let isNegative = hiPart < 0
        
        // Use NSDecimalNumber for precise conversion
        let hiDecimal = NSDecimalNumber(value: abs(hiPart))
        let loDecimal = NSDecimalNumber(value: loPart)
        
        // 2^64
        let shift = NSDecimalNumber(mantissa: 1, exponent: 64, isNegative: false)
        
        // hi * 2^64 + lo
        let shiftedHi = hiDecimal.multiplying(by: shift)
        let combined = shiftedHi.adding(loDecimal)
        
        // Apply sign
        let result = isNegative ? combined.multiplying(by: NSDecimalNumber(value: -1)) : combined
        
        // Convert to fixed-point decimal (USDC has 6 decimals)
        let divisor = NSDecimalNumber(mantissa: 1, exponent: 6, isNegative: false)
        return (result.dividing(by: divisor) as NSDecimalNumber) as Decimal
    }
}
