import Foundation
import stellarsdk

// MARK: - Backstop Contract Models

/// The pool's backstop data
public struct PoolBackstopData: Codable, Sendable {
    public let blnd: Int128
    public let q4wPercent: Int128  // q4w_pct in contract
    public let shares: Int128
    public let tokenSpotPrice: Int128  // token_spot_price in contract
    public let tokens: Int128
    public let usdc: Int128
    
    public init(blnd: Int128, q4wPercent: Int128, shares: Int128, tokenSpotPrice: Int128, tokens: Int128, usdc: Int128) {
        self.blnd = blnd
        self.q4wPercent = q4wPercent
        self.shares = shares
        self.tokenSpotPrice = tokenSpotPrice
        self.tokens = tokens
        self.usdc = usdc
    }
    
    /// Human readable representation of PoolBackstopData with values converted using FixedMath.SCALAR_7
    public struct HumanReadable: CustomStringConvertible {
        public let blnd: Decimal
        public let q4wPercent: Decimal
        public let shares: Decimal
        public let tokenSpotPrice: Decimal
        public let tokens: Decimal
        public let usdc: Decimal
        
        public var description: String {
            """
            PoolBackstopData:
              BLND: \(formatDecimal(blnd))
              Q4W Percent: \(formatDecimal(q4wPercent))%
              Shares: \(formatDecimal(shares))
              Token Spot Price: \(formatDecimal(tokenSpotPrice))
              Tokens: \(formatDecimal(tokens))
              USDC: \(formatDecimal(usdc))
            """
        }
        
        private func formatDecimal(_ value: Decimal) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 7
            formatter.minimumFractionDigits = 0
            return formatter.string(from: value as NSNumber) ?? "0"
        }
    }
    
    /// Convert raw contract values to human readable form using FixedMath.SCALAR_7
    public var humanReadable: HumanReadable {
        HumanReadable(
            blnd: Decimal(Double(blnd)) / FixedMath.SCALAR_7,
            q4wPercent: Decimal(Double(q4wPercent)) / FixedMath.SCALAR_7 * 100,  // Convert to percentage
            shares: Decimal(Double(shares)) / FixedMath.SCALAR_7,
            tokenSpotPrice: Decimal(Double(tokenSpotPrice)) / FixedMath.SCALAR_7,
            tokens: Decimal(Double(tokens)) / FixedMath.SCALAR_7,
            usdc: Decimal(Double(usdc)) / FixedMath.SCALAR_7
        )
    }
}

/// The pool's backstop balances
public struct PoolBalance: Codable, Sendable {
    public let q4w: Int128
    public let shares: Int128
    public let tokens: Int128
    
    public init(q4w: Int128, shares: Int128, tokens: Int128) {
        self.q4w = q4w
        self.shares = shares
        self.tokens = tokens
    }
}

/// A deposit that is queued for withdrawal
public struct Q4W: Codable, Sendable {
    public let amount: Int128
    public let exp: UInt64  // expiration timestamp
    
    public init(amount: Int128, exp: UInt64) {
        self.amount = amount
        self.exp = exp
    }
    
    /// Check if the withdrawal has expired and can be executed
    public var isExpired: Bool {
        return Date().timeIntervalSince1970 >= Double(exp)
    }
    
    /// Get expiration date
    public var expirationDate: Date {
        return Date(timeIntervalSince1970: Double(exp))
    }
}

/// User's balance data including queued withdrawals and shares
public struct UserBalance: Codable, Sendable {
    public let q4w: [Q4W]  // queued withdrawals
    public let shares: Int128
    
    public init(q4w: [Q4W], shares: Int128) {
        self.q4w = q4w
        self.shares = shares
    }
    
    /// Total amount in queued withdrawals
    public var totalQueuedAmount: Int128 {
        return q4w.reduce(0) { $0 + $1.amount }
    }
    
    /// Get expired withdrawals that can be executed
    public var expiredWithdrawals: [Q4W] {
        return q4w.filter { $0.isExpired }
    }
    
    /// Get pending withdrawals that haven't expired yet
    public var pendingWithdrawals: [Q4W] {
        return q4w.filter { !$0.isExpired }
    }
}

/// Backstop emission configuration
public struct BackstopEmissionConfig: Codable, Sendable {
    public let eps: UInt64  // emissions per second
    public let expiration: UInt64
    
    public init(eps: UInt64, expiration: UInt64) {
        self.eps = eps
        self.expiration = expiration
    }
    
    /// Check if emission config has expired
    public var isExpired: Bool {
        return Date().timeIntervalSince1970 >= Double(expiration)
    }
}

/// Backstop emissions data
public struct BackstopEmissionsData: Codable, Sendable {
    public let index: Int128
    public let lastTime: UInt64
    
    public init(index: Int128, lastTime: UInt64) {
        self.index = index
        self.lastTime = lastTime
    }
    
    /// Get last update date
    public var lastUpdateDate: Date {
        return Date(timeIntervalSince1970: Double(lastTime))
    }
}

/// User emission data for reserves
public struct UserEmissionData: Codable, Sendable {
    public let accrued: Int128
    public let index: Int128
    
    public init(accrued: Int128, index: Int128) {
        self.accrued = accrued
        self.index = index
    }
}

/// Pool and user key combination
public struct PoolUserKey: Codable, Sendable, Hashable {
    public let pool: String  // pool address
    public let user: String  // user address
    
    public init(pool: String, user: String) {
        self.pool = pool
        self.user = user
    }
}

// MARK: - Enums

/// Backstop data key types for storage operations
public enum BackstopDataKey: Codable, Sendable {
    case userBalance(PoolUserKey)
    case poolBalance(String)  // pool address
    case poolUSDC(String)     // pool address
    case poolEmissions(String) // pool address
    case backstopEmissionConfig(String) // pool address
    case backstopEmissionData(String)   // pool address
    case userEmissionData(PoolUserKey)
    
    /// Get the associated pool address for this key
    public var poolAddress: String? {
        switch self {
        case .userBalance(let key), .userEmissionData(let key):
            return key.pool
        case .poolBalance(let address), 
             .poolUSDC(let address), 
             .poolEmissions(let address),
             .backstopEmissionConfig(let address),
             .backstopEmissionData(let address):
            return address
        }
    }
    
    /// Get the associated user address for this key (if applicable)
    public var userAddress: String? {
        switch self {
        case .userBalance(let key), .userEmissionData(let key):
            return key.user
        default:
            return nil
        }
    }
}

/// Backstop contract errors matching the Soroban contract error codes
public enum BackstopContractError: Int, CaseIterable, Error, Sendable {
    case internalError = 1
    case alreadyInitializedError = 3
    case unauthorizedError = 4
    case negativeAmountError = 8
    case balanceError = 10
    case overflowError = 12
    case badRequest = 1000
    case notExpired = 1001
    case invalidRewardZoneEntry = 1002
    case insufficientFunds = 1003
    case notPool = 1004
    case invalidShareMintAmount = 1005
    case invalidTokenWithdrawAmount = 1006
    case tooManyQ4WEntries = 1007
    
    /// Human-readable error descriptions
    public var description: String {
        switch self {
        case .internalError:
            return "Internal contract error occurred"
        case .alreadyInitializedError:
            return "Contract has already been initialized"
        case .unauthorizedError:
            return "Unauthorized operation attempted"
        case .negativeAmountError:
            return "Negative amount not allowed"
        case .balanceError:
            return "Insufficient balance for operation"
        case .overflowError:
            return "Numeric overflow occurred"
        case .badRequest:
            return "Invalid request parameters"
        case .notExpired:
            return "Withdrawal queue period has not expired"
        case .invalidRewardZoneEntry:
            return "Invalid reward zone configuration"
        case .insufficientFunds:
            return "Insufficient funds for operation"
        case .notPool:
            return "Address is not a valid pool"
        case .invalidShareMintAmount:
            return "Invalid share mint amount"
        case .invalidTokenWithdrawAmount:
            return "Invalid token withdrawal amount"
        case .tooManyQ4WEntries:
            return "Too many queued withdrawal entries"
        }
    }
}

// MARK: - Result Types

/// Result of a deposit operation
public struct DepositResult: Codable, Sendable {
    public let sharesReceived: Int128
    public let transactionHash: String?
    
    public init(sharesReceived: Int128, transactionHash: String? = nil) {
        self.sharesReceived = sharesReceived
        self.transactionHash = transactionHash
    }
}

/// Result of a withdrawal operation
public struct WithdrawalResult: Codable, Sendable {
    public let amountWithdrawn: Int128
    public let transactionHash: String?
    
    public init(amountWithdrawn: Int128, transactionHash: String? = nil) {
        self.amountWithdrawn = amountWithdrawn
        self.transactionHash = transactionHash
    }
}

/// Result of a claim operation
public struct ClaimResult: Codable, Sendable {
    public let totalClaimed: Int128
    public let transactionHash: String?
    
    public init(totalClaimed: Int128, transactionHash: String? = nil) {
        self.totalClaimed = totalClaimed
        self.transactionHash = transactionHash
    }
}

/// Result of token value update
public struct TokenValueUpdateResult: Codable, Sendable {
    public let blndValue: Int128
    public let usdcValue: Int128
    public let transactionHash: String?
    
    public init(blndValue: Int128, usdcValue: Int128, transactionHash: String? = nil) {
        self.blndValue = blndValue
        self.usdcValue = usdcValue
        self.transactionHash = transactionHash
    }
}

// MARK: - Extensions for Convenience

extension PoolBackstopData {
    /// Calculate total value locked (BLND + USDC)
    public var totalValueLocked: Int128 {
        return blnd + usdc
    }
    
    /// Calculate utilization percentage (q4w / total)
    public var utilizationPercentage: Decimal {
        guard totalValueLocked > 0 else { return 0 }
        return Decimal(Double(q4wPercent)) / Decimal(Double(totalValueLocked)) * 100
    }
}

extension UserBalance {
    /// Check if user has any active positions
    public var hasActivePosition: Bool {
        return shares > 0 || !q4w.isEmpty
    }
    
    /// Get next withdrawal expiration date
    public var nextExpirationDate: Date? {
        return q4w.compactMap { $0.expirationDate }.min()
    }
}

extension BackstopContractError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}
