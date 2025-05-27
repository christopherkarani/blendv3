import SwiftUI
import stellarsdk

/// Demo runner for Smart Contract Debug View
/// Shows how to use the debug interface and logging system
struct SmartContractDebugDemo: View {
    var body: some View {
        SmartContractDebugView()
    }
}

/// Demo functions for testing the debug system
class SmartContractDebugDemoRunner {
    
    /// Runs a comprehensive demo of the debug system
    static func runDebugDemo() async {
        print("🎯 Smart Contract Debug System Demo")
        print("═══════════════════════════════════════")
        print("This demo showcases the debug logging and visualization system\n")
        
        // Configure logging for demo
        SmartContractDebugLogger.shared.setLogLevel(.verbose)
        SmartContractDebugLogger.shared.enableAllCategories()
        
        infoLog("Debug demo started", category: .ui, metadata: [
            "timestamp": Date().timeIntervalSince1970,
            "demoVersion": "1.0"
        ])
        
        // Demo 1: Basic contract exploration with logging
        await demoContractExploration()
        
        // Demo 2: Error handling and logging
        await demoErrorHandling()
        
        // Demo 3: Performance monitoring
        await demoPerformanceMonitoring()
        
        // Demo 4: Log analysis
        demoLogAnalysis()
        
        print("\n🎉 Debug demo completed!")
        print("Check the debug view to see all logged information.")
    }
    
    private static func demoContractExploration() async {
        print("\n📋 Demo 1: Contract Exploration with Logging")
        print("─────────────────────────────────────────────")
        
        let inspector = SmartContractInspector(
            rpcEndpoint: "https://soroban-testnet.stellar.org",
            network: Network.testnet
        )
        
        let contractId = "CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA"
        
        do {
            infoLog("Starting contract exploration demo", category: .contract, metadata: [
                "contractId": contractId,
                "demoStep": "1"
            ])
            
            let result = try await inspector.inspectContract(contractId: contractId)
            
            print("✅ Contract explored successfully!")
            print("   • Functions: \(result.functions.count)")
            print("   • Custom Types: \(result.customTypes.structs.count + result.customTypes.enums.count)")
            print("   • Interface Version: \(result.interfaceVersion)")
            
            // Try to get WASM binary
            let wasmData = try await inspector.getContractWasmBinary(contractId: contractId)
            print("   • WASM Size: \(ByteCountFormatter().string(fromByteCount: Int64(wasmData.count)))")
            
        } catch {
            errorLog("Contract exploration demo failed", category: .contract, metadata: [
                "contractId": contractId,
                "error": error.localizedDescription,
                "demoStep": "1"
            ])
            print("❌ Demo failed: \(error.localizedDescription)")
        }
    }
    
    private static func demoErrorHandling() async {
        print("\n⚠️ Demo 2: Error Handling and Logging")
        print("─────────────────────────────────────")
        
        let inspector = SmartContractInspector(
            rpcEndpoint: "https://soroban-testnet.stellar.org",
            network: Network.testnet
        )
        
        let invalidContractId = "INVALID_CONTRACT_ID_FOR_DEMO"
        
        do {
            warningLog("Attempting to explore invalid contract (expected to fail)", category: .contract, metadata: [
                "contractId": invalidContractId,
                "demoStep": "2",
                "expectedResult": "failure"
            ])
            
            let _ = try await inspector.inspectContract(contractId: invalidContractId)
            print("❌ Unexpected success - this should have failed")
            
        } catch {
            print("✅ Error handling working correctly!")
            print("   • Error: \(error.localizedDescription)")
            
            infoLog("Error handling demo completed successfully", category: .contract, metadata: [
                "contractId": invalidContractId,
                "error": error.localizedDescription,
                "demoStep": "2"
            ])
        }
    }
    
    private static func demoPerformanceMonitoring() async {
        print("\n⚡ Demo 3: Performance Monitoring")
        print("─────────────────────────────────")
        
        let operations = [
            "Network Request Simulation",
            "Data Processing Simulation",
            "WASM Analysis Simulation",
            "Contract Parsing Simulation"
        ]
        
        for (index, operation) in operations.enumerated() {
            let startTime = Date()
            
            debugLog("Starting performance demo operation", category: .performance, metadata: [
                "operation": operation,
                "step": index + 1,
                "totalSteps": operations.count
            ])
            
            // Simulate work
            try? await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...500_000_000)) // 0.1-0.5 seconds
            
            let duration = Date().timeIntervalSince(startTime)
            
            SmartContractDebugLogger.shared.logPerformanceMetric(operation, duration: duration, metadata: [
                "demoStep": "3",
                "operationIndex": index,
                "simulatedWork": true
            ])
            
            print("   • \(operation): \(String(format: "%.3f", duration))s")
        }
        
        print("✅ Performance monitoring demo completed!")
    }
    
    private static func demoLogAnalysis() {
        print("\n📊 Demo 4: Log Analysis")
        print("─────────────────────")
        
        let summary = SmartContractDebugLogger.shared.getLogSummary()
        print(summary)
        
        // Show recent logs by category
        let categories: [SmartContractDebugLogger.LogCategory] = [.contract, .network, .wasm, .performance]
        
        for category in categories {
            let categoryLogs = SmartContractDebugLogger.shared.getLogEntries(category: category, limit: 3)
            if !categoryLogs.isEmpty {
                print("\nRecent \(category.rawValue) logs:")
                for log in categoryLogs {
                    print("   \(log.level.emoji) \(log.message)")
                }
            }
        }
        
        infoLog("Log analysis demo completed", category: .ui, metadata: [
            "totalLogEntries": SmartContractDebugLogger.shared.getLogEntries().count,
            "demoStep": "4"
        ])
    }
}

// MARK: - Quick Demo Functions

/// Quick function to run the debug demo
func runSmartContractDebugDemo() async {
    await SmartContractDebugDemoRunner.runDebugDemo()
}

/// Quick function to test logging
func testSmartContractLogging() {
    print("🧪 Testing Smart Contract Logging System")
    print("═══════════════════════════════════════")
    
    // Test different log levels
    SmartContractDebugLogger.shared.verbose("This is a verbose message", category: .debug)
    SmartContractDebugLogger.shared.debug("This is a debug message", category: .contract)
    SmartContractDebugLogger.shared.info("This is an info message", category: .network)
    SmartContractDebugLogger.shared.warning("This is a warning message", category: .wasm)
    SmartContractDebugLogger.shared.error("This is an error message", category: .parsing)
    
    // Test with metadata
    infoLog("Testing logging with metadata", category: .ui, metadata: [
        "testParameter": "testValue",
        "timestamp": Date().timeIntervalSince1970,
        "logLevel": "info"
    ])
    
    // Test performance logging
    SmartContractDebugLogger.shared.logPerformanceMetric("Test Operation", duration: 0.123, metadata: [
        "testMetric": true,
        "operationType": "logging test"
    ])
    
    print("\n✅ Logging test completed!")
    print("Check the debug view logs tab to see all entries.")
}

// MARK: - Usage Examples

/*
 To test the Smart Contract Debug System:

 1. Run the complete debug demo:
    Task {
        await runSmartContractDebugDemo()
    }

 2. Test just the logging system:
    testSmartContractLogging()

 3. Use the debug view in your app:
    struct ContentView: View {
        var body: some View {
            SmartContractDebugView()
        }
    }

 4. Access logs programmatically:
    let logs = SmartContractDebugLogger.shared.getLogEntries(level: .info, limit: 50)
    let summary = SmartContractDebugLogger.shared.getLogSummary()
 */ 