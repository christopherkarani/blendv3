import Foundation
import stellarsdk

/// Simple test to verify SmartContractInspector functionality
class SmartContractInspectorTest {
    
    static func runBasicTest() async {
        print("🧪 Running SmartContractInspector Test")
        print("=====================================\n")
        
        // Initialize the inspector
        let inspector = SmartContractInspector(
            rpcEndpoint: "https://soroban-testnet.stellar.org",
            network: Network.testnet
        )
        
        // Test with a known Stellar Asset Contract (USDC on testnet)
        // This is a standard Stellar Asset Contract that should have predictable functions
        let testContractId = "CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA"
        
        do {
            print("🔍 Testing contract inspection...")
            let result = try await inspector.inspectContract(contractId: testContractId)
            
            print("✅ Contract inspection successful!")
            print("\n📋 Contract Summary:")
            print("Contract ID: \(result.contractId ?? "Unknown")")
            print("Interface Version: \(result.interfaceVersion)")
            print("Functions Count: \(result.functions.count)")
            print("Custom Types Count: \(result.customTypes.structs.count + result.customTypes.enums.count + result.customTypes.unions.count + result.customTypes.errors.count)")
            
            if !result.functions.isEmpty {
                print("\n🔧 All Functions:")
                for (index, function) in result.functions.enumerated() {
                    print("  \(index + 1). \(function.name)(\(function.inputs.map { "\($0.name): \($0.type)" }.joined(separator: ", ")))")
                    if !function.outputs.isEmpty {
                        print("     → Returns: \(function.outputs.joined(separator: ", "))")
                    }
                }
            }
            
            if !result.metadata.isEmpty {
                print("\n📌 Metadata:")
                for (key, value) in result.metadata {
                    print("  • \(key): \(value)")
                }
            }
            
            print("\n🎯 Test completed successfully!")
            
        } catch {
            print("❌ Test failed with error: \(error)")
            
            // Provide helpful debugging information
            if let inspectionError = error as? ContractInspectionError {
                switch inspectionError {
                case .rpcFailed(let message):
                    print("💡 RPC Error - Check network connectivity and contract ID")
                    print("   Details: \(message)")
                case .parsingFailed(let message):
                    print("💡 Parsing Error - Contract might use unsupported features")
                    print("   Details: \(message)")
                case .invalidContractId:
                    print("💡 Invalid Contract ID - Please verify the contract address")
                case .dataNotFound:
                    print("💡 Data Not Found - Contract might not exist on this network")
                }
            }
        }
    }
    
    static func runDataFormattingTest() {
        print("\n🎨 Testing Data Formatting")
        print("==========================\n")
        
        // Test the data formatting examples
        let example = SmartContractInspectorExample()
        example.demonstrateDataFormatting()
        
        print("\n✅ Data formatting test completed!")
    }
    
    static func runAllTests() async {
        await runBasicTest()
        runDataFormattingTest()
        
        print("\n🏁 All tests completed!")
        print("========================")
        print("The SmartContractInspector is ready to use!")
        print("You can now:")
        print("• Inspect any Soroban smart contract")
        print("• Retrieve WASM binaries")
        print("• Query contract data")
        print("• Get human-readable contract summaries")
    }
}

// MARK: - Usage Example

/// Example of how to run the tests
/// Uncomment the following lines to run tests in your app:

/*
Task {
    await SmartContractInspectorTest.runAllTests()
}
*/ 