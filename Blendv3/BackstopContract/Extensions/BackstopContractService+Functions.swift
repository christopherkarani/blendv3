import Foundation
import stellarsdk

// MARK: - Emission Functions

extension BackstopContractService {
    
    public func gulpEmissions() async throws {
        try await withTiming(operation: "gulpEmissions") {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
                
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "gulp_emissions",
                    functionArguments: []
                )
                
                _ = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            }
        }
    }
    
    public func addReward(toAdd: String, toRemove: String) async throws {
        // Allow empty strings for toAdd or toRemove, but at least one should be provided
        guard !toAdd.isEmpty || !toRemove.isEmpty else {
            throw BackstopError.invalidParameters("Either toAdd or toRemove must be provided")
        }
        
        if !toAdd.isEmpty {
            try validateAddress(toAdd, name: "toAdd")
        }
        if !toRemove.isEmpty {
            try validateAddress(toRemove, name: "toRemove")
        }
        
        try await withTiming(operation: "addReward") {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
                
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "add_reward",
                    functionArguments: [
                        try self.createAddressParameter(toAdd.isEmpty ? toRemove : toAdd),
                        try self.createAddressParameter(toRemove.isEmpty ? toAdd : toRemove)
                    ]
                )
                
                _ = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            }
        }
    }
    
    public func gulpPoolEmissions(poolAddress: String) async throws -> Int128 {
        try validateAddress(poolAddress, name: "poolAddress")
        
        return try await withTiming(operation: "gulpPoolEmissions") {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
                
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "gulp_pool_emissions",
                    functionArguments: [
                        try self.createAddressParameter(poolAddress)
                    ]
                )
                
                let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
                return try self.parseI128Response(response)
            }
        }
    }
    
    public func claim(from: String, poolAddresses: [String], to: String) async throws -> ClaimResult {
        try validateAddress(from, name: "from")
        try validateAddress(to, name: "to")
        try validateNonEmptyArray(poolAddresses, name: "poolAddresses")
        
        for (index, poolAddress) in poolAddresses.enumerated() {
            try validateAddress(poolAddress, name: "poolAddresses[\(index)]")
        }
        
        return try await withTiming(operation: "claim") {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
                
                // Create vector of pool addresses
                let poolAddressParams = try poolAddresses.map { poolAddress in
                    try self.createAddressParameter(poolAddress)
                }
                
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "claim",
                    functionArguments: [
                        try self.createAddressParameter(from),
                        self.createVectorParameter(poolAddressParams),
                        try self.createAddressParameter(to)
                    ]
                )
                
                let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
                let totalClaimed = try self.parseI128Response(response)
                
                return ClaimResult(totalClaimed: totalClaimed)
            }
        }
    }
}

// MARK: - Administrative Functions

extension BackstopContractService {
    
    public func drop() async throws {
        try await withTiming(operation: "drop") {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
                
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "drop",
                    functionArguments: []
                )
                
                _ = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            }
        }
    }
    
    public func draw(poolAddress: String, amount: Decimal, to: String) async throws {
        try validateAddress(poolAddress, name: "poolAddress")
        try validateAmount(amount, name: "amount")
        try validateAddress(to, name: "to")
        
        try await withTiming(operation: "draw") {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
                
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "draw",
                    functionArguments: [
                        try self.createAddressParameter(poolAddress),
                        try self.createAmountParameter(amount),
                        try self.createAddressParameter(to)
                    ]
                )
                
                _ = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            }
        }
    }
    
    public func donate(from: String, poolAddress: String, amount: Decimal) async throws {
        try validateAddress(from, name: "from")
        try validateAddress(poolAddress, name: "poolAddress")
        try validateAmount(amount, name: "amount")
        
        try await withTiming(operation: "donate") {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
                
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "donate",
                    functionArguments: [
                        try self.createAddressParameter(from),
                        try self.createAddressParameter(poolAddress),
                        try self.createAmountParameter(amount)
                    ]
                )
                
                _ = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            }
        }
    }
    
    public func updateTokenValues() async throws -> TokenValueUpdateResult {
        return try await withTiming(operation: "updateTokenValues") {
            try await withRetry(maxAttempts: maxRetries, delay: retryDelay) {
                let sorobanServer = SorobanServer(endpoint: self.config.rpcUrl)
                
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "update_tkn_val",
                    functionArguments: []
                )
                
                let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
                let (blndValue, usdcValue) = try self.parseTokenValueTupleResponse(response)
                
                return TokenValueUpdateResult(blndValue: blndValue, usdcValue: usdcValue)
            }
        }
    }
}

// MARK: - Batch Operations

extension BackstopContractService {
    
    public func getUserBalances(user: String, pools: [String]) async throws -> [String: UserBalance] {
        try validateAddress(user, name: "user")
        try validateNonEmptyArray(pools, name: "pools")
        
        for (index, pool) in pools.enumerated() {
            try validateAddress(pool, name: "pools[\(index)]")
        }
        
        return try await withTiming(operation: "getUserBalances(batch)") {
            var results: [String: UserBalance] = [:]
            
            // Execute requests concurrently for better performance
            try await withThrowingTaskGroup(of: (String, UserBalance).self) { group in
                for pool in pools {
                    group.addTask {
                        let balance = try await self.getUserBalance(pool: pool, user: user)
                        return (pool, balance)
                    }
                }
                
                for try await (pool, balance) in group {
                    results[pool] = balance
                }
            }
            
            return results
        }
    }
    
    public func getPoolDataBatch(pools: [String]) async throws -> [String: PoolBackstopData] {
        try validateNonEmptyArray(pools, name: "pools")
        
        for (index, pool) in pools.enumerated() {
            try validateAddress(pool, name: "pools[\(index)]")
        }
        
        return try await withTiming(operation: "getPoolDataBatch") {
            var results: [String: PoolBackstopData] = [:]
            
            // Execute requests concurrently for better performance
            try await withThrowingTaskGroup(of: (String, PoolBackstopData).self) { group in
                for pool in pools {
                    group.addTask {
                        let poolData = try await self.getPoolData(pool: pool)
                        return (pool, poolData)
                    }
                }
                
                for try await (pool, poolData) in group {
                    results[pool] = poolData
                }
            }
            
            return results
        }
    }
}

// MARK: - Additional Parsing Functions

extension BackstopContractService {
    
    /// Parse tuple response for token values (BLND, USDC)
    internal func parseTokenValueTupleResponse(_ response: SCValXDR) throws -> (Int128, Int128) {
        guard case .vec(let vecOptional) = response,
              let vec = vecOptional,
              vec.count == 2 else {
            throw BackstopError.parsingError(
                "parseTokenValueTupleResponse",
                expectedType: "tuple<i128,i128>",
                actualType: String(describing: type(of: response))
            )
        }
        
        let blndValue = try parseI128Response(vec[0])
        let usdcValue = try parseI128Response(vec[1])
        
        return (blndValue, usdcValue)
    }
}

// MARK: - Configuration Factory

extension BackstopContractService {
    
    /// Create service configuration for testnet
    public static func testnetConfig() -> BackstopServiceConfig {
        return BackstopServiceConfig(
            contractAddress: BlendUSDCConstants.Testnet.backstop,
            rpcUrl: BlendUSDCConstants.RPC.testnet,
            network: .testnet
        )
    }
    
    /// Create service configuration for mainnet
    public static func mainnetConfig() -> BackstopServiceConfig {
        return BackstopServiceConfig(
            contractAddress: BlendUSDCConstants.Mainnet.backstop,
            rpcUrl: BlendUSDCConstants.RPC.mainnet,
            network: .public
        )
    }
    
    /// Create service instance with default testnet configuration
    public static func createTestnetService(
        networkService: NetworkService,
        cacheService: CacheServiceProtocol
    ) -> BackstopContractService {
        return BackstopContractService(
            networkService: networkService,
            cacheService: cacheService,
            config: testnetConfig()
        )
    }
    
    /// Create service instance with default mainnet configuration
    public static func createMainnetService(
        networkService: NetworkService,
        cacheService: CacheServiceProtocol
    ) -> BackstopContractService {
        return BackstopContractService(
            networkService: networkService,
            cacheService: cacheService,
            config: mainnetConfig()
        )
    }
}
