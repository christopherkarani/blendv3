//
//  SorobanTransactionSimulator.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//


import stellarsdk
import Foundation
import CryptoKit

// MARK: - Transaction Status Support

/// Represents simulation transaction status with detailed information
public struct SimulationTransactionStatus {
    let statusCode: String
    let isSuccess: Bool
    let errorDetails: String?
    let costInfo: TransactionCost?
    
    init(statusCode: String, isSuccess: Bool, errorDetails: String? = nil, costInfo: TransactionCost? = nil) {
        self.statusCode = statusCode
        self.isSuccess = isSuccess
        self.errorDetails = errorDetails
        self.costInfo = costInfo
    }
    
    /// Create status from simulation response
    static func from(response: stellarsdk.SimulateTransactionResponse) -> SimulationTransactionStatus {
        let isSuccess = response.error == nil
        let statusCode = isSuccess ? "SUCCESS" : "FAILED"
        
        let costInfo: TransactionCost?
        if let minResourceFee = response.minResourceFee {
            let cpuInstructions = UInt64(response.transactionData?.resources.instructions ?? 0)
            let memoryBytes = UInt64(response.transactionData?.resources.readBytes ?? 0) + UInt64(response.transactionData?.resources.writeBytes ?? 0)
            costInfo = TransactionCost(cpuInstructions: cpuInstructions, memoryBytes: memoryBytes, resourceFee: UInt32(minResourceFee))
        } else {
            costInfo = nil
        }
        
        return SimulationTransactionStatus(
            statusCode: statusCode,
            isSuccess: isSuccess,
            errorDetails: response.error,
            costInfo: costInfo
        )
    }
}

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
            return nil 
        }
        
        // For now, return empty footprint arrays since the SDK structure is unclear
        // TODO: Investigate the actual structure of stellarsdk.SimulateTransactionResponse.footprint
        
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
        // Validate response for errors
        try validateResponseForErrors(response)
        
        // Extract and validate results
        let results = try extractAndValidateResults(from: response)
        
        // Parse the XDR data
        return try parseXDRResult(from: results.first!, contractCall: contractCall)
    }
    
    /**
     * Parses an XDR string into an SCValXDR object with improved error handling.
     * - Parameter xdrString: The XDR string to parse
     * - Returns: The parsed SCValXDR
     * - Throws: OracleError if XDR parsing fails
     */
    func parseXDRString(_ xdrString: String) throws -> SCValXDR {
        do {
            // Use enhanced XDR parsing with better error handling
            let scVal = try SCValXDR(xdr: xdrString)
            
            // Log success only for critical debugging
            if !scVal.isSuccessResult {
                BlendLogger.warning("📋 Parsed XDR contains error result: \(scVal.debugDescription)", category: logger)
            }
            
            return scVal
        } catch let error as SCValXDRError {
            // Handle our enhanced XDR errors with detailed context
            BlendLogger.error("📋 Enhanced XDR parsing failed: \(error.localizedDescription)", category: logger)
            throw OracleError.invalidResponse(
                details: "XDR parsing failed: \(error.localizedDescription)",
                rawData: xdrString
            )
        } catch {
            // Handle other parsing errors
            BlendLogger.error("📋 XDR parsing failed for string: \(xdrString.prefix(50))...", error: error, category: logger)
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
     * Simulates a contract call and returns the result with transaction status.
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
            let (response, status) = try await executeSimulationRequestWithStatus(server: server, transaction: transaction)
            
            // Step 3: Display transaction status
            displayTransactionStatus(status, contractCall: contractCall)
            
            // Step 4: Parse and return the result
            let result = try parseSimulationResponse(response, contractCall: contractCall)
            
            BlendLogger.info("🔮 Simulation completed successfully with status: \(status.statusCode)", category: logger)
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
    
    /**
     * Simulates a contract call using OracleContractCallBuilder and returns the result.
     * - Parameters:
     *   - server: The Soroban server to use for simulation
     *   - contractCallBuilder: The contract call builder
     * - Returns: The parsed result as SCValXDR
     * - Throws: OracleError for various failure scenarios
     */
    func simulate(server: SorobanServer, contractCallBuilder: OracleContractCallBuilder) async throws -> SCValXDR {
        do {
            // Convert builder to ContractCallParams
            let contractCall = try contractCallBuilder.build()
            
            // Use the existing simulate method with ContractCallParams
            return try await simulate(server: server, contractCall: contractCall)
        } catch {
            throw OracleError.networkError(error, context: "Failed to build contract call from builder")
        }
    }
    
    // MARK: - Private Orchestration Methods
    
    /**
     * Builds a transaction for simulation using the injected builder.
     */
    private func buildTransactionForSimulation(contractCall: ContractCallParams) throws -> Transaction {
        return try transactionBuilder.buildSimulationTransaction(for: contractCall)
    }
    
    /**
     * Executes the simulation request against the Soroban server and returns both response and status.
     */
    private func executeSimulationRequestWithStatus(
        server: SorobanServer,
        transaction: Transaction
    ) async throws -> (SimulateTransactionResponse, SimulationTransactionStatus) {
        let simulateRequest = stellarsdk.SimulateTransactionRequest(transaction: transaction)
        let stellarResponse = await server.simulateTransaction(simulateTxRequest: simulateRequest)
        
        switch stellarResponse {
        case .success(let sdkResponse):
            let status = SimulationTransactionStatus.from(response: sdkResponse)
            let response = responseConverter.convertToBlendResponse(sdkResponse)
            return (response, status)
            
        case .failure(let error):
            BlendLogger.error("🔮 Simulation request failed", error: error, category: logger)
            throw OracleError.contractError(code: 1, message: "Simulation failed: \(error.localizedDescription)")
        }
    }
    
    /**
     * Displays the transaction status information.
     */
    private func displayTransactionStatus(_ status: SimulationTransactionStatus, contractCall: ContractCallParams) {
        BlendLogger.info("📊 Transaction Status: \(status.statusCode) for \(contractCall.functionName)", category: logger)
        
        if let costInfo = status.costInfo {
            BlendLogger.info("💰 Cost - CPU: \(costInfo.cpuInstructions), Memory: \(costInfo.memoryBytes), Fee: \(costInfo.resourceFee)", category: logger)
        }
        
        if let errorDetails = status.errorDetails {
            BlendLogger.error("❌ Error Details: \(errorDetails)", category: logger)
        }
    }
    
    /**
     * Parses the simulation response using the injected parser.
     */
    private func parseSimulationResponse(
        _ response: SimulateTransactionResponse,
        contractCall: ContractCallParams
    ) throws -> SCValXDR {
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

