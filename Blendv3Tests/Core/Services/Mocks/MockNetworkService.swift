import Foundation
import stellarsdk
@testable import Blendv3

/// Comprehensive mock implementation of NetworkServiceProtocol for testing
/// Provides configurable responses, error simulation, and call tracking
@MainActor
final class MockNetworkService: NetworkServiceProtocol {
    
    // MARK: - Properties for Response Configuration
    
    /// Storage for responses keyed by asset ID or function parameters
    private var responseMap: [String: SCValXDR] = [:]
    
    /// Flag to control simulation failures
    var shouldFailSimulation: Bool = false
    var alwaysFail: Bool = false
    var failureCount: Int = 0
    private var currentFailureCount: Int = 0
    
    /// Error to throw when simulation fails
    var simulationError: Error = OracleError.networkError(NSError(domain: "MockError", code: 1))
    
    // MARK: - Call Tracking Properties
    
    var simulationCallCount: Int = 0
    var invocationCallCount: Int = 0
    var lastContractCall: ContractCallParams?
    var allContractCalls: [ContractCallParams] = []
    
    // MARK: - Configuration Properties
    
    var networkDelay: TimeInterval = 0.0 // Simulate network latency
    var shouldTrackCalls: Bool = true
    
    // MARK: - NetworkServiceProtocol Implementation
    
    func initialize() async throws {
        // Mock initialization - no-op
    }
    
    func checkConnectivity() async -> ConnectionState {
        return .connected
    }
    
    func addRequestInterceptor(_ interceptor: @escaping (URLRequest) -> URLRequest) {
        // Mock implementation - store interceptor if needed
    }
    
    func addResponseInterceptor(_ interceptor: @escaping (Data, URLResponse) -> Void) {
        // Mock implementation - store interceptor if needed
    }
    
    func getLedgerEntries(keys: [String]) async throws -> [String: Any] {
        // Mock implementation
        return [:]
    }
    
    func getAccount(accountId: String) async throws -> Account {
        // Mock implementation - create a basic account
        let keyPair = try KeyPair.generateRandomKeyPair()
        return Account(keyPair: keyPair, sequenceNumber: 1)
    }
    
    func simulateContractFunction<Args: Sendable, Result: Decodable>(
        contractId: String,
        functionName: String,
        args: Args
    ) async -> SimulationStatus<Result> {
        // This generic version is not directly used by BlendOracleService
        // Return a failure for now
        return .failure(OracleError.contractError(code: -1, message: "Generic simulation not implemented"))
    }
    
    func simulateContractFunction<Result: Decodable>(
        contractCall: ContractCallParams
    ) async -> SimulationStatus<Result> {
        await simulateDelay()
        
        if shouldTrackCalls {
            simulationCallCount += 1
            lastContractCall = contractCall
            allContractCalls.append(contractCall)
        }
        
        // Handle failure scenarios
        if shouldFailSimulation {
            if alwaysFail {
                return .failure(simulationError)
            } else if currentFailureCount < failureCount {
                currentFailureCount += 1
                return .failure(simulationError)
            } else {
                // Reset for next test
                currentFailureCount = 0
            }
        }
        
        // Try to find specific response for this call
        let callKey = "\(contractCall.contractId)_\(contractCall.functionName)"
        if let specificResponse = responseMap[callKey] {
            return createSuccessResult(with: specificResponse)
        }
        
        // Try to find response by asset ID (extract from function arguments)
        if let assetId = extractAssetIdFromArguments(contractCall.functionArguments),
           let assetResponse = responseMap[assetId] {
            return createSuccessResult(with: assetResponse)
        }
        
        // Fallback error
        return .failure(OracleError.contractError(code: -1, message: "No mock response configured"))
    }
    
    func invokeContractFunction(
        contractCall: ContractCallParams,
        force: Bool
    ) async throws -> SCValXDR {
        await simulateDelay()
        
        if shouldTrackCalls {
            invocationCallCount += 1
            lastContractCall = contractCall
            allContractCalls.append(contractCall)
        }
        
        if shouldFailSimulation {
            throw simulationError
        }
        
        // Return a default response for invocation
        return SCValXDR.void()
    }
    
    // MARK: - Mock Configuration Methods
    
    /// Add a response for a specific asset ID
    func addResponse(for assetId: String, response: SCValXDR) {
        responseMap[assetId] = response
    }
    
    /// Add a response for a specific contract call
    func addResponse(for contractId: String, functionName: String, response: SCValXDR) {
        let key = "\(contractId)_\(functionName)"
        responseMap[key] = response
    }
    
    /// Configure a failure simulation result
    func setFailureResponse(_ error: Error) {
        simulationError = error
        shouldFailSimulation = true
    }
    
    /// Reset all mock state
    func reset() {
        responseMap.removeAll()
        shouldFailSimulation = false
        alwaysFail = false
        failureCount = 0
        currentFailureCount = 0
        simulationCallCount = 0
        invocationCallCount = 0
        lastContractCall = nil
        allContractCalls.removeAll()
        networkDelay = 0.0
    }
    
    // MARK: - Helper Methods
    
    private func simulateDelay() async {
        if networkDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(networkDelay * 1_000_000_000))
        }
    }
    
    private func createSuccessResult<Result: Decodable>(with response: SCValXDR) -> SimulationStatus<Result> {
        // Try to cast the response to the expected type
        if let typedResult = response as? Result {
            return .success(MockSimulationResult(result: typedResult))
        }
        
        // If direct casting fails, return the SCValXDR as is (for SCValXDR results)
        if Result.self == SCValXDR.self, let result = response as? Result {
            return .success(MockSimulationResult(result: result))
        }
        
        // If all else fails, try to create a mock result based on the type
        if let mockResult = createMockResult(for: Result.self) {
            return .success(MockSimulationResult(result: mockResult))
        }
        
        return .failure(OracleError.contractError(code: -1, message: "Unable to convert response to expected type"))
    }
    
    private func createMockResult<T>(for type: T.Type) -> T? {
        if type == SCValXDR.self {
            return SCValXDR.void() as? T
        }
        // Add more type-specific mock creation as needed
        return nil
    }
    
    /// Extract asset ID from function arguments (simplified)
    private func extractAssetIdFromArguments(_ arguments: [SCValXDR]) -> String? {
        for argument in arguments {
            if case .vec(let vectorOptional) = argument,
               let vector = vectorOptional,
               vector.count >= 2,
               case .symbol(let symbol) = vector[0],
               symbol == "Stellar",
               case .address(let address) = vector[1] {
                
                // Extract contract address from SCAddressXDR
                switch address {
                case .contract(let wrappedData):
                    let contractData = wrappedData.wrapped
                    let hexString = contractData.map { String(format: "%02x", $0) }.joined()
                    return try? StellarContractID.encode(hex: hexString)
                default:
                    continue
                }
            }
        }
        return nil
    }
}

// MARK: - Supporting Types

/// Mock simulation result structure
struct MockSimulationResult<T: Decodable>: Decodable {
    let result: T
    let cost: MockResourceCost = MockResourceCost()
    let events: [String] = []
    let auth: [String] = []
    let minResourceFee: UInt64 = 1000
    let footprint: String? = nil
}

/// Mock resource cost for simulation results
struct MockResourceCost: Codable {
    let cpuInstructions: UInt64 = 1000
    let memoryBytes: UInt64 = 2048
}

/// Connection state for network connectivity
enum ConnectionState {
    case connected
    case disconnected
    case limited
} 