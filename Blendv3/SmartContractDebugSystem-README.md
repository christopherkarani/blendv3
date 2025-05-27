# Smart Contract Debug System

A comprehensive debugging and visualization system for Stellar/Soroban smart contracts with advanced logging, performance monitoring, and interactive debugging capabilities.

## 🎯 Overview

The Smart Contract Debug System provides:

- **📊 Interactive Debug View** - SwiftUI interface for real-time contract exploration
- **🔍 Comprehensive Logging** - Multi-level logging with categorization and metadata
- **⚡ Performance Monitoring** - Track operation timings and network activity
- **🛠️ Error Debugging** - Detailed error tracking and analysis
- **📈 Visual Analytics** - Charts and graphs for contract data visualization

## 📁 System Components

### Core Files

1. **`SmartContractDebugLogger.swift`** - Advanced logging system
2. **`SmartContractDebugView.swift`** - SwiftUI debug interface
3. **`SmartContractDebugViewModel.swift`** - State management and data binding
4. **`SmartContractDebugDemo.swift`** - Demo and testing utilities

### Enhanced Files

- **`SmartContractInspector.swift`** - Enhanced with comprehensive logging
- **`SmartContractExplorer.swift`** - Integration with debug system

## 🚀 Quick Start

### 1. Basic Debug View Usage

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        SmartContractDebugView()
    }
}
```

### 2. Run Debug Demo

```swift
// Run comprehensive debug demo
Task {
    await runSmartContractDebugDemo()
}

// Test logging system
testSmartContractLogging()
```

### 3. Programmatic Logging

```swift
// Basic logging
debugLog("Contract inspection started", category: .contract)
infoLog("Network request completed", category: .network)
errorLog("Parsing failed", category: .parsing)

// Logging with metadata
infoLog("Contract analyzed", category: .contract, metadata: [
    "contractId": "CBIELTK6...",
    "functionsCount": 12,
    "duration": "1.234"
])
```

## 🔍 Debug View Features

### Tab 1: Contract Explorer
- **Contract Overview** - Basic contract information and metadata
- **Function Analysis** - Detailed function signatures and documentation
- **Custom Types** - Structs, enums, unions, and error types
- **WASM Analysis** - Binary size, validation, and header information
- **Contract Data** - Storage entries and key-value pairs

### Tab 2: Debug Logs
- **Real-time Logging** - Live log updates with filtering
- **Log Level Filtering** - Verbose, Debug, Info, Warning, Error
- **Category Filtering** - Network, Parsing, Contract, WASM, Data, UI, Performance
- **Export Functionality** - Export logs for external analysis
- **Search and Filter** - Find specific log entries

### Tab 3: Performance Monitoring
- **Operation Timings** - Track how long operations take
- **Network Activity** - Monitor RPC requests and responses
- **Memory Usage** - Track memory consumption
- **Performance Metrics** - Historical performance data

### Tab 4: Settings
- **Log Configuration** - Adjust log levels and categories
- **Debug Options** - Enable/disable various debug features
- **Data Management** - Clear logs and reset settings

## 📊 Logging System

### Log Levels

```swift
enum LogLevel {
    case verbose    // 🔍 Detailed debugging information
    case debug      // 🐛 General debugging messages
    case info       // ℹ️ Informational messages
    case warning    // ⚠️ Warning conditions
    case error      // ❌ Error conditions
}
```

### Log Categories

```swift
enum LogCategory {
    case network     // 🌐 Network requests and responses
    case parsing     // 📝 Data parsing operations
    case contract    // 📋 Contract-related operations
    case wasm        // 💾 WASM binary operations
    case data        // 🗄️ Data storage operations
    case ui          // 🖥️ User interface events
    case performance // ⚡ Performance metrics
    case debug       // 🐛 General debugging messages
}
```

### Advanced Logging Features

- **Metadata Support** - Attach structured data to log entries
- **Performance Tracking** - Automatic timing and metrics
- **Memory Management** - Automatic log rotation and cleanup
- **Export Capabilities** - Export logs in various formats
- **Real-time Updates** - Live log streaming in debug view

## 🛠️ Usage Examples

### Contract Exploration with Debugging

```swift
@StateObject private var debugViewModel = SmartContractDebugViewModel()

// Explore a contract with full debugging
Task {
    await debugViewModel.exploreContract("CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA")
}

// Access results
if let result = debugViewModel.lastResult {
    print("Functions: \(result.functions.count)")
    print("Types: \(result.customTypes.structs.count)")
}

// Check for errors
if let error = debugViewModel.errorMessage {
    print("Error: \(error)")
}
```

### Custom Logging Integration

```swift
class MyContractService {
    func analyzeContract(_ contractId: String) async {
        let startTime = Date()
        
        infoLog("Starting contract analysis", category: .contract, metadata: [
            "contractId": contractId,
            "service": "MyContractService"
        ])
        
        do {
            // Your contract analysis code here
            let result = try await performAnalysis(contractId)
            
            let duration = Date().timeIntervalSince(startTime)
            infoLog("Contract analysis completed", category: .contract, metadata: [
                "contractId": contractId,
                "duration": String(format: "%.3f", duration),
                "resultCount": result.count
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            errorLog("Contract analysis failed", category: .contract, metadata: [
                "contractId": contractId,
                "duration": String(format: "%.3f", duration),
                "error": error.localizedDescription
            ])
        }
    }
}
```

### Performance Monitoring

```swift
// Automatic performance tracking
SmartContractDebugLogger.shared.logPerformanceMetric(
    "Contract Inspection",
    duration: 1.234,
    metadata: [
        "contractId": "CBIELTK6...",
        "functionsFound": 12
    ]
)

// Network activity tracking
SmartContractDebugLogger.shared.logNetworkResponse(
    "https://soroban-testnet.stellar.org",
    statusCode: 200,
    responseSize: 1024,
    duration: 0.456
)
```

## 🎨 Customization

### Configure Logging

```swift
// Set log level
SmartContractDebugLogger.shared.setLogLevel(.debug)

// Enable specific categories
SmartContractDebugLogger.shared.enableCategory(.contract)
SmartContractDebugLogger.shared.enableCategory(.network)

// Disable categories
SmartContractDebugLogger.shared.disableCategory(.verbose)
```

### Custom Debug Views

```swift
struct CustomDebugView: View {
    @StateObject private var debugViewModel = SmartContractDebugViewModel()
    
    var body: some View {
        VStack {
            // Your custom debug interface
            if let result = debugViewModel.lastResult {
                Text("Contract has \(result.functions.count) functions")
            }
            
            // Access logs
            List(debugViewModel.filteredLogEntries, id: \.timestamp) { entry in
                Text(entry.message)
                    .foregroundColor(colorForLogLevel(entry.level))
            }
        }
    }
    
    private func colorForLogLevel(_ level: SmartContractDebugLogger.LogLevel) -> Color {
        switch level {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .debug: return .gray
        case .verbose: return .secondary
        }
    }
}
```

## 📈 Performance Insights

The debug system automatically tracks:

- **Contract Inspection Time** - How long it takes to analyze contracts
- **Network Request Duration** - RPC call performance
- **WASM Binary Analysis** - Binary processing time
- **Data Query Performance** - Contract data retrieval speed
- **Memory Usage** - Application memory consumption

### Performance Metrics Example

```
📊 Performance Summary
═══════════════════════
Contract Inspection: 1.234s
WASM Analysis: 0.456s
Network Requests: 0.789s (avg)
Memory Usage: 45.2 MB
```

## 🔧 Troubleshooting

### Common Issues

1. **No Logs Appearing**
   - Check log level settings
   - Ensure categories are enabled
   - Verify auto-refresh is enabled

2. **Performance Issues**
   - Reduce log level to Warning or Error
   - Disable verbose categories
   - Clear old logs regularly

3. **Memory Usage**
   - Logs are automatically rotated (max 1000 entries)
   - Use `clearLogs()` to free memory
   - Monitor memory usage in Performance tab

### Debug Commands

```swift
// Get log summary
let summary = SmartContractDebugLogger.shared.getLogSummary()
print(summary)

// Export all logs
let exportedLogs = SmartContractDebugLogger.shared.exportLogs()

// Clear logs
SmartContractDebugLogger.shared.clearLogs()

// Get filtered logs
let errorLogs = SmartContractDebugLogger.shared.getLogEntries(
    level: .error,
    category: .contract,
    limit: 50
)
```

## 🎯 Best Practices

### Logging Guidelines

1. **Use Appropriate Log Levels**
   - `verbose`: Detailed debugging only
   - `debug`: Development debugging
   - `info`: Important events
   - `warning`: Potential issues
   - `error`: Actual problems

2. **Include Relevant Metadata**
   - Contract IDs
   - Operation timings
   - Error details
   - Context information

3. **Performance Considerations**
   - Use higher log levels in production
   - Include timing information
   - Monitor memory usage

### Debug View Usage

1. **Start with Contract Explorer** - Get overview of contract structure
2. **Check Debug Logs** - Look for errors and warnings
3. **Monitor Performance** - Identify slow operations
4. **Adjust Settings** - Fine-tune logging for your needs

## 🚀 Integration Guide

### Adding to Existing Project

1. **Copy Debug System Files**
   ```
   SmartContractDebugLogger.swift
   SmartContractDebugView.swift
   SmartContractDebugViewModel.swift
   SmartContractDebugDemo.swift
   ```

2. **Update Existing Code**
   - Add logging calls to your contract operations
   - Integrate debug view into your app
   - Configure logging levels

3. **Test Integration**
   ```swift
   // Test logging
   testSmartContractLogging()
   
   // Run debug demo
   Task {
       await runSmartContractDebugDemo()
   }
   ```

## 📚 API Reference

### SmartContractDebugLogger

```swift
// Configuration
func setLogLevel(_ level: LogLevel)
func enableCategory(_ category: LogCategory)
func disableCategory(_ category: LogCategory)

// Logging
func log(_ level: LogLevel, category: LogCategory, _ message: String, metadata: [String: Any]?)
func debug(_ message: String, category: LogCategory, metadata: [String: Any]?)
func info(_ message: String, category: LogCategory, metadata: [String: Any]?)
func warning(_ message: String, category: LogCategory, metadata: [String: Any]?)
func error(_ message: String, category: LogCategory, metadata: [String: Any]?)

// Specialized Logging
func logContractInspectionStart(_ contractId: String)
func logContractInspectionSuccess(_ contractId: String, functionsCount: Int, typesCount: Int, duration: TimeInterval)
func logPerformanceMetric(_ operation: String, duration: TimeInterval, metadata: [String: Any]?)

// Data Retrieval
func getLogEntries(level: LogLevel?, category: LogCategory?, limit: Int?) -> [LogEntry]
func getLogSummary() -> String
func exportLogs() -> String
func clearLogs()
```

### SmartContractDebugViewModel

```swift
// Contract Exploration
func exploreContract(_ contractId: String) async

// Log Management
func refreshLogEntries()
func clearLogs()
func enableCategory(_ category: LogCategory)
func disableCategory(_ category: LogCategory)

// Settings
func resetSettings()
func clearAllData()

// Export
func exportDebugReport() -> String
```

## ✅ Recent Fixes

### SorobanServer.serverUrl Issue Fixed

**Problem**: `Value of type 'SorobanServer' has no member 'serverUrl'`

**Root Cause**: The `SorobanServer` class has a private `endpoint` property, not a public `serverUrl` property.

**Solution**: Removed the non-existent `serverUrl` property access from logging metadata:

```swift
// BEFORE (❌ Error):
debugLog("Starting contract inspection", category: .contract, metadata: [
    "contractId": contractId,
    "rpcEndpoint": sorobanServer.serverUrl  // ❌ This property doesn't exist
])

// AFTER (✅ Fixed):
debugLog("Starting contract inspection", category: .contract, metadata: [
    "contractId": contractId  // ✅ Only include contractId
])
```

**Files Fixed**: `SmartContractInspector.swift`

**Impact**: Debug logging now works correctly without trying to access non-existent properties.

### LogCategory.debug Issue Fixed

**Problem**: `Type 'SmartContractDebugLogger.LogCategory' has no member 'debug'`

**Solution**: Added the missing `.debug` category to the `LogCategory` enum:

```swift
public enum LogCategory: String, CaseIterable {
    case network = "NETWORK"
    case parsing = "PARSING"
    case contract = "CONTRACT"
    case wasm = "WASM"
    case data = "DATA"
    case ui = "UI"
    case performance = "PERFORMANCE"
    case debug = "DEBUG"  // ← Added this missing category
    
    var emoji: String {
        switch self {
        case .network: return "🌐"
        case .parsing: return "📝"
        case .contract: return "📋"
        case .wasm: return "💾"
        case .data: return "🗄️"
        case .ui: return "🖥️"
        case .performance: return "⚡"
        case .debug: return "🐛"  // ← Added emoji for debug category
        }
    }
}
```

**Test**: Run `testLogCategoryDebugFix()` to verify the fix works correctly.

### DateFormatter Access Issue Fixed

**Problem**: `'dateFormatter' is inaccessible due to 'private' protection level`

**Root Cause**: The `LogEntry.formattedMessage` computed property was trying to access the private `dateFormatter` property from within the struct.

**Solution**: Changed the `dateFormatter` property from `private` to `internal`:

```swift
// BEFORE (❌ Error):
private let dateFormatter: DateFormatter

// AFTER (✅ Fixed):
internal let dateFormatter: DateFormatter
```

**Files Fixed**: `SmartContractDebugLogger.swift`

**Impact**: 
- ✅ `LogEntry.formattedMessage` can now access the dateFormatter
- ✅ Log entries display properly formatted timestamps
- ✅ All logging functionality works correctly
- ✅ DateFormatter remains encapsulated within the module

**Test**: Run `testDateFormatterFix()` to verify the fix works correctly.

### Inout Parameter Issue Fixed

**Problem**: `Cannot pass immutable value as inout argument: 'info' is a 'let' constant`

**Root Cause**: Variables declared with `let` are immutable and cannot be passed to functions that require `inout` parameters.

**Solution**: Ensure variables that need to be passed as `inout` parameters are declared with `var`:

```swift
// BEFORE (❌ Error):
let info = mach_task_basic_info()
task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), &info, &count)
// Error: Cannot pass immutable value as inout argument

// AFTER (✅ Fixed):
var info = mach_task_basic_info()
task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), &info, &count)
// Works correctly
```

**Files Fixed**: `SmartContractDebugView.swift` (MemoryUsageView)

**Impact**: 
- ✅ Memory usage tracking works correctly
- ✅ Performance monitoring displays accurate memory information
- ✅ No compilation errors related to inout parameters

**Common Inout Parameter Rules**:
- ✅ Use `var` for variables that will be passed as `inout`
- ❌ Cannot pass `let` constants as `inout` parameters
- ❌ Cannot pass computed properties as `inout` parameters
- ❌ Cannot pass function results directly as `inout` parameters

**Test**: Run `testInoutParameterFix()` to verify the fix works correctly.

---

## 🎉 Getting Started

1. **Add the debug view to your app:**
   ```swift
   struct ContentView: View {
       var body: some View {
           SmartContractDebugView()
       }
   }
   ```

2. **Run the demo to test everything:**
   ```swift
   Task {
       await runSmartContractDebugDemo()
   }
   ```

3. **Start exploring contracts and debugging!**

The Smart Contract Debug System provides everything you need to understand, debug, and optimize your Stellar/Soroban smart contract interactions. Happy debugging! 🚀 