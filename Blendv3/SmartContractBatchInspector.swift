import Foundation
import SwiftUI
import stellarsdk

/// Batch inspector for analyzing multiple smart contracts at once
/// Specifically designed for Blend protocol contracts
class SmartContractBatchInspector {
    
    // MARK: - Contract Definitions
    
    /// All Blend-related contracts to inspect
    struct BlendContracts {
        // Main contracts from your app
        static let contracts: [(name: String, id: String, description: String)] = [
            // Pool Contract
            (
                name: "Blend Pool",
                id: "CAMKTT6LIXNOKZJVFI64EBEQE25UYAQZBTHDIQ4LEDJLTCM6YVME6IIY",
                description: "Main Blend lending pool contract"
            ),
            
            // Asset Contracts
            (
                name: "USDC Asset",
                id: "CAQCFVLOBK5GIULPNZRGATJJMIZL5BSP7X5YJVMGCPTUEPFM4AVSRCJU",
                description: "USDC token contract on testnet"
            ),
            
            // Additional Blend contracts (if known)
            (
                name: "XLM Asset",
                id: "CAS3J7GYLGXMF6TDJBBYYSE3HQ6BBSMLNUQ34T6TZMYMW2EVH34XOWMA",
                description: "Wrapped XLM contract"
            ),
            
            // You can add more contracts here as you discover them
        ]
        
        // Oracle contracts (if applicable)
        static let oracleContracts: [(name: String, id: String, description: String)] = [
            // Add oracle contracts when available
        ]
        
        // Get all contracts
        static var allContracts: [(name: String, id: String, description: String)] {
            return contracts + oracleContracts
        }
    }
    
    // MARK: - Batch Inspection Results
    
    struct BatchInspectionResult {
        let contractName: String
        let contractId: String
        let description: String
        let inspectionResult: ContractInspectionResult?
        let error: String?
        let inspectionTime: TimeInterval
        let wasmSize: Int?
    }
    
    // MARK: - Batch Inspection
    
    /// Inspects all Blend contracts and returns results
    static func inspectAllBlendContracts() async -> [BatchInspectionResult] {
        var results: [BatchInspectionResult] = []
        
        // Create inspector
        let inspector = SmartContractInspector(
            rpcEndpoint: "https://soroban-testnet.stellar.org",
            network: Network.testnet
        )
        
        // Log batch inspection start
        infoLog("Starting batch contract inspection", category: .contract, metadata: [
            "totalContracts": BlendContracts.allContracts.count,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Inspect each contract
        for contract in BlendContracts.allContracts {
            let startTime = Date()
            
            debugLog("Inspecting contract: \(contract.name)", category: .contract, metadata: [
                "contractId": contract.id,
                "description": contract.description
            ])
            
            do {
                // Inspect the contract
                let result = try await inspector.inspectContract(contractId: contract.id)
                
                // Try to get WASM size
                var wasmSize: Int? = nil
                do {
                    let wasmData = try await inspector.getContractWasmBinary(contractId: contract.id)
                    wasmSize = wasmData.count
                } catch {
                    // WASM retrieval might fail for some contracts
                    debugLog("Could not retrieve WASM for \(contract.name)", category: .wasm)
                }
                
                let inspectionTime = Date().timeIntervalSince(startTime)
                
                let batchResult = BatchInspectionResult(
                    contractName: contract.name,
                    contractId: contract.id,
                    description: contract.description,
                    inspectionResult: result,
                    error: nil,
                    inspectionTime: inspectionTime,
                    wasmSize: wasmSize
                )
                
                results.append(batchResult)
                
                infoLog("Successfully inspected \(contract.name)", category: .contract, metadata: [
                    "functionsCount": result.functions.count,
                    "customTypesCount": result.customTypes.structs.count + result.customTypes.enums.count,
                    "inspectionTime": String(format: "%.3f", inspectionTime),
                    "wasmSize": wasmSize ?? 0
                ])
                
            } catch {
                let inspectionTime = Date().timeIntervalSince(startTime)
                
                let batchResult = BatchInspectionResult(
                    contractName: contract.name,
                    contractId: contract.id,
                    description: contract.description,
                    inspectionResult: nil,
                    error: error.localizedDescription,
                    inspectionTime: inspectionTime,
                    wasmSize: nil
                )
                
                results.append(batchResult)
                
                errorLog("Failed to inspect \(contract.name)", category: .contract, metadata: [
                    "contractId": contract.id,
                    "error": error.localizedDescription,
                    "inspectionTime": String(format: "%.3f", inspectionTime)
                ])
            }
            
            // Small delay between inspections to avoid rate limiting
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Log batch inspection summary
        let successCount = results.filter { $0.error == nil }.count
        let failureCount = results.filter { $0.error != nil }.count
        let totalTime = results.reduce(0) { $0 + $1.inspectionTime }
        
        infoLog("Batch inspection completed", category: .contract, metadata: [
            "totalContracts": results.count,
            "successCount": successCount,
            "failureCount": failureCount,
            "totalTime": String(format: "%.3f", totalTime)
        ])
        
        return results
    }
    
    // MARK: - Formatted Output
    
    /// Generates a formatted report of all contract inspections
    static func generateBatchReport(_ results: [BatchInspectionResult]) -> String {
        var report = """
        🔍 BLEND CONTRACTS INSPECTION REPORT
        ═══════════════════════════════════════
        Generated: \(Date())
        Total Contracts: \(results.count)
        
        """
        
        for result in results {
            report += """
            
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            📋 \(result.contractName)
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            Contract ID: \(result.contractId)
            Description: \(result.description)
            Inspection Time: \(String(format: "%.3f", result.inspectionTime))s
            
            """
            
            if let inspection = result.inspectionResult {
                report += """
                ✅ Status: Successfully Inspected
                
                📊 Overview:
                • Interface Version: \(inspection.interfaceVersion)
                • Functions: \(inspection.functions.count)
                • Custom Types: \(inspection.customTypes.structs.count) structs, \(inspection.customTypes.enums.count) enums
                
                """
                
                if let wasmSize = result.wasmSize {
                    report += """
                    • WASM Size: \(ByteCountFormatter().string(fromByteCount: Int64(wasmSize)))
                    
                    """
                }
                
                if !inspection.functions.isEmpty {
                    report += "🔧 Functions:\n"
                    for function in inspection.functions {
                        report += "  • \(function.name)"
                        if !function.inputs.isEmpty {
                            report += "(\(function.inputs.map { $0.name }.joined(separator: ", ")))"
                        }
                        if !function.outputs.isEmpty {
                            report += " → \(function.outputs.joined(separator: ", "))"
                        }
                        report += "\n"
                    }
                }
                
            } else if let error = result.error {
                report += """
                ❌ Status: Inspection Failed
                Error: \(error)
                
                """
            }
        }
        
        report += """
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        📈 SUMMARY
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        • Total Contracts: \(results.count)
        • Successful: \(results.filter { $0.error == nil }.count)
        • Failed: \(results.filter { $0.error != nil }.count)
        • Total Inspection Time: \(String(format: "%.3f", results.reduce(0) { $0 + $1.inspectionTime }))s
        
        ═══════════════════════════════════════
        """
        
        return report
    }
}

// MARK: - SwiftUI View Extension

extension SmartContractDebugViewModel {
    
    /// Inspects all Blend contracts and updates the view
    func inspectAllBlendContracts() async {
        isLoading = true
        errorMessage = nil
        
        debugLog("Starting batch inspection of all Blend contracts", category: .contract)
        
        let results = await SmartContractBatchInspector.inspectAllBlendContracts()
        
        // Generate and log the report
        let report = SmartContractBatchInspector.generateBatchReport(results)
        
        // Log the full report
        infoLog("Batch Inspection Report Generated", category: .contract, metadata: [
            "report": report
        ])
        
        // Also print to console for easy viewing
        print(report)
        
        // Update UI with first successful result (if any)
        if let firstSuccess = results.first(where: { $0.inspectionResult != nil }) {
            lastResult = firstSuccess.inspectionResult
            
            // Analyze WASM if available
            if let wasmSize = firstSuccess.wasmSize {
                wasmInfo = WasmInfo(
                    size: wasmSize,
                    sizeFormatted: ByteCountFormatter().string(fromByteCount: Int64(wasmSize)),
                    isValid: true,
                    version: 1,
                    magicNumber: "00 61 73 6d"
                )
            }
        }
        
        // Store results for display
        if results.allSatisfy({ $0.error != nil }) {
            errorMessage = "All contract inspections failed. Check the logs for details."
        } else {
            // Create a summary message
            let successCount = results.filter { $0.error == nil }.count
            errorMessage = nil
            infoLog("Batch inspection completed: \(successCount)/\(results.count) contracts inspected successfully", category: .ui)
        }
        
        isLoading = false
        refreshLogEntries()
    }
}

// MARK: - Quick Access Function

/// Convenience function to run batch inspection
func inspectAllBlendContracts() async {
    let results = await SmartContractBatchInspector.inspectAllBlendContracts()
    let report = SmartContractBatchInspector.generateBatchReport(results)
    print(report)
} 