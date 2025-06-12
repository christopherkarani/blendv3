import Foundation
import stellarsdk

// MARK: - Backstop Contract Service Protocol

/// Protocol defining the interface for Backstop contract operations
/// Follows the same patterns as BlendOracleServiceProtocol for consistency
public protocol BackstopContractServiceProtocol: Sendable {
    
    // MARK: - Core Deposit/Withdrawal Functions
    
    /// Deposit tokens into the backstop for a specific pool
    /// - Parameters:
    ///   - from: Address making the deposit
    ///   - poolAddress: Target pool address
    ///   - amount: Amount to deposit (in token decimals)
    /// - Returns: Number of shares received
    /// - Throws: BackstopError for various failure conditions
    func deposit(from: String, poolAddress: String, amount: Decimal) async throws -> DepositResult
    
    /// Queue a withdrawal from the backstop
    /// - Parameters:
    ///   - from: Address requesting withdrawal
    ///   - poolAddress: Pool to withdraw from
    ///   - amount: Amount of shares to queue for withdrawal
    /// - Returns: Q4W object with withdrawal details
    /// - Throws: BackstopError for various failure conditions
    func queueWithdrawal(from: String, poolAddress: String, amount: Decimal) async throws -> Q4W
    
    /// Cancel a queued withdrawal
    /// - Parameters:
    ///   - from: Address that queued the withdrawal
    ///   - poolAddress: Pool address
    ///   - amount: Amount to dequeue
    /// - Throws: BackstopError for various failure conditions
    func dequeueWithdrawal(from: String, poolAddress: String, amount: Decimal) async throws
    
    /// Execute a withdrawal that has passed the queue period
    /// - Parameters:
    ///   - from: Address executing withdrawal
    ///   - poolAddress: Pool address
    ///   - amount: Amount to withdraw
    /// - Returns: Amount of tokens withdrawn
    /// - Throws: BackstopError for various failure conditions
    func withdraw(from: String, poolAddress: String, amount: Decimal) async throws -> WithdrawalResult
    
    // MARK: - Query Functions
    
    /// Get user's balance information for a specific pool
    /// - Parameters:
    ///   - pool: Pool address
    ///   - user: User address
    /// - Returns: UserBalance with shares and queued withdrawals
    /// - Throws: BackstopError for parsing or network issues
    func getUserBalance(pool: String, user: String) async throws -> UserBalance
    
    /// Get pool's backstop data
    /// - Parameter pool: Pool address
    /// - Returns: PoolBackstopData with pool statistics
    /// - Throws: BackstopError for parsing or network issues
    func getPoolData(pool: String) async throws -> PoolBackstopData
    
    /// Get the backstop token address
    /// - Returns: Address of the backstop token contract
    /// - Throws: BackstopError for network or parsing issues
    func getBackstopToken() async throws -> String
    
    // MARK: - Emission Functions
    
    /// Process global emissions
    /// - Throws: BackstopError for transaction failures
    func gulpEmissions() async throws
    
    /// Add or remove reward tokens
    /// - Parameters:
    ///   - toAdd: Address to add to rewards (can be empty)
    ///   - toRemove: Address to remove from rewards (can be empty)
    /// - Throws: BackstopError for transaction failures
    func addReward(toAdd: String, toRemove: String) async throws
    
    /// Process pool-specific emissions
    /// - Parameter poolAddress: Pool to process emissions for
    /// - Returns: Amount of emissions processed
    /// - Throws: BackstopError for transaction failures
    func gulpPoolEmissions(poolAddress: String) async throws -> Int128
    
    /// Claim rewards from multiple pools
    /// - Parameters:
    ///   - from: Address claiming rewards
    ///   - poolAddresses: List of pool addresses to claim from
    ///   - to: Address to send rewards to
    /// - Returns: Total amount claimed
    /// - Throws: BackstopError for transaction failures
    func claim(from: String, poolAddresses: [String], to: String) async throws -> ClaimResult
    
    // MARK: - Administrative Functions
    
    /// Execute emergency airdrop
    /// - Throws: BackstopError for authorization or execution issues
    func drop() async throws
    
    /// Emergency withdrawal from pool (admin function)
    /// - Parameters:
    ///   - poolAddress: Pool to withdraw from
    ///   - amount: Amount to withdraw
    ///   - to: Address to send withdrawn funds
    /// - Throws: BackstopError for authorization or execution issues
    func draw(poolAddress: String, amount: Decimal, to: String) async throws
    
    /// Donate tokens to a pool's backstop
    /// - Parameters:
    ///   - from: Address making donation
    ///   - poolAddress: Pool to donate to
    ///   - amount: Amount to donate
    /// - Throws: BackstopError for transaction failures
    func donate(from: String, poolAddress: String, amount: Decimal) async throws
    
    /// Update token values (admin function)
    /// - Returns: Tuple of updated BLND and USDC values
    /// - Throws: BackstopError for authorization or execution issues
    func updateTokenValues() async throws -> TokenValueUpdateResult
    
    // MARK: - Batch Operations
    
    /// Get balances for multiple pools for a user
    /// - Parameters:
    ///   - user: User address
    ///   - pools: Array of pool addresses
    /// - Returns: Dictionary mapping pool addresses to UserBalance
    /// - Throws: BackstopError for any individual pool failures
    func getUserBalances(user: String, pools: [String]) async throws -> [String: UserBalance]
    
    /// Get pool data for multiple pools
    /// - Parameter pools: Array of pool addresses
    /// - Returns: Dictionary mapping pool addresses to PoolBackstopData
    /// - Throws: BackstopError for any individual pool failures
    func getPoolDataBatch(pools: [String]) async throws -> [String: PoolBackstopData]
}

// MARK: - Error Types

/// Comprehensive error type for backstop operations
public enum BackstopError: LocalizedError, CustomDebugStringConvertible, Sendable {
    
    // MARK: - Contract Errors
    case contractError(BackstopContractError)
    case simulationError(String, Error?)
    case transactionError(String, Error?)
    
    // MARK: - Network Errors  
    case networkError(Error)
    case timeoutError(TimeInterval)
    case rpcError(String)
    
    // MARK: - Parameter Errors
    case invalidAddress(String)
    case invalidAmount(String)
    case invalidParameters(String)
    case missingRequiredParameter(String)
    
    // MARK: - Parsing Errors
    case parsingError(String, expectedType: String, actualType: String)
    case responseFormatError(String)
    case dataCorruptionError(String)
    
    // MARK: - Cache Errors
    case cacheError(Error)
    case cacheCorruption(String)
    
    // MARK: - Business Logic Errors
    case withdrawalNotExpired(Date)
    case insufficientShares(required: Int128, available: Int128)
    case poolNotFound(String)
    case userNotFound(String)
    case noActivePosition(String)
    
    // MARK: - Configuration Errors
    case configurationError(String)
    case contractAddressNotSet
    case networkNotConfigured
    
    // MARK: - LocalizedError Implementation
    public var errorDescription: String? {
        switch self {
        case .contractError(let error):
            return "Contract error: \(error.description)"
        case .simulationError(let message, let underlyingError):
            return "Simulation failed: \(message)" + (underlyingError.map { " (\($0.localizedDescription))" } ?? "")
        case .transactionError(let message, let underlyingError):
            return "Transaction failed: \(message)" + (underlyingError.map { " (\($0.localizedDescription))" } ?? "")
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeoutError(let duration):
            return "Operation timed out after \(duration) seconds"
        case .rpcError(let message):
            return "RPC error: \(message)"
        case .invalidAddress(let address):
            return "Invalid address: \(address)"
        case .invalidAmount(let amount):
            return "Invalid amount: \(amount)"
        case .invalidParameters(let details):
            return "Invalid parameters: \(details)"
        case .missingRequiredParameter(let parameter):
            return "Missing required parameter: \(parameter)"
        case .parsingError(let context, let expectedType, let actualType):
            return "Parsing error in \(context): expected \(expectedType), got \(actualType)"
        case .responseFormatError(let details):
            return "Response format error: \(details)"
        case .dataCorruptionError(let details):
            return "Data corruption detected: \(details)"
        case .cacheError(let error):
            return "Cache error: \(error.localizedDescription)"
        case .cacheCorruption(let details):
            return "Cache corruption: \(details)"
        case .withdrawalNotExpired(let expirationDate):
            return "Withdrawal not expired until \(expirationDate)"
        case .insufficientShares(let required, let available):
            return "Insufficient shares: need \(required), have \(available)"
        case .poolNotFound(let address):
            return "Pool not found: \(address)"
        case .userNotFound(let address):
            return "User not found: \(address)"
        case .noActivePosition(let address):
            return "No active position for user: \(address)"
        case .configurationError(let details):
            return "Configuration error: \(details)"
        case .contractAddressNotSet:
            return "Backstop contract address not configured"
        case .networkNotConfigured:
            return "Network configuration missing"
        }
    }
    
    // MARK: - CustomDebugStringConvertible Implementation
    public var debugDescription: String {
        switch self {
        case .contractError(let error):
            return "BackstopError.contractError(\(error))"
        case .simulationError(let message, let error):
            return "BackstopError.simulationError(message: \(message), error: \(error?.localizedDescription ?? "nil"))"
        case .transactionError(let message, let error):
            return "BackstopError.transactionError(message: \(message), error: \(error?.localizedDescription ?? "nil"))"
        case .networkError(let error):
            return "BackstopError.networkError(\(error))"
        case .timeoutError(let duration):
            return "BackstopError.timeoutError(\(duration))"
        case .rpcError(let message):
            return "BackstopError.rpcError(\(message))"
        case .invalidAddress(let address):
            return "BackstopError.invalidAddress(\(address))"
        case .invalidAmount(let amount):
            return "BackstopError.invalidAmount(\(amount))"
        case .invalidParameters(let details):
            return "BackstopError.invalidParameters(\(details))"
        case .missingRequiredParameter(let parameter):
            return "BackstopError.missingRequiredParameter(\(parameter))"
        case .parsingError(let context, let expectedType, let actualType):
            return "BackstopError.parsingError(context: \(context), expectedType: \(expectedType), actualType: \(actualType))"
        case .responseFormatError(let details):
            return "BackstopError.responseFormatError(\(details))"
        case .dataCorruptionError(let details):
            return "BackstopError.dataCorruptionError(\(details))"
        case .cacheError(let error):
            return "BackstopError.cacheError(\(error))"
        case .cacheCorruption(let details):
            return "BackstopError.cacheCorruption(\(details))"
        case .withdrawalNotExpired(let date):
            return "BackstopError.withdrawalNotExpired(\(date))"
        case .insufficientShares(let required, let available):
            return "BackstopError.insufficientShares(required: \(required), available: \(available))"
        case .poolNotFound(let address):
            return "BackstopError.poolNotFound(\(address))"
        case .userNotFound(let address):
            return "BackstopError.userNotFound(\(address))"
        case .noActivePosition(let address):
            return "BackstopError.noActivePosition(\(address))"
        case .configurationError(let details):
            return "BackstopError.configurationError(\(details))"
        case .contractAddressNotSet:
            return "BackstopError.contractAddressNotSet"
        case .networkNotConfigured:
            return "BackstopError.networkNotConfigured"
        }
    }
}

// MARK: - Cache Configuration

/// Cache configuration for backstop service
public struct BackstopCacheConfig: Sendable {
    public let userBalanceTTL: TimeInterval
    public let poolDataTTL: TimeInterval
    public let tokenAddressTTL: TimeInterval
    public let emissionDataTTL: TimeInterval
    
    public init(
        userBalanceTTL: TimeInterval = 60,      // 1 minute
        poolDataTTL: TimeInterval = 300,        // 5 minutes
        tokenAddressTTL: TimeInterval = 3600,   // 1 hour
        emissionDataTTL: TimeInterval = 120     // 2 minutes
    ) {
        self.userBalanceTTL = userBalanceTTL
        self.poolDataTTL = poolDataTTL
        self.tokenAddressTTL = tokenAddressTTL
        self.emissionDataTTL = emissionDataTTL
    }
}

// MARK: - Service Configuration

/// Configuration for backstop contract service
public struct BackstopServiceConfig: Sendable {
    public let contractAddress: String
    public let rpcUrl: String
    public let network: Network
    public let maxRetries: Int
    public let retryDelay: TimeInterval
    public let timeoutInterval: TimeInterval
    public let cacheConfig: BackstopCacheConfig
    
    public init(
        contractAddress: String,
        rpcUrl: String,
        network: Network,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        timeoutInterval: TimeInterval = 30.0,
        cacheConfig: BackstopCacheConfig = BackstopCacheConfig()
    ) {
        self.contractAddress = contractAddress
        self.rpcUrl = rpcUrl
        self.network = network
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.timeoutInterval = timeoutInterval
        self.cacheConfig = cacheConfig
    }
}
