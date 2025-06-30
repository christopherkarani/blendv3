//
//  BlendExtensions.swift
//  Blendv3
//
//  Extension helpers for BlendVault API
//

import Foundation

// MARK: - Decimal Extensions

extension Decimal {
    /// Convert to human-readable format with specified decimal places
    func formatted(decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: self as NSDecimalNumber) ?? "0"
    }
    
    /// Convert to percentage format
    func asPercentage(decimals: Int = 2) -> String {
        let percentage = self * 100
        return "\(percentage.formatted(decimals: decimals))%"
    }
    
    /// Convert to currency format
    func asCurrency(symbol: String = "$") -> String {
        return "\(symbol)\(self.formatted(decimals: 2))"
    }
}

// MARK: - Date Extensions

extension Date {
    /// Check if date is in the past
    var isPast: Bool {
        return self < Date()
    }
    
    /// Check if date is in the future
    var isFuture: Bool {
        return self > Date()
    }
    
    /// Time remaining until this date
    var timeRemaining: TimeInterval {
        return self.timeIntervalSinceNow
    }
    
    /// Human-readable time remaining
    var timeRemainingDescription: String {
        let interval = self.timeIntervalSinceNow
        
        if interval < 0 {
            return "Available now"
        }
        
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") remaining"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") remaining"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") remaining"
        }
    }
}

// MARK: - Array Extensions

extension Array where Element == PoolStats {
    /// Calculate average APY across pools
    var averageAPY: Decimal {
        guard !isEmpty else { return .zero }
        let totalAPY = reduce(Decimal.zero) { $0 + $1.netAPY }
        return totalAPY / Decimal(count)
    }
    
    /// Total value locked across all pools
    var totalValueLocked: Decimal {
        return reduce(Decimal.zero) { $0 + $1.totalSuppliedUSD }
    }
}

extension Array where Element == BackstopHealthAlert {
    /// Filter by severity
    func bySeverity(_ severity: AlertSeverity) -> [BackstopHealthAlert] {
        return filter { $0.severity == severity }
    }
    
    /// Check if any critical alerts
    var hasCriticalAlerts: Bool {
        return contains { $0.severity == .critical }
    }
}

// MARK: - Health Status Extensions

extension HealthLevel {
    /// Color representation for UI
    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .moderate:
            return "yellow"
        case .poor:
            return "orange"
        case .critical:
            return "red"
        }
    }
    
    /// Emoji representation
    var emoji: String {
        switch self {
        case .excellent:
            return "✅"
        case .good:
            return "👍"
        case .moderate:
            return "⚠️"
        case .poor:
            return "⚡"
        case .critical:
            return "🚨"
        }
    }
}

// MARK: - Transaction Operation Extensions

extension TransactionOperation {
    /// Human-readable description
    var description: String {
        switch self {
        case .poolDeposit:
            return "Pool Deposit"
        case .poolWithdraw:
            return "Pool Withdrawal"
        case .backstopDeposit:
            return "Backstop Deposit"
        case .backstopWithdraw:
            return "Backstop Withdrawal"
        case .backstopClaim:
            return "Claim Rewards"
        case .borrow:
            return "Borrow"
        case .repay:
            return "Repay"
        }
    }
    
    /// Whether this operation increases user assets
    var isDeposit: Bool {
        switch self {
        case .poolDeposit, .backstopDeposit, .repay:
            return true
        default:
            return false
        }
    }
} 