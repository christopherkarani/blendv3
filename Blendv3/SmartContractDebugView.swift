import SwiftUI
import stellarsdk

/// Comprehensive debug view for Smart Contract exploration
/// Provides detailed visualization of contract data, logs, and debugging tools
struct SmartContractDebugView: View {
    
    @StateObject private var debugViewModel = SmartContractDebugViewModel()
    @State private var selectedTab = 0
    @State private var contractId = "CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA"
    @State private var showingLogExport = false
    @State private var logExportText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with controls
                debugHeader
                
                // Tab view for different debug sections
                TabView(selection: $selectedTab) {
                    // Contract Explorer Tab
                    contractExplorerTab
                        .tabItem {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Explorer")
                        }
                        .tag(0)
                    
                    // Debug Logs Tab
                    debugLogsTab
                        .tabItem {
                            Image(systemName: "list.bullet.rectangle")
                            Text("Logs")
                        }
                        .tag(1)
                    
                    // Performance Tab
                    performanceTab
                        .tabItem {
                            Image(systemName: "speedometer")
                            Text("Performance")
                        }
                        .tag(2)
                    
                    // Settings Tab
                    settingsTab
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .tag(3)
                }
            }
            .navigationTitle("Smart Contract Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingLogExport) {
            LogExportView(logText: logExportText)
        }
    }
    
    // MARK: - Header
    
    private var debugHeader: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Contract ID", text: $contractId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                
                Button(action: {
                    Task {
                        await debugViewModel.exploreContract(contractId)
                    }
                }) {
                    if debugViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(contractId.isEmpty || debugViewModel.isLoading)
            }
            
            // Batch inspection button
            Button(action: {
                Task {
                    await debugViewModel.inspectAllBlendContracts()
                }
            }) {
                HStack {
                    Image(systemName: "doc.on.doc.fill")
                    Text("Inspect All Blend Contracts")
                }
            }
            .buttonStyle(.bordered)
            .disabled(debugViewModel.isLoading)
            
            // Quick stats
            if let result = debugViewModel.lastResult {
                HStack(spacing: 20) {
                    StatView(title: "Functions", value: "\(result.functions.count)")
                    StatView(title: "Types", value: "\(result.customTypes.structs.count + result.customTypes.enums.count)")
                    StatView(title: "Interface", value: "\(result.interfaceVersion)")
                    StatView(title: "Logs", value: "\(debugViewModel.logEntries.count)")
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Contract Explorer Tab
    
    private var contractExplorerTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if let result = debugViewModel.lastResult {
                    // Contract Overview
                    DebugSection(title: "Contract Overview", icon: "doc.text") {
                        ContractOverviewView(result: result)
                    }
                    
                    // Functions
                    DebugSection(title: "Functions (\(result.functions.count))", icon: "function") {
                        FunctionsDebugView(functions: result.functions)
                    }
                    
                    // Custom Types
                    if !result.customTypes.isEmpty {
                        DebugSection(title: "Custom Types", icon: "cube.box") {
                            CustomTypesDebugView(customTypes: result.customTypes)
                        }
                    }
                    
                    // WASM Analysis
                    if let wasmInfo = debugViewModel.wasmInfo {
                        DebugSection(title: "WASM Analysis", icon: "memorychip") {
                            WasmDebugView(wasmInfo: wasmInfo)
                        }
                    }
                    
                    // Contract Data
                    if !debugViewModel.contractData.isEmpty {
                        DebugSection(title: "Contract Data", icon: "externaldrive") {
                            ContractDataDebugView(data: debugViewModel.contractData)
                        }
                    }
                    
                } else if debugViewModel.isLoading {
                    LoadingView()
                } else {
                    EmptyStateView()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Debug Logs Tab
    
    private var debugLogsTab: some View {
        VStack(spacing: 0) {
            // Log controls
            HStack {
                Picker("Level", selection: $debugViewModel.selectedLogLevel) {
                    ForEach(SmartContractDebugLogger.LogLevel.allCases, id: \.self) { level in
                        Text("\(level.emoji) \(level.name)").tag(level)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
                
                Button("Clear") {
                    debugViewModel.clearLogs()
                }
                .buttonStyle(.bordered)
                
                Button("Export") {
                    logExportText = SmartContractDebugLogger.shared.exportLogs()
                    showingLogExport = true
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            // Log entries
            List(debugViewModel.filteredLogEntries, id: \.timestamp) { entry in
                LogEntryView(entry: entry)
            }
            .listStyle(PlainListStyle())
        }
    }
    
    // MARK: - Performance Tab
    
    private var performanceTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                DebugSection(title: "Performance Metrics", icon: "speedometer") {
                    PerformanceMetricsView(metrics: debugViewModel.performanceMetrics)
                }
                
                DebugSection(title: "Network Activity", icon: "network") {
                    NetworkActivityView(networkLogs: debugViewModel.networkLogs)
                }
                
                DebugSection(title: "Memory Usage", icon: "memorychip") {
                    MemoryUsageView()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Settings Tab
    
    private var settingsTab: some View {
        Form {
            Section("Logging Configuration") {
                Picker("Log Level", selection: $debugViewModel.logLevel) {
                    ForEach(SmartContractDebugLogger.LogLevel.allCases, id: \.self) { level in
                        Text("\(level.emoji) \(level.name)").tag(level)
                    }
                }
                
                ForEach(SmartContractDebugLogger.LogCategory.allCases, id: \.self) { category in
                    Toggle("\(category.emoji) \(category.rawValue)", isOn: Binding(
                        get: { debugViewModel.enabledCategories.contains(category) },
                        set: { enabled in
                            if enabled {
                                debugViewModel.enableCategory(category)
                            } else {
                                debugViewModel.disableCategory(category)
                            }
                        }
                    ))
                }
            }
            
            Section("Debug Options") {
                Toggle("Enable Verbose Logging", isOn: $debugViewModel.verboseLogging)
                Toggle("Auto-refresh Logs", isOn: $debugViewModel.autoRefreshLogs)
                Toggle("Performance Monitoring", isOn: $debugViewModel.performanceMonitoring)
            }
            
            Section("Actions") {
                Button("Reset All Settings") {
                    debugViewModel.resetSettings()
                }
                .foregroundColor(.red)
                
                Button("Clear All Data") {
                    debugViewModel.clearAllData()
                }
                .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Supporting Views

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DebugSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct ContractOverviewView: View {
    let result: ContractInspectionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let contractId = result.contractId {
                InfoRow(label: "Contract ID", value: contractId, isMonospace: true)
            }
            InfoRow(label: "Interface Version", value: "\(result.interfaceVersion)")
            InfoRow(label: "Functions", value: "\(result.functions.count)")
            InfoRow(label: "Custom Types", value: "\(result.customTypes.structs.count + result.customTypes.enums.count)")
            
            if !result.metadata.isEmpty {
                Divider()
                Text("Metadata")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, 4)
                
                ForEach(Array(result.metadata.keys.sorted()), id: \.self) { key in
                    InfoRow(label: key, value: result.metadata[key] ?? "")
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let isMonospace: Bool
    
    init(label: String, value: String, isMonospace: Bool = false) {
        self.label = label
        self.value = value
        self.isMonospace = isMonospace
    }
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(isMonospace ? .system(.body, design: .monospaced) : .body)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}

struct FunctionsDebugView: View {
    let functions: [ContractFunction]
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(functions, id: \.name) { function in
                VStack(alignment: .leading, spacing: 6) {
                    Text(function.name)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                    
                    if !function.inputs.isEmpty {
                        Text("Parameters:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(function.inputs, id: \.name) { param in
                            HStack {
                                Text("• \(param.name):")
                                    .font(.caption)
                                Text(param.type)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                            .padding(.leading, 8)
                        }
                    }
                    
                    if !function.outputs.isEmpty {
                        HStack {
                            Text("Returns:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(function.outputs.joined(separator: ", "))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                    
                    if let doc = function.doc, !doc.isEmpty {
                        Text(doc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

struct CustomTypesDebugView: View {
    let customTypes: ContractCustomTypes
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !customTypes.structs.isEmpty {
                Text("Structs")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(customTypes.structs, id: \.name) { struct_ in
                    StructView(struct_: struct_)
                }
            }
            
            if !customTypes.enums.isEmpty {
                Text("Enums")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(customTypes.enums, id: \.name) { enum_ in
                    EnumView(enum_: enum_)
                }
            }
        }
    }
}

struct StructView: View {
    let struct_: ContractStruct
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(struct_.name)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
            
            ForEach(struct_.fields, id: \.name) { field in
                HStack {
                    Text("• \(field.name):")
                        .font(.caption)
                    Text(field.type)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                }
                .padding(.leading, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct EnumView: View {
    let enum_: ContractEnum
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(enum_.name)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
            
            ForEach(enum_.cases, id: \.name) { case_ in
                HStack {
                    Text("• \(case_.name):")
                        .font(.caption)
                    Text("\(case_.value)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.orange)
                }
                .padding(.leading, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct WasmDebugView: View {
    let wasmInfo: WasmInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InfoRow(label: "Size", value: wasmInfo.sizeFormatted)
            InfoRow(label: "Valid", value: wasmInfo.isValid ? "✅ Yes" : "❌ No")
            InfoRow(label: "Version", value: "\(wasmInfo.version)")
            InfoRow(label: "Magic", value: wasmInfo.magicNumber, isMonospace: true)
        }
    }
}

struct ContractDataDebugView: View {
    let data: [ContractDataResult]
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(data, id: \.key) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.key)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                        Spacer()
                        Text(entry.durability == .persistent ? "Persistent" : "Temporary")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(entry.durability == .persistent ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text(entry.value)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

struct LogEntryView: View {
    let entry: SmartContractDebugLogger.LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.level.emoji)
                Text(entry.category.emoji)
                Text(entry.message)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Text(SmartContractDebugLogger.shared.dateFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let metadata = entry.metadata, !metadata.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(metadata.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text("\(key):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(metadata[key] ?? "")")
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PerformanceMetricsView: View {
    let metrics: [SmartContractDebugViewModel.PerformanceMetric]
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(metrics, id: \.operation) { metric in
                HStack {
                    Text(metric.operation)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(String(format: "%.3f", metric.duration))s")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(metric.duration > 1.0 ? .red : .green)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

struct NetworkActivityView: View {
    let networkLogs: [NetworkLog]
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(networkLogs, id: \.endpoint) { log in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.method)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text(log.endpoint)
                            .font(.system(.caption, design: .monospaced))
                        
                        Spacer()
                        
                        if let statusCode = log.statusCode {
                            Text("\(statusCode)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(statusCode >= 400 ? .red : .green)
                        }
                    }
                    
                    HStack {
                        Text("Duration: \(String(format: "%.3f", log.duration))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let size = log.responseSize {
                            Text("Size: \(ByteCountFormatter().string(fromByteCount: Int64(size)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

struct MemoryUsageView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InfoRow(label: "Memory Usage", value: "\(getMemoryUsage()) MB")
            InfoRow(label: "Log Entries", value: "\(SmartContractDebugLogger.shared.getLogEntries().count)")
        }
    }
    
    private func getMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return String(format: "%.1f", Double(info.resident_size) / 1024.0 / 1024.0)
        } else {
            return "Unknown"
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)
            
            Text("Exploring Smart Contract...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Enter a Contract ID")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Enter a smart contract ID above and tap the search button to begin exploration.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LogExportView: View {
    let logText: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(logText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
            }
            .navigationTitle("Debug Log Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Data Types

struct WasmInfo {
    let size: Int
    let sizeFormatted: String
    let isValid: Bool
    let version: UInt32
    let magicNumber: String
}

struct NetworkLog {
    let endpoint: String
    let method: String
    let statusCode: Int?
    let responseSize: Int?
    let duration: TimeInterval
} 
