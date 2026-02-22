//
//  BlendParsingContext.swift
//  Blendv3
//
//  Context information for parsing operations
//

import Foundation

/// Context information for parsing operations
public struct BlendParsingContext: Sendable {
    public let functionName: String
    public let contractType: ContractType
    public let additionalInfo: [String: String]
    
    public enum ContractType: String, CaseIterable, Sendable {
        case oracle = "oracle"
        case pool = "pool"
        case backstop = "backstop"
        case userPosition = "user_position"
        case emission = "emission"
    }
    
    public init(
        functionName: String,
        contractType: ContractType = .pool,
        additionalInfo: [String: String] = [:]
    ) {
        self.functionName = functionName
        self.contractType = contractType
        self.additionalInfo = additionalInfo
    }
    
    // Convenience initializers for common contexts
    public static func oracle(_ functionName: String) -> BlendParsingContext {
        BlendParsingContext(functionName: functionName, contractType: .oracle)
    }
    
    public static func pool(_ functionName: String) -> BlendParsingContext {
        BlendParsingContext(functionName: functionName, contractType: .pool)
    }
    
    public static func backstop(_ functionName: String) -> BlendParsingContext {
        BlendParsingContext(functionName: functionName, contractType: .backstop)
    }
    
    public static func userPosition(_ functionName: String) -> BlendParsingContext {
        BlendParsingContext(functionName: functionName, contractType: .userPosition)
    }
}
