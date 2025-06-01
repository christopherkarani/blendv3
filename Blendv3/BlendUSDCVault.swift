//
//  BlendUSDCVault.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import Combine
import stellarsdk

// MARK: - Data Extension for Hex Conversion
extension Data {
    init?(hex: String) {
        let cleanHex = hex.replacingOccurrences(of: " ", with: "")
        guard cleanHex.count % 2 == 0 else { return nil }
        
        var data = Data()
        var index = cleanHex.startIndex
        
        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteString = String(cleanHex[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
}

/// Main service class for interacting with the Blend USDC lending pool
/// Handles deposits, withdrawals, and fetching pool statistics
/// Network connection state


public class BlendUSDCVault: ObservableObject {
    
    // MARK: - Logger
    
    private let logger = DebugLogger(subsystem: "com.blendv3.vault", category: "BlendUSDCVault")
    
    // Debug logger specifically for debug functions that should appear in DebugLogView
    private let debugLogger = DebugLogger(subsystem: "com.blendv3.debug", category: "VaultDebug")
    
    // MARK: - Published Properties
    
    /// Initialization state of the vault
    @Published public private(set) var initState: VaultInitState = .notInitialized
    
    /// Network connection state
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    
    /// Current pool statistics
    @Published public private(set) var poolStats: BlendPoolStats?
    
    /// Comprehensive pool statistics (new)
    @Published public private(set) var comprehensivePoolStats: ComprehensivePoolStats?
    
    /// True pool statistics (using actual contract functions)
    @Published public private(set) var truePoolStats: TruePoolStats?
    
    /// Pool configuration from get_config()
    @Published public private(set) var poolConfig: PoolConfig?
    
    /// Loading state for operations
    @Published public private(set) var isLoading = false
    
    /// Error state
    @Published public private(set) var error: BlendVaultError?
    
    /// Last initialization attempt timestamp
    @Published public private(set) var lastInitAttempt: Date?
    
    /// Number of consecutive connection failures
    @Published public private(set) var connectionFailures: Int = 0
    
    /// Number of consecutive successful connections
    @Published public private(set) var connectionSuccesses: Int = 0
    
   
   
   // var assetService: BlendAssetService?
    
    // MARK: - Private Properties
    
    private var poolService: PoolServiceProtocol!
    private var assetService: BlendAssetServiceProtocol!
    private var dataService: DataServiceProtocol!
    
    /// The signer for transactions
    private let signer: BlendSigner
    
    /// The network type (testnet or mainnet)
    private let networkType: BlendUSDCConstants.NetworkType
    
    /// The Stellar network to use
    private var network: Network {
        return networkType.stellarNetwork
    }
    
    /// Soroban server instance
    private let sorobanServer: SorobanServer
    
    /// Soroban client for contract interactions
    private var sorobanClient: SorobanClient?
    
    /// Rate calculator service for real APY/APR calculations
    private let rateCalculator: BlendRateCalculatorProtocol
    
    // Diagnostics service has been removed
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Timer for periodic network checks
    private var networkCheckTimer: Timer?
    
    // MARK: - Initialization
    
    /// Maximum number of initialization retry attempts
    private let maxInitRetries = 5
    
    /// Completion handlers for initialization
    private var initCompletionHandlers: [(Result<Void, Error>) -> Void] = []
    
    /// Initialize the Blend USDC Vault
    /// - Parameters:
    ///   - signer: The signer to use for transactions
    ///   - network: The network to connect to (default: testnet)
    ///   - enableNetworkMonitoring: Whether to enable periodic network checks (default: true)
    ///   - completion: Optional completion handler called when initialization completes
    public init(
        signer: BlendSigner,
        network: BlendUSDCConstants.NetworkType = .testnet,
        enableNetworkMonitoring: Bool = true,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        self.signer = signer
        self.networkType = network
        self.rateCalculator = DependencyContainer.shared.rateCalculator
       
        // Initialize Soroban server with appropriate endpoint
        let rpcUrl = networkType == .testnet ? BlendUSDCConstants.RPC.testnet : BlendUSDCConstants.RPC.mainnet
        self.sorobanServer = SorobanServer(endpoint: rpcUrl)
        
       
        
        // Add completion handler if provided
        if let completion = completion {
            initCompletionHandlers.append(completion)
        }
        
    }
    
    /// Clean up resources when the vault is deallocated
    deinit {
       
        cancellables.forEach { $0.cancel() }
        logger.info("BlendUSDCVault deallocated")
    }
    
   
    
    // MARK: - Public Methods
    
    /// Deposit USDC into the lending pool
    /// - Parameter amount: The amount of USDC to deposit (in standard units, e.g., 100.50 USDC)
    /// - Returns: The transaction hash if successful
//    @discardableResult
//    public func deposit(amount: Decimal) async throws -> String {
//        logger.info("Starting deposit of \(amount) USDC")
//        
//        guard amount > 0 else {
//            logger.error("Invalid deposit amount: \(amount)")
//            throw BlendVaultError.invalidAmount("Amount must be greater than zero")
//        }
//        
//        isLoading = true
//        error = nil
//        
//        defer { isLoading = false }
//        
//        do {
//            // Scale the amount to contract format
//            let scaledAmount = BlendUSDCConstants.scaleAmount(amount)
//            
//            // Create the request for supply collateral
//            let request = try createRequest(
//                type: .supplyCollateral,
//                amount: scaledAmount
//            )
//            logger.debug("Created deposit request")
//            
//            // Submit the transaction
//            let txHash = try await submitTransaction(requests: [request])
//            logger.info("Deposit successful! Transaction hash: \(txHash)")
//            
//            // Refresh pool stats after successful deposit
//            Task {
//                try? await refreshPoolStats()
//            }
//            
//            return txHash
//        } catch {
//            logger.error("Deposit failed: \(error.localizedDescription)")
//            self.error = error as? BlendVaultError ?? .unknown(error.localizedDescription)
//            throw self.error!
//        }
//    }
    
//    /// Withdraw USDC from the lending pool
//    /// - Parameter amount: The amount of USDC to withdraw (in standard units, e.g., 100.50 USDC)
//    /// - Returns: The transaction hash if successful
//    @discardableResult
//    public func withdraw(amount: Decimal) async throws -> String {
//        logger.info("Starting withdrawal of \(amount) USDC")
//        
//        guard amount > 0 else {
//            logger.error("Invalid withdrawal amount: \(amount)")
//            throw BlendVaultError.invalidAmount("Amount must be greater than zero")
//        }
//        
//        isLoading = true
//        error = nil
//        
//        defer { isLoading = false }
//        
//        do {
//            // Scale the amount to contract format
//            let scaledAmount = BlendUSDCConstants.scaleAmount(amount)
//            logger.debug("Scaled amount: hi=\(scaledAmount.hi), lo=\(scaledAmount.lo)")
//            
//            // Create the request for withdraw collateral
//            let request = try createRequest(
//                type: .withdrawCollateral,
//                amount: scaledAmount
//            )
//            logger.debug("Created withdrawal request")
//            
//            // Submit the transaction
//            let txHash = try await submitTransaction(requests: [request])
//            logger.info("Withdrawal successful! Transaction hash: \(txHash)")
//            
//            // Refresh pool stats after successful withdrawal
//            Task {
//                try? await refreshPoolStats()
//            }
//            
//            return txHash
//        } catch {
//            logger.error("Withdrawal failed: \(error.localizedDescription)")
//            self.error = error as? BlendVaultError ?? .unknown(error.localizedDescription)
//            throw self.error!
//        }
//    }
    
    /// Refresh the pool statistics from the blockchain
    public func refreshPoolStats() async throws {
        await initializeSorobanClient()
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // Get all asset addresses from the pool
            guard let assetService else {
                throw BlendError.unknown
            }
            let assetAddresses = try! await assetService.getAssets()
            
            // Get oracle service for price data
            let oracleService = DependencyContainer.shared.oracleService
            
            // Get prices for all assets - ONLY from oracle, no fallbacks
            var assetPrices: [String: Decimal] = [:]
            let priceData = try! await oracleService.getPrices(assets: assetAddresses)
     
            print("Price Data: \(priceData)")
            // Process all reserves
            var allReserves: [String: AssetReserveData] = [:]
            var totalSuppliedUSD = Decimal(0)
            var totalBorrowedUSD = Decimal(0)
            
            for assetAddress in assetAddresses {
                let symbol = getAssetSymbol(for: assetAddress.assetId)
                logger.info("🔄 Processing \(symbol) (\(assetAddress))")
                
                do {
                    let reserveData = try await assetService.get(assetData: assetAddress)
                    guard let price = assetPrices[assetAddress.assetId] else {
                        logger.error("🔄 ❌ No price available for \(symbol), skipping")
                        continue
                    }
                    
                    let assetReserve = AssetReserveData(
                        symbol: symbol,
                        contractAddress: assetAddress.assetId,
                        totalSupplied: reserveData.totalSupplied,
                        totalBorrowed: reserveData.totalBorrowed,
                        price: price,
                        utilizationRate: reserveData.maxUtil,
                        supplyApr: reserveData.supplyRate,
                        supplyApy: reserveData.supplyRate,
                        borrowApr: reserveData.borrowRate,
                        borrowApy: reserveData.borrowRate,
                        collateralFactor: Decimal(0.95), // Default
                        liabilityFactor: Decimal(1.0526) // Default
                    )
                    
                    allReserves[symbol] = assetReserve
                    totalSuppliedUSD += reserveData.totalSupplied * price
                    totalBorrowedUSD += reserveData.totalBorrowed * price
                    
                    logger.info("🔄 ✅ \(symbol): $\(reserveData.totalSupplied * price) supplied, $\(reserveData.totalBorrowed * price) borrowed")
                    
                } catch {
                    logger.error("🔄 ❌ Failed to process \(symbol): \(error)")
                    // Skip assets that fail to load - no mock data
                }
            }
            
            // Calculate overall utilization
            let overallUtilization = totalSuppliedUSD > 0 ? totalBorrowedUSD / totalSuppliedUSD : 0
            

            
            
         
            
            // Log individual assets
            for (symbol, reserve) in allReserves {
                logger.info("  \(symbol): $\(reserve.totalSuppliedUSD) supplied, $\(reserve.totalBorrowedUSD) borrowed")
            }
            
            // Update published properties
           // await MainActor.run {
                // Create legacy USDC-focused stats for backward compatibility
//                let usdcReserve = allReserves["USDC"]
//                let usdcReserveData = USDCReserveData(
//                    totalSupplied: usdcReserve?.totalSupplied ?? 0,
//                    totalBorrowed: usdcReserve?.totalBorrowed ?? 0,
//                    utilizationRate: usdcReserve?.utilizationRate ?? 0,
//                    supplyApr: usdcReserve?.supplyApr ?? 0,
//                    supplyApy: usdcReserve?.supplyApy ?? 0,
//                    borrowApr: usdcReserve?.borrowApr ?? 0,
//                    borrowApy: usdcReserve?.borrowApy ?? 0,
//                    collateralFactor: usdcReserve?.collateralFactor ?? Decimal(0.95),
//                    liabilityFactor: usdcReserve?.liabilityFactor ?? Decimal(1.0526)
            //    )
                
//                self.poolStats = BlendPoolStats(
//                    poolData: poolData,
//                    usdcReserveData: usdcReserveData,
//                    backstopData: backstopData,
//                    lastUpdated: Date()
//                )
                
//                // Create comprehensive stats with all assets
//                self.comprehensivePoolStats = ComprehensivePoolStats(
//                    poolData: poolData,
//                    allReserves: allReserves,
//                    backstopData: backstopData,
//                    lastUpdated: Date()
//                )
                
                logger.info("🔄 ✅ POOL STATS UPDATED WITH ALL ASSETS")
            
        
            
        } catch {
            logger.error("Failed to parse pool stats: \(error.localizedDescription)")
            throw error
        }
    }
    
   
    

    
    
    
    
    // MARK: - Extended Blend Protocol Functions
    
    /// Get pool status using the get_status() function
    
    
   
    
    /// Get user positions using get_positions(user)
    public func getUserPositions(userAddress: String) async throws  {
        logger.info("👤 Getting positions for user: \(userAddress)")
        
        guard let client = sorobanClient else {
            logger.error("SorobanClient not initialized")
            throw BlendVaultError.notInitialized
        }
        
        do {
            let positionsResult = try await client.invokeMethod(
                name: "get_positions",
                args: [try SCValXDR.address(SCAddressXDR(accountId: userAddress))],
                methodOptions: stellarsdk.MethodOptions(
                    fee: 100_000,
                    timeoutInSeconds: 30,
                    simulate: true,
                    restore: false
                )
            )
            
            logger.info("✅ User positions retrieved: \(String(describing: positionsResult))")
            
            // Parse the positions result
          
            
        } catch {
            logger.error("❌ Failed to get user positions: \(error)")
            throw BlendVaultError.networkError(error.localizedDescription)
        }
    }
    
    /// Get user emissions using get_user_emissions(user)
    public func getUserEmissions(userAddress: String) async throws  {
        logger.info("🎁 Getting emissions for user: \(userAddress)")
        
        guard let client = sorobanClient else {
            logger.error("SorobanClient not initialized")
            throw BlendVaultError.notInitialized
        }
        
        do {
            let emissionsResult = try await client.invokeMethod(
                name: "get_user_emissions",
                args: [try SCValXDR.address(SCAddressXDR(accountId: userAddress))],
                methodOptions: stellarsdk.MethodOptions(
                    fee: 100_000,
                    timeoutInSeconds: 30,
                    simulate: true,
                    restore: false
                )
            )
            
            logger.info("✅ User emissions retrieved: \(String(describing: emissionsResult))")
            
       
            
        } catch {
            logger.error("❌ Failed to get user emissions: \(error)")
            throw BlendVaultError.networkError(error.localizedDescription)
        }
    }
    
    /// Get emissions data using get_emissions_data()
    public func getEmissionsData() async throws  {
        logger.info("📊 Getting emissions data")
        
        guard let client = sorobanClient else {
            logger.error("SorobanClient not initialized")
            throw BlendVaultError.notInitialized
        }
        
        do {
            let emissionsResult = try await client.invokeMethod(
                name: "get_emissions_data",
                args: [],
                methodOptions: stellarsdk.MethodOptions(
                    fee: 100_000,
                    timeoutInSeconds: 30,
                    simulate: true,
                    restore: false
                )
            )
            
            logger.info("✅ Emissions data retrieved: \(String(describing: emissionsResult))")
            
           
            
        } catch {
            logger.error("❌ Failed to get emissions data: \(error)")
            throw BlendVaultError.networkError(error.localizedDescription)
        }
    }
    
    /// Get emissions configuration using get_emissions_config()
    public func getEmissionsConfig() async throws  {
        logger.info("⚙️ Getting emissions configuration")
        
        guard let client = sorobanClient else {
            logger.error("SorobanClient not initialized")
            throw BlendVaultError.notInitialized
        }
        
        do {
            let configResult = try await client.invokeMethod(
                name: "get_emissions_config",
                args: [],
                methodOptions: stellarsdk.MethodOptions(
                    fee: 100_000,
                    timeoutInSeconds: 30,
                    simulate: true,
                    restore: false
                )
            )
            
            logger.info("✅ Emissions config retrieved: \(String(describing: configResult))")
            
  
        } catch {
            logger.error("❌ Failed to get emissions config: \(error)")
            throw BlendVaultError.networkError(error.localizedDescription)
        }
    }
    
    /// Get auction data using get_auction(auction_id)
    public func getAuction(auctionId: String) async throws  {
        logger.info("🏛️ Getting auction data for ID: \(auctionId)")
        
        guard let client = sorobanClient else {
            logger.error("SorobanClient not initialized")
            throw BlendVaultError.notInitialized
        }
        
        do {
            let auctionResult = try await client.invokeMethod(
                name: "get_auction",
                args: [SCValXDR.string(auctionId)],
                methodOptions: stellarsdk.MethodOptions(
                    fee: 100_000,
                    timeoutInSeconds: 30,
                    simulate: true,
                    restore: false
                )
            )
            
            logger.info("✅ Auction data retrieved: \(String(describing: auctionResult))")
            
            // Parse the auction result
    
            
        } catch {
            logger.error("❌ Failed to get auction data: \(error)")
            throw BlendVaultError.networkError(error.localizedDescription)
        }
    }
    
    /// Get auction data for a specific user using get_auction_data(auction_type, user)
    public func getAuctionData(auctionType: UInt32, userAddress: String) async throws {
        logger.info("🏛️ Getting auction data for type: \(auctionType), user: \(userAddress)")
        
        guard let client = sorobanClient else {
            logger.error("SorobanClient not initialized")
            throw BlendVaultError.notInitialized
        }
        
        do {
            let auctionDataResult = try await client.invokeMethod(
                name: "get_auction_data",
                args: [
                    SCValXDR.u32(auctionType),
                    try SCValXDR.address(SCAddressXDR(accountId: userAddress))
                ],
                methodOptions: stellarsdk.MethodOptions(
                    fee: 100_000,
                    timeoutInSeconds: 30,
                    simulate: true,
                    restore: false
                )
            )
            
            logger.info("✅ Auction data retrieved: \(String(describing: auctionDataResult))")

            
        } catch {
            logger.error("❌ Failed to get auction data: \(error)")
            throw BlendVaultError.networkError(error.localizedDescription)
        }
    }
    
    /// Check bad debt for a user using bad_debt(user)
    public func getBadDebt(userAddress: String) async throws  {
        logger.info("💸 Checking bad debt for user: \(userAddress)")
        
        guard let client = sorobanClient else {
            logger.error("SorobanClient not initialized")
            throw BlendVaultError.notInitialized
        }
        
        do {
            let badDebtResult = try await client.invokeMethod(
                name: "bad_debt",
                args: [try SCValXDR.address(SCAddressXDR(accountId: userAddress))],
                methodOptions: stellarsdk.MethodOptions(
                    fee: 100_000,
                    timeoutInSeconds: 30,
                    simulate: true,
                    restore: false
                )
            )
            
            logger.info("✅ Bad debt data retrieved: \(String(describing: badDebtResult))")
            
        
            
        } catch {
            logger.error("❌ Failed to get bad debt: \(error)")
            throw BlendVaultError.networkError(error.localizedDescription)
        }
    }
    

    
    
   
    
    /// Set initialization state with MainActor protection
    @MainActor
    private func setInitState(_ newState: VaultInitState) {
        initState = newState
    }
    
    /// Notify all registered completion handlers
    private func notifyInitCompletion(_ result: Result<Void, Error>) {
        let handlers = initCompletionHandlers
        initCompletionHandlers.removeAll()
        
        for handler in handlers {
            handler(result)
        }
    }
    
    /// Initialize the Soroban client
    func initializeSorobanClient() async -> Result<Void, Error> {
        logger.info("Initializing Soroban client")
        
        do {
            let keyPair = try signer.getKeyPair()
            let testServer = SorobanServer(endpoint:  BlendUSDCConstants.RPC.testnet)
            testServer.enableLogging = true
            let healthEnum = await testServer.getHealth()
            
            switch healthEnum {
            case .success(response: let response):
                logger.info(response.status)
            case .failure(error: let error):
                logger.error(error.localizedDescription)
            }
            
            // Create client options
            let clientOptions = ClientOptions(
                sourceAccountKeyPair: keyPair,
                contractId: BlendUSDCConstants.Testnet.xlmUsdcPool,
                network: network,
                rpcUrl:  BlendUSDCConstants.RPC.testnet,
                enableServerLogging: true
            )
            
            // This is where the error likely occurs
            self.sorobanClient = try! await SorobanClient.forClientOptions(options: clientOptions)
            let oracleService = DependencyContainer.shared.oracleService
        
            if let client = sorobanClient {
                poolService = PoolService(sorobanClient: client)
                assetService = BlendAssetService(client: client)
                dataService = BlendDataService(
                    client: client,
                    poolService: poolService,
                    oracleService: oracleService,
                    assetService: assetService
                )
            }
            
            try await dataService.fetchPoolStats()

            logger.info("Soroban client initialized successfully")
            
            return .success(())
            
        } catch let error as SorobanRpcRequestError {
            let vaultError: BlendVaultError
            
            switch error {
            case .requestFailed(let message):

                vaultError = .initializationFailed("Request failed: \(message)")
                
            case .errorResponse(let errorData):

                let errorMessage = errorData["message"] as? String ?? "Unknown error"
                let errorCode = errorData["code"] as? Int ?? -1
                vaultError = .initializationFailed("RPC Error: \(errorMessage)")
                
            case .parsingResponseFailed(let message, let responseData):
                logger.error("Parsing failed: \(message)")
                vaultError = .initializationFailed("Response parsing failed: \(message)")
            }
            
            self.error = vaultError
            return .failure(vaultError)
            
        } catch {
            logger.error("Failed to initialize Soroban client: \(error.localizedDescription)")
            logger.error("Error type: \(type(of: error))")
            
            if let nsError = error as NSError? {
                logger.error("NSError domain: \(nsError.domain), code: \(nsError.code)")
            }
            
            let vaultError = BlendVaultError.initializationFailed(error.localizedDescription)
            self.error = vaultError
            return .failure(vaultError)
        }
    }
    
    /// Create a request object for the submit function
    private func createRequest(type: BlendUSDCConstants.RequestType, amount: Int128PartsXDR) throws -> SCValXDR {
        logger.debug("Creating request - Type: \(type.rawValue), Amount: hi=\(amount.hi), lo=\(amount.lo)")
        
        // Create the Request struct as a map
        let requestMap: [SCMapEntryXDR] = [
            // request_type field
            SCMapEntryXDR(
                key: .symbol("request_type"),
                val: .u32(type.rawValue)
            ),
            // address field (USDC asset issuer)
            SCMapEntryXDR(
                key: .symbol("address"),
                val: try SCValXDR.address(SCAddressXDR(accountId: BlendUSDCConstants.usdcAssetIssuer))
            ),
            // amount field
            SCMapEntryXDR(
                key: .symbol("amount"),
                val: .i128(amount)
            )
        ]
        
        logger.debug("Request created successfully")
        return .map(requestMap)
    }
    
    
    


    
  
    
    

    // Diagnostic method moved to BlendPoolDiagnosticsService
    
    // Factory diagnostic methods moved to BlendPoolDiagnosticsService
    
    /// Get the actual pool statistics that match the dashboard
    
    
    
    
    /// Get a summary of pool-wide statistics
    public func getPoolSummary() -> PoolSummary? {
        guard let stats = comprehensivePoolStats else { return nil }
        
        return PoolSummary(
            totalValueLocked: stats.poolData.totalValueLocked,
            totalBorrowed: stats.allReserves.values.reduce(Decimal(0)) { $0 + $1.totalBorrowed },
            overallUtilization: stats.poolData.overallUtilization,
            healthScore: stats.poolData.healthScore,
            activeAssets: stats.poolData.activeReserves,
            topAssetByTVL: stats.allReserves.max(by: { $0.value.totalSupplied < $1.value.totalSupplied })?.key ?? "N/A",
            averageSupplyAPY: stats.allReserves.values.reduce(Decimal(0)) { $0 + $1.supplyApy } / Decimal(max(1, stats.allReserves.count))
        )
    }
    
    
    /// 🎯 Phase 1.2: Get pool configuration using get_config() -> PoolConfig
    public func getPoolConfigNew() async throws -> PoolConfig {
        guard let pool = poolService else {
            throw BlendError.unknown
        }
        return try await pool.fetchPoolConfig()
    }
    
    
    struct BlendAssetPrice {
        var contractID: String
        var price: Decimal
    }
    
    /// 🎯 Phase 1.3: Fetch reserve data for all assets
    public func fetchAllPoolReserves() async throws -> [PoolReserveData] {
        guard let assetService  else {
            throw BlendError.unknown
        }
        
        let oracleAssets = try await assetService.getAssets()
        
        // Get all asset addresses
        let assetAddresses = oracleAssets
            .map { normalizeContractAddress($0.assetId) }
        
        
        // Get oracle service from dependency container
        let oracleService = DependencyContainer.shared.oracleService
        
        // get prices
        do {
            let priceData = try await oracleService.getPrices(assets: oracleAssets)
        } catch {
            logger.error("❌ Failed to get oracle prices: \(error)")
            throw error
        }
        
        var reserves: [PoolReserveData] = []
        var successCount = 0
        var failureCount = 0
        

        /// get reserve data for asset
        for assetAddress in assetAddresses {
            let symbol = getAssetSymbol(for: assetAddress)
            do {
                // Get reserve data for this asset
                let reserveData = try await assetService.get(assetData: .stellar(address: assetAddress))
                
                // Get asset price from oracle data - must exist
            
//                guard let price = assetPrices[assetAddress] else {
//                    logger.error("🎯 ❌ No price available for \(symbol), skipping")
//                    debugLogger.error("🎯 ❌ No price available for \(symbol), skipping")
//                    continue
//                }
                
                // Convert to PoolReserveData
                let poolReserve = PoolReserveData(
                    asset: assetAddress,
                    symbol: symbol,
                    totalSupplied: reserveData.totalSupplied,
                    totalBorrowed: reserveData.totalBorrowed,
                    utilizationRate: reserveData.maxUtil,
                    supplyAPY: reserveData.supplyRate,
                    borrowAPY: reserveData.borrowRate,
                    scalar: reserveData.scalar,
                    price: 0
                )
                
                reserves.append(poolReserve)
                successCount += 1
                
                
            } catch {
                failureCount += 1
                print("error: \(error)")
            }
        }

        return reserves
    }
    
    /// 🎯 Phase 1.4: Get true pool statistics (aggregated from all reserves)
    public func getTruePoolStats() async throws -> TruePoolStats {
        // Get pool configuration (with error handling)
        var config: PoolConfig
        do {
            config = try await getPoolConfigNew()
            logger.info("🎯 ✅ Pool config retrieved successfully")
            debugLogger.info("🎯 ✅ Pool config retrieved successfully")
            
            // Store the config in the published property
            await MainActor.run {
                self.poolConfig = config
            }
        } catch {
            logger.warning("🎯 ⚠️ Failed to get pool config, using defaults: \(error)")
            debugLogger.warning("🎯 ⚠️ Failed to get pool config, using defaults: \(error)")
            // Use default values if config fails
            config = PoolConfig(
                backstopRate: 1000, // 10% default
                maxPositions: 4,
                minCollateral: 0,
                oracle: "",
                status: 0 // Active
            )
            
            // Store the default config
            await MainActor.run {
                self.poolConfig = config
            }
        }
        
        // Get all reserve data
        let reserves = try await fetchAllPoolReserves()
        
        // Aggregate totals
        let totalSuppliedUSD = reserves.reduce(Decimal(0)) { $0 + $1.totalSuppliedUSD }
        let totalBorrowedUSD = reserves.reduce(Decimal(0)) { $0 + $1.totalBorrowedUSD }
        
        // Calculate overall utilization
        let overallUtilization = totalSuppliedUSD > 0 ? totalBorrowedUSD / totalSuppliedUSD : 0
        
 
        
        let trueStats = TruePoolStats(
            totalSuppliedUSD: totalSuppliedUSD,
            totalBorrowedUSD: totalBorrowedUSD,
            backstopBalanceUSD: 0,
            overallUtilization: overallUtilization,
            backstopRate: Decimal(config.backstopRate) / Decimal(10000), // Convert from basis points
            poolStatus: config.status,
            reserves: reserves,
            lastUpdated: Date()
        )

        ("\(interpretPoolStatus(config.status)))")
        

        return trueStats
    }
    
    
    /// Helper: Map asset address to symbol with enhanced debugging and fallback mapping
    private func getAssetSymbol(for address: String) -> String {
        // Log the original address for debugging
        logger.debug("🔍 Mapping address to symbol: \(address)")
        debugLogger.info("🔍 Original address: \(address)")
        
        // Convert contract ID to proper Soroban address if needed
        let normalizedAddress = normalizeContractAddress(address)
        logger.debug("🔍 Normalized address: \(normalizedAddress)")
        debugLogger.info("🔍 Normalized address: \(normalizedAddress)")
        
        // Primary mapping using normalized addresses
        let primaryMapping = [
            normalizeContractAddress(BlendUSDCConstants.Testnet.usdc): "USDC",
            normalizeContractAddress(BlendUSDCConstants.Testnet.xlm): "XLM",
            normalizeContractAddress(BlendUSDCConstants.Testnet.blnd): "BLND",
            normalizeContractAddress(BlendUSDCConstants.Testnet.weth): "wETH",
            normalizeContractAddress(BlendUSDCConstants.Testnet.wbtc): "wBTC"
        ]
        
        // Check primary mapping first
        if let symbol = primaryMapping[normalizedAddress] {
            logger.debug("🔍 ✅ Found symbol via primary mapping: \(symbol)")
            debugLogger.info("🔍 ✅ Primary mapping success: \(symbol)")
            return symbol
        }

        return "UNKNOWN(\(address.prefix(8))...)"
    }
    
    /// Convert contract ID hex to proper Soroban contract address with enhanced debugging
    private func normalizeContractAddress(_ address: String) -> String {
        guard let normalised = try? StellarContractID.decodeFlexible(address) else {
            return "Error"
        }
        return normalised
    }
    
    
    
    /// 🎯 Main function to refresh true pool statistics
    public func refreshTruePoolStats() async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let stats = try await getTruePoolStats()
            
            await MainActor.run {
                self.truePoolStats = stats
            }
            
        } catch {
            await MainActor.run {
                self.error = BlendVaultError.networkError(error.localizedDescription)
            }
            throw error
        }
    }
    

    
    /// Helper function to interpret pool status codes
    private func interpretPoolStatus(_ status: UInt32) -> String {
        switch status {
        case 0:
            return "Active"
        case 1:
            return "On Ice (Frozen)"
        case 2:
            return "Admin Only"
        case 3:
            return "Reducing Only"
        default:
            return "Unknown (\(status))"
        }
    }
    
}

// MARK: - Errors

/// Errors that can occur in BlendUSDCVault operations
public enum BlendVaultError: LocalizedError {
    case notInitialized
    case invalidAmount(String)
    case insufficientBalance
    case transactionFailed(String)
    case networkError(String)
    case initializationFailed(String)
    case invalidResponse
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Vault not initialized. Please wait and try again."
        case .invalidAmount(let message):
            return "Invalid amount: \(message)"
        case .insufficientBalance:
            return "Insufficient balance for this operation"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .initializationFailed(let message):
            return "Failed to initialize: \(message)"
        case .invalidResponse:
            return "Invalid response from contract"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}





