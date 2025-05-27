//
//  DiagnosticsModels.swift
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

/// Individual health issue detected during health check
public struct HealthIssue {
    public let severity: Severity
    public let description: String
    public let recommendation: String
    
    public init(severity: Severity, description: String, recommendation: String) {
        self.severity = severity
        self.description = description
        self.recommendation = recommendation
    }
    
    /// Severity levels for health issues
    public enum Severity {
        case low
        case medium
        case high
        case critical
    }
}

// MARK: - Performance Models

/// Performance metrics for monitoring service health
public struct PerformanceMetrics {
    public let averageResponseTime: TimeInterval
    public let successRate: Double
    public let errorRate: Double
    public let totalRequests: Int
    public let memoryUsage: Double
    
    public init(averageResponseTime: TimeInterval, successRate: Double, errorRate: Double, totalRequests: Int, memoryUsage: Double) {
        self.averageResponseTime = averageResponseTime
        self.successRate = successRate
        self.errorRate = errorRate
        self.totalRequests = totalRequests
        self.memoryUsage = memoryUsage
    }
}