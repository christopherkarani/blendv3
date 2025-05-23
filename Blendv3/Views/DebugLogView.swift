//
//  DebugLogView.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import SwiftUI
import os.log

struct DebugLogView: View {
    @StateObject private var logStore = LogStore.shared
    @State private var autoScroll = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Controls
                HStack {
                    Button(action: {
                        logStore.clear()
                    }) {
                        Label("Clear", systemImage: "trash")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Toggle("Auto-scroll", isOn: $autoScroll)
                        .font(.caption)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                
                // Log entries
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(logStore.entries) { entry in
                                LogEntryView(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                    .onChange(of: logStore.entries.count) { _ in
                        if autoScroll, let lastEntry = logStore.entries.last {
                            withAnimation {
                                proxy.scrollTo(lastEntry.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct LogEntryView: View {
    let entry: LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.timestamp, style: .time)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Text(entry.category)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.blue)
                
                Image(systemName: entry.level.icon)
                    .font(.caption2)
                    .foregroundColor(entry.level.color)
                
                Spacer()
            }
            
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(entry.level.textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(entry.level.backgroundColor)
        .cornerRadius(4)
    }
}

// MARK: - Log Store

class LogStore: ObservableObject {
    static let shared = LogStore()
    
    @Published var entries: [LogEntry] = []
    private let maxEntries = 500
    
    private init() {}
    
    func addEntry(_ entry: LogEntry) {
        DispatchQueue.main.async {
            self.entries.append(entry)
            // Keep only last maxEntries
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst()
            }
        }
    }
    
    func clear() {
        entries.removeAll()
    }
}

// MARK: - Custom Logger

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

// MARK: - Models

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let level: LogLevel
    let message: String
}

enum LogLevel {
    case debug
    case info
    case warning
    case error
    
    var icon: String {
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
    
    var color: Color {
        switch self {
        case .debug:
            return .gray
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
    
    var textColor: Color {
        switch self {
        case .debug:
            return .secondary
        case .info:
            return .primary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .debug:
            return Color(.systemGray6)
        case .info:
            return Color(.systemBackground)
        case .warning:
            return .orange.opacity(0.1)
        case .error:
            return .red.opacity(0.1)
        }
    }
} 