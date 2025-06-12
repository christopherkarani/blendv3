//
//  TimeoutConfiguration.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Timeout Configuration

/// Configuration for operation timeouts
public struct TimeoutConfiguration: Sendable {
    public let networkTimeout: TimeInterval
    public let transactionTimeout: TimeInterval
    public let initializationTimeout: TimeInterval
    
    public init(networkTimeout: TimeInterval = 30.0, transactionTimeout: TimeInterval = 60.0, initializationTimeout: TimeInterval = 30.0) {
        self.networkTimeout = networkTimeout
        self.transactionTimeout = transactionTimeout
        self.initializationTimeout = initializationTimeout
    }
}