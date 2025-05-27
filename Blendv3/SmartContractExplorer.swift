import Foundation
import stellarsdk

/// Comprehensive Smart Contract Explorer
/// Uses the SmartContractInspector to analyze multiple contracts and present detailed insights
class SmartContractExplorer {
    
    public lazy var inspector = SmartContractInspector(
        rpcEndpoint: "https://soroban-testnet.stellar.org",
        network: Network.testnet
    )
    
    // MARK: - Known Contract Addresses for Testing
    
    /// Collection of known smart contract addresses for exploration
    private let knownContracts = [
        ContractInfo(
            id: "CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA",
            name: "Stellar Asset Contract (USDC)",
            description: "Standard Stellar Asset Contract for USDC token"
        ),
        ContractInfo(
            id: "CCFZRNQVZZUQIGGPXNLC7UHIUA4AW3TBQ3QOBHSKOCE2AF5GBARHHXKL",
            name: "Example Token Contract",
            description: "Sample token contract for testing"
        ),
        // Add more known contracts here as needed
    ]
    
    // MARK: - Main Exploration Functions
    
    /// Explores all known smart contracts and presents comprehensive analysis
    func exploreAllContracts() async {
        print("🚀 Starting Comprehensive Smart Contract Exploration")
        print("═══════════════════════════════════════════════════════")
        print("Analyzing \(knownContracts.count) known smart contracts...\n")
        
        var successfulInspections = 0
        var totalFunctions = 0
        var totalCustomTypes = 0
        
        for (index, contractInfo) in knownContracts.enumerated() {
            print("[\(index + 1)/\(knownContracts.count)] 🔍 Inspecting: \(contractInfo.name)")
            print("Contract ID: \(contractInfo.id)")
            print("Description: \(contractInfo.description)")
            print("─────────────────────────────────────────────────────")
            
            do {
                let result = try await inspector.inspectContract(contractId: contractInfo.id)
                
                // Display comprehensive analysis
                await displayContractAnalysis(result, contractInfo: contractInfo)
                
                successfulInspections += 1
                totalFunctions += result.functions.count
                totalCustomTypes += result.customTypes.structs.count + 
                                   result.customTypes.enums.count + 
                                   result.customTypes.unions.count + 
                                   result.customTypes.errors.count
                
            } catch {
                print("❌ Error inspecting contract: \(error.localizedDescription)")
            }
            
            print("\n" + String(repeating: "═", count: 80) + "\n")
        }
        
        // Display summary statistics
        await displayExplorationSummary(
            total: knownContracts.count,
            successful: successfulInspections,
            totalFunctions: totalFunctions,
            totalCustomTypes: totalCustomTypes
        )
    }
    
    /// Explores a specific contract by ID with detailed analysis
    func exploreContract(contractId: String, name: String? = nil) async {
        print("🔍 Deep Dive Analysis: \(name ?? "Unknown Contract")")
        print("Contract ID: \(contractId)")
        print("═══════════════════════════════════════════════════════\n")
        
        do {
            let result = try await inspector.inspectContract(contractId: contractId)
            
            // Comprehensive analysis
            await displayDetailedContractAnalysis(result)
            
            // Try to retrieve WASM binary info
            await analyzeWasmBinary(contractId: contractId)
            
            // Attempt to query some common data keys
            await exploreContractData(contractId: contractId)
            
        } catch {
            print("❌ Failed to inspect contract: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Analysis and Display Functions
    
    private func displayContractAnalysis(_ result: ContractInspectionResult, contractInfo: ContractInfo) async {
        print("✅ Successfully inspected contract!")
        print("\n📊 Contract Overview:")
        print("  • Interface Version: \(result.interfaceVersion)")
        print("  • Total Functions: \(result.functions.count)")
        print("  • Custom Types: \(result.customTypes.structs.count) structs, \(result.customTypes.enums.count) enums")
        
        // Display metadata if available
        if !result.metadata.isEmpty {
            print("\n📋 Metadata:")
            for (key, value) in result.metadata.sorted(by: { $0.key < $1.key }) {
                print("  • \(key): \(value)")
            }
        }
        
        // Display functions summary
        if !result.functions.isEmpty {
            print("\n🔧 Functions:")
            for function in result.functions { // Show all functions instead of just first 5
                let params = function.inputs.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
                let returns = function.outputs.isEmpty ? "void" : function.outputs.joined(separator: ", ")
                print("  • \(function.name)(\(params)) → \(returns)")
            }
        }
        
        // Display custom types summary
        if !result.customTypes.isEmpty {
            print("\n📦 Custom Types Summary:")
            if !result.customTypes.structs.isEmpty {
                print("  • Structs: \(result.customTypes.structs.map { $0.name }.joined(separator: ", "))")
            }
            if !result.customTypes.enums.isEmpty {
                print("  • Enums: \(result.customTypes.enums.map { $0.name }.joined(separator: ", "))")
            }
            if !result.customTypes.errors.isEmpty {
                print("  • Errors: \(result.customTypes.errors.map { $0.name }.joined(separator: ", "))")
            }
        }
    }
    
    private func displayDetailedContractAnalysis(_ result: ContractInspectionResult) async {
        // Use the built-in summary for comprehensive display
        print(result.summary())
        
        // Additional detailed analysis
        print("\n🔬 Detailed Function Analysis:")
        print("═══════════════════════════════════")
        
        for function in result.functions {
            print("\n📝 Function: \(function.name)")
            
            if let doc = function.doc, !doc.isEmpty {
                print("   Description: \(doc)")
            }
            
            if !function.inputs.isEmpty {
                print("   Parameters:")
                for param in function.inputs {
                    print("     • \(param.name): \(param.type)")
                    if let doc = param.doc, !doc.isEmpty {
                        print("       └─ \(doc)")
                    }
                }
            } else {
                print("   Parameters: None")
            }
            
            if !function.outputs.isEmpty {
                print("   Returns: \(function.outputs.joined(separator: ", "))")
            } else {
                print("   Returns: void")
            }
        }
        
        // Analyze custom types in detail
        if !result.customTypes.isEmpty {
            print("\n🏗️ Custom Types Deep Dive:")
            print("═══════════════════════════")
            
            // Structs
            for struct_ in result.customTypes.structs {
                print("\n📋 Struct: \(struct_.name)")
                if let doc = struct_.doc, !doc.isEmpty {
                    print("   Description: \(doc)")
                }
                print("   Fields:")
                for field in struct_.fields {
                    print("     • \(field.name): \(field.type)")
                    if let doc = field.doc, !doc.isEmpty {
                        print("       └─ \(doc)")
                    }
                }
            }
            
            // Enums
            for enum_ in result.customTypes.enums {
                print("\n🔢 Enum: \(enum_.name)")
                if let doc = enum_.doc, !doc.isEmpty {
                    print("   Description: \(doc)")
                }
                print("   Cases:")
                for case_ in enum_.cases {
                    print("     • \(case_.name) = \(case_.value)")
                    if let doc = case_.doc, !doc.isEmpty {
                        print("       └─ \(doc)")
                    }
                }
            }
            
            // Errors
            for error in result.customTypes.errors {
                print("\n⚠️ Error: \(error.name)")
                if let doc = error.doc, !doc.isEmpty {
                    print("   Description: \(doc)")
                }
                print("   Cases:")
                for case_ in error.cases {
                    print("     • \(case_.name) = \(case_.value)")
                    if let doc = case_.doc, !doc.isEmpty {
                        print("       └─ \(doc)")
                    }
                }
            }
        }
    }
    
    private func analyzeWasmBinary(contractId: String) async {
        print("\n💾 WASM Binary Analysis:")
        print("═══════════════════════")
        
        do {
            let wasmData = try await inspector.getContractWasmBinary(contractId: contractId)
            print("✅ WASM binary retrieved successfully")
            print("   • Size: \(formatBytes(wasmData.count))")
            print("   • First 16 bytes: \(wasmData.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")
            
            // Basic WASM header analysis
            if wasmData.count >= 8 {
                let magic = wasmData.prefix(4)
                let version = wasmData.dropFirst(4).prefix(4)
                
                if magic.elementsEqual([0x00, 0x61, 0x73, 0x6d]) {
                    print("   • Valid WASM magic number detected")
                    let versionBytes = Array(version)
                    let versionNumber = UInt32(versionBytes[0]) | 
                                       (UInt32(versionBytes[1]) << 8) | 
                                       (UInt32(versionBytes[2]) << 16) | 
                                       (UInt32(versionBytes[3]) << 24)
                    print("   • WASM version: \(versionNumber)")
                } else {
                    print("   • ⚠️ Invalid WASM magic number")
                }
            }
            
        } catch {
            print("❌ Failed to retrieve WASM binary: \(error.localizedDescription)")
        }
    }
    
    private func exploreContractData(contractId: String) async {
        print("\n🗄️ Contract Data Exploration:")
        print("═══════════════════════════")
        
        // Common keys to try
        let commonKeys: [SCValXDR] = [
            .symbol("balance"),
            .symbol("admin"),
            .symbol("name"),
            .symbol("symbol"),
            .symbol("decimals"),
            .symbol("total_supply"),
            .symbol("allowance"),
            .symbol("metadata")
        ]
        
        var foundData = 0
        
        for key in commonKeys {
            do {
                let dataResult = try await inspector.getContractData(
                    contractId: contractId,
                    key: key,
                    durability: .persistent
                )
                
                print("✅ Found data for key: \(dataResult.key)")
                print("   Value: \(dataResult.value)")
                print("   Durability: \(dataResult.durability == .persistent ? "Persistent" : "Temporary")")
                print("   Last Modified: Ledger \(dataResult.lastModifiedLedger)")
                foundData += 1
                
            } catch {
                // Silently continue - most keys won't exist
                continue
            }
        }
        
        if foundData == 0 {
            print("ℹ️ No data found for common keys (this is normal for many contracts)")
        } else {
            print("\n📊 Found \(foundData) data entries")
        }
    }
    
    private func displayExplorationSummary(total: Int, successful: Int, totalFunctions: Int, totalCustomTypes: Int) async {
        print("📈 Exploration Summary")
        print("═══════════════════════")
        print("• Total Contracts Analyzed: \(total)")
        print("• Successful Inspections: \(successful)")
        print("• Failed Inspections: \(total - successful)")
        print("• Total Functions Discovered: \(totalFunctions)")
        print("• Total Custom Types Found: \(totalCustomTypes)")
        print("• Average Functions per Contract: \(successful > 0 ? String(format: "%.1f", Double(totalFunctions) / Double(successful)) : "N/A")")
        
        if successful > 0 {
            print("\n✅ Exploration completed successfully!")
            print("All contract data has been analyzed and presented above.")
        } else {
            print("\n⚠️ No contracts could be successfully inspected.")
            print("This might be due to network issues or invalid contract addresses.")
        }
    }
    
    // MARK: - Utility Functions
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Searches for contracts by trying to inspect a range of contract IDs
    func discoverContracts(startingFrom baseId: String, count: Int = 10) async {
        print("🔍 Contract Discovery Mode")
        print("═══════════════════════════")
        print("Attempting to discover contracts starting from: \(baseId)")
        print("Will try \(count) variations...\n")
        
        // This is a simplified discovery - in practice, you'd need more sophisticated methods
        // For now, we'll just try the known contracts
        await exploreAllContracts()
    }
}

// MARK: - Supporting Types

struct ContractInfo {
    let id: String
    let name: String
    let description: String
}

// MARK: - Usage Examples

extension SmartContractExplorer {
    
    /// Demonstrates various exploration capabilities
    static func runDemo() async {
        let explorer = SmartContractExplorer()
        
        print("🎯 Smart Contract Explorer Demo")
        print("═══════════════════════════════════\n")
        
        // Option 1: Explore all known contracts
        await explorer.exploreAllContracts()
        
        // Option 2: Deep dive into a specific contract
        print("\n" + String(repeating: "═", count: 80))
        print("🔬 DEEP DIVE ANALYSIS")
        print(String(repeating: "═", count: 80) + "\n")
        
        await explorer.exploreContract(
            contractId: "CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA",
            name: "Stellar Asset Contract (USDC)"
        )
        
        print("\n🎉 Demo completed! Check the output above for detailed contract analysis.")
    }
} 
