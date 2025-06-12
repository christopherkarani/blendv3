//import Foundation
//import Combine
//
///// ViewModel for pool statistics and operations
//@MainActor
//public final class PoolViewModel: ObservableObject {
//    
//    // MARK: - Published Properties
//    
//    @Published public private(set) var supplyAPR: String = "--"
//    @Published public private(set) var supplyAPY: String = "--"
//    @Published public private(set) var borrowAPR: String = "--"
//    @Published public private(set) var borrowAPY: String = "--"
//    @Published public private(set) var utilization: String = "--"
//    @Published public private(set) var totalSupply: String = "--"
//    @Published public private(set) var totalBorrow: String = "--"
//    @Published public private(set) var isLoading = false
//    @Published public private(set) var error: Error?
//    
//    // MARK: - Dependencies
//    
//    // Using concrete implementation to access all methods
//    private let rateCalculator = BlendRateCalculator()
//    @Injected(\.oracleService) private var oracleService
//    
//    // MARK: - Private Properties
//    
//    private let poolId: String
//    private var cancellables = Set<AnyCancellable>()
//    private let refreshInterval: TimeInterval = 30 // 30 seconds
//    
//    // MARK: - Initialization
//    
//    public init(poolId: String) {
//        self.poolId = poolId
//        BlendLogger.info("PoolViewModel initialized for pool: \(poolId)", category: BlendLogger.ui)
//        setupAutoRefresh()
//    }
//    
//    // MARK: - Public Methods
//    
//    /// Load pool data and calculate statistics
//    public func loadPoolData() async {
//        BlendLogger.info("Starting pool data load for pool: \(poolId)", category: BlendLogger.ui)
//        
//        isLoading = true
//        error = nil
//        
//        do {
//            let poolData = try await measurePerformance(operation: "loadPoolData", category: BlendLogger.ui) {
//                return try await loadPoolDataFromChain()
//            }
//            
//            BlendLogger.info("Pool data loaded successfully, calculating rates", category: BlendLogger.ui)
//            
//            // Calculate rates with logging
//            let config = InterestRateConfig(
//                targetUtilization: poolData.targetUtilization,
//                rBase: poolData.rBase,
//                rOne: poolData.rOne,
//                rTwo: poolData.rTwo,
//                rThree: poolData.rThree,
//                reactivity: poolData.reactivity
//            )
//            
//            BlendLogger.debug("Interest rate config: target=\(poolData.targetUtilization), rBase=\(poolData.rBase)", category: BlendLogger.ui)
//            
//            let curIr = rateCalculator.calculateKinkedInterestRate(
//                utilization: Decimal(poolData.utilization),
//                config: config
//            )
//            
//            // Calculate APRs
//            let borrowAPRValue = rateCalculator.calculateBorrowAPR(curIr: curIr)
//            let supplyAPRValue = rateCalculator.calculateSupplyAPR(
//                curIr: curIr,
//                curUtil: FixedMath.toFixed(value: poolData.utilization, decimals: 7),
//                backstopTakeRate: poolData.backstopTakeRate
//            )
//            
//            // Calculate APYs
//            let borrowAPYValue = rateCalculator.calculateBorrowAPY(fromAPR: borrowAPRValue)
//            let supplyAPYValue = rateCalculator.calculateSupplyAPY(fromAPR: supplyAPRValue)
//            
//            BlendLogger.info("Rate calculations completed - Supply APR: \(supplyAPRValue), Borrow APR: \(borrowAPRValue)", category: BlendLogger.ui)
//            
//            // Update UI
//            await updateUI(
//                supplyAPR: supplyAPRValue,
//                supplyAPY: supplyAPYValue,
//                borrowAPR: borrowAPRValue,
//                borrowAPY: borrowAPYValue,
//                utilization: poolData.utilization,
//                totalSupply: poolData.totalSupply,
//                totalBorrow: poolData.totalBorrow
//            )
//            
//            BlendLogger.info("Pool data load completed successfully", category: BlendLogger.ui)
//            
//        } catch {
//            BlendLogger.error("Failed to load pool data", error: error, category: BlendLogger.ui)
//            self.error = error
//        }
//        
//        isLoading = false
//    }
//    
//    /// Refresh pool data manually
//    public func refresh() async {
//        BlendLogger.info("Manual refresh triggered for pool: \(poolId)", category: BlendLogger.ui)
//        await loadPoolData()
//    }
//    
//    // MARK: - Private Methods
//    
//    private func setupAutoRefresh() {
//        BlendLogger.info("Setting up auto-refresh with interval: \(refreshInterval)s", category: BlendLogger.ui)
//        
//        Timer.publish(every: refreshInterval, on: .main, in: .common)
//            .autoconnect()
//            .sink { [weak self] _ in
//                guard let self = self else { return }
//                BlendLogger.debug("Auto-refresh timer fired", category: BlendLogger.ui)
//                
//                Task { [weak self] in
//                    await self?.loadPoolData()
//                }
//            }
//            .store(in: &cancellables)
//    }
//    
//    private func loadPoolDataFromChain() async throws -> PoolData {
//        BlendLogger.info("Loading pool data from chain for pool: \(poolId)", category: BlendLogger.ui)
//        
//        // Fetch oracle prices for assets in the pool
//      //  let assets = ["USDC", "XLM"] // Example assets
//        
//        let assets = try await oracleService.getSupportedAssets()
//        
//        do {
//            let prices = try await oracleService.getPrices(assets: assets)
//            BlendLogger.info("Fetched prices for \(prices.count) assets", category: BlendLogger.ui)
//            
//  
//        } catch {
//            BlendLogger.warning("Failed to fetch oracle prices, using mock data", category: BlendLogger.ui)
//        }
//        
//        // TODO: Replace with actual chain data loading
//        // This is a mock implementation for now
//        let mockData = PoolData(
//            utilization: 0.65,
//            targetUtilization: 0.8,
//            rBase: 100_000,
//            rOne: 400_000,
//            rTwo: 2_000_000,
//            rThree: 10_000_000,
//            reactivity: 100_000,
//            backstopTakeRate: 1_000_000,
//            totalSupply: 1_000_000,
//            totalBorrow: 650_000
//        )
//        
//        BlendLogger.debug("Mock pool data created with utilization: \(mockData.utilization)", category: BlendLogger.ui)
//        return mockData
//    }
//    
//    private func updateUI(
//        supplyAPR: Decimal,
//        supplyAPY: Decimal,
//        borrowAPR: Decimal,
//        borrowAPY: Decimal,
//        utilization: Double,
//        totalSupply: Double,
//        totalBorrow: Double
//    ) async {
//        BlendLogger.debug("Updating UI with new values", category: BlendLogger.ui)
//        
//        let oldSupplyAPR = self.supplyAPR
//        let oldBorrowAPR = self.borrowAPR
//        
//        self.supplyAPR = formatPercentage(supplyAPR)
//        self.supplyAPY = formatPercentage(supplyAPY)
//        self.borrowAPR = formatPercentage(borrowAPR)
//        self.borrowAPY = formatPercentage(borrowAPY)
//        self.utilization = formatPercentage(Decimal(utilization))
//        self.totalSupply = formatCurrency(totalSupply)
//        self.totalBorrow = formatCurrency(totalBorrow)
//        
//        // Log significant changes
//        if oldSupplyAPR != self.supplyAPR {
//            BlendLogger.info("Supply APR changed from \(oldSupplyAPR) to \(self.supplyAPR)", category: BlendLogger.ui)
//        }
//        
//        if oldBorrowAPR != self.borrowAPR {
//            BlendLogger.info("Borrow APR changed from \(oldBorrowAPR) to \(self.borrowAPR)", category: BlendLogger.ui)
//        }
//        
//        BlendLogger.debug("UI update completed", category: BlendLogger.ui)
//    }
//    
//    private func formatPercentage(_ value: Decimal) -> String {
//        let percentage = NSDecimalNumber(decimal: value * 100).doubleValue
//        let formatted = String(format: "%.2f%%", percentage)
//        
//        // Log extreme values for debugging
//        if percentage > 100 {
//            BlendLogger.warning("Extremely high percentage detected: \(formatted)", category: BlendLogger.ui)
//        } else if percentage < 0 {
//            BlendLogger.warning("Negative percentage detected: \(formatted)", category: BlendLogger.ui)
//        }
//        
//        return formatted
//    }
//    
//    private func formatCurrency(_ value: Double) -> String {
//        let formatter = NumberFormatter()
//        formatter.numberStyle = .currency
//        formatter.currencySymbol = "$"
//        formatter.maximumFractionDigits = 2
//        
//        let formatted = formatter.string(from: NSNumber(value: value)) ?? "$0.00"
//        
//        // Log large values for monitoring
//        if value > 1_000_000 {
//            BlendLogger.info("Large currency value formatted: \(formatted)", category: BlendLogger.ui)
//        }
//        
//        return formatted
//    }
//    
//    deinit {
//        BlendLogger.info("PoolViewModel deallocated for pool: \(poolId)", category: BlendLogger.ui)
//    }
//}
//
//// MARK: - Supporting Types
//
//private struct PoolData {
//    let utilization: Double
//    let targetUtilization: Decimal
//    let rBase: Decimal
//    let rOne: Decimal
//    let rTwo: Decimal
//    let rThree: Decimal
//    let reactivity: Decimal
//    let backstopTakeRate: Decimal
//    let totalSupply: Double
//    let totalBorrow: Double
//} 
