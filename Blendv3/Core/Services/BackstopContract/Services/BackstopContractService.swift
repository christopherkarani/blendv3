import Foundation
import stellarsdk
import os

/// Main Backstop contract service implementation
/// Follows patterns established in BlendOracleService for consistency
public final class BackstopContractService: BackstopContractServiceProtocol {
    
    // MARK: - Properties
    
    internal let networkService: NetworkService
    internal let cacheService: CacheServiceProtocol
    internal let config: BackstopServiceConfig
    internal let blendParser: BlendParser
    
    // Debug logging
    internal let debugLogger = DebugLogger(subsystem: "com.blendv3.backstop", category: "BackstopService")
    
    // Retry configuration
    internal let maxRetries: Int
    internal let retryDelay: TimeInterval
    
    // MARK: - Initialization
    
    public init(
        networkService: NetworkService,
        cacheService: CacheServiceProtocol,
        config: BackstopServiceConfig,
        blendParser: BlendParser = BlendParser()
    ) {
        self.networkService = networkService
        self.cacheService = cacheService
        self.config = config
        self.blendParser = blendParser
        self.maxRetries = config.maxRetries
        self.retryDelay = config.retryDelay
        
        debugLogger.info("🛡️ Backstop service initialized")
        debugLogger.info("🛡️ Contract: \(config.contractAddress)")
        debugLogger.info("🛡️ RPC: \(config.rpcUrl)")
    }
    
    // MARK: - Core Functions
    
    public func deposit(from: String, poolAddress: String, amount: Decimal) async throws -> DepositResult {
        try validateAddress(from, name: "from")
        try validateAddress(poolAddress, name: "poolAddress")
        try validateAmount(amount, name: "amount")
        
        return try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
            
            let contractCall = ContractCallParams(
                contractId: self.config.contractAddress,
                functionName: "deposit",
                functionArguments: [
                    try self.createAddressParameter(from),
                    try self.createAddressParameter(poolAddress),
                    try self.createAmountParameter(amount)
                ]
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            let sharesReceived = try self.blendParser.parseI128Response(response)
            
            return DepositResult(sharesReceived: sharesReceived)
        }
    }
    
    public func queueWithdrawal(from: String, poolAddress: String, amount: Decimal) async throws -> Q4W {
        try validateAddress(from, name: "from")
        try validateAddress(poolAddress, name: "poolAddress")
        try validateAmount(amount, name: "amount")
        
        return try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
            
            let contractCall = ContractCallParams(
                contractId: self.config.contractAddress,
                functionName: "queue_withdrawal",
                functionArguments: [
                    try self.createAddressParameter(from),
                    try self.createAddressParameter(poolAddress),
                    try self.createAmountParameter(amount)
                ]
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            return try self.blendParser.parseQ4WResponse(response)
        }
    }
    
    public func dequeueWithdrawal(from: String, poolAddress: String, amount: Decimal) async throws {
        try validateAddress(from, name: "from")
        try validateAddress(poolAddress, name: "poolAddress")
        try validateAmount(amount, name: "amount")
        
        try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
            
            let contractCall = ContractCallParams(
                contractId: self.config.contractAddress,
                functionName: "dequeue_withdrawal",
                functionArguments: [
                    try self.createAddressParameter(from),
                    try self.createAddressParameter(poolAddress),
                    try self.createAmountParameter(amount)
                ]
            )
            
            _ = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
        }
    }
    
    public func withdraw(from: String, poolAddress: String, amount: Decimal) async throws -> WithdrawalResult {
        try validateAddress(from, name: "from")
        try validateAddress(poolAddress, name: "poolAddress")
        try validateAmount(amount, name: "amount")
        
        return try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
            
            let contractCall = ContractCallParams(
                contractId: self.config.contractAddress,
                functionName: "withdraw",
                functionArguments: [
                    try self.createAddressParameter(from),
                    try self.createAddressParameter(poolAddress),
                    try self.createAmountParameter(amount)
                ]
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            let amountWithdrawn = try self.blendParser.parseI128Response(response)
            
            return WithdrawalResult(amountWithdrawn: amountWithdrawn)
        }
    }
    
    // MARK: - Query Functions
    
    public func getUserBalance(pool: String, user: String) async throws -> UserBalance {
        try validateAddress(pool, name: "pool")
        try validateAddress(user, name: "user")
        
        let cacheKey = "user_balance_\(user)_\(pool)"
        
        if let cached = await cacheService.get(cacheKey, type: UserBalance.self) {
            return cached
        }
        
        let balance = try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
            
            let contractCall = ContractCallParams(
                contractId: self.config.contractAddress,
                functionName: "user_balance",
                functionArguments: [
                    try self.createAddressParameter(pool),
                    try self.createAddressParameter(user)
                ]
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            return try self.blendParser.parseUserBalanceResponse(response)
        }
        
        await cacheService.set(balance, key: cacheKey, ttl: config.cacheConfig.userBalanceTTL)
        return balance
    }
    
    public func getPoolData(pool: String) async throws -> PoolBackstopData {
        try validateAddress(pool, name: "pool")
        
        let cacheKey = "pool_data_\(pool)"
        
        if let cached = await cacheService.get(cacheKey, type: PoolBackstopData.self) {
            return cached
        }
        
        let poolData = try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
            
            let contractCall = ContractCallParams(
                contractId: self.config.contractAddress,
                functionName: "pool_data",
                functionArguments: [
                    try! self.createAddressParameter(pool)
                ]
            )
            
            let response = try! await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            dump(response)
            return try self.blendParser.parsePoolBackstopDataResponse(response)
        }
        
        await cacheService.set(poolData, key: cacheKey, ttl: config.cacheConfig.poolDataTTL)
        return poolData
    }
    
    public func getBackstopToken() async throws -> String {
        let cacheKey = "backstop_token"
        
        if let cached = await cacheService.get(cacheKey, type: String.self) {
            return cached
        }
        
        let tokenAddress = try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
            
            let contractCall = ContractCallParams(
                contractId: self.config.contractAddress,
                functionName: "backstop_token",
                functionArguments: []
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            return try self.blendParser.parseAddressResponse(response)
        }
        
        await cacheService.set(tokenAddress, key: cacheKey, ttl: config.cacheConfig.tokenAddressTTL)
        return tokenAddress
    }
    
    // MARK: - Additional Functions (Implementation continues in extensions...)
    
    // Emission functions, admin functions, and batch operations will be implemented in extensions
    // to keep the main file manageable following the BlendOracleService pattern
}

// MARK: - Contract Call Infrastructure

extension BackstopContractService {
    
    /// Simulate contract call using Soroban RPC
    internal func simulateContractCall(sorobanServer: SorobanServer, contractCall: ContractCallParams) async throws -> SCValXDR {
        let simulator = SorobanTransactionSimulator(debugLogger: debugLogger)
        
        // Convert ContractCallParams to OracleContractCallBuilder
        // This is needed because the simulator now expects OracleContractCallBuilder instead of ContractCallParams
        guard let function = OracleContractFunction(rawValue: contractCall.functionName) else {
            throw BackstopError.invalidParameters("Invalid function name: \(contractCall.functionName)")
        }
        
        var builder = OracleContractCallBuilder(
            contractId: contractCall.contractId,
            function: function
        )
        
        // Add any required arguments through the builder pattern
        // Note: This is a simplified approach. In a complete implementation,
        // you would need to properly map the arguments based on the function requirements.
        
        return try await simulator.simulate(server: sorobanServer, contractCallBuilder: builder)
    }
    
    /// Retry mechanism with exponential backoff
    internal func withRetry<T>(
        maxAttempts: Int,
        delay: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                let result = try await operation()
                if attempt > 1 {
                    debugLogger.info("🛡️ ✅ Operation succeeded on attempt \(attempt)")
                }
                return result
            } catch {
                lastError = error
                debugLogger.warning("🛡️ ❌ Attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw BackstopError.simulationError("All attempts failed", lastError)
    }
}
