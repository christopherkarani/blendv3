//
//  NetworkEvent.swift
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