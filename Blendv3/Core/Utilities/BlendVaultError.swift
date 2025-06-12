//
//  BlendVaultError.swift
//  Blendv3
//
//  Created by Chris Karani on 06/06/2025.
//

import Foundation

public enum BlendVaultError: LocalizedError {
    case notInitialized
    case invalidAmount(String)
    case insufficientBalance
    case transactionFailed(String)
    case networkError(String)
    case initializationFailed(String)
    case invalidResponse
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Vault not initialized. Please wait and try again."
        case .invalidAmount(let message):
            return "Invalid amount: \(message)"
        case .insufficientBalance:
            return "Insufficient balance for this operation"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .initializationFailed(let message):
            return "Failed to initialize: \(message)"
        case .invalidResponse:
            return "Invalid response from contract"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}
