import Foundation
import stellarsdk

/// Comprehensive debug logger for Smart Contract exploration
/// Provides detailed logging with different levels and categories
public class SmartContractDebugLogger {
    
    // MARK: - Log Levels
    
    public enum LogLevel: Int, CaseIterable {
        case verbose = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
        
        var emoji: String {
            switch self {
            case .verbose: return "🔍"
            case .debug: return "🐛"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
        
        var name: String {
            switch self {
            case .verbose: return "VERBOSE"
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARNING"
            case .error: return "ERROR"
            }
        }
    }
    
    // MARK: - Log Categories
    
    public enum LogCategory: String, CaseIterable {
        case network = "NETWORK"
        case parsing = "PARSING"
        case contract = "CONTRACT"
        case wasm = "WASM"
        case data = "DATA"
        case ui = "UI"
        case performance = "PERFORMANCE"
        case debug = "DEBUG"
        
        var emoji: String {
            switch self {
            case .network: return "🌐"
            case .parsing: return "📝"
            case .contract: return "📋"
            case .wasm: return "💾"
            case .data: return "🗄️"
            case .ui: return "🖥️"
            case .performance: return "⚡"
            case .debug: return "🐛"
            }
        }
    }
    
    // MARK: - Properties
    
    public static let shared = SmartContractDebugLogger()
    
    private var currentLogLevel: LogLevel = .debug
    private var enabledCategories: Set<LogCategory> = Set(LogCategory.allCases)
    private var logEntries: [LogEntry] = []
    private let maxLogEntries = 1000
    internal let dateFormatter: DateFormatter
    
    // MARK: - Log Entry Structure
    
    public struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let category: LogCategory
        let message: String
        let file: String
        let function: String
        let line: Int
        let metadata: [String: Any]?
        
        var formattedMessage: String {
            let timeString = SmartContractDebugLogger.shared.dateFormatter.string(from: timestamp)
            let fileName = (file as NSString).lastPathComponent
            return "\(timeString) \(level.emoji) [\(level.name)] \(category.emoji) \(category.rawValue) | \(fileName):\(line) \(function) | \(message)"
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }
    
    // MARK: - Configuration
    
    public func setLogLevel(_ level: LogLevel) {
        currentLogLevel = level
        log(.info, category: .ui, "Log level set to \(level.name)")
    }
    
    public func enableCategory(_ category: LogCategory) {
        enabledCategories.insert(category)
        log(.info, category: .ui, "Enabled logging for category: \(category.rawValue)")
    }
    
    public func disableCategory(_ category: LogCategory) {
        enabledCategories.remove(category)
        log(.info, category: .ui, "Disabled logging for category: \(category.rawValue)")
    }
    
    public func enableAllCategories() {
        enabledCategories = Set(LogCategory.allCases)
        log(.info, category: .ui, "Enabled all logging categories")
    }
    
    // MARK: - Logging Methods
    
    public func log(
        _ level: LogLevel,
        category: LogCategory,
        _ message: String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level.rawValue >= currentLogLevel.rawValue else { return }
        guard enabledCategories.contains(category) else { return }
        
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line,
            metadata: metadata
        )
        
        // Add to log entries
        logEntries.append(entry)
        
        // Maintain max entries
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
        
        // Print to console
        print(entry.formattedMessage)
        
        // Print metadata if available
        if let metadata = metadata {
            for (key, value) in metadata {
                print("    \(key): \(value)")
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    public func verbose(_ message: String, category: LogCategory = .debug, metadata: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.verbose, category: category, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func debug(_ message: String, category: LogCategory = .debug, metadata: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, category: category, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, category: LogCategory = .contract, metadata: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: category, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, category: LogCategory = .contract, metadata: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, category: category, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    public func error(_ message: String, category: LogCategory = .contract, metadata: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, category: category, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    // MARK: - Contract-Specific Logging
    
    public func logContractInspectionStart(_ contractId: String) {
        info("Starting contract inspection", category: .contract, metadata: [
            "contractId": contractId,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    public func logContractInspectionSuccess(_ contractId: String, functionsCount: Int, typesCount: Int, duration: TimeInterval) {
        info("Contract inspection completed successfully", category: .contract, metadata: [
            "contractId": contractId,
            "functionsCount": functionsCount,
            "typesCount": typesCount,
            "duration": String(format: "%.3f", duration)
        ])
    }
    
    public func logContractInspectionFailure(_ contractId: String, error: Error, duration: TimeInterval) {
        self.error("Contract inspection failed", category: .contract, metadata: [
            "contractId": contractId,
            "error": error.localizedDescription,
            "duration": String(format: "%.3f", duration)
        ])
    }
    
    public func logNetworkRequest(_ endpoint: String, method: String = "GET") {
        debug("Making network request", category: .network, metadata: [
            "endpoint": endpoint,
            "method": method,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    public func logNetworkResponse(_ endpoint: String, statusCode: Int?, responseSize: Int?, duration: TimeInterval) {
        let level: LogLevel = (statusCode ?? 0) >= 400 ? .warning : .debug
        log(level, category: .network, "Network response received", metadata: [
            "endpoint": endpoint,
            "statusCode": statusCode ?? "unknown",
            "responseSize": responseSize ?? "unknown",
            "duration": String(format: "%.3f", duration)
        ])
    }
    
    public func logWasmAnalysis(_ contractId: String, wasmSize: Int, isValid: Bool) {
        info("WASM binary analyzed", category: .wasm, metadata: [
            "contractId": contractId,
            "wasmSize": wasmSize,
            "isValid": isValid,
            "sizeFormatted": ByteCountFormatter().string(fromByteCount: Int64(wasmSize))
        ])
    }
    
    public func logDataQuery(_ contractId: String, key: String, found: Bool) {
        let level: LogLevel = found ? .debug : .verbose
        log(level, category: .data, "Contract data query", metadata: [
            "contractId": contractId,
            "key": key,
            "found": found
        ])
    }
    
    public func logPerformanceMetric(_ operation: String, duration: TimeInterval, metadata: [String: Any]? = nil) {
        var performanceMetadata = metadata ?? [:]
        performanceMetadata["operation"] = operation
        performanceMetadata["duration"] = String(format: "%.3f", duration)
        performanceMetadata["durationMs"] = String(format: "%.0f", duration * 1000)
        
        debug("Performance metric", category: .performance, metadata: performanceMetadata)
    }
    
    // MARK: - Log Retrieval
    
    public func getLogEntries(level: LogLevel? = nil, category: LogCategory? = nil, limit: Int? = nil) -> [LogEntry] {
        var filtered = logEntries
        
        if let level = level {
            filtered = filtered.filter { $0.level.rawValue >= level.rawValue }
        }
        
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }
        
        if let limit = limit {
            filtered = Array(filtered.suffix(limit))
        }
        
        return filtered
    }
    
    public func getLogSummary() -> String {
        let totalEntries = logEntries.count
        let errorCount = logEntries.filter { $0.level == .error }.count
        let warningCount = logEntries.filter { $0.level == .warning }.count
        
        var summary = "📊 Debug Log Summary\n"
        summary += "═══════════════════\n"
        summary += "Total Entries: \(totalEntries)\n"
        summary += "Errors: \(errorCount)\n"
        summary += "Warnings: \(warningCount)\n"
        summary += "Current Log Level: \(currentLogLevel.name)\n"
        summary += "Enabled Categories: \(enabledCategories.map { $0.rawValue }.joined(separator: ", "))\n"
        
        if let lastEntry = logEntries.last {
            summary += "Last Entry: \(dateFormatter.string(from: lastEntry.timestamp))\n"
        }
        
        return summary
    }
    
    public func clearLogs() {
        logEntries.removeAll()
        info("Debug logs cleared", category: .ui)
    }
    
    public func exportLogs() -> String {
        var export = "Smart Contract Debug Log Export\n"
        export += "Generated: \(Date())\n"
        export += "═══════════════════════════════\n\n"
        
        for entry in logEntries {
            export += entry.formattedMessage + "\n"
            if let metadata = entry.metadata {
                for (key, value) in metadata {
                    export += "    \(key): \(value)\n"
                }
            }
            export += "\n"
        }
        
        return export
    }
}

// MARK: - Global Logging Functions

/// Global convenience functions for logging
public func debugLog(_ message: String, category: SmartContractDebugLogger.LogCategory = .debug, metadata: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    SmartContractDebugLogger.shared.debug(message, category: category, metadata: metadata, file: file, function: function, line: line)
}

public func infoLog(_ message: String, category: SmartContractDebugLogger.LogCategory = .contract, metadata: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    SmartContractDebugLogger.shared.info(message, category: category, metadata: metadata, file: file, function: function, line: line)
}

public func warningLog(_ message: String, category: SmartContractDebugLogger.LogCategory = .contract, metadata: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    SmartContractDebugLogger.shared.warning(message, category: category, metadata: metadata, file: file, function: function, line: line)
}

public func errorLog(_ message: String, category: SmartContractDebugLogger.LogCategory = .contract, metadata: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    SmartContractDebugLogger.shared.error(message, category: category, metadata: metadata, file: file, function: function, line: line)
} 