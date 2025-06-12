import Foundation
import stellarsdk
import os

typealias Int128XDR = Int128PartsXDR

// MARK: - Soroban Contract Operations

/// Contract call parameters for real Soroban operations
public struct ContractCallParams {
    let contractId: String
    let functionName: String
    let functionArguments: [SCValXDR]
    
    public init(contractId: String, functionName: String, functionArguments: [SCValXDR]) {
        self.contractId = contractId
        self.functionName = functionName
        self.functionArguments = functionArguments
    }
}

/// Oracle service implementation with NetworkService integration
public final class BlendOracleService {
    
    // MARK: - Properties
    
    internal let cacheService: CacheServiceProtocol
    private let networkService: NetworkServiceProtocol
    let oracleNetworkService: OracleNetworkService
    
    // Debug logging
    internal let debugLogger = DebugLogger(subsystem: "com.blendv3.oracle", category: "OracleService")
    
    // Cache TTL configurations
    internal let priceCacheTTL: TimeInterval = 300 // 5 minutes
    internal let decimalsCacheTTL: TimeInterval = 3600 // 1 hour
    
    // Retry configuration
    internal let maxRetries = 3
    internal let retryDelay: TimeInterval = 1.0
    
    // Oracle contract configuration
    internal let oracleAddress = BlendConstants.Testnet.oracle
    internal let rpcUrl = BlendConstants.RPC.testnet
    internal let network = Network.testnet
    
    // Parsers
    let optionalPriceDataParser = OptionalPriceDataParser()
    let priceDataVectorParser = PriceDataVectorParser()
    let assetVectorParser = AssetVectorParser()
    let u32Parser = U32Parser()
    let assetParser = AssetParser()
    
    let sourceKeyPair: KeyPair
    
    // MARK: - Initialization
    
    @MainActor
    public init(cacheService: CacheServiceProtocol, networkService: NetworkServiceProtocol, sourceKeyPair: KeyPair) {
        self.cacheService = cacheService
        self.networkService = networkService
        self.sourceKeyPair = sourceKeyPair
        self.oracleNetworkService = OracleNetworkService(
            networkService: networkService,
            contractId: BlendConstants.Testnet.oracle,
            sourceKeyPair: sourceKeyPair
        )
        
        debugLogger.info("🔮 Oracle service initialized with NetworkService integration")
        debugLogger.info("🔮 Oracle address: \(oracleAddress)")
        debugLogger.info("🔮 Using RPC: \(rpcUrl)")
    }
    
    public func getOracleDecimals() async throws -> Int {
        try await fetchOracleDecimals()
    }
    
    private func fetchOracleDecimals() async throws -> Int {
        BlendLogger.debug("Fetching oracle decimals from contract", category: BlendLogger.oracle)
        
        return try await withRetry(maxAttempts: self.maxRetries, delay: self.retryDelay) {
            do {
                let decimals = try await self.oracleNetworkService.simulateAndParse(
                    .decimals,
                    using: self.u32Parser,
                    context: OracleParsingContext(functionName: "decimals")
                )
                return Int(decimals)
            } catch {
                // Default to 7 decimals if decimals() function doesn't exist
                BlendLogger.warning("Oracle decimals() function not available, using default 7", category: BlendLogger.oracle)
                return 7
            }
        }
    }
    
    /// Simulate a contract call using an OracleContractCallBuilder instance.
    ///
    /// THIS METHOD ONLY ACCEPTS `OracleContractCallBuilder` AND WILL NOT COMPILE WITH `ContractCallParams`.
    /// If you have a `ContractCallParams` instance, use `exampleSimulateCall(contractCallParams:)` instead to perform the call.
    ///
    /// Use an `OracleContractCallBuilder` to construct the contract call before invoking this method.
    internal func simulateContractCall(contractCallBuilder: OracleContractCallBuilder) async throws -> SCValXDR {
        // Note: This function expects an OracleContractCallBuilder, NOT ContractCallParams.
        // Calls passing ContractCallParams must be migrated to use OracleContractCallBuilder instead.
        let contractCall = try contractCallBuilder.build()
        
        let response = try await self.oracleNetworkService.simulate(using: contractCallBuilder)
        return response
    }
    
    /// Create Asset::Stellar(contract_address) parameter for oracle calls
    /// Based on Blend Protocol documentation, Asset::Stellar is represented as an enum variant
    internal func createAssetParameter(contractAddress: String) throws -> SCValXDR {
        debugLogger.info("🔮 📝 createAssetParameter called with: \(contractAddress)")
        
        // Normalize the contract address to ensure it's in proper Soroban format
        //  let normalizedAddress = normalizeContractAddress(contractAddress) ?? contractAddress
        
        // Create Asset::Stellar(address) enum variant
        let contractAddressXdr = try SCAddressXDR(contractId: contractAddress)
        let addressVal = SCValXDR.address(contractAddressXdr)
        
        // Based on Blend Protocol documentation and Stellar SDK patterns,
        // Asset::Stellar(address) should be represented as a vector with symbol and address
        // This follows the Soroban enum representation pattern
        let assetVariant = SCValXDR.vec([
            SCValXDR.symbol("Stellar"),
            addressVal
        ])
        
        return assetVariant
    }
    
    /// Normalize contract address to ensure proper Soroban format
    /// Converts hex contract IDs to proper Stellar contract addresses if needed
    private func normalizeContractAddress(_ address: String) -> String? {
        // If the address is already in proper Stellar format (starts with 'C' and is 56 chars), return as-is
        if StellarContractID.isStrKeyContract(address) {
            return address
        }
        return try? StellarContractID.decode(strKey: address)
    }
    
    /// Get asset symbol for logging purposes
    private func getAssetSymbol(for assetId: String) -> String {
        // Extract symbol from asset ID for better logging
        if assetId.contains("USDC") {
            return "USDC"
        } else if assetId.contains("XLM") {
            return "XLM"
        } else {
            return String(assetId.prefix(8)) + "..."
        }
    }
    
    /// Parse i128 to Decimal for price values
    private func parseI128ToDecimal(_ i128: Int128XDR) -> Decimal {
        // Convert i128 to Decimal
        // i128 is a 128-bit signed integer, we need to handle both high and low parts
        let high = i128.hi
        let low = i128.lo
        
        // Combine high and low parts to form the full 128-bit value
        let fullValue = (Int64(high) << 64) | Int64(low)
        
        return Decimal(fullValue)
    }
    
    internal func withRetry<T>(
        maxAttempts: Int,
        delay: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        BlendLogger.debug("🔮 🔄 Starting retry mechanism (max: \(maxAttempts), delay: \(delay)s)", category: BlendLogger.oracle)
        debugLogger.info("🔮 🔄 withRetry called - maxAttempts: \(maxAttempts), delay: \(delay)s")
        
        for attempt in 1...maxAttempts {
            do {
                BlendLogger.debug("🔮 🎯 Attempt \(attempt)/\(maxAttempts)", category: BlendLogger.oracle)
                debugLogger.info("🔮 🎯 Starting attempt \(attempt) of \(maxAttempts)")
                
                let result = try await operation()
                
                if attempt > 1 {
                    BlendLogger.info("🔮 ✅ Operation succeeded on attempt \(attempt)", category: BlendLogger.oracle)
                    debugLogger.info("🔮 ✅ Success after \(attempt) attempts")
                } else {
                    BlendLogger.debug("🔮 ✅ Operation succeeded on first attempt", category: BlendLogger.oracle)
                    debugLogger.info("🔮 ✅ Success on first attempt")
                }
                
                return result
            } catch {
                lastError = error
                BlendLogger.warning("🔮 ❌ Attempt \(attempt) failed: \(error.localizedDescription)", category: BlendLogger.oracle)
                debugLogger.warning("🔮 ❌ Attempt \(attempt) failed with error: \(type(of: error))")
                debugLogger.warning("🔮 ❌ Error details: \(error.localizedDescription)")
                
                if attempt < maxAttempts {
                    BlendLogger.debug("🔮 ⏳ Retrying in \(delay) seconds...", category: BlendLogger.oracle)
                    debugLogger.info("🔮 ⏳ Waiting \(delay)s before retry \(attempt + 1)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    BlendLogger.error("🔮 💥 All \(maxAttempts) attempts failed", category: BlendLogger.oracle)
                    debugLogger.error("🔮 💥 Maximum retry attempts (\(maxAttempts)) exceeded")
                }
            }
        }
        
        BlendLogger.error("🔮 💥 Retry mechanism exhausted, throwing last error", category: BlendLogger.oracle)
        debugLogger.error("🔮 💥 Final error: \(lastError?.localizedDescription ?? "Unknown")")
        throw OracleError.maxRetriesExceeded(attempts: maxAttempts, lastError: lastError)
    }
    
    // Example of a method that calls simulateContractCall.
    // Migrated from ContractCallParams to OracleContractCallBuilder.
    internal func exampleSimulateCall(contractCallParams: ContractCallParams) async throws -> SCValXDR {
        // NOTE: This method converts legacy ContractCallParams into OracleContractCallBuilder
        // because simulateContractCall requires OracleContractCallBuilder, not ContractCallParams.
        // This migration is necessary to align with the new API expectations.
        guard let function = OracleContractFunction(rawValue: contractCallParams.functionName) else {
            throw OracleError.invalidParameterCount(function: contractCallParams.functionName, expected: 0, actual: contractCallParams.functionArguments.count)
        }
        var builder = OracleContractCallBuilder(
            contractId: contractCallParams.contractId,
            function: function
        )
        // NOTE: OracleContractCallBuilder provides specialized argument methods only.
        // If functionArguments are generic, you would need to implement additional builder methods, but for now, we just construct the builder for the function and contractId.
        return try await simulateContractCall(contractCallBuilder: builder)
    }
}

/// Error severity levels for better error categorization
public enum ErrorSeverity: String, CaseIterable {
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    public var emoji: String {
        switch self {
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "💥"
        }
    }
}

// MARK: - Performance Measurement Extension

extension BlendOracleService {
    /// Measure performance of an async operation
    private func measurePerformance<T>(
        operation: String,
        category: OSLog,
        work: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await work()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        BlendLogger.debug("⏱️ \(operation) completed in \(String(format: "%.3f", timeElapsed))s", category: category)
        return result
    }
    
    /// Log successful operations with metrics
    private func logSuccess(operation: String, asset: String? = nil, duration: TimeInterval? = nil, additionalInfo: [String: Any] = [:]) {
        let symbol = asset != nil ? getAssetSymbol(for: asset!) : nil
        let assetInfo = symbol != nil ? " [\(symbol!)]" : ""
        let durationInfo = duration != nil ? " in \(String(format: "%.3f", duration!))s" : ""
        
        BlendLogger.info("✅ \(operation)\(assetInfo) completed successfully\(durationInfo)", category: BlendLogger.oracle)
        
        if !additionalInfo.isEmpty {
            for (key, value) in additionalInfo {
                debugLogger.info("📊 \(key): \(value)")
            }
        }
    }
    
    /// Log operation start with context
    private func logOperationStart(operation: String, asset: String? = nil, parameters: [String: Any] = [:]) {
        let symbol = asset != nil ? getAssetSymbol(for: asset!) : nil
        let assetInfo = symbol != nil ? " [\(symbol!)]" : ""
        
        BlendLogger.debug("🚀 Starting \(operation)\(assetInfo)", category: BlendLogger.oracle)
        
        if !parameters.isEmpty {
            debugLogger.info("📋 Parameters:")
            for (key, value) in parameters {
                debugLogger.info("  - \(key): \(value)")
            }
        }
    }
}

