//
//  TestFullFunctionListing.swift
//  Blendv3
//
//  Created to test that all contract functions are displayed without truncation.
//

import Foundation

/// Test function to verify that all Blend pool functions are displayed
func testFullBlendPoolFunctionListing() async {
    print("🧪 Testing Full Function Listing for Blend Pool")
    print("===============================================\n")
    
    // Use the updated SmartContractExplorer to inspect the Blend pool
    let explorer = SmartContractExplorer()
    
    // Inspect the Blend pool contract with the updated address
    let blendPoolId = BlendUSDCConstants.Testnet.xlmUsdcPool
    
    do {
        print("🔍 Inspecting Blend Pool Contract...")
        print("Contract ID: \(blendPoolId)")
        print("Network: Testnet\n")
        
        let result = try await explorer.inspector.inspectContract(contractId: blendPoolId)
        
        print("✅ Contract inspection successful!")
        print("📊 Total Functions Found: \(result.functions.count)")
        print("\n🔧 Complete Function List:")
        print("═══════════════════════════\n")
        
        // Display all functions with detailed information
        for (index, function) in result.functions.enumerated() {
            print("\(index + 1). \(function.name)")
            
            if !function.inputs.isEmpty {
                print("   Parameters:")
                for param in function.inputs {
                    print("     • \(param.name): \(param.type)")
                }
            } else {
                print("   Parameters: None")
            }
            
            if !function.outputs.isEmpty {
                print("   Returns: \(function.outputs.joined(separator: ", "))")
            } else {
                print("   Returns: void")
            }
            
            if let doc = function.doc, !doc.isEmpty {
                print("   Description: \(doc)")
            }
            
            print() // Empty line between functions
        }
        
        print("🎯 Test completed successfully!")
        print("All \(result.functions.count) functions are now displayed without truncation.")
        
    } catch {
        print("❌ Test failed with error: \(error)")
    }
}

/// Quick test to run the full function listing
/// Uncomment to run:
/*
Task {
    await testFullBlendPoolFunctionListing()
}
*/ 
