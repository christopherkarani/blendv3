//
//  TransactionModels.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Transaction Event Models

/// Transaction event for diagnostics and monitoring
public struct TransactionEvent {
    public let timestamp: Date
    public let type: TransactionEventType
    public let transactionId: String?
    public let amount: Decimal?
    public let duration: TimeInterval?
    
    public init(timestamp: Date, type: TransactionEventType, transactionId: String? = nil, amount: Decimal? = nil, duration: TimeInterval? = nil) {
        self.timestamp = timestamp
        self.type = type
        self.transactionId = transactionId
        self.amount = amount
        self.duration = duration
    }
}

/// Types of transaction events that can occur
public enum TransactionEventType {
    case depositStarted
    case depositCompleted
    case withdrawStarted
    case withdrawCompleted
    case failed
}

// MARK: - Contract Interaction Models

/// Options for Soroban contract method invocation
public struct MethodOptions {
    public let fee: UInt32
    public let timeoutInSeconds: UInt32
    public let simulate: Bool
    public let restore: Bool
    
    public init(fee: UInt32 = 100_000, timeoutInSeconds: UInt32 = 30, simulate: Bool = true, restore: Bool = false) {
        self.fee = fee
        self.timeoutInSeconds = timeoutInSeconds
        self.simulate = simulate
        self.restore = restore
    }
}