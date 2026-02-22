import Foundation
import stellarsdk

// MARK: - Emission Functions

extension BackstopContractService {
    
    public func gulpEmissions() async throws {
        try await withTiming(operation: "gulpEmissions", execute: {
            let contractCall = ContractCallParams(
                contractId: self.config.contractAddress,
                functionName: "gulp_emissions",
                functionArguments: []
            )
            
            // 1. Simulate the contract call first
            let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
            
            switch simulationResult {
            case .success(_):
                // 2. If simulation succeeds, invoke the actual contract
                do {
                    _ = try await self.networkService.invokeContractFunction(contractCall: contractCall)
                    // Gulp emissions doesn't return a value
                    return
                } catch {
                    self.debugLogger.error("🛡️ ❌ Gulp emissions invocation failed: \(error.localizedDescription)")
                    throw self.convertInvocationError(error, operation: "gulpEmissions")
                }
                
            case .failure(let error):
                self.debugLogger.error("🛡️ ❌ Gulp emissions simulation failed: \(error.localizedDescription)")
                throw self.convertNetworkError(error, operation: "gulpEmissions")
            }
        })
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
        
        try await withTiming(operation: "addReward", execute: {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "add_reward",
                    functionArguments: [
                        try self.createAddressParameter(toAdd.isEmpty ? toRemove : toAdd),
                        try self.createAddressParameter(toRemove.isEmpty ? toAdd : toRemove)
                    ]
                )
                
                // 1. Simulate the contract call first
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(_):
                    // 2. If simulation succeeds, invoke the actual contract
                    do {
                        _ = try await self.networkService.invokeContractFunction(contractCall: contractCall)
                        // Add reward doesn't return a value
                        return
                    } catch {
                        self.debugLogger.error("🛡️ ❌ Add reward invocation failed: \(error.localizedDescription)")
                        throw self.convertInvocationError(error, operation: "addReward")
                    }
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Add reward simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "addReward")
                }
        })
    }
    
    public func gulpPoolEmissions(poolAddress: String) async throws -> Int128 {
        try validateAddress(poolAddress, name: "poolAddress")
        
        return try await withTiming(operation: "gulpPoolEmissions", execute: {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "gulp_pool_emissions",
                    functionArguments: [
                        try self.createAddressParameter(poolAddress)
                    ]
                )
                
                // 1. Simulate the contract call first
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(_):
                    // 2. If simulation succeeds, invoke the actual contract
                    do {
                        let invocationResult = try await self.networkService.invokeContractFunction(contractCall: contractCall)
                        return try self.blendParser.parseI128Response(invocationResult)
                    } catch {
                        self.debugLogger.error("🛡️ ❌ Gulp pool emissions invocation failed: \(error.localizedDescription)")
                        throw self.convertInvocationError(error, operation: "gulpPoolEmissions")
                    }
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Gulp pool emissions simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "gulpPoolEmissions")
                }
        })
    }
    
    public func claim(from: String, poolAddresses: [String], to: String) async throws -> ClaimResult {
        try validateAddress(from, name: "from")
        try validateAddress(to, name: "to")
        try validateNonEmptyArray(poolAddresses, name: "poolAddresses")
        
        for (index, poolAddress) in poolAddresses.enumerated() {
            try validateAddress(poolAddress, name: "poolAddresses[\(index)]")
        }
        
        return try await withTiming(operation: "claim", execute: {
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
                
                // 1. Simulate the contract call first
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(_):
                    // 2. If simulation succeeds, invoke the actual contract
                    do {
                        let invocationResult = try await self.networkService.invokeContractFunction(contractCall: contractCall)
                        let totalClaimed = try self.blendParser.parseI128Response(invocationResult)
                        return ClaimResult(totalClaimed: totalClaimed)
                    } catch {
                        self.debugLogger.error("🛡️ ❌ Claim invocation failed: \(error.localizedDescription)")
                        throw self.convertInvocationError(error, operation: "claim")
                    }
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Claim simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "claim")
                }
        })
    }
}

// MARK: - Administrative Functions

extension BackstopContractService {
    
    public func drop() async throws {
        try await withTiming(operation: "drop", execute: {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "drop",
                    functionArguments: []
                )
                
                // 1. Simulate the contract call first
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(_):
                    // 2. If simulation succeeds, invoke the actual contract
                    do {
                        _ = try await self.networkService.invokeContractFunction(contractCall: contractCall)
                        // Drop doesn't return a value
                        return
                    } catch {
                        self.debugLogger.error("🛡️ ❌ Drop invocation failed: \(error.localizedDescription)")
                        throw self.convertInvocationError(error, operation: "drop")
                    }
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Drop simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "drop")
                }
        })
    }
    
    public func draw(poolAddress: String, amount: Decimal, to: String) async throws {
        try validateAddress(poolAddress, name: "poolAddress")
        try validateAmount(amount, name: "amount")
        try validateAddress(to, name: "to")
        
        try await withTiming(operation: "draw", execute: {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "draw",
                    functionArguments: [
                        try self.createAddressParameter(poolAddress),
                        try self.createAmountParameter(amount),
                        try self.createAddressParameter(to)
                    ]
                )
                
                // 1. Simulate the contract call first
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(_):
                    // 2. If simulation succeeds, invoke the actual contract
                    do {
                        _ = try await self.networkService.invokeContractFunction(contractCall: contractCall)
                        // Draw doesn't return a value
                        return
                    } catch {
                        self.debugLogger.error("🛡️ ❌ Draw invocation failed: \(error.localizedDescription)")
                        throw self.convertInvocationError(error, operation: "draw")
                    }
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Draw simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "draw")
                }
        })
    }
    
    public func donate(from: String, poolAddress: String, amount: Decimal) async throws {
        try validateAddress(from, name: "from")
        try validateAddress(poolAddress, name: "poolAddress")
        try validateAmount(amount, name: "amount")
        
        try await withTiming(operation: "donate", execute: {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "donate",
                    functionArguments: [
                        try self.createAddressParameter(from),
                        try self.createAddressParameter(poolAddress),
                        try self.createAmountParameter(amount)
                    ]
                )
                
                // 1. Simulate the contract call first
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(_):
                    // 2. If simulation succeeds, invoke the actual contract
                    do {
                        _ = try await self.networkService.invokeContractFunction(contractCall: contractCall)
                        // Donate doesn't return a value
                        return
                    } catch {
                        self.debugLogger.error("🛡️ ❌ Donate invocation failed: \(error.localizedDescription)")
                        throw self.convertInvocationError(error, operation: "donate")
                    }
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Donate simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "donate")
                }
        })
    }
    
    public func updateTokenValues() async throws -> TokenValueUpdateResult {
        return try await withTiming(operation: "updateTokenValues", execute: {
                let contractCall = ContractCallParams(
                    contractId: self.config.contractAddress,
                    functionName: "update_tkn_val",
                    functionArguments: []
                )
                
                // 1. Simulate the contract call first
                let simulationResult: SimulationStatus<SCValXDR> = await self.networkService.simulateContractFunction(contractCall: contractCall)
                
                switch simulationResult {
                case .success(_):
                    // 2. If simulation succeeds, invoke the actual contract
                    do {
                        let invocationResult = try await self.networkService.invokeContractFunction(contractCall: contractCall)
                        let (blndValue, usdcValue) = try self.blendParser.parseTokenValueTupleResponse(invocationResult)
                        return TokenValueUpdateResult(blndValue: blndValue, usdcValue: usdcValue)
                    } catch {
                        self.debugLogger.error("🛡️ ❌ Update token values invocation failed: \(error.localizedDescription)")
                        throw self.convertInvocationError(error, operation: "updateTokenValues")
                    }
                    
                case .failure(let error):
                    self.debugLogger.error("🛡️ ❌ Update token values simulation failed: \(error.localizedDescription)")
                    throw self.convertNetworkError(error, operation: "updateTokenValues")
                }
        })
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
        
        return try await withTiming(operation: "getUserBalances(batch)", execute: {
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
        })
    }
    
    public func getPoolDataBatch(pools: [String]) async throws -> [String: PoolBackstopData] {
        try validateNonEmptyArray(pools, name: "pools")
        
        for (index, pool) in pools.enumerated() {
            try validateAddress(pool, name: "pools[\(index)]")
        }
        
        return try await withTiming(operation: "getPoolDataBatch", execute: {
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
        })
    }
}


