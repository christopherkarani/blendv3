//
//  OracleNetworkService.swift
//  Blendv3
//
//  Oracle network service that uses NetworkService for contract invocations
//

import Foundation
import stellarsdk
import os

/// Protocol for Oracle network operations
public protocol OracleNetworkServiceProtocol: Sendable {
    /// Invoke an Oracle contract function
    /// - Parameters:
    ///   - function: Type-safe contract function
    ///   - arguments: Function arguments
    ///   - sourceKeyPair: Source account key pair
    /// - Returns: Raw SCValXDR response
    /// - Throws: OracleError if invocation fails
    func invokeContractFunction(
        _ function: OracleContractFunction,
        arguments: [SCValXDR],
        sourceKeyPair: KeyPair
    ) async throws -> SCValXDR
    
    /// Simulate an Oracle contract function (read-only)
    /// - Parameters:
    ///   - function: Type-safe contract function
    ///   - arguments: Function arguments
    /// - Returns: Raw SCValXDR response
    /// - Throws: OracleError if simulation fails
    func simulateContractFunction(
        _ function: OracleContractFunction,
        arguments: [SCValXDR]
    ) async throws -> SCValXDR
}

/// Oracle network service implementation using NetworkService
@MainActor
public final class OracleNetworkService: OracleNetworkServiceProtocol {
    
    // MARK: - Properties
    
    private let networkService: NetworkServiceProtocol
    private let contractId: String
    private let debugLogger = DebugLogger(subsystem: "com.blendv3.oracle", category: "OracleNetworkService")
    
    let sourceKeyPair: KeyPair
    
    // MARK: - Initialization
    
    public init(networkService: NetworkServiceProtocol,
                contractId: String,
                sourceKeyPair: KeyPair) {
        self.networkService = networkService
        self.contractId = contractId
        self.sourceKeyPair = sourceKeyPair
        debugLogger.info("🔮 🌐 Oracle network service initialized with contract: \(contractId)")
    }
    
    // MARK: - OracleNetworkServiceProtocol Implementation
    
    public func invokeContractFunction(
        _ function: OracleContractFunction,
        arguments: [SCValXDR] = [],
        sourceKeyPair: KeyPair
    ) async throws -> SCValXDR {
        debugLogger.info("🔮 🚀 Invoking contract function: \(function.rawValue)")
        
        do {
            // Validate parameters
            try function.validateParameterCount(arguments.count)
            
            // Use NetworkService to invoke the contract function
            let result = try await networkService.invokeContractFunction(
                contractId: contractId,
                functionName: function.rawValue,
                args: arguments,
                sourceKeyPair: sourceKeyPair,
                force: false
            )
            
            debugLogger.info("🔮 ✅ Contract function \(function.rawValue) invoked successfully")
            return result
            
        } catch let error as OracleError {
            debugLogger.error("🔮 💥 Oracle error invoking \(function.rawValue): \(error.localizedDescription)")
            throw error
        } catch {
            debugLogger.error("🔮 💥 Network error invoking \(function.rawValue): \(error.localizedDescription)")
            throw OracleError.networkError(error.localizedDescription)
        }
    }
    
    public func simulateContractFunction(
        _ function: OracleContractFunction,
        arguments: [SCValXDR] = []
    ) async throws -> SCValXDR {
        debugLogger.info("🔮 🔍 Simulating contract function: \(function.rawValue)")
        
        do {
            // Validate parameters
            try! function.validateParameterCount(arguments.count)
            
            
            // Use NetworkService to simulate the contract function
            let simulationResult = await networkService.simulateContractFunction(
                contractId: contractId,
                functionName: function.rawValue,
                args: arguments,
                sourceKeyPair: sourceKeyPair
            )
            
            switch simulationResult {
            case .success(let result):
                debugLogger.info("🔮 ✅ Contract function \(function.rawValue) simulated successfully")
                return result.result
                
            case .failure(let error):
                debugLogger.error("🔮 💥 Simulation failed for \(function.rawValue): \(error.localizedDescription)")
                throw OracleError.simulationFailed(error.localizedDescription)
            }
        } catch let error as OracleError {
            debugLogger.error("🔮 💥 Oracle error simulating \(function.rawValue): \(error.localizedDescription)")
            throw error
        } catch {
            debugLogger.error("🔮 💥 Network error simulating \(function.rawValue): \(error.localizedDescription)")
            throw OracleError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - Convenience Methods

extension OracleNetworkService {
    
    /// Simulate contract function with builder pattern
    /// - Parameter builder: Contract call builder
    /// - Returns: Raw SCValXDR response
    /// - Throws: OracleError if simulation fails
    public func simulate(using builder: OracleContractCallBuilder) async throws -> SCValXDR {
        let contractCall = try builder.build()
        
        // Extract function from contract call
        guard let function = OracleContractFunction(rawValue: contractCall.functionName) else {
            throw OracleError.invalidFunction(contractCall.functionName)
        }
        
        return try await simulateContractFunction(function, arguments: contractCall.functionArguments)
    }
    
    /// Invoke contract function with builder pattern
    /// - Parameters:
    ///   - builder: Contract call builder
    ///   - sourceKeyPair: Source account key pair
    /// - Returns: Raw SCValXDR response
    /// - Throws: OracleError if invocation fails
    public func invoke(using builder: OracleContractCallBuilder, sourceKeyPair: KeyPair) async throws -> SCValXDR {
        let contractCall = try builder.build()
        
        // Extract function from contract call
        guard let function = OracleContractFunction(rawValue: contractCall.functionName) else {
            throw OracleError.invalidFunction(contractCall.functionName)
        }
        
        return try await invokeContractFunction(function, arguments: contractCall.functionArguments, sourceKeyPair: sourceKeyPair)
    }
}

// MARK: - Typed Response Methods

extension OracleNetworkService {
    
    /// Simulate and parse Optional PriceData response
    public func simulateAndParseOptionalPriceData(
        _ function: OracleContractFunction,
        arguments: [SCValXDR] = [],
        context: OracleParsingContext? = nil
    ) async throws -> PriceData? {
        let response = try await simulateContractFunction(function, arguments: arguments)
        let parsingContext = context ?? OracleParsingContext(functionName: function.rawValue)
        return try BlendParser().parseOptionalPriceData(response, context: parsingContext)
    }
    
    /// Simulate and parse PriceData vector response
    public func simulateAndParsePriceDataVector(
        _ function: OracleContractFunction,
        arguments: [SCValXDR] = [],
        context: OracleParsingContext? = nil
    ) async throws -> [PriceData] {
        let response = try await simulateContractFunction(function, arguments: arguments)
        let parsingContext = context ?? OracleParsingContext(functionName: function.rawValue)
        return try BlendParser().parsePriceDataVector(response, context: parsingContext)
    }
    
    /// Simulate and parse Asset vector response
    public func simulateAndParseAssetVector(
        _ function: OracleContractFunction,
        arguments: [SCValXDR] = []
    ) async throws -> [OracleAsset] {
        let response = try await simulateContractFunction(function, arguments: arguments)
        return try BlendParser().parseAssetVector(response)
    }
    
    /// Simulate and parse u32 response
    public func simulateAndParseU32(
        _ function: OracleContractFunction,
        arguments: [SCValXDR] = [],
        context: OracleParsingContext? = nil
    ) async throws -> UInt32 {
        let response = try await simulateContractFunction(function, arguments: arguments)
        let parsingContext = context ?? OracleParsingContext(functionName: function.rawValue)
        return try BlendParser().parseU32Response(response, context: parsingContext)
    }
    
    /// Simulate and parse Asset response
    public func simulateAndParseAsset(
        _ function: OracleContractFunction,
        arguments: [SCValXDR] = []
    ) async throws -> OracleAsset {
        let response = try await simulateContractFunction(function, arguments: arguments)
        return try BlendParser().parseAssetResponse(response)
    }
}

// MARK: - Error Extensions

extension OracleError {
    /// Create network error
    static func networkError(_ message: String) -> OracleError {
        return .contractError(code: -1, message: "Network error: \(message)")
    }
    
    /// Create simulation failed error
    static func simulationFailed(_ message: String) -> OracleError {
        return .contractError(code: -2, message: "Simulation failed: \(message)")
    }
    
    /// Create invalid function error
    static func invalidFunction(_ functionName: String) -> OracleError {
        return .contractError(code: -3, message: "Invalid function: \(functionName)")
    }
    
    /// Create invalid parameter count error
    static func invalidParameterCount(function: String, expected: Int, actual: Int) -> OracleError {
        return .contractError(
            code: -4,
            message: "Invalid parameter count for \(function): expected \(expected), got \(actual)"
        )
    }
}
