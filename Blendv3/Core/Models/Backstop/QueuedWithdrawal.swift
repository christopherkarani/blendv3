//
//  QueuedWithdrawal.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//
import Foundation

/// Queued withdrawal request
public struct QueuedWithdrawal: Codable {
    
    /// Unique withdrawal ID
    public let id: String
    
    /// User address
    public let userAddress: String
    
    /// Pool ID
    public let poolId: String
    
    /// Amount of backstop tokens to withdraw
    public let backstopTokenAmount: Decimal
    
    /// Equivalent LP token amount at time of request
    public let lpTokenAmount: Decimal
    
    /// Timestamp when withdrawal was queued
    public let queuedAt: Date
    
    /// Timestamp when withdrawal becomes executable
    public let executableAt: Date
    
    /// Current status of the withdrawal
    public let status: WithdrawalStatus
    
    /// Optional cancellation timestamp
    public let cancelledAt: Date?
    
    /// Optional execution timestamp
    public let executedAt: Date?
    
    // MARK: - Calculated Properties
    
    /// Whether the withdrawal can be executed now
    public var isExecutable: Bool {
        return status == .queued && Date() >= executableAt
    }
    
    /// Whether the withdrawal is still pending
    public var isPending: Bool {
        return status == .queued
    }
    
    /// Time remaining until executable (in seconds)
    public var timeUntilExecutable: TimeInterval {
        return max(0, executableAt.timeIntervalSince(Date()))
    }
    
    /// Time since queued (in seconds)
    public var timeSinceQueued: TimeInterval {
        return Date().timeIntervalSince(queuedAt)
    }
    
    public init(
        id: String = UUID().uuidString,
        userAddress: String,
        poolId: String,
        backstopTokenAmount: Decimal,
        lpTokenAmount: Decimal,
        queuedAt: Date = Date(),
        queueDelay: TimeInterval = 604800, // 7 days default
        status: WithdrawalStatus = .queued,
        cancelledAt: Date? = nil,
        executedAt: Date? = nil
    ) {
        self.id = id
        self.userAddress = userAddress
        self.poolId = poolId
        self.backstopTokenAmount = backstopTokenAmount
        self.lpTokenAmount = lpTokenAmount
        self.queuedAt = queuedAt
        self.executableAt = queuedAt.addingTimeInterval(queueDelay)
        self.status = status
        self.cancelledAt = cancelledAt
        self.executedAt = executedAt
        
        BlendLogger.info(
            "QueuedWithdrawal created: \(id) for user: \(userAddress), amount: \(backstopTokenAmount)",
            category: BlendLogger.rateCalculation
        )
    }
}


extension QueuedWithdrawal: Equatable {
    public static func == (lhs: QueuedWithdrawal, rhs: QueuedWithdrawal) -> Bool {
        return lhs.id == rhs.id
    }
}
