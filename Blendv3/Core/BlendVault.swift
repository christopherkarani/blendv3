//
//  BlendVault.swift
//  Blendv3
//
//  Refactored Blend Vault - Orchestrates all services
//

import Foundation
import Combine
import stellarsdk

/// Refactored Blend Vault that orchestrates all services
@MainActor
public final class BlendVault: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var initState: VaultInitState = .notInitialized
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: BlendVaultError?
    @Published public private(set) var poolStats: BlendPoolStats?
    @Published public private(set) var userPosition: UserPositionData?
    
    // MARK: - Services
    
    private let configuration: ConfigurationServiceProtocol
    private let errorBoundary: ErrorBoundaryServiceProtocol
    private let validation: ValidationServiceProtocol
    private let stateManagement: StateManagementServiceProtocol
    private let networkService: BlendNetworkServiceProtocol
    private let cacheService: CacheServiceProtocol
    private let transactionService: TransactionServiceProtocol
    private let dataService: DataServiceProtocol
    
    // MARK: - Properties
    
    private let logger: DebugLogger
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    // MARK: - Initialization
    
    public init(networkType: BlendUSDCConstants.NetworkType = .testnet) {
        self.logger = DebugLogger(subsystem: "com.blendv3.vault", category: "BlendVault")
        
        // Initialize configuration
        self.configuration = ConfigurationService(networkType: networkType)
        
        // Initialize foundation services
        self.errorBoundary = ErrorBoundaryService()
        self.validation = ValidationService()
        self.stateManagement = StateManagementService()
        
        // Initialize infrastructure services
        self.networkService = NetworkService(configuration: configuration)
        self.cacheService = CacheService()
        
        // Initialize business services
        self.transactionService = TransactionService(
            networkService: networkService,
            errorBoundary: errorBoundary,
            validation: validation,
            configuration: configuration
        )
        
        self.dataService = DataService(
            networkService: networkService,
            cacheService: cacheService,
            errorBoundary: errorBoundary,
            validation: validation,
            configuration: configuration
        )
        
        setupBindings()
        logger.info("BlendVault initialized for \(networkType)")
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Initialize the vault and connect to the network
    public func initialize() async {
        logger.info("Starting vault initialization")
        
        await stateManagement.setInitState(.initializing)
        
        let result = await errorBoundary.handle {
            // Initialize network service
            try await self.networkService.initialize()
            
            // Fetch initial pool stats
            let statsResult = await self.dataService.fetchPoolStats()
            if case .success(let stats) = statsResult {
                self.poolStats = stats
            }
            
            await self.stateManagement.setInitState(.ready)
            self.startAutoRefresh()
        }
        
        if case .failure(let error) = result {
            await stateManagement.setInitState(.failed(error))
        }
    }
    
    /// Deposit USDC into the pool
    public func deposit(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError> {
        logger.info("Processing deposit of \(amount) USDC")
        
        await stateManagement.setLoading(true)
        defer { Task { await stateManagement.setLoading(false) } }
        
        // Perform deposit
        let result = await transactionService.deposit(amount: amount, userAccount: userAccount)
        
        // Refresh data on success
        if case .success = result {
            await refreshUserData(userId: userAccount.accountId)
            await refreshPoolData()
        }
        
        return result
    }
    
    /// Withdraw USDC from the pool
    public func withdraw(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError> {
        logger.info("Processing withdrawal of \(amount) USDC")
        
        await stateManagement.setLoading(true)
        defer { Task { await stateManagement.setLoading(false) } }
        
        // Perform withdrawal
        let result = await transactionService.withdraw(amount: amount, userAccount: userAccount)
        
        // Refresh data on success
        if case .success = result {
            await refreshUserData(userId: userAccount.accountId)
            await refreshPoolData()
        }
        
        return result
    }
    
    /// Borrow USDC from the pool
    public func borrow(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError> {
        logger.info("Processing borrow of \(amount) USDC")
        
        await stateManagement.setLoading(true)
        defer { Task { await stateManagement.setLoading(false) } }
        
        // Perform borrow
        let result = await transactionService.borrow(amount: amount, userAccount: userAccount)
        
        // Refresh data on success
        if case .success = result {
            await refreshUserData(userId: userAccount.accountId)
            await refreshPoolData()
        }
        
        return result
    }
    
    /// Repay borrowed USDC
    public func repay(amount: Decimal, userAccount: KeyPair) async -> Result<String, BlendError> {
        logger.info("Processing repayment of \(amount) USDC")
        
        await stateManagement.setLoading(true)
        defer { Task { await stateManagement.setLoading(false) } }
        
        // Perform repayment
        let result = await transactionService.repay(amount: amount, userAccount: userAccount)
        
        // Refresh data on success
        if case .success = result {
            await refreshUserData(userId: userAccount.accountId)
            await refreshPoolData()
        }
        
        return result
    }
    
    /// Claim available emissions
    public func claimEmissions(userAccount: KeyPair) async -> Result<String, BlendError> {
        logger.info("Processing emissions claim")
        
        await stateManagement.setLoading(true)
        defer { Task { await stateManagement.setLoading(false) } }
        
        // Perform claim
        let result = await transactionService.claimEmissions(userAccount: userAccount)
        
        // Refresh data on success
        if case .success = result {
            await refreshUserData(userId: userAccount.accountId)
        }
        
        return result
    }
    
    /// Refresh pool statistics
    public func refreshPoolData() async {
        logger.debug("Refreshing pool data")
        
        let result = await dataService.fetchPoolStats()
        if case .success(let stats) = result {
            poolStats = stats
        }
    }
    
    /// Refresh user position data
    public func refreshUserData(userId: String) async {
        logger.debug("Refreshing user data for: \(userId)")
        
        let result = await dataService.fetchUserPosition(userId: userId)
        if case .success(let position) = result {
            userPosition = position
        }
    }
    
    /// Clear all cached data
    public func clearCache() async {
        logger.info("Clearing all cached data")
        await cacheService.clear()
        poolStats = nil
        userPosition = nil
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind state management to published properties
        Task {
            stateManagement.initStatePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.initState = state
                }
                .store(in: &cancellables)
            
            stateManagement.isLoading
                .receive(on: DispatchQueue.main)
                .sink { [weak self] loading in
                    self?.isLoading = loading
                }
                .store(in: &cancellables)
            
            stateManagement.error
                .receive(on: DispatchQueue.main)
                .sink { [weak self] error in
                    self?.error = error
                }
                .store(in: &cancellables)
        }
    }
    
    private func startAutoRefresh() {
        logger.debug("Starting auto-refresh timer")
        
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshPoolData()
                
                // Refresh user data if we have a position
                if let userId = self?.userPosition?.userId {
                    await self?.refreshUserData(userId: userId)
                }
            }
        }
    }
}

// MARK: - Convenience Methods

extension BlendVault {
    
    /// Get the current network type
    public var networkType: BlendUSDCConstants.NetworkType {
        configuration.networkType
    }
    
    /// Check if vault is ready for operations
    public var isReady: Bool {
        if case .ready = initState {
            return true
        }
        return false
    }
    
    /// Get formatted pool TVL
    public var formattedTVL: String {
        guard let stats = poolStats else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: stats.totalSupplied as NSNumber) ?? "$0.00"
    }
    
    /// Get formatted user net value
    public var formattedUserNetValue: String {
        guard let position = userPosition else { return "$0.00" }
        let netValue = position.supplied - position.borrowed
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: netValue as NSNumber) ?? "$0.00"
    }
} 