//
//  WalletError.swift
//  Blendv3
//
//  Wallet-specific error types
//

import Foundation

/// Errors specific to wallet operations
enum WalletError: LocalizedError {
    case invalidSecretSeed
    case keychainError(String)
    case walletNotFound
    case networkError(String)
    case insufficientBalance
    case invalidAddress
    case transactionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidSecretSeed:
            return "Invalid secret seed provided"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .walletNotFound:
            return "Wallet not found"
        case .networkError(let message):
            return "Network error: \(message)"
        case .insufficientBalance:
            return "Insufficient balance for this operation"
        case .invalidAddress:
            return "Invalid Stellar address"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        }
    }
}