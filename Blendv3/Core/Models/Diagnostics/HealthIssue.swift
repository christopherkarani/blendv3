//
//  HealthIssue.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Health Issue Models

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