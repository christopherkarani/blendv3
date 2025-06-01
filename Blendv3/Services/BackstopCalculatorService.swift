import Foundation

/// Comprehensive backstop calculation service
public final class BackstopCalculatorService {
    
    // MARK: - Constants
    
    /// Seconds in a year for APR calculations
    private let secondsPerYear: Double = 31536000
    
    /// Default Q4W delay (7 days)
    private let defaultQueueDelay: TimeInterval = 604800
    
    /// Minimum auction duration (1 hour)
    private let minAuctionDuration: TimeInterval = 3600
    
    /// Maximum auction duration (7 days)
    private let maxAuctionDuration: TimeInterval = 604800
    
    // MARK: - Dependencies
    
    private let oracleService: BlendOracleServiceProtocol
    private let cacheService: CacheServiceProtocol
    
    // MARK: - Initialization
    
    public init(oracleService: BlendOracleServiceProtocol, cacheService: CacheServiceProtocol) {
        self.oracleService = oracleService
        self.cacheService = cacheService
        BlendLogger.info("BackstopCalculatorService initialized", category: BlendLogger.rateCalculation)
    }
    
    // MARK: - Backstop APR Calculations
    
    /// Calculate backstop APR based on interest capture and total value
    /// - Parameters:
    ///   - backstopPool: Backstop pool data
    ///   - totalInterestPerYear: Total interest captured per year in USD
    /// - Returns: Backstop APR as decimal (e.g., 0.05 = 5%)
    public func calculateBackstopAPR(
        backstopPool: BackstopPool,
        totalInterestPerYear: Double
    ) -> Decimal {
        
        BlendLogger.info("Calculating backstop APR for pool: \(backstopPool.poolId)", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateBackstopAPR", category: BlendLogger.rateCalculation) {
            
            guard backstopPool.totalValueUSD > 0 else {
                BlendLogger.warning("Backstop pool has zero value, returning 0% APR", category: BlendLogger.rateCalculation)
                return 0
            }
            
            // Calculate APR: (Annual Interest Captured / Total Backstop Value)
            let apr = totalInterestPerYear / backstopPool.totalValueUSD
            let aprDecimal = Decimal(apr)
            
            BlendLogger.rateCalculation(
                operation: "calculateBackstopAPR",
                inputs: [
                    "poolId": backstopPool.poolId,
                    "totalInterestPerYear": totalInterestPerYear,
                    "totalValueUSD": backstopPool.totalValueUSD,
                    "takeRate": backstopPool.takeRate
                ],
                result: aprDecimal
            )
            
            return aprDecimal
        }
    }
    
    /// Calculate backstop APR from pool reserves
    /// - Parameters:
    ///   - backstopPool: Backstop pool data
    ///   - poolReserves: Array of pool reserves with their interest rates
    /// - Returns: Backstop APR as decimal
    public func calculateBackstopAPRFromReserves(
        backstopPool: BackstopPool,
        poolReserves: [BackstopPoolReserveData]
    ) async throws -> Decimal {
        
        BlendLogger.info("Calculating backstop APR from reserves for pool: \(backstopPool.poolId)", category: BlendLogger.rateCalculation)
        
        return try await measurePerformance(operation: "calculateBackstopAPRFromReserves", category: BlendLogger.rateCalculation) {
            
            var totalInterestPerYear: Double = 0
            
            // Get asset prices for USD conversion
            let assetIds = poolReserves.map { $0.assetId }
          //  let prices = try await oracleService.getPrices(assets: assetIds)
            
            // Calculate total interest captured by backstop
//            for reserve in poolReserves {
//                guard let priceData = prices[reserve.assetId] else {
//                    BlendLogger.warning("No price data for asset: \(reserve.assetId)", category: BlendLogger.rateCalculation)
//                    continue
//                }
//                
//                // Convert reserve liabilities to USD
//                let reserveLiabilitiesUSD = reserve.totalBorrowedUSD(priceData: priceData)
//                
//                // Calculate annual interest in USD
//                let annualInterest = reserveLiabilitiesUSD * NSDecimalNumber(decimal: reserve.borrowAPR).doubleValue
//                
//                // Apply backstop take rate
//                let backstopShare = annualInterest * NSDecimalNumber(decimal: backstopPool.takeRate).doubleValue / NSDecimalNumber(decimal: FixedMath.SCALAR_7).doubleValue
//                
//                totalInterestPerYear += backstopShare
//                
//                BlendLogger.debug(
//                    "Reserve \(reserve.assetId): liabilities=$\(reserveLiabilitiesUSD), backstop share=$\(backstopShare)",
//                    category: BlendLogger.rateCalculation
//                )
//            }
//            
//            return calculateBackstopAPR(backstopPool: backstopPool, totalInterestPerYear: totalInterestPerYear)
            return 0
        }
    }
    
    // MARK: - Emissions Calculations
    
    /// Calculate user's claimable emissions
    /// - Parameters:
    ///   - userState: User's current emissions state
    ///   - emissionsData: Pool emissions configuration
    ///   - backstopPool: Backstop pool data for share calculation
    /// - Returns: Updated user emissions state with claimable amount
    public func calculateClaimableEmissions(
        userState: UserEmissionsState,
        emissionsData: EmissionsData,
        backstopPool: BackstopPool
    ) -> UserEmissionsState {
        
        BlendLogger.info("Calculating claimable emissions for user: \(userState.userAddress)", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateClaimableEmissions", category: BlendLogger.rateCalculation) {
            
            guard emissionsData.isActive && !emissionsData.hasEnded else {
                BlendLogger.debug("Emissions inactive or ended for pool: \(emissionsData.poolId)", category: BlendLogger.rateCalculation)
                return userState
            }
            
            // Calculate time elapsed since last update
            let timeElapsed = Date().timeIntervalSince(userState.lastClaimTime)
            
            // Calculate user's share of total backstop tokens
            let userShare = backstopPool.totalBackstopTokens > 0 ? 
                NSDecimalNumber(decimal: userState.backstopTokenBalance / backstopPool.totalBackstopTokens).doubleValue : 0
            
            // Calculate emissions accrued during this period
            let emissionsPerSecondDouble = NSDecimalNumber(decimal: emissionsData.emissionsPerSecond).doubleValue
            let accruedEmissions = emissionsPerSecondDouble * timeElapsed * userShare
            let accruedEmissionsDecimal = FixedMath.toFixed(value: accruedEmissions, decimals: 7)
            
            // Total claimable = previous accrued + newly accrued
            let totalClaimable = userState.accruedEmissions + accruedEmissionsDecimal
            
            let updatedState = UserEmissionsState(
                userAddress: userState.userAddress,
                poolId: userState.poolId,
                backstopTokenBalance: userState.backstopTokenBalance,
                shareOfPool: userShare,
                totalClaimed: userState.totalClaimed,
                lastClaimTime: userState.lastClaimTime,
                accruedEmissions: totalClaimable,
                lastEmissionsIndex: userState.lastEmissionsIndex
            )
            
            BlendLogger.rateCalculation(
                operation: "calculateClaimableEmissions",
                inputs: [
                    "userAddress": userState.userAddress,
                    "timeElapsed": timeElapsed,
                    "userShare": userShare,
                    "emissionsPerSecond": emissionsData.emissionsPerSecond,
                    "previousAccrued": userState.accruedEmissions
                ],
                result: totalClaimable
            )
            
            return updatedState
        }
    }
    
    /// Calculate emissions APR for backstop participation
    /// - Parameters:
    ///   - emissionsData: Pool emissions configuration
    ///   - backstopPool: Backstop pool data
    ///   - blndPrice: Current BLND token price in USD
    /// - Returns: Emissions APR as decimal
    public func calculateEmissionsAPR(
        emissionsData: EmissionsData,
        backstopPool: BackstopPool,
        blndPrice: Double
    ) -> Decimal {
        
        BlendLogger.info("Calculating emissions APR for pool: \(emissionsData.poolId)", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateEmissionsAPR", category: BlendLogger.rateCalculation) {
            
            guard backstopPool.totalValueUSD > 0 && emissionsData.isActive else {
                BlendLogger.debug("Invalid conditions for emissions APR calculation", category: BlendLogger.rateCalculation)
                return 0
            }
            
            // Calculate annual emissions value in USD
            let emissionsPerSecondDouble = NSDecimalNumber(decimal: emissionsData.emissionsPerSecond).doubleValue
            let annualEmissionsTokens = emissionsPerSecondDouble * secondsPerYear
            let annualEmissionsValueUSD = annualEmissionsTokens * blndPrice
            
            // Calculate APR: (Annual Emissions Value / Total Backstop Value)
            let emissionsAPR = annualEmissionsValueUSD / backstopPool.totalValueUSD
            let aprDecimal = Decimal(emissionsAPR)
            
            BlendLogger.rateCalculation(
                operation: "calculateEmissionsAPR",
                inputs: [
                    "emissionsPerSecond": emissionsData.emissionsPerSecond,
                    "annualEmissionsTokens": annualEmissionsTokens,
                    "blndPrice": blndPrice,
                    "totalValueUSD": backstopPool.totalValueUSD
                ],
                result: aprDecimal
            )
            
            return aprDecimal
        }
    }
    
    // MARK: - Q4W (Queue for Withdrawal) Calculations
    
    /// Calculate optimal withdrawal queue delay based on pool conditions
    /// - Parameters:
    ///   - backstopPool: Backstop pool data
    ///   - currentUtilization: Current pool utilization
    /// - Returns: Recommended queue delay in seconds
    public func calculateOptimalQueueDelay(
        backstopPool: BackstopPool,
        currentUtilization: Double
    ) -> TimeInterval {
        
        BlendLogger.info("Calculating optimal queue delay for pool: \(backstopPool.poolId)", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateOptimalQueueDelay", category: BlendLogger.rateCalculation) {
            
            // Base delay is 7 days
            var queueDelay = defaultQueueDelay
            
            // Increase delay for high utilization (stress conditions)
            if currentUtilization > 0.9 {
                queueDelay *= 2 // 14 days for very high utilization
                BlendLogger.warning("High utilization detected, extending queue delay to 14 days", category: BlendLogger.rateCalculation)
            } else if currentUtilization > 0.8 {
                queueDelay *= 1.5 // 10.5 days for high utilization
                BlendLogger.info("Elevated utilization, extending queue delay to 10.5 days", category: BlendLogger.rateCalculation)
            }
            
            // Increase delay if backstop is near minimum threshold
            if backstopPool.totalBackstopTokens < backstopPool.minThreshold * FixedMath.toFixed(value: 1.2, decimals: 7) {
                queueDelay *= 1.5
                BlendLogger.warning("Backstop near minimum threshold, extending queue delay", category: BlendLogger.rateCalculation)
            }
            
            // Emergency status requires maximum delay
            if backstopPool.status == .emergency {
                queueDelay = maxAuctionDuration // 7 days maximum
                BlendLogger.warning("Emergency status, setting maximum queue delay", category: BlendLogger.rateCalculation)
            }
            
            BlendLogger.rateCalculation(
                operation: "calculateOptimalQueueDelay",
                inputs: [
                    "poolId": backstopPool.poolId,
                    "currentUtilization": currentUtilization,
                    "backstopStatus": backstopPool.status.rawValue,
                    "backstopRatio": NSDecimalNumber(decimal: backstopPool.totalBackstopTokens / backstopPool.minThreshold).doubleValue
                ],
                result: queueDelay
            )
            
            return queueDelay
        }
    }
    
    /// Calculate withdrawal impact on backstop pool
    /// - Parameters:
    ///   - withdrawal: Queued withdrawal request
    ///   - backstopPool: Current backstop pool state
    /// - Returns: Impact analysis of the withdrawal
    public func calculateWithdrawalImpact(
        withdrawal: QueuedWithdrawal,
        backstopPool: BackstopPool
    ) -> WithdrawalImpact {
        
        BlendLogger.info("Calculating withdrawal impact for: \(withdrawal.id)", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateWithdrawalImpact", category: BlendLogger.rateCalculation) {
            
            // Calculate new backstop state after withdrawal
            let newBackstopTokens = backstopPool.totalBackstopTokens - withdrawal.backstopTokenAmount
            let newLpTokens = backstopPool.totalLpTokens - withdrawal.lpTokenAmount
            
            // Calculate new utilization
            let newUtilization = backstopPool.maxCapacity > 0 ? 
                NSDecimalNumber(decimal: newBackstopTokens / backstopPool.maxCapacity).doubleValue : 0
            
            // Check if withdrawal would breach minimum threshold
            let breachesMinThreshold = newBackstopTokens < backstopPool.minThreshold
            
            // Calculate impact severity
            let impactSeverity: WithdrawalImpactSeverity
            if breachesMinThreshold {
                impactSeverity = .critical
            } else if newUtilization > 0.9 {
                impactSeverity = .high
            } else if newUtilization > 0.7 {
                impactSeverity = .medium
            } else {
                impactSeverity = .low
            }
            
            let impact = WithdrawalImpact(
                withdrawalId: withdrawal.id,
                currentBackstopTokens: backstopPool.totalBackstopTokens,
                newBackstopTokens: newBackstopTokens,
                currentUtilization: backstopPool.utilization,
                newUtilization: newUtilization,
                breachesMinThreshold: breachesMinThreshold,
                impactSeverity: impactSeverity,
                recommendedDelay: breachesMinThreshold ? maxAuctionDuration : defaultQueueDelay
            )
            
            BlendLogger.rateCalculation(
                operation: "calculateWithdrawalImpact",
                inputs: [
                    "withdrawalId": withdrawal.id,
                    "withdrawalAmount": withdrawal.backstopTokenAmount,
                    "currentTokens": backstopPool.totalBackstopTokens,
                    "minThreshold": backstopPool.minThreshold
                ],
                result: "Severity: \(impactSeverity.rawValue), Breaches: \(breachesMinThreshold)"
            )
            
            return impact
        }
    }
    
    // MARK: - Auction Calculations
    
    /// Calculate optimal auction parameters for bad debt or liquidation
    /// - Parameters:
    ///   - auctionType: Type of auction (bad debt, liquidation, etc.)
    ///   - assetAmount: Amount of asset to auction
    ///   - assetPrice: Current asset price
    ///   - urgency: Urgency level (affects duration and starting bid)
    /// - Returns: Recommended auction parameters
    public func calculateAuctionParameters(
        auctionType: AuctionType,
        assetAmount: Decimal,
        assetPrice: Decimal,
        urgency: AuctionUrgency = .normal
    ) -> AuctionParameters {
        
        BlendLogger.info("Calculating auction parameters for \(auctionType.rawValue)", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "calculateAuctionParameters", category: BlendLogger.rateCalculation) {
            
            let assetValue = FixedMath.mulFloor(assetAmount, assetPrice, scalar: FixedMath.SCALAR_7)
            
            // Calculate starting bid based on auction type and urgency
            let startingBidMultiplier: Decimal
            switch auctionType {
            case .badDebt:
                startingBidMultiplier = urgency == .high ? FixedMath.toFixed(value: 0.5, decimals: 7) : FixedMath.toFixed(value: 0.7, decimals: 7)
            case .liquidation:
                startingBidMultiplier = urgency == .high ? FixedMath.toFixed(value: 0.8, decimals: 7) : FixedMath.toFixed(value: 0.9, decimals: 7)
            case .interest:
                startingBidMultiplier = FixedMath.toFixed(value: 0.95, decimals: 7)
            }
            
            let startingBid = FixedMath.mulFloor(assetValue, startingBidMultiplier, scalar: FixedMath.SCALAR_7)
            
            // Calculate reserve price (minimum acceptable)
            let reserveMultiplier: Decimal = auctionType == .badDebt ? 
                FixedMath.toFixed(value: 0.3, decimals: 7) : FixedMath.toFixed(value: 0.6, decimals: 7)
            let reservePrice = FixedMath.mulFloor(assetValue, reserveMultiplier, scalar: FixedMath.SCALAR_7)
            
            // Calculate auction duration based on urgency
            let duration: TimeInterval
            switch urgency {
            case .low:
                duration = maxAuctionDuration // 7 days
            case .normal:
                duration = 86400 // 24 hours
            case .high:
                duration = 14400 // 4 hours
            case .critical:
                duration = minAuctionDuration // 1 hour
            }
            
            // Calculate minimum bid increment (1% of current value)
            let minBidIncrement = FixedMath.mulCeil(assetValue, FixedMath.toFixed(value: 0.01, decimals: 7), scalar: FixedMath.SCALAR_7)
            
            let parameters = AuctionParameters(
                auctionType: auctionType,
                startingBid: startingBid,
                reservePrice: reservePrice,
                duration: duration,
                minBidIncrement: minBidIncrement,
                urgency: urgency
            )
            
            BlendLogger.rateCalculation(
                operation: "calculateAuctionParameters",
                inputs: [
                    "auctionType": auctionType.rawValue,
                    "assetAmount": assetAmount,
                    "assetPrice": assetPrice,
                    "urgency": urgency.rawValue,
                    "assetValue": assetValue
                ],
                result: "StartingBid: \(startingBid), Reserve: \(reservePrice), Duration: \(duration)s"
            )
            
            return parameters
        }
    }
    
    /// Calculate auction bid validation
    /// - Parameters:
    ///   - auction: Current auction data
    ///   - bidAmount: Proposed bid amount
    ///   - bidder: Bidder address
    /// - Returns: Bid validation result
    public func validateAuctionBid(
        auction: AuctionData,
        bidAmount: Decimal,
        bidder: String
    ) -> BidValidationResult {
        
        BlendLogger.info("Validating auction bid for auction: \(auction.id)", category: BlendLogger.rateCalculation)
        
        return measurePerformance(operation: "validateAuctionBid", category: BlendLogger.rateCalculation) {
            
            var issues: [String] = []
            var warnings: [String] = []
            
            // Check if auction is active
            guard auction.isActive else {
                issues.append("Auction is not active")
                return BidValidationResult(
                    isValid: false,
                    issues: issues,
                    warnings: warnings,
                    auction: auction,
                    bidAmount: bidAmount,
                    bidder: bidder
                )
            }
            
            // Check minimum bid requirement
            if bidAmount < auction.nextMinBid {
                issues.append("Bid amount \(bidAmount) is below minimum required: \(auction.nextMinBid)")
            }
            
            // Check reserve price
            if bidAmount < auction.reservePrice {
                warnings.append("Bid is below reserve price of \(auction.reservePrice)")
            }
            
            // Check if bidder is current highest bidder
            if auction.currentBidder == bidder {
                issues.append("Cannot bid against yourself")
            }
            
            // Check time remaining
            if auction.timeRemaining < 300 { // 5 minutes
                warnings.append("Auction ending soon - only \(Int(auction.timeRemaining)) seconds remaining")
            }
            
            let isValid = issues.isEmpty
            let result = BidValidationResult(
                isValid: isValid,
                issues: issues,
                warnings: warnings,
                auction: auction,
                bidAmount: bidAmount,
                bidder: bidder
            )
            
            BlendLogger.rateCalculation(
                operation: "validateAuctionBid",
                inputs: [
                    "auctionId": auction.id,
                    "bidAmount": bidAmount,
                    "bidder": bidder,
                    "currentBid": auction.currentBid,
                    "minBid": auction.nextMinBid
                ],
                result: "Valid: \(isValid), Issues: \(issues.count), Warnings: \(warnings.count)"
            )
            
            return result
        }
    }
}

// MARK: - Supporting Types



/// Withdrawal impact analysis
public struct WithdrawalImpact {
    public let withdrawalId: String
    public let currentBackstopTokens: Decimal
    public let newBackstopTokens: Decimal
    public let currentUtilization: Double
    public let newUtilization: Double
    public let breachesMinThreshold: Bool
    public let impactSeverity: WithdrawalImpactSeverity
    public let recommendedDelay: TimeInterval
}

/// Withdrawal impact severity levels
public enum WithdrawalImpactSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

/// Auction urgency levels
public enum AuctionUrgency: String, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
}

/// Auction parameter recommendations
public struct AuctionParameters {
    public let auctionType: AuctionType
    public let startingBid: Decimal
    public let reservePrice: Decimal
    public let duration: TimeInterval
    public let minBidIncrement: Decimal
    public let urgency: AuctionUrgency
}

/// Bid validation result
public struct BidValidationResult {
    public let isValid: Bool
    public let issues: [String]
    public let warnings: [String]
    public let auction: AuctionData
    public let bidAmount: Decimal
    public let bidder: String
    
    /// Get a formatted validation report
    public var report: String {
        var lines: [String] = []
        
        lines.append("Auction Bid Validation Report")
        lines.append("============================")
        lines.append("Auction ID: \(auction.id)")
        lines.append("Bidder: \(bidder)")
        lines.append("Bid Amount: \(bidAmount)")
        lines.append("Status: \(isValid ? "✅ VALID" : "❌ INVALID")")
        lines.append("")
        
        if !issues.isEmpty {
            lines.append("Issues:")
            for issue in issues {
                lines.append("  • \(issue)")
            }
            lines.append("")
        }
        
        if !warnings.isEmpty {
            lines.append("Warnings:")
            for warning in warnings {
                lines.append("  ⚠️ \(warning)")
            }
            lines.append("")
        }
        
        return lines.joined(separator: "\n")
    }
} 
