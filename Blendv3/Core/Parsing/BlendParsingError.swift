//
//  BlendParsingError.swift
//  Blendv3
//
//  Errors for BlendParser operations
//

import Foundation

/// Errors that can occur during parsing operations
public enum BlendParsingError: Error, LocalizedError, Sendable {
    case invalidType(expected: String, actual: String)
    case missingRequiredField(String)
    case invalidValue(String)
    case unsupportedOperation(String)
    case conversionFailed(String)
    case malformedResponse(String)
    
    // Additional error cases for Oracle parsing
    case invalidData
    case unsupportedType(String)
    case decodingError(Error)
    case invalidFormat(String)
    case invalidResponse(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidType(let expected, let actual):
            return "Invalid type: expected \(expected), got \(actual)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidValue(let description):
            return "Invalid value: \(description)"
        case .unsupportedOperation(let operation):
            return "Unsupported operation: \(operation)"
        case .conversionFailed(let description):
            return "Conversion failed: \(description)"
        case .malformedResponse(let description):
            return "Malformed response: \(description)"
        case .invalidData:
            return "Invalid data provided for parsing"
        case .unsupportedType(let type):
            return "Unsupported type: \(type)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .invalidFormat(let format):
            return "Invalid format: \(format)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        }
    }
}
