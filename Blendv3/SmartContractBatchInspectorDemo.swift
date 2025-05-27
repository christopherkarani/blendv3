import Foundation
import SwiftUI

/// Demo for the Smart Contract Batch Inspector
/// Shows how to use the batch inspection feature
class SmartContractBatchInspectorDemo {
    
    /// Runs a demo of the batch inspection feature
    static func runBatchInspectionDemo() async {
        print("""
        🔍 SMART CONTRACT BATCH INSPECTOR DEMO
        ═══════════════════════════════════════
        
        This demo shows how to inspect multiple contracts at once.
        
        """)
        
        // Method 1: Using the convenience function
        print("📋 Method 1: Quick Batch Inspection")
        print("─────────────────────────────────")
        print("Simply call: await inspectAllBlendContracts()")
        print("")
        
        // Method 2: Using the debug view
        print("📱 Method 2: Using the Debug View")
        print("─────────────────────────────────")
        print("1. Open your app")
        print("2. Go to the Debug tab")
        print("3. Tap 'Inspect All Blend Contracts' button")
        print("4. Watch the results appear in the view and logs")
        print("")
        
        // Method 3: Programmatic access
        print("💻 Method 3: Programmatic Access")
        print("─────────────────────────────────")
        print("Example code:")
        print("""
        let results = await SmartContractBatchInspector.inspectAllBlendContracts()
        for result in results {
            if let inspection = result.inspectionResult {
                print("\\(result.contractName): \\(inspection.functions.count) functions")
            }
        }
        """)
        print("")
        
        // Actually run the inspection
        print("🚀 Running batch inspection now...")
        print("═══════════════════════════════════")
        
        await inspectAllBlendContracts()
    }
    
    /// Example of custom contract list inspection
    static func inspectCustomContractList() async {
        print("""
        
        🎯 CUSTOM CONTRACT LIST EXAMPLE
        ═══════════════════════════════
        
        You can also create your own contract lists:
        
        """)
        
        // Define custom contracts
        let customContracts = [
            (name: "My Contract 1", id: "CONTRACT_ID_1", description: "Description 1"),
            (name: "My Contract 2", id: "CONTRACT_ID_2", description: "Description 2")
        ]
        
        // Create inspector
        let inspector = SmartContractInspector(
            rpcEndpoint: "https://soroban-testnet.stellar.org",
            network: .testnet
        )
        
        // Inspect each contract
        for contract in customContracts {
            print("Inspecting \(contract.name)...")
            do {
                let result = try await inspector.inspectContract(contractId: contract.id)
                print("✅ \(contract.name): \(result.functions.count) functions found")
            } catch {
                print("❌ \(contract.name): \(error.localizedDescription)")
            }
        }
    }
    
    /// Shows how to add new contracts to the batch inspector
    static func showHowToAddContracts() {
        print("""
        
        📝 HOW TO ADD NEW CONTRACTS
        ═══════════════════════════
        
        To add new contracts to the batch inspector:
        
        1. Open SmartContractBatchInspector.swift
        
        2. Find the BlendContracts struct
        
        3. Add your contracts to the appropriate array:
        
        static let contracts: [(name: String, id: String, description: String)] = [
            // Existing contracts...
            
            // Add your new contract:
            (
                name: "My New Contract",
                id: "YOUR_CONTRACT_ID_HERE",
                description: "Description of what this contract does"
            ),
        ]
        
        4. Save the file and run the batch inspection again!
        
        """)
    }
}

// MARK: - Quick Access Functions

/// Run the complete batch inspection demo
func runBatchInspectionDemo() async {
    await SmartContractBatchInspectorDemo.runBatchInspectionDemo()
}

/// Show how to add new contracts
func showHowToAddContracts() {
    SmartContractBatchInspectorDemo.showHowToAddContracts()
} 
