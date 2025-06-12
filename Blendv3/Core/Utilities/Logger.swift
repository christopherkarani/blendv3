import Foundation
import os.log

/// Centralized logging utility for Blend Protocol
public enum BlendLogger {
    
    // MARK: - Log Categories
    
    private static let subsystem = "com.blend.protocol"
    
    public static let network = OSLog(subsystem: subsystem, category: "Network")
    public static let oracle = OSLog(subsystem: subsystem, category: "Oracle")
    public static let rateCalculation = OSLog(subsystem: subsystem, category: "RateCalculation")
    public static let cache = OSLog(subsystem: subsystem, category: "Cache")
    public static let ui = OSLog(subsystem: subsystem, category: "UI")
    public static let error = OSLog(subsystem: subsystem, category: "Error")
    
    // MARK: - Logging Methods
    
    /// Log debug information
    public static func debug(_ message: String, category: OSLog = .default, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        os_log(.debug, log: category, "[%{public}@:%{public}@:%d] %{public}@", fileName, function, line, message)
    }
    
    /// Log informational messages
    public static func info(_ message: String, category: OSLog = .default, file: String = #file, function: String = #function) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        os_log(.info, log: category, "[%{public}@:%{public}@] %{public}@", fileName, function, message)
    }
    
    /// Log warnings
    public static func warning(_ message: String, category: OSLog = .default, file: String = #file, function: String = #function) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        os_log(.default, log: category, "⚠️ [%{public}@:%{public}@] %{public}@", fileName, function, message)
    }
    
    /// Log errors
    public static func error(_ message: String, error: Error? = nil, category: OSLog = BlendLogger.error, file: String = #file, function: String = #function) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let errorDescription = error?.localizedDescription ?? "No error details"
        os_log(.error, log: category, "❌ [%{public}@:%{public}@] %{public}@ | Error: %{public}@", fileName, function, message, errorDescription)
    }
    
    /// Log performance metrics
    public static func performance(_ operation: String, duration: TimeInterval, category: OSLog = .default) {
        os_log(.info, log: category, "⏱️ Performance: %{public}@ completed in %.3f seconds", operation, duration)
    }
    
    /// Log rate calculation details
    public static func rateCalculation(
        operation: String,
        inputs: [String: Any],
        result: Any,
        file: String = #file,
        function: String = #function
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let inputsString = inputs.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        os_log(.info, log: rateCalculation, "🧮 [%{public}@:%{public}@] %{public}@ | Inputs: {%{public}@} | Result: %{public}@", 
               fileName, function, operation, inputsString, String(describing: result))
    }
    
    /// Log oracle price data
    public static func oraclePrice(
        asset: String,
        price: Decimal,
        timestamp: Date,
        isStale: Bool,
        file: String = #file
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        let staleIndicator = isStale ? "🔴 STALE" : "🟢 FRESH"
        os_log(.info, log: oracle, "💰 [%{public}@] Oracle Price: %{public}@ = $%{public}@ at %{public}@ %{public}@", 
               fileName, asset, String(describing: price), formatter.string(from: timestamp), staleIndicator)
    }
    
    /// Log cache operations
    public static func cache(operation: String, key: String, hit: Bool? = nil, file: String = #file) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let hitIndicator = hit == true ? "🎯 HIT" : hit == false ? "❌ MISS" : ""
        os_log(.info, log: cache, "💾 [%{public}@] Cache %{public}@: %{public}@ %{public}@", 
               fileName, operation, key, hitIndicator)
    }
}

/// Performance measurement utility
public struct PerformanceTimer {
    private let startTime: CFAbsoluteTime
    private let operation: String
    private let category: OSLog
    
    public init(operation: String, category: OSLog = .default) {
        self.operation = operation
        self.category = category
        self.startTime = CFAbsoluteTimeGetCurrent()
        BlendLogger.debug("Started: \(operation)", category: category)
    }
    
    public func end() {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        BlendLogger.performance(operation, duration: duration, category: category)
    }
}

/// Macro for easy performance timing
public func measurePerformance<T>(
    operation: String,
    category: OSLog = .default,
    block: () throws -> T
) rethrows -> T {
    let timer = PerformanceTimer(operation: operation, category: category)
    defer { timer.end() }
    return try block()
}

/// Async version of measurePerformance for asynchronous operations
public func measurePerformance<T>(
    operation: String,
    category: OSLog = .default,
    block: () async throws -> T
) async rethrows -> T {
    let timer = PerformanceTimer(operation: operation, category: category)
    defer { timer.end() }
    return try await block()
} 