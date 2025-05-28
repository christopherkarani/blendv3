//
//  DiagnosticsService.swift
//  Blendv3
//
//  Service for diagnostics, monitoring, and health checks
//

//import Foundation
//import Combine
//import os.log
//
///// Service for diagnostics, monitoring, and health checks
//public actor DiagnosticsService: DiagnosticsServiceProtocol {
//    
//    // MARK: - Properties
//    
//    private let logger = Logger(subsystem: "com.blendv3.diagnostics", category: "Diagnostics")
//    
//    // Event storage
//    private var networkEvents: [NetworkEvent] = []
//    private var transactionEvents: [TransactionEvent] = []
//    private let maxEventCount = 1000
//    
//    // Performance metrics
//    private var performanceMetrics = PerformanceMetrics()
//    private var operationTimings: [String: [TimeInterval]] = [:]
//    
//    // Health check state
//    private var lastHealthCheck: HealthCheckResult?
//    private var healthCheckInterval: TimeInterval = 60.0 // 1 minute
//    private var healthCheckTask: Task<Void, Never>?
//    
//    // Publishers
//    private let healthStatusSubject = CurrentValueSubject<HealthStatus, Never>(.unknown)
//    public nonisolated var healthStatusPublisher: AnyPublisher<HealthStatus, Never> {
//        healthStatusSubject.eraseToAnyPublisher()
//    }
//    
//    // MARK: - Initialization
//    
//    public init() {
//        logger.info("DiagnosticsService initialized")
//        startHealthMonitoring()
//    }
//    
//    deinit {
//        healthCheckTask?.cancel()
//    }
//    
//    // MARK: - DiagnosticsServiceProtocol
//    
//    public func logNetworkEvent(_ event: NetworkEvent) {
//        logger.debug("Network event: \(event.type.rawValue) - \(event.endpoint)")
//        
//        networkEvents.append(event)
//        
//        // Trim events if needed
//        if networkEvents.count > maxEventCount {
//            networkEvents.removeFirst(networkEvents.count - maxEventCount)
//        }
//        
//        // Update metrics
//        updateNetworkMetrics(for: event)
//    }
//    
//    public func logTransactionEvent(_ event: TransactionEvent) {
//        logger.info("Transaction event: \(event.type.rawValue) - \(event.transactionId ?? "unknown")")
//        
//        transactionEvents.append(event)
//        
//        // Trim events if needed
//        if transactionEvents.count > maxEventCount {
//            transactionEvents.removeFirst(transactionEvents.count - maxEventCount)
//        }
//        
//        // Update metrics
//        updateTransactionMetrics(for: event)
//    }
//    
//    public func performHealthCheck() async -> HealthCheckResult {
//        logger.info("Performing health check")
//        
//        let startTime = Date()
//        var checks: [HealthCheck] = []
//        
//        // Network connectivity check
//        let networkCheck = await checkNetworkConnectivity()
//        checks.append(networkCheck)
//        
//        // Memory usage check
//        let memoryCheck = checkMemoryUsage()
//        checks.append(memoryCheck)
//        
//        // Performance check
//        let performanceCheck = checkPerformance()
//        checks.append(performanceCheck)
//        
//        // Error rate check
//        let errorRateCheck = checkErrorRate()
//        checks.append(errorRateCheck)
//        
//        // Calculate overall status
//        let overallStatus = calculateOverallStatus(from: checks)
//        
//        let result = HealthCheckResult(
//            timestamp: Date(),
//            status: overallStatus,
//            checks: checks,
//            duration: Date().timeIntervalSince(startTime)
//        )
//        
//        lastHealthCheck = result
//        healthStatusSubject.send(overallStatus)
//        
//        logger.info("Health check completed: \(overallStatus.rawValue)")
//        
//        return result
//    }
//    
//    nonisolated public func getPerformanceMetrics() -> PerformanceMetrics {
//        return performanceMetrics
//    }
//    
//    // MARK: - Performance Tracking
//    
//    public func trackOperationTiming(operation: String, duration: TimeInterval) {
//        logger.debug("Operation '\(operation)' completed in \(String(format: "%.3f", duration))s")
//        
//        if operationTimings[operation] == nil {
//            operationTimings[operation] = []
//        }
//        
//        operationTimings[operation]?.append(duration)
//        
//        // Keep only last 100 timings per operation
//        if let count = operationTimings[operation]?.count, count > 100 {
//            operationTimings[operation]?.removeFirst(count - 100)
//        }
//        
//        // Update average timing
//        updateAverageTimings()
//    }
//    
//    // MARK: - Event Analysis
//    
//    public func getRecentNetworkEvents(count: Int = 50) -> [NetworkEvent] {
//        return Array(networkEvents.suffix(count))
//    }
//    
//    public func getRecentTransactionEvents(count: Int = 50) -> [TransactionEvent] {
//        return Array(transactionEvents.suffix(count))
//    }
//    
//    public func getErrorSummary() -> ErrorSummary {
//        let recentWindow = Date().addingTimeInterval(-300) // Last 5 minutes
//        
//        let recentNetworkErrors = networkEvents
//            .filter { $0.timestamp > recentWindow && $0.error != nil }
//        
//        let recentTransactionErrors = transactionEvents
//            .filter { $0.timestamp > recentWindow && !$0.success }
//        
//        let errorsByType = Dictionary(grouping: recentNetworkErrors) { event in
//            event.error?.localizedDescription ?? "Unknown"
//        }.mapValues { $0.count }
//        
//        return ErrorSummary(
//            totalErrors: recentNetworkErrors.count + recentTransactionErrors.count,
//            networkErrors: recentNetworkErrors.count,
//            transactionErrors: recentTransactionErrors.count,
//            errorsByType: errorsByType,
//            timeWindow: 300
//        )
//    }
//    
//    // MARK: - Private Methods
//    
//    private func startHealthMonitoring() {
//        healthCheckTask = Task {
//            while !Task.isCancelled {
//                _ = await performHealthCheck()
//                try? await Task.sleep(nanoseconds: UInt64(healthCheckInterval * 1_000_000_000))
//            }
//        }
//    }
//    
//    private func checkNetworkConnectivity() async -> HealthCheck {
//        // Check recent network events for connectivity issues
//        let recentEvents = networkEvents.suffix(10)
//        let failureCount = recentEvents.filter { $0.error != nil }.count
//        
//        let status: HealthStatus = failureCount == 0 ? .healthy : 
//                                  failureCount < 3 ? .degraded : .unhealthy
//        
//        return HealthCheck(
//            name: "Network Connectivity",
//            status: status,
//            message: failureCount == 0 ? "All recent requests successful" : 
//                    "\(failureCount) failures in last 10 requests",
//            details: ["failure_count": failureCount]
//        )
//    }
//    
//    private func checkMemoryUsage() -> HealthCheck {
//        let memoryUsage = getMemoryUsage()
//        let usagePercentage = Double(memoryUsage.used) / Double(memoryUsage.total) * 100
//        
//        let status: HealthStatus = usagePercentage < 70 ? .healthy :
//                                  usagePercentage < 85 ? .degraded : .unhealthy
//        
//        return HealthCheck(
//            name: "Memory Usage",
//            status: status,
//            message: String(format: "%.1f%% memory used", usagePercentage),
//            details: [
//                "used_bytes": memoryUsage.used,
//                "total_bytes": memoryUsage.total,
//                "percentage": usagePercentage
//            ]
//        )
//    }
//    
//    private func checkPerformance() -> HealthCheck {
//        let avgResponseTime = performanceMetrics.averageResponseTime
//        
//        let status: HealthStatus = avgResponseTime < 1.0 ? .healthy :
//                                  avgResponseTime < 3.0 ? .degraded : .unhealthy
//        
//        return HealthCheck(
//            name: "Performance",
//            status: status,
//            message: String(format: "Average response time: %.2fs", avgResponseTime),
//            details: [
//                "avg_response_time": avgResponseTime,
//                "total_requests": performanceMetrics.totalRequests
//            ]
//        )
//    }
//    
//    private func checkErrorRate() -> HealthCheck {
//        let errorSummary = getErrorSummary()
//        let errorRate = performanceMetrics.totalRequests > 0 ?
//            Double(errorSummary.totalErrors) / Double(performanceMetrics.totalRequests) * 100 : 0
//        
//        let status: HealthStatus = errorRate < 1 ? .healthy :
//                                  errorRate < 5 ? .degraded : .unhealthy
//        
//        return HealthCheck(
//            name: "Error Rate",
//            status: status,
//            message: String(format: "%.1f%% error rate", errorRate),
//            details: [
//                "error_rate": errorRate,
//                "total_errors": errorSummary.totalErrors
//            ]
//        )
//    }
//    
//    private func calculateOverallStatus(from checks: [HealthCheck]) -> HealthStatus {
//        if checks.contains(where: { $0.status == .unhealthy }) {
//            return .unhealthy
//        } else if checks.contains(where: { $0.status == .degraded }) {
//            return .degraded
//        } else {
//            return .healthy
//        }
//    }
//    
//    private func updateNetworkMetrics(for event: NetworkEvent) {
//        performanceMetrics.totalRequests += 1
//        
//        if let duration = event.duration {
//            performanceMetrics.totalResponseTime += duration
//            performanceMetrics.averageResponseTime = 
//                performanceMetrics.totalResponseTime / Double(performanceMetrics.totalRequests)
//        }
//        
//        if event.error != nil {
//            performanceMetrics.totalErrors += 1
//        }
//    }
//    
//    private func updateTransactionMetrics(for event: TransactionEvent) {
//        if event.success {
//            performanceMetrics.successfulTransactions += 1
//        } else {
//            performanceMetrics.failedTransactions += 1
//        }
//    }
//    
//    private func updateAverageTimings() {
//        var timings: [String: Double] = [:]
//        
//        for (operation, durations) in operationTimings {
//            if !durations.isEmpty {
//                let average = durations.reduce(0, +) / Double(durations.count)
//                timings[operation] = average
//            }
//        }
//        
//        performanceMetrics.averageOperationTimings = timings
//    }
//    
//    private func getMemoryUsage() -> (used: Int64, total: Int64) {
//        var info = mach_task_basic_info()
//        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
//        
//        let result = withUnsafeMutablePointer(to: &info) {
//            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
//                task_info(mach_task_self_,
//                         task_flavor_t(MACH_TASK_BASIC_INFO),
//                         $0,
//                         &count)
//            }
//        }
//        
//        if result == KERN_SUCCESS {
//            let usedMemory = Int64(info.resident_size)
//            let totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)
//            return (usedMemory, totalMemory)
//        }
//        
//        return (0, 0)
//    }
//}
//
//// MARK: - Supporting Types
//
//public struct NetworkEvent {
//    public let id = UUID()
//    public let timestamp = Date()
//    public let type: NetworkEventType
//    public let endpoint: String
//    public let method: String?
//    public let statusCode: Int?
//    public let duration: TimeInterval?
//    public let error: Error?
//    
//    public enum NetworkEventType: String {
//        case request
//        case response
//        case error
//        case timeout
//    }
//}
//
//public struct TransactionEvent {
//    public let id = UUID()
//    public let timestamp = Date()
//    public let type: TransactionEventType
//    public let transactionId: String?
//    public let operation: String
//    public let success: Bool
//    public let error: Error?
//    public let gasUsed: Int64?
//    
//    public enum TransactionEventType: String {
//        case submitted
//        case confirmed
//        case failed
//        case simulated
//    }
//}
//
//public struct HealthCheckResult {
//    public let timestamp: Date
//    public let status: HealthStatus
//    public let checks: [HealthCheck]
//    public let duration: TimeInterval
//}
//
//public struct HealthCheck {
//    public let name: String
//    public let status: HealthStatus
//    public let message: String
//    public let details: [String: Any]
//}
//
//public enum HealthStatus: String {
//    case healthy
//    case degraded
//    case unhealthy
//    case unknown
//}
//
//public struct DGNPerformanceMetrics {
//    public var totalRequests: Int = 0
//    public var totalErrors: Int = 0
//    public var totalResponseTime: TimeInterval = 0
//    public var averageResponseTime: TimeInterval = 0
//    public var successfulTransactions: Int = 0
//    public var failedTransactions: Int = 0
//    public var averageOperationTimings: [String: TimeInterval] = [:]
//}
//
//public struct ErrorSummary {
//    public let totalErrors: Int
//    public let networkErrors: Int
//    public let transactionErrors: Int
//    public let errorsByType: [String: Int]
//    public let timeWindow: TimeInterval
//} 
