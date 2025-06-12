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
        
        return try await withTiming(operation: "deposit", execute: {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "deposit",
                    functionArguments: [
                        try self.createAddressParameter(from),
                        try self.createAddressParameter(poolAddress),
                        try self.createAmountParameter(amount)
                    ]
                )
                
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(let result):
                    let sharesReceived = try self.blendParser.parseI128Response(result.result)
                    return DepositResult(sharesReceived: sharesReceived)
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Deposit simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "deposit")
                }
            }
        })
    }
    
    public func queueWithdrawal(from: String, poolAddress: String, amount: Decimal) async throws -> Q4W {
        try validateAddress(from, name: "from")
        try validateAddress(poolAddress, name: "poolAddress")
        try validateAmount(amount, name: "amount")
        
        return try await withTiming(operation: "queueWithdrawal", execute: {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "queue_withdrawal",
                    functionArguments: [
                        try self.createAddressParameter(from),
                        try self.createAddressParameter(poolAddress),
                        try self.createAmountParameter(amount)
                    ]
                )
                
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(let result):
                    return try self.blendParser.parseQ4WResponse(result.result)
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Queue withdrawal simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "queueWithdrawal")
                }
            }
        })
    }
    
    public func dequeueWithdrawal(from: String, poolAddress: String, amount: Decimal) async throws {
        try validateAddress(from, name: "from")
        try validateAddress(poolAddress, name: "poolAddress")
        try validateAmount(amount, name: "amount")
        
        try await withTiming(operation: "dequeueWithdrawal", execute: {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "dequeue_withdrawal",
                    functionArguments: [
                        try self.createAddressParameter(from),
                        try self.createAddressParameter(poolAddress),
                        try self.createAmountParameter(amount)
                    ]
                )
                
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(_):
                    // Dequeue withdrawal doesn't return a value
                    return
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Dequeue withdrawal simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "dequeueWithdrawal")
                }
            }
        })
    }
    
    public func withdraw(from: String, poolAddress: String, amount: Decimal) async throws -> WithdrawalResult {
        try validateAddress(from, name: "from")
        try validateAddress(poolAddress, name: "poolAddress")
        try validateAmount(amount, name: "amount")
        
        return try await withTiming(operation: "withdraw", execute: {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "withdraw",
                    functionArguments: [
                        try self.createAddressParameter(from),
                        try self.createAddressParameter(poolAddress),
                        try self.createAmountParameter(amount)
                    ]
                )
                
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(let result):
                    let amountWithdrawn = try self.blendParser.parseI128Response(result.result)
                    return WithdrawalResult(amountWithdrawn: amountWithdrawn)
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Withdraw simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "withdraw")
                }
            }
        })
    }
    
    // MARK: - Query Functions
    
    public func getUserBalance(pool: String, user: String) async throws -> UserBalance {
        try validateAddress(pool, name: "pool")
        try validateAddress(user, name: "user")
        
        let cacheKey = "user_balance_\(user)_\(pool)"
        
        if let cached = await cacheService.get(cacheKey, type: UserBalance.self) {
            return cached
        }
        
        let balance = try await withTiming(operation: "getUserBalance", execute: {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "user_balance",
                    functionArguments: [
                        try self.createAddressParameter(pool),
                        try self.createAddressParameter(user)
                    ]
                )
                
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(let result):
                    return try self.blendParser.parseUserBalanceResponse(result.result)
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Get user balance simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "getUserBalance")
                }
            }
        })
        
        await cacheService.set(balance, key: cacheKey, ttl: config.cacheConfig.userBalanceTTL)
        return balance
    }
    
    public func getPoolData(pool: String) async throws -> PoolBackstopData {
        try validateAddress(pool, name: "pool")
        
        let cacheKey = "pool_data_\(pool)"
        
        if let cached = await cacheService.get(cacheKey, type: PoolBackstopData.self) {
            return cached
        }
        
        let poolData = try await withTiming(operation: "getPoolData", execute: {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "pool_data",
                    functionArguments: [
                        try self.createAddressParameter(pool)
                    ]
                )
                
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(let result):
                    return try self.blendParser.parsePoolBackstopDataResponse(result.result)
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Get pool data simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "getPoolData")
                }
            }
        })
        
        await cacheService.set(poolData, key: cacheKey, ttl: config.cacheConfig.poolDataTTL)
        return poolData
    }
    
    public func getBackstopToken() async throws -> String {
        let cacheKey = "backstop_token"
        
        if let cached = await cacheService.get(cacheKey, type: String.self) {
            return cached
        }
        
        let tokenAddress = try await withTiming(operation: "getBackstopToken", execute: {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "backstop_token",
                    functionArguments: []
                )
                
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(let result):
                    return try self.blendParser.parseAddressResponse(result.result)
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Get backstop token simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "getBackstopToken")
                }
            }
        })
        
        await cacheService.set(tokenAddress, key: cacheKey, ttl: config.cacheConfig.tokenAddressTTL)
        return tokenAddress
    }
    
    // MARK: - Additional Functions (Implementation continues in extensions...)
    
    // Emission functions, admin functions, and batch operations will be implemented in extensions
    // to keep the main file manageable following the BlendOracleService pattern
}

// MARK: - Contract Call Infrastructure

extension BackstopContractService {
    
    /// Convert NetworkSimulationError to BackstopError
    /// - Parameters:
    ///   - error: The network simulation error
    ///   - operation: The operation that failed for context
    /// - Returns: BackstopError with appropriate error type
    internal func convertNetworkError(_ error: NetworkSimulationError, operation: String) -> BackstopError {
        switch error {
        case .transactionFailed(let message):
            return BackstopError.simulationError("Transaction failed during \(operation): \(message)", nil)
        case .connectionFailed(let message):
            return BackstopError.simulationError("Connection failed during \(operation): \(message)", nil)
        case .invalidResponse(let message):
            return BackstopError.simulationError("Invalid response during \(operation): \(message)", nil)
        case .unknown(let message):
            return BackstopError.simulationError("Unknown error during \(operation): \(message)", nil)
        }
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
