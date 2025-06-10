//
//  TransactionEvent.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
////
//
//import Foundation
//
//// MARK: - Transaction Event Models
//
///// Transaction event for diagnostics and monitoring
//public struct TransactionEvent {
//    public let timestamp: Date
//    public let type: TransactionEventType
//    public let transactionId: String?
//    public let amount: Decimal?
//    public let duration: TimeInterval?
//    
//    public init(timestamp: Date, type: TransactionEventType, transactionId: String? = nil, amount: Decimal? = nil, duration: TimeInterval? = nil) {
//        self.timestamp = timestamp
//        self.type = type
//        self.transactionId = transactionId
//        self.amount = amount
//        self.duration = duration
//    }
//}
//
///// Types of transaction events that can occur
//public enum TransactionEventType {
//    case depositStarted
//    case depositCompleted
//    case withdrawStarted
//    case withdrawCompleted
//    case failed
//}
