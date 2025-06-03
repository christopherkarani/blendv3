//
//  HealthCheckResult.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Health Check Models

/// Result of a health check operation
public struct HealthCheckResult {
    public let isHealthy: Bool
    public let networkStatus: ConnectionState
    public let sorobanClientStatus: Bool
    public let lastSuccessfulOperation: Date?
    public let issues: [HealthIssue]
    
    public init(isHealthy: Bool, networkStatus: ConnectionState, sorobanClientStatus: Bool, lastSuccessfulOperation: Date? = nil, issues: [HealthIssue] = []) {
        self.isHealthy = isHealthy
        self.networkStatus = networkStatus
        self.sorobanClientStatus = sorobanClientStatus
        self.lastSuccessfulOperation = lastSuccessfulOperation
        self.issues = issues
    }
}