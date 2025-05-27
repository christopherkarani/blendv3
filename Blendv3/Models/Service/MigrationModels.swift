//
//  MigrationModels.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Migration Models

/// Migration event for tracking architecture transition
public struct MigrationEvent {
    public let timestamp: Date
    public let type: MigrationEventType
    public let description: String
    public let metadata: [String: Any]
    
    public init(timestamp: Date, type: MigrationEventType, description: String, metadata: [String: Any] = [:]) {
        self.timestamp = timestamp
        self.type = type
        self.description = description
        self.metadata = metadata
    }
    
    /// Types of migration events
    public enum MigrationEventType {
        case featureFlagToggled
        case comparisonCompleted
        case validationFailed
        case rollbackTriggered
    }
}

/// Result of migration validation between old and new implementations
public enum MigrationValidationResult {
    case success
    case differences([String])
    case incomplete(String)
}