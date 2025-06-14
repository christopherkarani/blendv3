//
//  BlendError.swift
//  Blendv3
//
//  Created by Chris Karani on 12/06/2025.
//

import Foundation

///// Sanitized error type that never exposes internal implementation details
public enum BlendError: LocalizedError, Equatable {
    case network(NetworkErrorType)
    case validation(ValidationErrorType)
    case transaction(TransactionErrorType)
    case tokenMetadata(TokenMetadataErrorType)
    case initialization(String)
    case serviceError(String)
    case unauthorized
    case insufficientFunds
    case serviceUnavailable
    case assetRetrivalFailed
    case borrowError(String)
    case withdraw(String)
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .network(let type):
            return "Network error: \(type.userFriendlyMessage)"
        case .validation(let type):
            return "Validation error: \(type.userFriendlyMessage)"
        case .transaction(let type):
            return "Transaction error: \(type.userFriendlyMessage)"
        case .tokenMetadata(let type):
            return "Token metadata error: \(type.userFriendlyMessage)"
        case .initialization(let message):
            return "Initialization failed: \(message)"
        case .unauthorized:
            return "Unauthorized access"
        case .insufficientFunds:
            return "Insufficient funds for this operation"
        case .serviceUnavailable:
            return "Service temporarily unavailable"
        case .unknown:
            return "An unexpected error occurred"
        case .assetRetrivalFailed:
            return "Asset RetrievalFailed"
        case .serviceError(let message):
            return "Service error: \(message)"
        case .borrowError(let message):
            return "Borrow Error: \(message)"
            
        case .withdraw(let message):
            return "Withdraw Error: \(message)"
        }
    }
}

public enum NetworkErrorType: Equatable {
    case connectionFailed
    case timeout
    case serverError
    
    var userFriendlyMessage: String {
        switch self {
        case .connectionFailed: return "Unable to connect to the network"
        case .timeout: return "Request timed out"
        case .serverError: return "Server error occurred"
        }
    }
}
//
public enum ValidationErrorType: Equatable {
    case invalidInput
    case invalidResponse
    case integerOverflow
    case outOfBounds
    
    var userFriendlyMessage: String {
        switch self {
        case .invalidInput: return "Invalid input provided"
        case .invalidResponse: return "Invalid response from server"
        case .integerOverflow: return "Number too large"
        case .outOfBounds: return "Value out of acceptable range"
        }
    }
}
//
public enum TransactionErrorType: Equatable {
    case failed
    case rejected
    case insufficientFee
    
    var userFriendlyMessage: String {
        switch self {
        case .failed: return "Transaction failed"
        case .rejected: return "Transaction was rejected"
        case .insufficientFee: return "Insufficient fee for transaction"
        }
    }
}

public enum TokenMetadataErrorType: Equatable {
    case noInstance
    case malformed
    case invalidContractId
    
    var userFriendlyMessage: String {
        switch self {
        case .noInstance: return "Contract instance not found"
        case .malformed: return "Malformed metadata in contract"
        case .invalidContractId: return "Invalid contract ID format"
        }
    }
}
