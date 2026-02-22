import Foundation
import stellarsdk

// MARK: - Utility Functions

extension BackstopContractService {
    
    // MARK: - Parameter Creation
    
    /// Create address parameter for contract calls
    internal func createAddressParameter(_ address: String) throws -> SCValXDR {
        guard !address.isEmpty else {
            throw BackstopError.invalidAddress("Address cannot be empty")
        }
        
        do {
            let contractAddressXdr = try SCAddressXDR(contractId: address)
            return SCValXDR.address(contractAddressXdr)
        } catch {
            throw BackstopError.invalidAddress("Invalid address format: \(address)")
        }
    }
    
    /// Create amount parameter for contract calls (converts Decimal to i128)
    internal func createAmountParameter(_ amount: Decimal) throws -> SCValXDR {
        guard amount >= 0 else {
            throw BackstopError.invalidAmount("Amount cannot be negative: \(amount)")
        }
        
        // Scale amount by 7 decimals (standard for Blend Protocol)
        let scaledAmount = amount * Decimal(10_000_000)
        
        // Convert to Int128 using the established pattern
        let intValue = Int(truncating: scaledAmount as NSNumber)
        let int128Value = Int128(intValue)
        
        return createI128Parameter(int128Value)
    }
    
    /// Create i128 parameter for contract calls
    internal func createI128Parameter(_ value: Int128) -> SCValXDR {
        // Convert Int128 to Int128PartsXDR for Soroban
        let parts = convertInt128ToParts(value)
        return SCValXDR.i128(parts)
    }
    
    /// Create u64 parameter for contract calls
    internal func createU64Parameter(_ value: UInt64) -> SCValXDR {
        return SCValXDR.u64(value)
    }
    
    /// Create vector parameter for contract calls
    internal func createVectorParameter(_ elements: [SCValXDR]) -> SCValXDR {
        return SCValXDR.vec(elements)
    }
    
    /// Create symbol parameter for contract calls
    internal func createSymbolParameter(_ symbol: String) -> SCValXDR {
        return SCValXDR.symbol(symbol)
    }
    
    // MARK: - Validation Functions
    
    /// Validate address format
    internal func validateAddress(_ address: String, name: String) throws {
        guard !address.isEmpty else {
            throw BackstopError.missingRequiredParameter(name)
        }
        
        guard StellarContractID.isStrKeyContract(address) || isValidPublicKey(address) else {
            throw BackstopError.invalidAddress("Invalid \(name) address format: \(address)")
        }
    }
    
    /// Validate amount value
    internal func validateAmount(_ amount: Decimal, name: String) throws {
        guard amount >= 0 else {
            throw BackstopError.invalidAmount("\(name) cannot be negative: \(amount)")
        }
        
        // Check for reasonable upper bound to prevent overflow
        let maxAmount = Decimal(Int64.max) / Decimal(10_000_000)
        guard amount <= maxAmount else {
            throw BackstopError.invalidAmount("\(name) exceeds maximum allowed value: \(amount)")
        }
    }
    
    /// Validate array is not empty
    internal func validateNonEmptyArray<T>(_ array: [T], name: String) throws {
        guard !array.isEmpty else {
            throw BackstopError.invalidParameters("\(name) array cannot be empty")
        }
    }
    
    // MARK: - Helper Functions
    
    /// Check if string is a valid Stellar public key
    private func isValidPublicKey(_ key: String) -> Bool {
        do {
            _ = try PublicKey(accountId: key)
            return true
        } catch {
            return false
        }
    }
    
    /// Convert Int128 to Int128PartsXDR
    private func convertInt128ToParts(_ value: Int128) -> Int128PartsXDR {
        if value >= 0 && value <= UInt64.max {
            // Simple case: fits in 64 bits
            return Int128PartsXDR(hi: 0, lo: UInt64(value))
        } else if value < 0 && value >= Int64.min {
            // Negative number that fits in 64 bits
            let unsignedLo = UInt64(bitPattern: Int64(value))
            return Int128PartsXDR(hi: -1, lo: unsignedLo)
        } else {
            // Large number: split into hi and lo parts
            let hi = Int64(value >> 64)
            let lo = UInt64(value & 0xFFFFFFFFFFFFFFFF)
            return Int128PartsXDR(hi: hi, lo: lo)
        }
    }
    
    /// Normalize contract address to ensure proper format
    internal func normalizeContractAddress(_ address: String) -> String {
        if StellarContractID.isStrKeyContract(address) {
            return address
        }
        
        // Try to convert from hex format
        if let normalized = try? StellarContractID.encode(hex: address) {
            return normalized
        }
        
        return address
    }
    
    // MARK: - Cache Key Generation
    
    /// Generate cache key for user balance
    internal func userBalanceCacheKey(user: String, pool: String) -> String {
        return "backstop_user_balance_\(user)_\(pool)"
    }
    
    /// Generate cache key for pool data
    internal func poolDataCacheKey(pool: String) -> String {
        return "backstop_pool_data_\(pool)"
    }
    
    /// Generate cache key for emission data
    internal func emissionDataCacheKey(pool: String) -> String {
        return "backstop_emission_data_\(pool)"
    }
    
    /// Generate cache key for token address
    internal func tokenAddressCacheKey() -> String {
        return "backstop_token_address"
    }
    
    // MARK: - Error Handling Utilities
    
    /// Convert Soroban contract error to BackstopError
    internal func convertContractError(_ error: Error) -> BackstopError {
        if let backstopError = error as? BackstopError {
            return backstopError
        }
        
        // Try to extract contract error code from error message
        let errorMessage = error.localizedDescription.lowercased()
        
        for contractError in BackstopContractError.allCases {
            if errorMessage.contains("error(\(contractError.rawValue))") {
                return BackstopError.contractError(contractError)
            }
        }
        
        // Default to simulation error
        return BackstopError.simulationError("Contract call failed", error)
    }
    
    /// Log operation start
    internal func logOperationStart(_ operation: String, parameters: [String: Any] = [:]) {
        debugLogger.info("🛡️ ▶️ Starting \(operation)")
        for (key, value) in parameters {
            debugLogger.debug("🛡️ 📝 \(key): \(value)")
        }
    }
    
    /// Log operation success
    internal func logOperationSuccess(_ operation: String, result: Any? = nil, duration: TimeInterval? = nil) {
        if let duration = duration {
            debugLogger.info("🛡️ ✅ \(operation) completed in \(String(format: "%.2f", duration))s")
        } else {
            debugLogger.info("🛡️ ✅ \(operation) completed")
        }
        
        if let result = result {
            debugLogger.debug("🛡️ 📊 Result: \(result)")
        }
    }
    
    /// Log operation failure
    internal func logOperationFailure(_ operation: String, error: Error, duration: TimeInterval? = nil) {
        if let duration = duration {
            debugLogger.error("🛡️ ❌ \(operation) failed after \(String(format: "%.2f", duration))s: \(error.localizedDescription)")
        } else {
            debugLogger.error("🛡️ ❌ \(operation) failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Performance Monitoring
    
    /// Execute operation with timing
    internal func withTiming<T>(
        operation: String,
        execute: () async throws -> T
    ) async rethrows -> T {
        let startTime = Date()
        logOperationStart(operation)
        
        do {
            let result = try await execute()
            let duration = Date().timeIntervalSince(startTime)
            logOperationSuccess(operation, result: result, duration: duration)
            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logOperationFailure(operation, error: error, duration: duration)
            throw error
        }
    }
    
    // MARK: - Data Conversion Utilities
    
    /// Convert Decimal to display string with proper formatting
    internal func formatAmount(_ amount: Decimal, decimals: Int = 7) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = decimals
        
        return formatter.string(from: amount as NSNumber) ?? amount.description
    }
    
    /// Convert timestamp to Date
    internal func timestampToDate(_ timestamp: UInt64) -> Date {
        return Date(timeIntervalSince1970: Double(timestamp))
    }
    
    /// Convert Date to timestamp
    internal func dateToTimestamp(_ date: Date) -> UInt64 {
        return UInt64(date.timeIntervalSince1970)
    }
}
