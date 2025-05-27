import Foundation
import stellarsdk

/// Simple runner for Smart Contract Exploration
/// This file provides easy-to-use functions to explore smart contracts
class SmartContractExplorationRunner {
    
    /// Runs the complete smart contract exploration demo
    static func runCompleteExploration() async {
        print("🚀 Starting Complete Smart Contract Exploration")
        print("This will analyze all known contracts and provide detailed insights\n")
        
        await SmartContractExplorer.runDemo()
    }
    
    /// Explores only the known contracts with basic analysis
    static func runBasicExploration() async {
        let explorer = SmartContractExplorer()
        await explorer.exploreAllContracts()
    }
    
    /// Explores a specific contract with deep analysis
    static func exploreSpecificContract(contractId: String, name: String? = nil) async {
        let explorer = SmartContractExplorer()
        await explorer.exploreContract(contractId: contractId, name: name)
    }
    
    /// Interactive exploration - lets you choose what to explore
    static func runInteractiveExploration() async {
        print("🎯 Interactive Smart Contract Explorer")
        print("═══════════════════════════════════════")
        print("Choose an exploration option:")
        print("1. Explore all known contracts")
        print("2. Deep dive into USDC contract")
        print("3. Deep dive into example token contract")
        print("4. Run complete demo")
        print("\nRunning option 4 (complete demo) by default...\n")
        
        // For now, just run the complete demo
        // In a real app, you'd implement user input handling
        await runCompleteExploration()
    }
}

// MARK: - Quick Access Functions

/// Quick function to explore all contracts
func exploreAllSmartContracts() async {
    await SmartContractExplorationRunner.runBasicExploration()
}

/// Quick function to explore USDC contract specifically
func exploreUSDCContract() async {
    await SmartContractExplorationRunner.exploreSpecificContract(
        contractId: "CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA",
        name: "Stellar Asset Contract (USDC)"
    )
}

/// Quick function to run the complete demo
func runSmartContractDemo() async {
    await SmartContractExplorationRunner.runCompleteExploration()
}

// MARK: - Usage Instructions

/*
 HOW TO USE THIS SMART CONTRACT EXPLORER:
 
 1. To explore all known contracts:
    Task {
        await exploreAllSmartContracts()
    }
 
 2. To explore just the USDC contract:
    Task {
        await exploreUSDCContract()
    }
 
 3. To run the complete demo with detailed analysis:
    Task {
        await runSmartContractDemo()
    }
 
 4. To explore a custom contract:
    Task {
        await SmartContractExplorationRunner.exploreSpecificContract(
            contractId: "YOUR_CONTRACT_ID_HERE",
            name: "Your Contract Name"
        )
    }
 
 5. For interactive exploration:
    Task {
        await SmartContractExplorationRunner.runInteractiveExploration()
    }
 
 WHAT YOU'LL SEE:
 - Contract metadata and basic information
 - All available functions with their parameters and return types
 - Custom types (structs, enums, errors) defined in the contract
 - WASM binary analysis
 - Contract data exploration
 - Comprehensive summary statistics
 
 EXAMPLE OUTPUT:
 The explorer will show you detailed information like:
 - Function signatures: transfer(from: address, to: address, amount: i128) → bool
 - Custom types: TokenMetadata struct with name, symbol, decimals fields
 - Contract data: balance entries, admin settings, etc.
 - WASM binary size and validation
 
 */

// MARK: - Example Usage (Uncomment to run)

/*
// Example 1: Run the complete exploration
Task {
    await runSmartContractDemo()
}

// Example 2: Explore just the contracts without deep dive
Task {
    await exploreAllSmartContracts()
}

// Example 3: Focus on USDC contract
Task {
    await exploreUSDCContract()
}
*/ 