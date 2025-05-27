//
//  NetworkModels.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Network Event Models

/// Network event for diagnostics and monitoring
public struct NetworkEvent {
    public let timestamp: Date
    public let type: NetworkEventType
    public let details: String
    public let duration: TimeInterval?
    
    public init(timestamp: Date, type: NetworkEventType, details: String, duration: TimeInterval? = nil) {
        self.timestamp = timestamp
        self.type = type
        self.details = details
        self.duration = duration
    }
}

/// Types of network events that can occur
public enum NetworkEventType {
    case connectionAttempt
    case connectionSuccess
    case connectionFailure
    case retry
}

// MARK: - Configuration Models

/// Configuration for retry logic with exponential backoff
public struct RetryConfiguration {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let exponentialBase: Double
    public let jitterRange: ClosedRange<Double>
    
    public init(maxRetries: Int = 5, baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 30.0, exponentialBase: Double = 2.0, jitterRange: ClosedRange<Double> = 0.0...0.3) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.exponentialBase = exponentialBase
        self.jitterRange = jitterRange
    }
}

/// Configuration for operation timeouts
public struct TimeoutConfiguration {
    public let networkTimeout: TimeInterval
    public let transactionTimeout: TimeInterval
    public let initializationTimeout: TimeInterval
    
    public init(networkTimeout: TimeInterval = 30.0, transactionTimeout: TimeInterval = 60.0, initializationTimeout: TimeInterval = 30.0) {
        self.networkTimeout = networkTimeout
        self.transactionTimeout = transactionTimeout
        self.initializationTimeout = initializationTimeout
    }
}