import Foundation
@preconcurrency import stellarsdk
import os

typealias Int128XDR = Int128PartsXDR

// MARK: - Soroban Contract Operations



/// Oracle service implementation with NetworkService integration
@MainActor
public final class BlendOracleService {
    
    // MARK: - Properties
    
    internal let cacheService: CacheServiceProtocol
    private let networkService: NetworkServiceProtocol
    let oracleNetworkService: OracleNetworkService
    
    // Cache TTL configurations
    internal let priceCacheTTL: TimeInterval = 300 // 5 minutes
    internal let decimalsCacheTTL: TimeInterval = 3600 // 1 hour
    
    // Retry configuration
    internal let maxRetries = 3
    internal let retryDelay: TimeInterval = 1.0
    
    // Oracle contract configuration
   // internal let oracleAddress = BlendConstants.Testnet.oracle
    let oracleAddress: String
    internal let rpcUrl = "https://soroban-testnet.stellar.org"
    internal let network = Network.testnet
    
    // Centralized parser
    private let parser = BlendParser()
    

    
    // MARK: - Initialization
    
    public init(poolId: String, cacheService: CacheServiceProtocol, networkService: NetworkServiceProtocol, sourceKeyPair: KeyPair) {
        self.oracleAddress = poolId
        self.cacheService = cacheService
        self.networkService = networkService
        self.oracleNetworkService = OracleNetworkService(
            networkService: networkService,
            contractId: BlendConstants.Testnet.oracle,
            sourceKeyPair: sourceKeyPair
        )
        
    }
    
    public func getOracleDecimals() async throws -> Int {
        try await fetchOracleDecimals()
    }
    
    private func fetchOracleDecimals() async throws -> Int {
        BlendLogger.debug("Fetching oracle decimals from contract", category: BlendLogger.oracle)
        
        return try await withRetry(maxAttempts: self.maxRetries, delay: self.retryDelay) {
            do {
                let decimals = try await self.oracleNetworkService.simulateAndParseU32(
                    .decimals,
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
        
        // Handle different cases to avoid overflow
        if high == 0 {
            // Simple case: only low 64 bits are used
            return Decimal(low)
        } else if high == -1 && (low & 0x8000000000000000) != 0 {
            // Negative number in two's complement
            let signedLow = Int64(bitPattern: low)
            return Decimal(signedLow)
        } else {
            // Large number: combine hi and lo parts using Decimal arithmetic
            let highDecimal = Decimal(high) * Decimal(sign: .plus, exponent: 64, significand: 1)
            let lowDecimal = Decimal(low)
            return highDecimal + lowDecimal
        }
    }
    
    internal func withRetry<T: Sendable>(
        maxAttempts: Int,
        delay: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    BlendLogger.error("Oracle operation failed after \(maxAttempts) attempts", error: error, category: BlendLogger.oracle)
                }
            }
        }
        
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
    /// Measure performance of an async operation (only logs if >2 seconds)
    private func measurePerformance<T: Sendable>(
        operation: String,
        category: OSLog,
        work: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await work()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Only log slow operations (>2 seconds)
        if timeElapsed > 2.0 {
            BlendLogger.warning("Slow operation: \(operation) took \(String(format: "%.3f", timeElapsed))s", category: category)
        }
        return result
    }
    

}

