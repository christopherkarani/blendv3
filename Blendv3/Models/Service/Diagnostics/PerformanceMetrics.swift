//
//  PerformanceMetrics.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

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