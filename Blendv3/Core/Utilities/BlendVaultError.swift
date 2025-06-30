//
//  BlendVaultError.swift
//  Blendv3
//
//  Created by Chris Karani on 06/06/2025.
//

import Foundation

public enum BlendVaultError: LocalizedError, CustomDebugStringConvertible, Sendable {
    // MARK: - Configuration & Initialization
    case notInitialized
    case initializationFailed(String)
    case invalidConfiguration(String)
    case keyPairError(String)
    
    // MARK: - Network & Communication
    case networkError(String, retryable: Bool = true)
    case timeoutError(operation: String)
    case rpcError(String)
    
    // MARK: - Input Validation
    case invalidAmount(String)
    case assetNotSupported(String)
    case poolNotFound(String)
    case insufficientBalance(required: Decimal, available: Decimal)
    
    // MARK: - Transaction Failures
    case transactionFailed(reason: String, transactionHash: String? = nil)
    case simulationFailed(String)
    case healthFactorTooLow(current: Decimal, minimum: Decimal)
    
    // MARK: - Backstop-Specific Errors
    case backstopWithdrawalNotReady(availableAt: Date)
    case backstopInsufficientShares(required: Int128, available: Int128)
    case backstopQueueFull
    case backstopEmissionsClaimed
    case backstopRewardsNotAvailable
    case backstopTokenError(String)
    
    // MARK: - Service Errors (wrapped)
    case oracleError(OracleError)
    case backstopError(BackstopError)
    case poolError(BlendError)
    
    // MARK: - Cache & Data Errors
    case cacheError(String)
    case dataCorruption(String)
    case invalidResponse
    
    // MARK: - Concurrency Errors
    case taskCancelled(operation: String)
    case concurrencyLimitExceeded
    case resourceExhausted(resource: String)
    
    // MARK: - Unknown
    case unknown(String)
    
    // MARK: - LocalizedError Implementation
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Vault not initialized. Please wait and try again."
        case .initializationFailed(let message):
            return "Failed to initialize: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .keyPairError(let message):
            return "KeyPair error: \(message)"
            
        case .networkError(let message, _):
            return "Network error: \(message)"
        case .timeoutError(let operation):
            return "Operation timed out: \(operation)"
        case .rpcError(let message):
            return "RPC error: \(message)"
            
        case .invalidAmount(let message):
            return "Invalid amount: \(message)"
        case .assetNotSupported(let asset):
            return "Asset not supported: \(asset)"
        case .poolNotFound(let poolID):
            return "Pool not found: \(poolID)"
        case .insufficientBalance(let required, let available):
            return "Insufficient balance. Required: \(required), Available: \(available)"
            
        case .transactionFailed(let reason, let hash):
            let hashInfo = hash.map { " (Transaction: \($0))" } ?? ""
            return "Transaction failed: \(reason)\(hashInfo)"
        case .simulationFailed(let message):
            return "Transaction simulation failed: \(message)"
        case .healthFactorTooLow(let current, let minimum):
            return "Health factor too low. Current: \(current), Minimum required: \(minimum)"
            
        case .backstopWithdrawalNotReady(let availableAt):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "Backstop withdrawal not ready. Available at: \(formatter.string(from: availableAt))"
        case .backstopInsufficientShares(let required, let available):
            return "Insufficient backstop shares. Required: \(required), Available: \(available)"
        case .backstopQueueFull:
            return "Backstop withdrawal queue is full"
        case .backstopEmissionsClaimed:
            return "Backstop emissions already claimed"
        case .backstopRewardsNotAvailable:
            return "No backstop rewards available to claim"
        case .backstopTokenError(let message):
            return "Backstop token error: \(message)"
            
        case .oracleError(let error):
            return "Oracle error: \(error.localizedDescription)"
        case .backstopError(let error):
            return "Backstop error: \(error.localizedDescription)"
        case .poolError(let error):
            return "Pool error: \(error.localizedDescription)"
            
        case .cacheError(let message):
            return "Cache error: \(message)"
        case .dataCorruption(let message):
            return "Data corruption: \(message)"
        case .invalidResponse:
            return "Invalid response from contract"
            
        case .taskCancelled(let operation):
            return "Operation cancelled: \(operation)"
        case .concurrencyLimitExceeded:
            return "Too many concurrent operations"
        case .resourceExhausted(let resource):
            return "Resource exhausted: \(resource)"
            
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
    
    // MARK: - Custom Properties
    
    /// Whether the error is retryable
    public var isRetryable: Bool {
        switch self {
        case .networkError(_, let retryable):
            return retryable
        case .timeoutError, .rpcError:
            return true
        case .taskCancelled:
            return true
        case .transactionFailed, .simulationFailed:
            return false
        default:
            return false
        }
    }
    
    /// Recovery suggestion for the error
    public var recoverySuggestion: String? {
        switch self {
        case .insufficientBalance:
            return "Please deposit more funds or reduce the transaction amount."
        case .healthFactorTooLow:
            return "Consider depositing more collateral or repaying some borrowed assets."
        case .backstopWithdrawalNotReady(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "Please wait until \(formatter.string(from: date)) to execute this withdrawal."
        case .assetNotSupported:
            return "Please select a supported asset from the available list."
        case .networkError(_, let retryable) where retryable:
            return "Please check your internet connection and try again."
        case .concurrencyLimitExceeded:
            return "Please wait for other operations to complete before trying again."
        default:
            return nil
        }
    }
    
    // MARK: - Debug Description
    
    public var debugDescription: String {
        return "BlendVaultError: \(errorDescription ?? "Unknown error")"
    }
}
