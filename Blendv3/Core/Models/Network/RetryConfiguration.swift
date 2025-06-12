//
//  RetryConfiguration.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Retry Configuration

/// Configuration for retry logic with exponential backoff
public struct RetryConfiguration: Sendable {
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