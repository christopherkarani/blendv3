import Foundation
import stellarsdk
import os

// MARK: - Data Extensions (using existing extension from BlendUSDCVault)

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

/// Oracle service implementation with correct Blend oracle functions
public final class BlendOracleService {

    
    public func getOracleDecimals() async throws -> Int {
        try await fetchOracleDecimals()
    }

    // MARK: - Properties
    internal let cacheService: CacheServiceProtocol
    
    // Debug logging
    internal let debugLogger = DebugLogger(subsystem: "com.blendv3.oracle", category: "OracleService")
    
    // Cache TTL configurations
    internal let priceCacheTTL: TimeInterval = 300 // 5 minutes
    internal let decimalsCacheTTL: TimeInterval = 3600 // 1 hour
    
    // Retry configuration
    internal let maxRetries = 3
    internal let retryDelay: TimeInterval = 1.0
    
    // Oracle contract configuration
    internal let oracleAddress = BlendUSDCConstants.Testnet.oracle
    internal let rpcUrl = BlendUSDCConstants.RPC.testnet
    internal let network = Network.testnet
    
    // MARK: - Initialization
    
    public init(cacheService: CacheServiceProtocol) {
        self.cacheService = cacheService
        debugLogger.info("🔮 Oracle service initialized with address: \(oracleAddress)")
        debugLogger.info("🔮 Using RPC: \(rpcUrl)")
    }
    
  
    
     func fetchOracleDecimals() async throws -> Int {
        BlendLogger.debug("Fetching oracle decimals from contract", category: BlendLogger.oracle)
        
        return try await withRetry(maxAttempts: self.maxRetries, delay: self.retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
            
            // Create contract call for decimals() function (if it exists)
            let contractCall = ContractCallParams(
                contractId: self.oracleAddress,
                functionName: "decimals",
                functionArguments: []
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            
            // Parse decimals from response
            if case .u32(let decimals) = response {
                return Int(decimals)
            } else {
                // Default to 7 decimals if decimals() function doesn't exist
                BlendLogger.warning("Oracle decimals() function not available, using default 7", category: BlendLogger.oracle)
                return 7
            }
        }
    }
    
    /// Simulate contract call and return result using real Soroban RPC
 

internal func simulateContractCall(sorobanServer: SorobanServer, contractCall: ContractCallParams) async throws -> SCValXDR {
    let simulator = SorobanTransactionSimulator(debugLogger: debugLogger)
    return try await simulator.simulate(server: sorobanServer, contractCall: contractCall)
}
    

    
    /// Create Asset::Stellar(contract_address) parameter for oracle calls
    /// Based on Blend Protocol documentation, Asset::Stellar is represented as an enum variant
    private func createAssetParameter(contractAddress: String) throws -> SCValXDR {
        BlendLogger.debug("🔮 📝 Creating asset parameter for: \(contractAddress)", category: BlendLogger.oracle)
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
    
    /// Parse Option<PriceData> from oracle response
    internal func parseOptionalPriceData(from resultXdr: SCValXDR, asset: OracleAsset) throws -> PriceData? {
        let symbol = getAssetSymbol(for: asset.assetId)
        
        switch resultXdr {
        case .void:
            return nil
        case .vec(let vecOptional):
            // Some(PriceData) case - might be wrapped in a vector
            guard let vec = vecOptional, !vec.isEmpty else {
                BlendLogger.debug("🔮 ❌ Empty vector for \(symbol)", category: BlendLogger.oracle)
                return nil
            }
            return try parseWrappedPriceData(from: vec[0], assetId: asset.assetId)
        case .map(let mapOptional):
            // Direct PriceData struct (no Option wrapper)
            guard let map = mapOptional else {
                throw OracleError.invalidResponse(
                    details:  "Map is nil in direct PriceData response",
                    rawData: String(describing: resultXdr)
                )
            }
            return try parsePriceDataStruct(from: map, assetId: asset.assetId)
            
        case .i128(let priceValue):
            debugLogger.info("🔮 💰 Parsing simple i128 price for \(symbol)")
            let price = parseI128ToDecimal(priceValue)
            return PriceData(
                price: price,
                timestamp: Date(), // Use current time if no timestamp provided
                assetId: asset.assetId,
                decimals: 7
            )
            
        default:
            let details = "Unexpected XDR type: \(String(describing: type(of: resultXdr)))"
            throw OracleError.invalidResponse(details: details, rawData: String(describing: resultXdr))
        }
    }
    
    /// Parse Option<Vec<PriceData>> from oracle response
    internal func parseOptionalPriceDataVector(from resultXdr: SCValXDR, assetId: String) throws -> [PriceData] {
        BlendLogger.debug("Parsing Option<Vec<PriceData>> for asset: \(assetId)", category: BlendLogger.oracle)
        
        switch resultXdr {
        case .void:
            // None case - no price data available
            BlendLogger.debug("No price data available (None) for asset: \(assetId)", category: BlendLogger.oracle)
            return []
            
        case .vec(let vecOptional):
            // Some(Vec<PriceData>) case
            guard let vec = vecOptional else {
                let details = "Vector is nil in Option<Vec<PriceData>> response"
                throw OracleError.invalidResponse(details: details, rawData: String(describing: resultXdr))
            }
            
            var priceDataArray: [PriceData] = []
            for item in vec {
                if case .map(let mapOptional) = item, let map = mapOptional {
                    let priceData = try parsePriceDataStruct(from: map, assetId: assetId)
                    priceDataArray.append(priceData)
                }
            }
            return priceDataArray
            
        default:
            let details = "Unexpected XDR type for price vector: \(String(describing: type(of: resultXdr)))"
            throw OracleError.invalidResponse(details: details, rawData: String(describing: resultXdr))
        }
    }
    
    /// Parse wrapped PriceData from Option<PriceData> instance
    private func parseWrappedPriceData(from value: SCValXDR, assetId: String) throws -> PriceData? {
        let symbol = getAssetSymbol(for: assetId)
        BlendLogger.debug("🔮 🔍 Parsing wrapped PriceData for \(symbol)", category: BlendLogger.oracle)
        debugLogger.info("🔮 🔍 parseWrappedPriceData called for \(symbol)")
        
        switch value {
        case .map(let mapOptional):
            guard let map = mapOptional else {
                BlendLogger.error("🔮 💥 Invalid wrapped map for \(symbol)", category: BlendLogger.oracle)
                let details = "Map is nil in wrapped PriceData"
                throw OracleError.invalidResponse(details: details, rawData: String(describing: value))
            }
            return try parsePriceDataStruct(from: map, assetId: assetId)
            
        case .i128(let priceValue):
            // Simple price value
            let price = parseI128ToDecimal(priceValue)
            return PriceData(
                price: price,
                timestamp: Date(),
                assetId: assetId,
                decimals: 7
            )
            
        default:
            BlendLogger.warning("🔮 ⚠️ Unexpected wrapped value type for \(symbol): \(value)", category: BlendLogger.oracle)
            let details = "Unexpected wrapped value type: \(String(describing: type(of: value)))"
            throw OracleError.invalidResponse(details: details, rawData: String(describing: value))
        }
    }
    
    /// Parse PriceData struct from map
    private func parsePriceDataStruct(from map: [SCMapEntryXDR], assetId: String) throws -> PriceData {
        let symbol = getAssetSymbol(for: assetId)
        BlendLogger.debug("🔮 🔍 Parsing PriceData struct for \(symbol) with \(map.count) fields", category: BlendLogger.oracle)
        debugLogger.info("🔮 🔍 parsePriceDataStruct called for \(symbol)")
        
        var price: Decimal?
        var timestamp: Date?
        
        for entry in map {
            if case .symbol(let key) = entry.key {
                debugLogger.info("🔮 🔑 Processing field: \(key)")
                
                switch key {
                case "price":
                    if case .i128(let priceValue) = entry.val {
                        // Convert i128 to Decimal
                        price = parseI128ToDecimal(priceValue)
                        BlendLogger.debug("🔮 💰 Parsed price for \(symbol): \(price!)", category: BlendLogger.oracle)
                        debugLogger.info("🔮 💰 Price field parsed: \(price!)")
                    } else {
                        BlendLogger.warning("🔮 ⚠️ Invalid price field type for \(symbol)", category: BlendLogger.oracle)
                        debugLogger.warning("🔮 ⚠️ Price field is not i128: \(entry.val)")
                    }
                case "timestamp":
                    if case .u64(let timestampValue) = entry.val {
                        timestamp = Date(timeIntervalSince1970: TimeInterval(timestampValue))
                        BlendLogger.debug("🔮 ⏰ Parsed timestamp for \(symbol): \(timestamp!)", category: BlendLogger.oracle)
                        debugLogger.info("🔮 ⏰ Timestamp field parsed: \(timestamp!)")
                    } else {
                        BlendLogger.warning("🔮 ⚠️ Invalid timestamp field type for \(symbol)", category: BlendLogger.oracle)
                        debugLogger.warning("🔮 ⚠️ Timestamp field is not u64: \(entry.val)")
                    }
                default:
                    BlendLogger.debug("🔮 ❓ Unknown PriceData field: \(key) for \(symbol)", category: BlendLogger.oracle)
                    debugLogger.info("🔮 ❓ Ignoring unknown field: \(key)")
                }
            } else {
                BlendLogger.warning("🔮 ⚠️ Non-symbol key in PriceData for \(symbol)", category: BlendLogger.oracle)
                debugLogger.warning("🔮 ⚠️ Non-symbol key: \(entry.key)")
            }
        }
        
        guard let finalPrice = price, let finalTimestamp = timestamp else {
            BlendLogger.error("🔮 💥 Missing required PriceData fields for asset: \(symbol)", category: BlendLogger.oracle)
            debugLogger.error("🔮 💥 Missing fields - price: \(price != nil), timestamp: \(timestamp != nil)")
            
            let missingFields = [
                price == nil ? "price" : nil,
                timestamp == nil ? "timestamp" : nil
            ].compactMap { $0 }
            
            let details = "Missing required fields: \(missingFields.joined(separator: ", "))"
            throw OracleError.contractError(code: 1, message: "error")
        }
        
        let priceData = PriceData(
            price: FixedMath.toFloat(value: finalPrice, decimals: 7),
            timestamp: finalTimestamp,
            assetId: assetId,
            decimals: 7 // Default to 7 decimals for Blend
        )
        
        BlendLogger.debug("🔮 ✅ Successfully parsed PriceData for \(symbol): price=\(FixedMath.toFloat(value: finalPrice, decimals: 7)), timestamp=\(finalTimestamp)", category: BlendLogger.oracle)
        debugLogger.info("🔮 ✅ PriceData created for \(symbol): $\(priceData.priceInUSD)")
        
        return priceData
    }
    
    /// Parse i128 to Decimal with proper fixed-point arithmetic
    /// Blend Protocol uses 7 decimal places for prices (10^7 = 10,000,000)
    private func parseI128ToDecimal(_ value: Int128PartsXDR) -> Decimal {
        BlendLogger.debug("🔮 🔢 Parsing i128 value: hi=\(value.hi), lo=\(value.lo)", category: BlendLogger.oracle)
        debugLogger.info("🔮 🔢 parseI128ToDecimal - hi: \(value.hi), lo: \(value.lo)")
        
        // Convert i128 to a single 128-bit integer value
        let fullValue: Decimal
        
        if value.hi == 0 {
            // Simple case: only low 64 bits are used
            fullValue = Decimal(value.lo)
            debugLogger.info("🔮 🔢 Simple case - using lo value: \(value.lo)")
        } else if value.hi == -1 && (value.lo & 0x8000000000000000) != 0 {
            // Negative number in two's complement
            let signedLo = Int64(bitPattern: value.lo)
            fullValue = Decimal(signedLo)
            debugLogger.info("🔮 🔢 Negative case - signed lo: \(signedLo)")
        } else {
            // Large positive number: combine hi and lo parts
            // hi represents the upper 64 bits, lo represents the lower 64 bits
            let hiDecimal = Decimal(value.hi) * Decimal(sign: .plus, exponent: 64, significand: 1)
            let loDecimal = Decimal(value.lo)
            fullValue = hiDecimal + loDecimal
            debugLogger.info("🔮 🔢 Large number case - combined value: \(fullValue)")
        }
        
        // The value from the oracle is in fixed-point format with 7 decimals
        // So we need to return the raw value as-is (it's already scaled)
        // The PriceData.priceInUSD property will handle the conversion to float
        
        BlendLogger.debug("🔮 💰 Parsed fixed-point price: \(fullValue)", category: BlendLogger.oracle)
        debugLogger.info("🔮 💰 Final parsed price (fixed-point): \(fullValue)")
        
        return fullValue
    }
    
    /// Helper method to get asset symbol from address
    private func getAssetSymbol(for address: String) -> String {
        print("asset address: \(address)")
        
        let assetMapping = [
            BlendUSDCConstants.Testnet.usdc: "USDC",
            BlendUSDCConstants.Testnet.xlm: "XLM",
            BlendUSDCConstants.Testnet.blnd: "BLND",
            BlendUSDCConstants.Testnet.weth: "wETH",
            BlendUSDCConstants.Testnet.wbtc: "wBTC"
        ]
        if !StellarContractID.isStrKeyContract(address) {
            let asset = decode(address: address) ?? ""
            return assetMapping[asset]!
        }
    
        return assetMapping[address] ?? address
    }
    
    private func decode(address: String) -> String? {
        try? StellarContractID.encode(hex: address)
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
