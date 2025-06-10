//
//  SorobanTransactionSimulator.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//


import stellarsdk
import Foundation
import CryptoKit

// MARK: - Transaction Builder

/**
 * Responsible for building Stellar transactions for contract invocation.
 * Handles the creation of operations and transaction setup for simulation purposes.
 */
class SorobanTransactionBuilder {
    
    // Default dummy seed for simulation transactions
    private static let defaultSimulationSeed = "SCIBQNAV4M3ED6WA7DPUBHBG3NCWNXFRQMWZFPZE5EPD5MENMN2FXF5V"
    
    private let simulationSeed: String
    private let logger = BlendLogger.oracle
    
    /**
     * Initializes the transaction builder with an optional custom simulation seed.
     * - Parameter simulationSeed: The secret seed to use for simulation transactions
     */
    init(simulationSeed: String = defaultSimulationSeed) {
        self.simulationSeed = simulationSeed
    }
    
    /**
     * Builds a transaction for contract invocation simulation.
     * - Parameter contractCall: The contract call parameters
     * - Returns: A configured Transaction ready for simulation
     * - Throws: OracleError if transaction building fails
     */
    func buildSimulationTransaction(for contractCall: ContractCallParams) throws -> Transaction {
        do {
            // Create the contract invocation operation
            let operation = try createInvokeOperation(from: contractCall)
            
            // Create source account for simulation
            let sourceAccount = try createSimulationAccount()
            
            // Build the complete transaction
            let transaction = try Transaction(
                sourceAccount: sourceAccount,
                operations: [operation],
                memo: Memo.none
            )
            
            return transaction
            
        } catch {
            throw OracleError.transactionBuildError(underlying: error)
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Creates an InvokeHostFunctionOperation from contract call parameters.
     */
    private func createInvokeOperation(from contractCall: ContractCallParams) throws -> InvokeHostFunctionOperation {
        return try InvokeHostFunctionOperation.forInvokingContract(
            contractId: contractCall.contractId,
            functionName: contractCall.functionName,
            functionArguments: contractCall.functionArguments
        )
    }
    
    /**
     * Creates a dummy source account for simulation purposes.
     */
    private func createSimulationAccount() throws -> Account {
        let sourceKeyPair = try KeyPair(secretSeed: simulationSeed)
        return Account(keyPair: sourceKeyPair, sequenceNumber: 0)
    }
}

// MARK: - Response Converter

/**
 * Converts between different simulation response formats.
 * Handles the mapping from Stellar SDK responses to Blend-specific response types.
 */
class SimulationResponseConverter {
    
    private let logger = BlendLogger.oracle
    
    /**
     * Converts a Stellar SDK simulation response to a Blend simulation response.
     * - Parameter sdkResponse: The response from Stellar SDK
     * - Returns: A SimulateTransactionResponse
     */
    func convertToBlendResponse(_ sdkResponse: stellarsdk.SimulateTransactionResponse) -> SimulateTransactionResponse {
        BlendLogger.debug("🔄 Converting SDK response to Blend format", category: logger)
        
        // Extract XDR strings from results
        let xdrStrings = extractXDRStrings(from: sdkResponse) ?? []
        
        // Extract cost information
        let cost = extractCostInformation(from: sdkResponse) ?? 
            TransactionCost(cpuInstructions: 0, memoryBytes: 0, resourceFee: 0)
        
        // Extract footprint data
        let footprint = extractFootprintData(from: sdkResponse) ?? 
            TransactionFootprint(readOnly: [], readWrite: [])
        
        // Convert SDK results to our SimulateTransactionResult type
        let results = sdkResponse.results?.compactMap { result in
            return SimulateTransactionResult(xdr: result.xdr)
        }
        
        return SimulateTransactionResponse(
            xdrStrings: xdrStrings,
            cost: cost,
            footprint: footprint,
            results: results,
            error: sdkResponse.error
        )
    }
    
    // MARK: - Private Extraction Methods
    
    /**
     * Extracts XDR strings from SDK simulation results.
     */
    private func extractXDRStrings(from response: stellarsdk.SimulateTransactionResponse) -> [String]? {
        return response.results?.compactMap { result in
            return result.xdr
        }
    }
    
    /**
     * Extracts cost information from the SDK response.
     */
    private func extractCostInformation(from response: stellarsdk.SimulateTransactionResponse) -> TransactionCost? {
        guard let minResourceFee = response.minResourceFee else { return nil }
        
        // Extract CPU instructions and read/write bytes if available
        let cpuInstructions: UInt64 = UInt64(response.transactionData?.resources.instructions ?? 0)
        let memoryBytes: UInt64 = UInt64(response.transactionData?.resources.readBytes ?? 0) + UInt64(response.transactionData?.resources.writeBytes ?? 0)
        
        return TransactionCost(
            cpuInstructions: cpuInstructions, 
            memoryBytes: memoryBytes, 
            resourceFee: UInt32(minResourceFee)
        )
    }
    
    /**
     * Extracts footprint data from the SDK response.
     */
    private func extractFootprintData(from response: stellarsdk.SimulateTransactionResponse) -> TransactionFootprint? {
        guard let footprint = response.footprint else { 
            BlendLogger.debug("🔄 No footprint available in response", category: logger)
            return nil 
        }
        
        // For now, return empty footprint arrays since the SDK structure is unclear
        // TODO: Investigate the actual structure of stellarsdk.SimulateTransactionResponse.footprint
        BlendLogger.debug("🔄 Footprint extraction temporarily disabled - SDK structure investigation needed", category: logger)
        
        return TransactionFootprint(readOnly: [], readWrite: [])
    }
}

// MARK: - Transaction Parser

/**
 * Handles parsing of transaction simulation results and XDR data.
 * Responsible for extracting meaningful data from simulation responses.
 */
class SorobanTransactionParser {
    
    private let logger = BlendLogger.oracle
    
    /**
     * Parses a simulation response to extract the contract call result.
     * - Parameters:
     *   - response: The simulation response to parse
     *   - contractCall: The original contract call parameters for context
     * - Returns: The parsed SCValXDR result
     * - Throws: OracleError if parsing fails
     */
    func parseSimulationResult(
        from response: SimulateTransactionResponse,
        contractCall: ContractCallParams
    ) throws -> SCValXDR {
        BlendLogger.debug("📋 Parsing simulation result for \(contractCall.functionName)", category: logger)
        
        // Validate response for errors
        try validateResponseForErrors(response)
        
        // Extract and validate results
        let results = try extractAndValidateResults(from: response)
        
        // Parse the XDR data
        return try parseXDRResult(from: results.first!, contractCall: contractCall)
    }
    
    /**
     * Parses an XDR string into an SCValXDR object.
     * - Parameter xdrString: The XDR string to parse
     * - Returns: The parsed SCValXDR
     * - Throws: OracleError if XDR parsing fails
     */
    func parseXDRString(_ xdrString: String) throws -> SCValXDR {
        BlendLogger.debug("📋 Parsing XDR string", category: logger)
        do {
            let scVal = try SCValXDR(xdr: xdrString)
            BlendLogger.debug("📋 Successfully parsed XDR", category: logger)
            return scVal
        } catch {
            BlendLogger.error("📋 XDR parsing failed", error: error, category: logger)
            throw OracleError.invalidResponse(
                details: "Failed to parse XDR string: \(error.localizedDescription)",
                rawData: xdrString
            )
        }
    }
    
    // MARK: - Private Validation Methods
    
    /**
     * Validates the simulation response for any errors.
     */
    private func validateResponseForErrors(_ response: SimulateTransactionResponse) throws {
        if let error = response.error, !error.isEmpty {
            BlendLogger.error("📋 Simulation response contains error: \(error)", category: logger)
            throw OracleError.contractError(code: 1, message: error)
        }
    }
    
    /**
     * Extracts and validates results from the simulation response.
     */
    private func extractAndValidateResults(from response: SimulateTransactionResponse) throws -> [String] {
        guard let results = response.results, !results.isEmpty else {
            BlendLogger.error("📋 No results found in simulation response", category: logger)
            throw OracleError.invalidResponse(
                details: "No results in simulation response",
                rawData: String(describing: response)
            )
        }
        // Map each SimulateTransactionResult to its `xdr` string, ignoring nils
        let xdrResults = results.compactMap { $0.xdr }
        if xdrResults.isEmpty {
            BlendLogger.error("📋 No valid XDR results found in simulation response", category: logger)
            throw OracleError.invalidResponse(
                details: "No valid XDR results in simulation response",
                rawData: String(describing: results)
            )
        }
        return xdrResults
    }
    
    /**
     * Parses the XDR result with additional context for error reporting.
     */
    private func parseXDRResult(from xdrString: String, contractCall: ContractCallParams) throws -> SCValXDR {
        do {
            return try parseXDRString(xdrString)
        } catch {
            let context = "Contract: \(contractCall.contractId), Function: \(contractCall.functionName)"
            BlendLogger.error("📋 Failed to parse result for \(context)", error: error, category: logger)
            throw error // Re-throw the already formatted error from parseXDRString
        }
    }
}

// MARK: - Main Simulator Class

/**
 * Main class for simulating Soroban contract transactions.
 * Orchestrates transaction building, simulation execution, and result parsing.
 */
@objc class SorobanTransactionSimulator: NSObject {
    
    private let logger = BlendLogger.oracle
    private let debugLogger: DebugLogger
    
    // Injected dependencies for better testability
    private let transactionBuilder: SorobanTransactionBuilder
    private let responseConverter: SimulationResponseConverter
    private let transactionParser: SorobanTransactionParser
    
    /**
     * Initializes the simulator with required dependencies.
     * - Parameters:
     *   - debugLogger: Logger for debug information
     *   - transactionBuilder: Builder for creating transactions (optional, uses default if nil)
     *   - responseConverter: Converter for response formats (optional, uses default if nil)
     *   - transactionParser: Parser for transaction results (optional, uses default if nil)
     */
    init(
        debugLogger: DebugLogger,
        transactionBuilder: SorobanTransactionBuilder? = nil,
        responseConverter: SimulationResponseConverter? = nil,
        transactionParser: SorobanTransactionParser? = nil
    ) {
        self.debugLogger = debugLogger
        self.transactionBuilder = transactionBuilder ?? SorobanTransactionBuilder()
        self.responseConverter = responseConverter ?? SimulationResponseConverter()
        self.transactionParser = transactionParser ?? SorobanTransactionParser()
        super.init()
    }
    
    /**
     * Simulates a contract call and returns the result.
     * - Parameters:
     *   - server: The Soroban server to use for simulation
     *   - contractCall: The contract call parameters
     * - Returns: The parsed result as SCValXDR
     * - Throws: OracleError for various failure scenarios
     */
    func simulate(server: SorobanServer, contractCall: ContractCallParams) async throws -> SCValXDR {
        BlendLogger.info("🔮 Starting simulation for: \(contractCall.functionName)", category: logger)
        
        do {
            // Step 1: Build the transaction
            let transaction = try buildTransactionForSimulation(contractCall: contractCall)
            
            // Step 2: Execute the simulation
            let response = try await executeSimulationRequest(server: server, transaction: transaction)
            
            
            // Step 3: Parse and return the result
            let result = try parseSimulationResponse(response, contractCall: contractCall)
            
            BlendLogger.info("🔮 Simulation completed successfully", category: logger)
            return result
            
        } catch let error as OracleError {
            // Re-throw already formatted Oracle errors
            BlendLogger.error("🔮 Simulation failed with Oracle error", error: error, category: logger)
            throw error
        } catch {
            // Wrap unexpected errors with context
            let context = "Contract: \(contractCall.contractId), Function: \(contractCall.functionName)"
            BlendLogger.error("🔮 Simulation failed with unexpected error", error: error, category: logger)
            throw OracleError.networkError(error, context: context)
        }
    }
    
    // MARK: - Private Orchestration Methods
    
    /**
     * Builds a transaction for simulation using the injected builder.
     */
    private func buildTransactionForSimulation(contractCall: ContractCallParams) throws -> Transaction {
        BlendLogger.debug("🔮 Building simulation transaction", category: logger)
        return try transactionBuilder.buildSimulationTransaction(for: contractCall)
    }
    
    /**
     * Executes the simulation request against the Soroban server.
     */
    private func executeSimulationRequest(
        server: SorobanServer,
        transaction: Transaction
    ) async throws -> SimulateTransactionResponse {
        BlendLogger.debug("🔮 Executing simulation request", category: logger)
        
        let simulateRequest = stellarsdk.SimulateTransactionRequest(transaction: transaction)
        let stellarResponse =  await server.simulateTransaction(simulateTxRequest: simulateRequest)
        
        switch stellarResponse {
        case .success(let sdkResponse):
            BlendLogger.debug("🔮 Simulation request successful", category: logger)
            return responseConverter.convertToBlendResponse(sdkResponse)
            
        case .failure(let error):
            BlendLogger.error("🔮 Simulation request failed", error: error, category: logger)
            throw OracleError.contractError(code: 1, message: "Simulation failed: \(error.localizedDescription)")
        }
    }
    
    /**
     * Parses the simulation response using the injected parser.
     */
    private func parseSimulationResponse(
        _ response: SimulateTransactionResponse,
        contractCall: ContractCallParams
    ) throws -> SCValXDR {
        BlendLogger.debug("🔮 Parsing simulation response", category: logger)
        return try transactionParser.parseSimulationResult(from: response, contractCall: contractCall)
    }
}

// MARK: - Enhanced Error Types

extension OracleError {
    /**
     * Error for transaction building failures.
     */
    static func transactionBuildError(underlying: Error) -> OracleError {
        return .networkError(underlying, context: "Failed to build simulation transaction")
    }
}

