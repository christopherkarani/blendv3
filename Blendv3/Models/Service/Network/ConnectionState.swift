//
//  ConnectionState.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Connection State

/// Network connection state
public enum ConnectionState {
    case unknown
    case connected
    case disconnected(String)
    case unstable(String)
    
    public var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .connected: return "Connected"
        case .disconnected(let reason): return "Disconnected: \(reason)"
        case .unstable(let details): return "Unstable: \(details)"
        }
    }
    
    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    public var color: String {
        switch self {
        case .unknown: return "gray"
        case .connected: return "green"
        case .disconnected: return "red"
        case .unstable: return "orange"
        }
    }
}