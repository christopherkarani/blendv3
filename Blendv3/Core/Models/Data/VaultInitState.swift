//
//  VaultInitState.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Vault Initialization State

/// Initialization state for the BlendUSDCVault
public enum VaultInitState {
    case notInitialized
    case initializing
    case ready
    case failed(Error)
    
    public var description: String {
        switch self {
        case .notInitialized: return "Not Initialized"
        case .initializing: return "Initializing..."
        case .ready: return "Ready"
        case .failed(let error): return "Failed: \(error.localizedDescription)"
        }
    }
    
    public var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}