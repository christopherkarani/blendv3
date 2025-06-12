//
//  OracleError.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//

import Foundation

/// Error types for the Oracle implementation
public enum OracleError: LocalizedError, CustomDebugStringConvertible {
    /// Price not found for the specified asset
    case priceNotFound(asset: String, reason: String? = nil)
    
    /// Price is not available for the specified asset
    case priceNotAvailable(asset: String, reason: String? = nil)
    
    /// No data available for the request
    case noDataAvailable(context: String? = nil)
    
    /// Maximum retry attempts reached
    case maxRetriesExceeded(attempts: Int, lastError: Error? = nil)
    
    /// Network error during oracle request
    case networkError(Error, context: String? = nil)
    
    /// Invalid response format from oracle
    case invalidResponseFormat(String)
    
    /// Invalid response from oracle with details and raw data
    case invalidResponse(details: String? = nil, rawData: String? = nil)
    
    /// Invalid asset format
    case invalidAssetFormat(String)
    
    /// Oracle contract error
    case contractError(code: Int, message: String)
    
    /// Unknown error
    case unknown(Error)
    
    // MARK: - LocalizedError
    
    public var errorDescription: String? {
        switch self {
        case .priceNotFound(let asset, let reason):
            return "Price not found for asset: \(asset)\(reason != nil ? " - \(reason!)" : "")"
            
        case .priceNotAvailable(let asset, let reason):
            return "Price not available for asset: \(asset)\(reason != nil ? " - \(reason!)" : "")"
            
        case .noDataAvailable(let context):
            return "No data available\(context != nil ? " - \(context!)" : "")"
            
        case .maxRetriesExceeded(let attempts, let error):
            return "Max retries exceeded (\(attempts))\(error != nil ? " - \(error!.localizedDescription)" : "")"
            
        case .networkError(let error, let context):
            return "Network error: \(error.localizedDescription)\(context != nil ? " - \(context!)" : "")"
            
        case .invalidResponseFormat(let message):
            return "Invalid response format: \(message)"
            
        case .invalidResponse(let details, _):
            return "Invalid response from oracle\(details != nil ? ": \(details!)" : "")"
            
        case .invalidAssetFormat(let message):
            return "Invalid asset format: \(message)"
            
        case .contractError(let code, let message):
            return "Contract error \(code): \(message)"
            
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - CustomDebugStringConvertible
    
    public var debugDescription: String {
        switch self {
        case .priceNotFound(let asset, let reason):
            return "OracleError.priceNotFound(asset: \(asset), reason: \(reason ?? "nil"))"
            
        case .priceNotAvailable(let asset, let reason):
            return "OracleError.priceNotAvailable(asset: \(asset), reason: \(reason ?? "nil"))"
            
        case .noDataAvailable(let context):
            return "OracleError.noDataAvailable(context: \(context ?? "nil"))"
            
        case .maxRetriesExceeded(let attempts, let error):
            return "OracleError.maxRetriesExceeded(attempts: \(attempts), lastError: \(error?.localizedDescription ?? "nil"))"
            
        case .networkError(let error, let context):
            return "OracleError.networkError(\(error), context: \(context ?? "nil"))"
            
        case .invalidResponseFormat(let message):
            return "OracleError.invalidResponseFormat(\(message))"
            
        case .invalidResponse(let details, let rawData):
            return "OracleError.invalidResponse(details: \(details ?? "nil"), rawData: \(rawData ?? "nil"))"
            
        case .invalidAssetFormat(let message):
            return "OracleError.invalidAssetFormat(\(message))"
            
        case .contractError(let code, let message):
            return "OracleError.contractError(code: \(code), message: \(message))"
            
        case .unknown(let error):
            return "OracleError.unknown(\(error))"
        }
    }
}
