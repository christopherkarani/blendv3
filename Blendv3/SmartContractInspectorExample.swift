import Foundation
import stellarsdk

/// Example usage of the SmartContractInspector
/// Shows how to inspect smart contracts and present data in human-readable format
class SmartContractInspectorExample {
    
    // Lazy initialization to avoid MainActor issues
    private lazy var inspector = SmartContractInspector(
        rpcEndpoint: "https://soroban-testnet.stellar.org",
        network: Network.testnet
    )
    
    /// Example 1: Inspect a contract by its ID
    func inspectContractById() async {
        do {
            // Replace with your actual contract ID
            let contractId = "CCFZRNQVZZUQIGGPXNLC7UHIUA4AW3TBQ3QOBHSKOCE2AF5GBARHHXKL"
            
            print("🚀 Starting contract inspection...")
            let result = try await inspector.inspectContract(contractId: contractId)
            
            // Print human-readable summary
            print(result.summary())
            
            // Access specific information
            print("\n📋 Detailed Function Information:")
            for function in result.functions {
                print("\nFunction: \(function.name)")
                print("Parameters:")
                for param in function.inputs {
                    print("  - \(param.name): \(param.type)")
                    if let doc = param.doc {
                        print("    Description: \(doc)")
                    }
                }
                if !function.outputs.isEmpty {
                    print("Returns: \(function.outputs.joined(separator: ", "))")
                }
            }
            
        } catch {
            print("❌ Error inspecting contract: \(error)")
        }
    }
    
    /// Example 2: Retrieve and save WASM binary
    func retrieveWasmBinary() async {
        do {
            let contractId = "CCFZRNQVZZUQIGGPXNLC7UHIUA4AW3TBQ3QOBHSKOCE2AF5GBARHHXKL"
            
            print("📥 Downloading WASM binary...")
            let wasmData = try await inspector.getContractWasmBinary(contractId: contractId)
            
            print("✅ WASM binary retrieved: \(wasmData.count) bytes")
            
            // Save to file if needed
            let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                        in: .userDomainMask).first!
            let wasmPath = documentsPath.appendingPathComponent("contract.wasm")
            try wasmData.write(to: wasmPath)
            print("💾 Saved to: \(wasmPath)")
            
        } catch {
            print("❌ Error retrieving WASM: \(error)")
        }
    }
    
    /// Example 3: Query contract data
    func queryContractData() async {
        do {
            let contractId = "CCFZRNQVZZUQIGGPXNLC7UHIUA4AW3TBQ3QOBHSKOCE2AF5GBARHHXKL"
            
            // Example: Query a simple symbol key
            let key = SCValXDR.symbol("balance")
            
            print("🔍 Querying contract data...")
            let dataResult = try await inspector.getContractData(
                contractId: contractId,
                key: key,
                durability: .persistent
            )
            
            print(dataResult.summary())
            
        } catch {
            print("❌ Error querying contract data: \(error)")
        }
    }
    
    /// Example 4: Format complex contract data
    func demonstrateDataFormatting() {
        print("\n📊 Data Formatting Examples:")
        print("═══════════════════════════")
        
        // Example of how different data types would be formatted
        let examples = [
            ("Simple Number", "u64", "1000000"),
            ("Address", "address", "account(GABC123...)"),
            ("Token Amount", "i128", "i128(0:5000000)"),
            ("Map Entry", "map<symbol, u64>", "{balance: 1000, allowance: 500}"),
            ("Vector", "vec<address>", "[account(GA...), account(GB...)]"),
            ("Option", "option<u32>", "Some(42)"),
            ("Bytes", "bytes", "bytes(0x48656c6c6f)"),
            ("String", "string", "\"Hello, Soroban!\"")
        ]
        
        print("\n┌─────────────────┬──────────────────┬─────────────────────────────┐")
        print("│ Field Name      │ Type             │ Value                       │")
        print("├─────────────────┼──────────────────┼─────────────────────────────┤")
        
        for (name, type, value) in examples {
            let paddedName = name.padding(toLength: 15, withPad: " ", startingAt: 0)
            let paddedType = type.padding(toLength: 16, withPad: " ", startingAt: 0)
            let paddedValue = value.padding(toLength: 27, withPad: " ", startingAt: 0)
            print("│ \(paddedName) │ \(paddedType) │ \(paddedValue) │")
        }
        
        print("└─────────────────┴──────────────────┴─────────────────────────────┘")
    }
    
    /// Example 5: Batch inspect multiple contracts
    func batchInspectContracts() async {
        let contractIds = [
            "CCFZRNQVZZUQIGGPXNLC7UHIUA4AW3TBQ3QOBHSKOCE2AF5GBARHHXKL",
            // Add more contract IDs here
        ]
        
        print("\n📦 Batch Contract Inspection")
        print("════════════════════════════\n")
        
        for (index, contractId) in contractIds.enumerated() {
            print("[\(index + 1)/\(contractIds.count)] Inspecting: \(contractId)")
            
            do {
                let result = try await inspector.inspectContract(contractId: contractId)
                
                // Create a compact summary for batch display
                print("  ✓ Functions: \(result.functions.count)")
                print("  ✓ Custom Types: \(result.customTypes.structs.count) structs, " +
                      "\(result.customTypes.enums.count) enums")
                
                if let name = result.metadata["name"] {
                    print("  ✓ Name: \(name)")
                }
                if let version = result.metadata["version"] {
                    print("  ✓ Version: \(version)")
                }
                
            } catch {
                print("  ✗ Error: \(error.localizedDescription)")
            }
            
            print("")
        }
    }
}

// MARK: - Usage in SwiftUI

import SwiftUI

/// SwiftUI View for displaying contract inspection results
struct ContractInspectorView: View {
    @State private var contractId = ""
    @State private var inspectionResult: ContractInspectionResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Lazy initialization to avoid MainActor issues
    private var inspector: SmartContractInspector {
        SmartContractInspector(
            rpcEndpoint: "https://soroban-testnet.stellar.org",
            network: Network.testnet
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Input Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Contract ID")
                        .font(.headline)
                    
                    HStack {
                        TextField("Enter contract ID...", text: $contractId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: inspectContract) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Inspect")
                            }
                        }
                        .disabled(contractId.isEmpty || isLoading)
                    }
                }
                .padding()
                
                // Results Section
                if let result = inspectionResult {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            // Contract Info
                            GroupBox(label: Label("Contract Information", systemImage: "doc.text")) {
                                VStack(alignment: .leading, spacing: 5) {
                                    if let contractId = result.contractId {
                                        InfoRow(label: "Contract ID", value: contractId)
                                    }
                                    InfoRow(label: "Interface Version", value: "\(result.interfaceVersion)")
                                    InfoRow(label: "Functions", value: "\(result.functions.count)")
                                }
                            }
                            
                            // Functions List
                            GroupBox(label: Label("Available Functions", systemImage: "function")) {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(result.functions, id: \.name) { function in
                                        FunctionView(function: function)
                                    }
                                }
                            }
                            
                            // Metadata
                            if !result.metadata.isEmpty {
                                GroupBox(label: Label("Metadata", systemImage: "tag")) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        ForEach(Array(result.metadata.keys), id: \.self) { key in
                                            InfoRow(label: key, value: result.metadata[key]!)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Error Display
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Smart Contract Inspector")
        }
    }
    
    private func inspectContract() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await inspector.inspectContract(contractId: contractId)
                await MainActor.run {
                    self.inspectionResult = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// Helper Views
//struct InfoRow: View {
//    let label: String
//    let value: String
//    
//    var body: some View {
//        HStack {
//            Text(label)
//                .fontWeight(.medium)
//            Spacer()
//            Text(value)
//                .foregroundColor(.secondary)
//                .lineLimit(1)
//                .truncationMode(.middle)
//        }
//    }
//}

struct FunctionView: View {
    let function: ContractFunction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(function.name)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
            
            if !function.inputs.isEmpty {
                Text("Parameters: " + function.inputs.map { "\($0.name): \($0.type)" }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !function.outputs.isEmpty {
                Text("Returns: " + function.outputs.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
} 
