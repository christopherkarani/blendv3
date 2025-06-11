import Foundation

/// Backstop Contract Service - handles backstop operations for Blend protocol
/// Uses NetworkService for networking and BlendParser for parsing
@MainActor
class BackstopContractService: ObservableObject {
    
    // MARK: - Dependencies
    
    private let networkService: NetworkService
    private let parser: BlendParser
    
    // MARK: - Published Properties
    
    @Published var backstopData: [String: BackstopInfo] = [:] // backstopAddress -> info
    @Published var userDeposits: [String: [String: UInt64]] = [:] // backstopAddress -> userAddress -> amount
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Initialization
    
    init(networkService: NetworkService = NetworkService(), parser: BlendParser = BlendParser.shared) {
        self.networkService = networkService
        self.parser = parser
    }
    
    // MARK: - Backstop Information
    
    /// Get backstop configuration and status
    func getBackstopInfo(backstopAddress: String) async throws -> BackstopInfo {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await networkService.invokeContract(
                contractAddress: backstopAddress,
                method: "get_backstop_info",
                args: [],
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            let infoMap = try parser.parseMap(from: result)
            
            let backstopInfo = try parseBackstopInfo(from: infoMap, address: backstopAddress)
            
            // Update state
            DispatchQueue.main.async {
                self.backstopData[backstopAddress] = backstopInfo
                self.error = nil
            }
            
            return backstopInfo
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    /// Get total backstop deposits across all users
    func getTotalBackstopDeposits(backstopAddress: String) async throws -> UInt64 {
        do {
            let response = try await networkService.invokeContract(
                contractAddress: backstopAddress,
                method: "get_total_deposits",
                args: [],
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
    
    /// Get backstop token balance for a user
    func getBackstopBalance(
        backstopAddress: String,
        userAddress: String
    ) async throws -> UInt64 {
        do {
            let userArg = try parser.createAddressSCVal(from: userAddress)
            let args = [userArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: backstopAddress,
                method: "get_balance",
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
    
    // MARK: - Backstop Operations
    
    /// Deposit into the backstop
    func deposit(
        backstopAddress: String,
        poolAddress: String,
        amount: UInt64,
        sourceKeyPair: Any
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let poolArg = try parser.createAddressSCVal(from: poolAddress)
            let amountArg = try parser.createSCVal(from: amount)
            let args = [poolArg, amountArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: backstopAddress,
                method: "deposit",
                args: args,
                sourceAccount: sourceKeyPair
            )
            
            // Update local state after successful deposit
            await refreshUserBalance(
                backstopAddress: backstopAddress,
                userAddress: getAddressFromKeyPair(sourceKeyPair)
            )
            
            return response.hash
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    /// Withdraw from the backstop
    func withdraw(
        backstopAddress: String,
        poolAddress: String,
        amount: UInt64,
        sourceKeyPair: Any
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let poolArg = try parser.createAddressSCVal(from: poolAddress)
            let amountArg = try parser.createSCVal(from: amount)
            let args = [poolArg, amountArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: backstopAddress,
                method: "withdraw",
                args: args,
                sourceAccount: sourceKeyPair
            )
            
            // Update local state after successful withdrawal
            await refreshUserBalance(
                backstopAddress: backstopAddress,
                userAddress: getAddressFromKeyPair(sourceKeyPair)
            )
            
            return response.hash
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    /// Queue a withdrawal (if there's a withdrawal delay)
    func queueWithdrawal(
        backstopAddress: String,
        poolAddress: String,
        amount: UInt64,
        sourceKeyPair: Any
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let poolArg = try parser.createAddressSCVal(from: poolAddress)
            let amountArg = try parser.createSCVal(from: amount)
            let args = [poolArg, amountArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: backstopAddress,
                method: "queue_withdrawal",
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
    
    /// Execute a queued withdrawal
    func executeWithdrawal(
        backstopAddress: String,
        poolAddress: String,
        sourceKeyPair: Any
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let poolArg = try parser.createAddressSCVal(from: poolAddress)
            let args = [poolArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: backstopAddress,
                method: "execute_withdrawal",
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
    
    // MARK: - Liquidation Support
    
    /// Check if backstop can cover a liquidation
    func canCoverLiquidation(
        backstopAddress: String,
        poolAddress: String,
        liquidationAmount: UInt64
    ) async throws -> Bool {
        do {
            let poolArg = try parser.createAddressSCVal(from: poolAddress)
            let amountArg = try parser.createSCVal(from: liquidationAmount)
            let args = [poolArg, amountArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: backstopAddress,
                method: "can_cover_liquidation",
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
    
    /// Execute backstop liquidation
    func executeLiquidation(
        backstopAddress: String,
        poolAddress: String,
        userAddress: String,
        sourceKeyPair: Any
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let poolArg = try parser.createAddressSCVal(from: poolAddress)
            let userArg = try parser.createAddressSCVal(from: userAddress)
            let args = [poolArg, userArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: backstopAddress,
                method: "liquidate",
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
    
    // MARK: - Rewards and Emissions
    
    /// Get current emission rate for backstop rewards
    func getEmissionRate(backstopAddress: String) async throws -> UInt64 {
        do {
            let response = try await networkService.invokeContract(
                contractAddress: backstopAddress,
                method: "get_emission_rate",
                args: [],
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
    
    /// Claim rewards for a user
    func claimRewards(
        backstopAddress: String,
        sourceKeyPair: Any
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await networkService.invokeContract(
                contractAddress: backstopAddress,
                method: "claim_rewards",
                args: [],
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
    
    /// Get claimable rewards for a user
    func getClaimableRewards(
        backstopAddress: String,
        userAddress: String
    ) async throws -> UInt64 {
        do {
            let userArg = try parser.createAddressSCVal(from: userAddress)
            let args = [userArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: backstopAddress,
                method: "get_claimable_rewards",
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
    
    // MARK: - Helper Methods
    
    /// Get historical backstop events
    func getBackstopEvents(
        backstopAddress: String,
        fromLedger: UInt32? = nil,
        toLedger: UInt32? = nil
    ) async throws -> [BackstopEvent] {
        do {
            let eventsResponse = try await networkService.getEvents(
                contractAddress: backstopAddress,
                topics: ["deposit", "withdraw", "liquidation"],
                startLedger: fromLedger,
                endLedger: toLedger
            )
            
            let events = parser.parseEvents(from: eventsResponse)
            var backstopEvents: [BackstopEvent] = []
            
            for event in events {
                let topics = try parser.parseEventTopics(from: event)
                
                if let eventType = parseEventType(from: topics) {
                    let backstopEvent = try parser.parseEventData(from: event) { data in
                        let dataMap = try parser.parseMap(from: data)
                        return BackstopEvent(
                            type: eventType,
                            data: dataMap,
                            timestamp: Date() // Would be parsed from event
                        )
                    }
                    backstopEvents.append(backstopEvent)
                }
            }
            
            return backstopEvents
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func parseBackstopInfo(from infoMap: [String: Any], address: String) throws -> BackstopInfo {
        // Simplified parsing - actual implementation would parse the full structure
        return BackstopInfo(
            address: address,
            totalShares: 0,
            totalTokens: 0,
            emissionRate: 0,
            lastRewardTime: Date(),
            poolAddresses: []
        )
    }
    
    private func parseEventType(from topics: [String]) -> BackstopEventType? {
        if topics.contains("deposit") {
            return .deposit
        } else if topics.contains("withdraw") {
            return .withdrawal
        } else if topics.contains("liquidation") {
            return .liquidation
        }
        return nil
    }
    
    private func refreshUserBalance(backstopAddress: String, userAddress: String) async {
        do {
            let balance = try await getBackstopBalance(
                backstopAddress: backstopAddress,
                userAddress: userAddress
            )
            
            DispatchQueue.main.async {
                if self.userDeposits[backstopAddress] == nil {
                    self.userDeposits[backstopAddress] = [:]
                }
                self.userDeposits[backstopAddress]?[userAddress] = balance
            }
        } catch {
            // Silently fail balance refresh
        }
    }
    
    private func getAddressFromKeyPair(_ keyPair: Any) -> String {
        // This would extract the address from the keyPair
        // Placeholder implementation
        return "GXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    }
    
    private func getDefaultKeyPair() -> Any {
        fatalError("KeyPair should be provided through dependency injection")
    }
}

// MARK: - Data Models

struct BackstopInfo {
    let address: String
    let totalShares: UInt64
    let totalTokens: UInt64
    let emissionRate: UInt64
    let lastRewardTime: Date
    let poolAddresses: [String]
}

struct BackstopEvent {
    let type: BackstopEventType
    let data: [String: Any]
    let timestamp: Date
}

enum BackstopEventType {
    case deposit
    case withdrawal
    case liquidation
    case rewardClaim
}

// MARK: - Error Types

enum BackstopError: Error, LocalizedError {
    case insufficientBackstopFunds
    case withdrawalDelayNotMet
    case invalidPoolAddress(String)
    case liquidationNotAllowed
    case noRewardsToClaim
    
    var errorDescription: String? {
        switch self {
        case .insufficientBackstopFunds:
            return "Insufficient funds in backstop"
        case .withdrawalDelayNotMet:
            return "Withdrawal delay period not yet met"
        case .invalidPoolAddress(let address):
            return "Invalid pool address: \(address)"
        case .liquidationNotAllowed:
            return "Liquidation not allowed at this time"
        case .noRewardsToClaim:
            return "No rewards available to claim"
        }
    }
}