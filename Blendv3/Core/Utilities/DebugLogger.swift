//
//  DebugLogger.swift
//  Blendv3
//
//  Created by Chris Karani on 02/07/2025.
//
import os.log
import Foundation

public struct DebugLogger {
    private let subsystem: String
    private let category: String
    private let osLogger: Logger
    
    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        self.osLogger = Logger(subsystem: subsystem, category: category)
    }
    
    public func debug(_ message: String) {
        osLogger.debug("\(message)")
        LogStore.shared.addEntry(LogEntry(
            timestamp: Date(),
            category: category,
            level: .debug,
            message: message
        ))
    }
    
    public func info(_ message: String) {
        osLogger.info("\(message)")
        LogStore.shared.addEntry(LogEntry(
            timestamp: Date(),
            category: category,
            level: .info,
            message: message
        ))
    }
    
    public func error(_ message: String) {
        osLogger.error("\(message)")
        LogStore.shared.addEntry(LogEntry(
            timestamp: Date(),
            category: category,
            level: .error,
            message: message
        ))
    }
    
    public func warning(_ message: String) {
        osLogger.warning("\(message)")
        LogStore.shared.addEntry(LogEntry(
            timestamp: Date(),
            category: category,
            level: .warning,
            message: message
        ))
    }
}

public struct LogEntry: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let category: String
    public let level: LogLevel
    public let message: String
}

public enum LogLevel {
    case debug
    case info
    case warning
    case error
    
    public var icon: String {
        switch self {
        case .debug:
            return "ant.circle"
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }
}

public class LogStore {
    public static let shared = LogStore()
    
    public var entries: [LogEntry] = []
    private let maxEntries = 500
    private let queue = DispatchQueue(label: "com.blendv3.logstore", attributes: .concurrent)
    
    private init() {}
    
    public func addEntry(_ entry: LogEntry) {
        queue.async(flags: .barrier) {
            self.entries.append(entry)
            // Keep only last maxEntries
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst()
            }
        }
    }
    
    public func clear() {
        queue.async(flags: .barrier) {
            self.entries.removeAll()
        }
    }
    
    public func getEntries() -> [LogEntry] {
        return queue.sync {
            return self.entries
        }
    }
}
