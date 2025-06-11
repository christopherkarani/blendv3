import Foundation

/// Pool service implementation for Blend protocol
/// Uses NetworkService for networking and BlendParser for parsing
@MainActor
class PoolService: ObservableObject, PoolServiceProtocol {
    
    // MARK: - Dependencies
    
    private let networkService: NetworkService
    private let parser: BlendParser
    
    // MARK: - Published Properties
    
    @Published var pools: [String: PoolConfig] = [:]
    @Published var reserves: [String: [String: PoolReserve]] = [:] // poolAddress -> assetId -> reserve
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Initialization
    
    init(networkService: NetworkService = NetworkService(), parser: BlendParser = BlendParser.shared) {
        self.networkService = networkService
        self.parser = parser
    }
    
    // MARK: - Pool Information
    
    func getPoolConfig(poolAddress: String) async throws -> PoolConfig {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_config",
                args: [],
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            let configMap = try parser.parseMap(from: result)
            
            let poolConfig = try parsePoolConfig(from: configMap, poolAddress: poolAddress)
            
            // Update state
            DispatchQueue.main.async {
                self.pools[poolAddress] = poolConfig
                self.error = nil
            }
            
            return poolConfig
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getPoolReserves(poolAddress: String) async throws -> [String: PoolReserve] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_reserves",
                args: [],
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            let reservesMap = try parser.parseMap(from: result)
            
            var poolReserves: [String: PoolReserve] = [:]
            
            for (assetId, reserveScVal) in reservesMap {
                let reserve = try parsePoolReserve(from: reserveScVal, assetId: assetId)
                poolReserves[assetId] = reserve
            }
            
            // Update state
            DispatchQueue.main.async {
                self.reserves[poolAddress] = poolReserves
                self.error = nil
            }
            
            return poolReserves
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getPoolStatus(poolAddress: String) async throws -> PoolStatus {
        do {
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_status",
                args: [],
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            let statusMap = try parser.parseMap(from: result)
            
            return try parsePoolStatus(from: statusMap)
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Liquidity Operations
    
    func supply(
        poolAddress: String,
        assetId: String,
        amount: UInt64,
        sourceKeyPair: Any
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let assetArg = try parser.createSCVal(from: assetId)
            let amountArg = try parser.createSCVal(from: amount)
            let args = [assetArg, amountArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "supply",
                args: args,
                sourceAccount: sourceKeyPair
            )
            
            // Extract transaction hash from response
            return response.hash
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func withdraw(
        poolAddress: String,
        assetId: String,
        amount: UInt64,
        sourceKeyPair: Any
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let assetArg = try parser.createSCVal(from: assetId)
            let amountArg = try parser.createSCVal(from: amount)
            let args = [assetArg, amountArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "withdraw",
                args: args,
                sourceAccount: sourceKeyPair
            )
            
            return response.hash
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getSuppliedBalance(
        poolAddress: String,
        userAddress: String,
        assetId: String
    ) async throws -> UInt64 {
        do {
            let userArg = try parser.createAddressSCVal(from: userAddress)
            let assetArg = try parser.createSCVal(from: assetId)
            let args = [userArg, assetArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_supplied_balance",
                args: args,
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            return try parser.parseUInt64(from: result)
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Borrowing Operations
    
    func borrow(
        poolAddress: String,
        assetId: String,
        amount: UInt64,
        sourceKeyPair: Any
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let assetArg = try parser.createSCVal(from: assetId)
            let amountArg = try parser.createSCVal(from: amount)
            let args = [assetArg, amountArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "borrow",
                args: args,
                sourceAccount: sourceKeyPair
            )
            
            return response.hash
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func repay(
        poolAddress: String,
        assetId: String,
        amount: UInt64,
        sourceKeyPair: Any
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let assetArg = try parser.createSCVal(from: assetId)
            let amountArg = try parser.createSCVal(from: amount)
            let args = [assetArg, amountArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "repay",
                args: args,
                sourceAccount: sourceKeyPair
            )
            
            return response.hash
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getBorrowedBalance(
        poolAddress: String,
        userAddress: String,
        assetId: String
    ) async throws -> UInt64 {
        do {
            let userArg = try parser.createAddressSCVal(from: userAddress)
            let assetArg = try parser.createSCVal(from: assetId)
            let args = [userArg, assetArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_borrowed_balance",
                args: args,
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            return try parser.parseUInt64(from: result)
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Pool Analytics
    
    func getPoolUtilization(poolAddress: String) async throws -> [String: Double] {
        do {
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_utilization",
                args: [],
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            let utilizationMap = try parser.parseMap(from: result)
            
            var utilization: [String: Double] = [:]
            for (assetId, utilizationScVal) in utilizationMap {
                let rate = try parser.parseUInt64(from: utilizationScVal)
                utilization[assetId] = Double(rate) / 1_000_000 // Convert to percentage
            }
            
            return utilization
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getInterestRates(poolAddress: String) async throws -> [String: InterestRates] {
        do {
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_interest_rates",
                args: [],
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            let ratesMap = try parser.parseMap(from: result)
            
            var interestRates: [String: InterestRates] = [:]
            for (assetId, ratesScVal) in ratesMap {
                let rates = try parseInterestRates(from: ratesScVal)
                interestRates[assetId] = rates
            }
            
            return interestRates
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getPoolTVL(poolAddress: String) async throws -> Double {
        do {
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_tvl",
                args: [],
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            let tvl = try parser.parseUInt64(from: result)
            
            return Double(tvl) / 1_000_000 // Convert from microunits
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Risk Management
    
    func getPositionHealth(
        poolAddress: String,
        userAddress: String
    ) async throws -> PositionHealth {
        do {
            let userArg = try parser.createAddressSCVal(from: userAddress)
            let args = [userArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_position_health",
                args: args,
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            return try parsePositionHealth(from: result)
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func canLiquidate(
        poolAddress: String,
        userAddress: String
    ) async throws -> Bool {
        do {
            let userArg = try parser.createAddressSCVal(from: userAddress)
            let args = [userArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "can_liquidate",
                args: args,
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            return try parser.parseBool(from: result)
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    func getLiquidationThresholds(
        poolAddress: String
    ) async throws -> [String: Double] {
        do {
            let response = try await networkService.invokeContract(
                contractAddress: poolAddress,
                method: "get_liquidation_thresholds",
                args: [],
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            let thresholdsMap = try parser.parseMap(from: result)
            
            var thresholds: [String: Double] = [:]
            for (assetId, thresholdScVal) in thresholdsMap {
                let threshold = try parser.parseUInt64(from: thresholdScVal)
                thresholds[assetId] = Double(threshold) / 1_000_000
            }
            
            return thresholds
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Private Parsing Methods
    
    private func parsePoolConfig(from configMap: [String: Any], poolAddress: String) throws -> PoolConfig {
        // This is a simplified version - actual implementation would parse the full config structure
        let name = "Pool" // Would be parsed from config
        let assets: [PoolAsset] = [] // Would be parsed from config
        let reserveFactor = 0.1 // Would be parsed from config
        let maxUtilizationRate = 0.8 // Would be parsed from config
        let oracle = "" // Would be parsed from config
        
        return PoolConfig(
            poolAddress: poolAddress,
            name: name,
            assets: assets,
            reserveFactor: reserveFactor,
            maxUtilizationRate: maxUtilizationRate,
            oracle: oracle,
            backstop: nil
        )
    }
    
    private func parsePoolReserve(from scVal: Any, assetId: String) throws -> PoolReserve {
        // Simplified parsing - actual implementation would parse the reserve structure
        return PoolReserve(
            assetId: assetId,
            totalSupplied: 0,
            totalBorrowed: 0,
            availableLiquidity: 0,
            utilizationRate: 0.0,
            supplyIndex: 1_000_000,
            borrowIndex: 1_000_000,
            lastUpdateTime: Date()
        )
    }
    
    private func parsePoolStatus(from statusMap: [String: Any]) throws -> PoolStatus {
        // Simplified parsing - actual implementation would parse the status structure
        return PoolStatus(
            isActive: true,
            isPaused: false,
            totalSuppliedValue: 0.0,
            totalBorrowedValue: 0.0,
            totalLiquidityValue: 0.0,
            utilizationRate: 0.0,
            lastUpdateTime: Date()
        )
    }
    
    private func parseInterestRates(from scVal: Any) throws -> InterestRates {
        // Simplified parsing - actual implementation would parse the rates structure
        return InterestRates(
            supplyRate: 0.0,
            borrowRate: 0.0,
            baseRate: 0.0,
            slope1: 0.0,
            slope2: 0.0,
            optimalUtilization: 0.8
        )
    }
    
    private func parsePositionHealth(from scVal: Any) throws -> PositionHealth {
        // Simplified parsing - actual implementation would parse the health structure
        return PositionHealth(
            healthFactor: 1.5,
            totalCollateralValue: 0.0,
            totalBorrowedValue: 0.0,
            availableBorrowValue: 0.0,
            liquidationThreshold: 0.75,
            isHealthy: true
        )
    }
    
    private func getDefaultKeyPair() -> Any {
        fatalError("KeyPair should be provided through dependency injection")
    }
}

// MARK: - Error Types

enum PoolServiceError: Error, LocalizedError {
    case invalidPoolAddress(String)
    case insufficientLiquidity
    case exceededBorrowLimit
    case positionUnhealthy
    case assetNotSupported(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPoolAddress(let address):
            return "Invalid pool address: \(address)"
        case .insufficientLiquidity:
            return "Insufficient liquidity in pool"
        case .exceededBorrowLimit:
            return "Borrow amount exceeds limit"
        case .positionUnhealthy:
            return "Position health factor too low"
        case .assetNotSupported(let assetId):
            return "Asset not supported: \(assetId)"
        }
    }
}