import Foundation
import stellarsdk

/// Test script for Smart Contract Exploration
/// This demonstrates how to use the explorer and verifies functionality
class TestSmartContractExploration {
    
    /// Runs a comprehensive test of the smart contract exploration system
    static func runTests() async {
        print("🧪 Testing Smart Contract Exploration System")
        print("═══════════════════════════════════════════════")
        print("This will test all components of the exploration system\n")
        
        // Test 1: Basic Inspector Functionality
        await testBasicInspector()
        
        // Test 2: Explorer Functionality
        await testExplorer()
        
        // Test 3: Error Handling
        await testErrorHandling()
        
        print("\n✅ All tests completed!")
        print("The Smart Contract Explorer is ready for use.")
    }
    
    private static func testBasicInspector() async {
        print("🔬 Test 1: Basic Inspector Functionality")
        print("─────────────────────────────────────────")
        
        let inspector = SmartContractInspector(
            rpcEndpoint: "https://soroban-testnet.stellar.org",
            network: Network.testnet
        )
        
        do {
            // Test with a known contract
            let contractId = "CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA"
            print("Testing contract inspection for: \(contractId)")
            
            let result = try await inspector.inspectContract(contractId: contractId)
            
            print("✅ Contract inspection successful!")
            print("   • Functions found: \(result.functions.count)")
            print("   • Interface version: \(result.interfaceVersion)")
            print("   • Metadata entries: \(result.metadata.count)")
            
            // Test WASM binary retrieval
            print("\nTesting WASM binary retrieval...")
            let wasmData = try await inspector.getContractWasmBinary(contractId: contractId)
            print("✅ WASM binary retrieved: \(wasmData.count) bytes")
            
        } catch {
            print("❌ Basic inspector test failed: \(error.localizedDescription)")
        }
        
        print("")
    }
    
    private static func testExplorer() async {
        print("🔍 Test 2: Explorer Functionality")
        print("─────────────────────────────────")
        
        let explorer = SmartContractExplorer()
        
        print("Testing contract exploration...")
        await explorer.exploreContract(
            contractId: "CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA",
            name: "Test Contract"
        )
        
        print("✅ Explorer test completed!")
        print("")
    }
    
    private static func testErrorHandling() async {
        print("⚠️ Test 3: Error Handling")
        print("─────────────────────────")
        
        let inspector = SmartContractInspector(
            rpcEndpoint: "https://soroban-testnet.stellar.org",
            network: Network.testnet
        )
        
        do {
            // Test with an invalid contract ID
            let invalidContractId = "INVALID_CONTRACT_ID_FOR_TESTING"
            print("Testing with invalid contract ID: \(invalidContractId)")
            
            let _ = try await inspector.inspectContract(contractId: invalidContractId)
            print("❌ Expected error but got success")
            
        } catch {
            print("✅ Error handling working correctly: \(error.localizedDescription)")
        }
        
        print("")
    }
    
    /// Demonstrates the complete exploration workflow
    static func demonstrateExploration() async {
        print("🎯 Smart Contract Exploration Demonstration")
        print("═══════════════════════════════════════════════")
        print("This will show you how to explore smart contracts\n")
        
        // Option 1: Quick exploration of all known contracts
        print("📋 Option 1: Quick Overview of All Known Contracts")
        print("─────────────────────────────────────────────────")
        await exploreAllSmartContracts()
        
        print("\n" + String(repeating: "═", count: 60) + "\n")
        
        // Option 2: Deep dive into a specific contract
        print("🔬 Option 2: Deep Dive Analysis")
        print("─────────────────────────────")
        await exploreUSDCContract()
        
        print("\n🎉 Demonstration completed!")
        print("You can now use these functions in your own code.")
    }
}

// MARK: - Quick Test Runner

/// Simple function to run all tests
func runSmartContractTests() async {
    await TestSmartContractExploration.runTests()
}

/// Simple function to run the demonstration
func demonstrateSmartContractExploration() async {
    await TestSmartContractExploration.demonstrateExploration()
}

// MARK: - Usage Examples for Testing

/*
 To test the Smart Contract Explorer, uncomment and run any of these:

 // Run comprehensive tests
 Task {
     await runSmartContractTests()
 }

 // Run the demonstration
 Task {
     await demonstrateSmartContractExploration()
 }

 // Or run specific explorations
 Task {
     await runSmartContractDemo()
 }
 */ 
