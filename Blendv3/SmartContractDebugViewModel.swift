import Foundation
import SwiftUI
import stellarsdk
import Combine

/// ViewModel for the Smart Contract Debug View
/// Manages state, logging, and data for the debug interface
@MainActor
class SmartContractDebugViewModel: ObservableObject {
    
    // MARK: - Nested Types
    
    /// Performance metric data structure for tracking operation performance
    struct PerformanceMetric {
        let operation: String
        let duration: TimeInterval
        let metadata: [String: Any]?
    }
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var lastResult: ContractInspectionResult?
    @Published var wasmInfo: WasmInfo?
    @Published var contractData: [ContractDataResult] = []
    @Published var logEntries: [SmartContractDebugLogger.LogEntry] = []
    @Published var performanceMetrics: [PerformanceMetric] = []
    @Published var networkLogs: [NetworkLog] = []
    @Published var errorMessage: String?
    
    // MARK: - Settings
    
    @Published var logLevel: SmartContractDebugLogger.LogLevel = .debug {
        didSet {
            SmartContractDebugLogger.shared.setLogLevel(logLevel)
            refreshLogEntries()
        }
    }
    
    @Published var selectedLogLevel: SmartContractDebugLogger.LogLevel = .debug {
        didSet {
            refreshLogEntries()
        }
    }
    
    @Published var enabledCategories: Set<SmartContractDebugLogger.LogCategory> = Set(SmartContractDebugLogger.LogCategory.allCases) {
        didSet {
            refreshLogEntries()
        }
    }
    
    @Published var verboseLogging = false {
        didSet {
            if verboseLogging {
                SmartContractDebugLogger.shared.setLogLevel(.verbose)
            } else {
                SmartContractDebugLogger.shared.setLogLevel(.debug)
            }
        }
    }
    
    @Published var autoRefreshLogs = true
    @Published var performanceMonitoring = true
    
    // MARK: - Private Properties
    
    private lazy var inspector = SmartContractInspector(
        rpcEndpoint: "https://soroban-testnet.stellar.org",
        network: Network.testnet
    )
    
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var filteredLogEntries: [SmartContractDebugLogger.LogEntry] {
        SmartContractDebugLogger.shared.getLogEntries(
            level: selectedLogLevel,
            category: nil,
            limit: 100
        ).filter { entry in
            enabledCategories.contains(entry.category)
        }
    }
    
    // MARK: - Initialization
    
    init() {
        setupLogging()
        setupAutoRefresh()
        
        // Initial log refresh
        refreshLogEntries()
        
        debugLog("SmartContractDebugViewModel initialized", category: .ui)
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Setup Methods
    
    private func setupLogging() {
        // Configure the logger
        SmartContractDebugLogger.shared.setLogLevel(logLevel)
        SmartContractDebugLogger.shared.enableAllCategories()
        
        infoLog("Debug logging configured", category: .ui, metadata: [
            "logLevel": logLevel.name,
            "enabledCategories": enabledCategories.count
        ])
    }
    
    private func setupAutoRefresh() {
        // Auto-refresh logs every 2 seconds if enabled
        $autoRefreshLogs
            .sink { [weak self] autoRefresh in
                self?.refreshTimer?.invalidate()
                if autoRefresh {
                    self?.refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                        Task { @MainActor in
                            self?.refreshLogEntries()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Contract Exploration
    
    func exploreContract(_ contractId: String) async {
        guard !contractId.isEmpty else {
            errorMessage = "Contract ID cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let startTime = Date()
        
        SmartContractDebugLogger.shared.logContractInspectionStart(contractId)
        
        do {
            // Clear previous data
            wasmInfo = nil
            contractData.removeAll()
            
            // Inspect the contract
            let result = try await inspector.inspectContract(contractId: contractId)
            
            // Update the result
            lastResult = result
            
            // Log success
            let duration = Date().timeIntervalSince(startTime)
            let typesCount = result.customTypes.structs.count + 
                           result.customTypes.enums.count + 
                           result.customTypes.unions.count + 
                           result.customTypes.errors.count
            
            SmartContractDebugLogger.shared.logContractInspectionSuccess(
                contractId,
                functionsCount: result.functions.count,
                typesCount: typesCount,
                duration: duration
            )
            
            // Record performance metric
            if performanceMonitoring {
                recordPerformanceMetric(
                    operation: "Contract Inspection",
                    duration: duration,
                    metadata: [
                        "contractId": contractId,
                        "functionsCount": result.functions.count,
                        "typesCount": typesCount
                    ]
                )
            }
            
            // Analyze WASM binary
            await analyzeWasmBinary(contractId)
            
            // Explore contract data
            await exploreContractData(contractId)
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            SmartContractDebugLogger.shared.logContractInspectionFailure(contractId, error: error, duration: duration)
            
            errorMessage = "Failed to inspect contract: \(error.localizedDescription)"
            
            errorLog("Contract exploration failed", category: .contract, metadata: [
                "contractId": contractId,
                "error": error.localizedDescription,
                "duration": String(format: "%.3f", duration)
            ])
        }
        
        isLoading = false
        refreshLogEntries()
    }
    
    private func analyzeWasmBinary(_ contractId: String) async {
        let startTime = Date()
        
        do {
            debugLog("Starting WASM binary analysis", category: .wasm, metadata: ["contractId": contractId])
            
            let wasmData = try await inspector.getContractWasmBinary(contractId: contractId)
            
            // Analyze WASM header
            let isValid = wasmData.count >= 8 && wasmData.prefix(4).elementsEqual([0x00, 0x61, 0x73, 0x6d])
            let version: UInt32
            let magicNumber: String
            
            if wasmData.count >= 8 {
                let versionBytes = Array(wasmData.dropFirst(4).prefix(4))
                version = UInt32(versionBytes[0]) | 
                         (UInt32(versionBytes[1]) << 8) | 
                         (UInt32(versionBytes[2]) << 16) | 
                         (UInt32(versionBytes[3]) << 24)
                magicNumber = wasmData.prefix(4).map { String(format: "%02x", $0) }.joined(separator: " ")
            } else {
                version = 0
                magicNumber = "Invalid"
            }
            
            wasmInfo = WasmInfo(
                size: wasmData.count,
                sizeFormatted: ByteCountFormatter().string(fromByteCount: Int64(wasmData.count)),
                isValid: isValid,
                version: version,
                magicNumber: magicNumber
            )
            
            SmartContractDebugLogger.shared.logWasmAnalysis(contractId, wasmSize: wasmData.count, isValid: isValid)
            
            let duration = Date().timeIntervalSince(startTime)
            if performanceMonitoring {
                recordPerformanceMetric(
                    operation: "WASM Analysis",
                    duration: duration,
                    metadata: [
                        "contractId": contractId,
                        "wasmSize": wasmData.count,
                        "isValid": isValid
                    ]
                )
            }
            
        } catch {
            errorLog("WASM binary analysis failed", category: .wasm, metadata: [
                "contractId": contractId,
                "error": error.localizedDescription
            ])
        }
    }
    
    private func exploreContractData(_ contractId: String) async {
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
        
        var foundData: [ContractDataResult] = []
        
        for key in commonKeys {
            do {
                let keyString = extractSymbolString(from: key)
                
                debugLog("Querying contract data", category: .data, metadata: [
                    "contractId": contractId,
                    "key": keyString
                ])
                
                let dataResult = try await inspector.getContractData(
                    contractId: contractId,
                    key: key,
                    durability: .persistent
                )
                
                foundData.append(dataResult)
                SmartContractDebugLogger.shared.logDataQuery(contractId, key: keyString, found: true)
                
            } catch {
                let keyString = extractSymbolString(from: key)
                SmartContractDebugLogger.shared.logDataQuery(contractId, key: keyString, found: false)
                // Continue silently - most keys won't exist
            }
        }
        
        contractData = foundData
        
        infoLog("Contract data exploration completed", category: .data, metadata: [
            "contractId": contractId,
            "foundEntries": foundData.count
        ])
    }
    
    private func extractSymbolString(from scVal: SCValXDR) -> String {
        switch scVal {
        case .symbol(let symbol):
            return symbol
        default:
            return "unknown"
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func recordPerformanceMetric(operation: String, duration: TimeInterval, metadata: [String: Any]? = nil) {
        let metric = PerformanceMetric(
            operation: operation,
            duration: duration,
            metadata: metadata
        )
        
        performanceMetrics.append(metric)
        
        // Keep only last 50 metrics
        if performanceMetrics.count > 50 {
            performanceMetrics.removeFirst(performanceMetrics.count - 50)
        }
        
        SmartContractDebugLogger.shared.logPerformanceMetric(operation, duration: duration, metadata: metadata)
    }
    
    private func recordNetworkActivity(endpoint: String, method: String = "GET", statusCode: Int? = nil, responseSize: Int? = nil, duration: TimeInterval) {
        let networkLog = NetworkLog(
            endpoint: endpoint,
            method: method,
            statusCode: statusCode,
            responseSize: responseSize,
            duration: duration
        )
        
        networkLogs.append(networkLog)
        
        // Keep only last 20 network logs
        if networkLogs.count > 20 {
            networkLogs.removeFirst(networkLogs.count - 20)
        }
        
        SmartContractDebugLogger.shared.logNetworkResponse(endpoint, statusCode: statusCode, responseSize: responseSize, duration: duration)
    }
    
    // MARK: - Log Management
    
    func refreshLogEntries() {
        logEntries = SmartContractDebugLogger.shared.getLogEntries(limit: 200)
    }
    
    func clearLogs() {
        SmartContractDebugLogger.shared.clearLogs()
        refreshLogEntries()
    }
    
    func enableCategory(_ category: SmartContractDebugLogger.LogCategory) {
        enabledCategories.insert(category)
        SmartContractDebugLogger.shared.enableCategory(category)
    }
    
    func disableCategory(_ category: SmartContractDebugLogger.LogCategory) {
        enabledCategories.remove(category)
        SmartContractDebugLogger.shared.disableCategory(category)
    }
    
    // MARK: - Settings Management
    
    func resetSettings() {
        logLevel = .debug
        selectedLogLevel = .debug
        enabledCategories = Set(SmartContractDebugLogger.LogCategory.allCases)
        verboseLogging = false
        autoRefreshLogs = true
        performanceMonitoring = true
        
        SmartContractDebugLogger.shared.setLogLevel(.debug)
        SmartContractDebugLogger.shared.enableAllCategories()
        
        infoLog("Debug settings reset to defaults", category: .ui)
    }
    
    func clearAllData() {
        lastResult = nil
        wasmInfo = nil
        contractData.removeAll()
        performanceMetrics.removeAll()
        networkLogs.removeAll()
        errorMessage = nil
        
        SmartContractDebugLogger.shared.clearLogs()
        refreshLogEntries()
        
        infoLog("All debug data cleared", category: .ui)
    }
    
    // MARK: - Export Functions
    
    func exportDebugReport() -> String {
        var report = "Smart Contract Debug Report\n"
        report += "Generated: \(Date())\n"
        report += "═══════════════════════════════\n\n"
        
        // Contract Information
        if let result = lastResult {
            report += "CONTRACT INFORMATION\n"
            report += "─────────────────────\n"
            if let contractId = result.contractId {
                report += "Contract ID: \(contractId)\n"
            }
            report += "Interface Version: \(result.interfaceVersion)\n"
            report += "Functions: \(result.functions.count)\n"
            report += "Custom Types: \(result.customTypes.structs.count + result.customTypes.enums.count)\n\n"
            
            // Functions
            report += "FUNCTIONS\n"
            report += "─────────\n"
            for function in result.functions {
                report += "• \(function.name)("
                report += function.inputs.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
                report += ")"
                if !function.outputs.isEmpty {
                    report += " → \(function.outputs.joined(separator: ", "))"
                }
                report += "\n"
            }
            report += "\n"
        }
        
        // WASM Information
        if let wasmInfo = wasmInfo {
            report += "WASM ANALYSIS\n"
            report += "─────────────\n"
            report += "Size: \(wasmInfo.sizeFormatted)\n"
            report += "Valid: \(wasmInfo.isValid ? "Yes" : "No")\n"
            report += "Version: \(wasmInfo.version)\n"
            report += "Magic: \(wasmInfo.magicNumber)\n\n"
        }
        
        // Performance Metrics
        if !performanceMetrics.isEmpty {
            report += "PERFORMANCE METRICS\n"
            report += "───────────────────\n"
            for metric in performanceMetrics.suffix(10) {
                report += "• \(metric.operation): \(String(format: "%.3f", metric.duration))s\n"
            }
            report += "\n"
        }
        
        // Debug Logs
        report += "DEBUG LOGS\n"
        report += "──────────\n"
        let recentLogs = SmartContractDebugLogger.shared.getLogEntries(limit: 50)
        for entry in recentLogs {
            report += entry.formattedMessage + "\n"
        }
        
        return report
    }
    
    // MARK: - Utility Functions
    
    func getLogSummary() -> String {
        return SmartContractDebugLogger.shared.getLogSummary()
    }
} 