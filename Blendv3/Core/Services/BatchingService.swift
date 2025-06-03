//
//  BatchingService.swift
//  Blendv3
//
//  Service for request batching and optimization
//

import Foundation
import Combine
import stellarsdk

/// Service for batching multiple requests to optimize network calls
public actor BatchingService: BatchingServiceProtocol {
    
    // MARK: - Properties
    
    private let networkService: BlendNetworkServiceProtocol
    private let diagnosticsService: DiagnosticsServiceProtocol
    
    // Batching configuration
    private var maxBatchSize: Int = 10
    private var maxWaitTime: TimeInterval = 0.5 // 500ms
    
    // Batch queue
    private var pendingRequests: [PendingRequest] = []
    private var batchTimer: Task<Void, Never>?
    
    // Statistics
    private var totalBatches: Int = 0
    private var totalRequests: Int = 0
    private var averageBatchSize: Double = 0
    
    // MARK: - Initialization
    
    public init(
        networkService: BlendNetworkServiceProtocol,
        diagnosticsService: DiagnosticsServiceProtocol
    ) {
        self.networkService = networkService
        self.diagnosticsService = diagnosticsService
        
        BlendLogger.info("BatchingService initialized", category: BlendLogger.network)
    }
    
    // MARK: - BatchingServiceProtocol
    
    public func batch<T>(_ requests: [BatchableRequest]) async throws -> [T] {
        BlendLogger.debug("Batching \(requests.count) requests", category: BlendLogger.network)
        
        let startTime = Date()
        
        // Add requests to pending queue
        let pendingBatch = requests.map { request in
            PendingRequest(
                id: UUID(),
                request: request,
                addedAt: Date()
            )
        }
        
        pendingRequests.append(contentsOf: pendingBatch)
        
        // Process batch if it meets criteria
        if shouldProcessBatch() {
            return try await processBatch()
        } else {
            // Start timer if not already running
            if batchTimer == nil {
                startBatchTimer()
            }
            
            // Wait for batch to complete
            return try await waitForBatchCompletion(pendingBatch)
        }
    }
    
    public func configureBatching(maxBatchSize: Int, maxWaitTime: TimeInterval) async {
        self.maxBatchSize = maxBatchSize
        self.maxWaitTime = maxWaitTime
        
        BlendLogger.info("Batch configuration updated: size=\(maxBatchSize), wait=\(maxWaitTime)s", 
                         category: BlendLogger.network)
    }
    
    // MARK: - Batch Processing
    
    private func shouldProcessBatch() -> Bool {
        // Process if we've reached max batch size
        if pendingRequests.count >= maxBatchSize {
            return true
        }
        
        // Process if oldest request has waited too long
        if let oldestRequest = pendingRequests.first {
            let waitTime = Date().timeIntervalSince(oldestRequest.addedAt)
            if waitTime >= maxWaitTime {
                return true
            }
        }
        
        return false
    }
    
    private func startBatchTimer() {
        batchTimer = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: UInt64(maxWaitTime * 1_000_000_000))
            
            if !Task.isCancelled && !pendingRequests.isEmpty {
                // Process batch with void return type to avoid type ambiguity
                try? await processBatchVoid()
            }
            
            batchTimer = nil
        }
    }
    
    // Non-generic version to avoid type ambiguity in timer context
    private func processBatchVoid() async throws {
        guard !pendingRequests.isEmpty else {
            return
        }
        
        // Duplicate the necessary batch processing logic to avoid generic type issues
        // Take up to maxBatchSize requests
        let batchSize = min(pendingRequests.count, maxBatchSize)
        let batch = Array(pendingRequests.prefix(batchSize))
        pendingRequests.removeFirst(batchSize)
        
        BlendLogger.info("Processing batch of \(batch.count) requests", category: BlendLogger.network)
        
        // Cancel timer if no more pending requests
        if pendingRequests.isEmpty {
            batchTimer?.cancel()
            batchTimer = nil
        }
        
        // Group requests by type for optimal batching
        let groupedRequests = Dictionary(grouping: batch) { $0.request.type }
        
        // Process each group but discard results - we're just processing the batch
        for (requestType, requests) in groupedRequests {
            try? await processRequestGroup(type: requestType, requests: requests)
        }
    }
    
    private func processBatch<T>() async throws -> [T] {
        guard !pendingRequests.isEmpty else {
            return []
        }
        
        let startTime = Date()
        
        // Take up to maxBatchSize requests
        let batchSize = min(pendingRequests.count, maxBatchSize)
        let batch = Array(pendingRequests.prefix(batchSize))
        pendingRequests.removeFirst(batchSize)
        
        BlendLogger.info("Processing batch of \(batch.count) requests", category: BlendLogger.network)
        
        // Cancel timer if no more pending requests
        if pendingRequests.isEmpty {
            batchTimer?.cancel()
            batchTimer = nil
        }
        
        // Group requests by type for optimal batching
        let groupedRequests = Dictionary(grouping: batch) { $0.request.type }
        
        var results: [UUID: Result<Any, Error>] = [:]
        
        // Process each group
        for (requestType, requests) in groupedRequests {
            do {
                let groupResults = try await processRequestGroup(type: requestType, requests: requests)
                for (id, result) in groupResults {
                    results[id] = .success(result)
                }
            } catch {
                // If group fails, mark all requests in group as failed
                for request in requests {
                    results[request.id] = .failure(error)
                }
            }
        }
        
        // Update statistics
        updateStatistics(batchSize: batch.count, duration: Date().timeIntervalSince(startTime))
        
        // Log batch completion
        await diagnosticsService.trackOperationTiming(
            operation: "batch_processing",
            duration: Date().timeIntervalSince(startTime)
        )
        
        // Extract results in order
        let orderedResults: [T] = try batch.map { pendingRequest in
            guard let result = results[pendingRequest.id] else {
                throw BlendError.batch(.requestNotFound)
            }
            
            switch result {
            case .success(let value):
                guard let typedValue = value as? T else {
                    throw BlendError.batch(.typeMismatch)
                }
                return typedValue
            case .failure(let error):
                throw error
            }
        }
        
        return orderedResults
    }
    
    private func processRequestGroup(
        type: BatchableRequestType,
        requests: [PendingRequest]
    ) async throws -> [UUID: Any] {
        switch type {
        case .getLedgerEntry:
            return try await processLedgerEntryBatch(requests)
        case .getAccount:
            return try await processAccountBatch(requests)
        case .simulateTransaction:
            return try await processSimulationBatch(requests)
        case .custom(let handler):
            return try await handler(requests.map { $0.request })
        }
    }
    
    private func processLedgerEntryBatch(_ requests: [PendingRequest]) async throws -> [UUID: Any] {
        // Extract keys from all requests
        let keys = requests.compactMap { request -> String? in
            guard case .getLedgerEntry(let key) = request.request.type else { return nil }
            return key
        }
        
        // Make single batched call
        let entries: [String: Any] = try await networkService.getLedgerEntries(keys: keys)
        
        // Map results back to request IDs
        var results: [UUID: Any] = [:]
        for request in requests {
            guard case .getLedgerEntry(let key) = request.request.type else { continue }
            if let entry = entries[key] {
                results[request.id] = entry
            }
        }
        
        return results
    }
    
    private func processAccountBatch(_ requests: [PendingRequest]) async throws -> [UUID: Any] {
        // For accounts, we might need to make individual calls
        // but we can do them concurrently
        var results: [UUID: Any] = [:]
        
        await withTaskGroup(of: (UUID, Result<Any, Error>).self) { group in
            for request in requests {
                guard case .getAccount(let accountId) = request.request.type else { continue }
                
                group.addTask {
                    do {
                        let account = try await self.networkService.getAccount(accountId: accountId)
                        return (request.id, .success(account))
                    } catch {
                        return (request.id, .failure(error))
                    }
                }
            }
            
            for await (id, result) in group {
                switch result {
                case .success(let value):
                    results[id] = value
                case .failure:
                    // Error handling done at higher level
                    break
                }
            }
        }
        
        return results
    }
    
    private func processSimulationBatch(_ requests: [PendingRequest]) async throws -> [UUID: Any] {
        // Similar to accounts, simulations are processed concurrently
        var results: [UUID: Any] = [:]
        
        await withTaskGroup(of: (UUID, Result<Any, Error>).self) { group in
            for request in requests {
                guard case .simulateTransaction(let operation) = request.request.type else { continue }
                
                group.addTask {
                    do {
                        let result = try await self.networkService.simulateOperation(operation)
                        return (request.id, .success(result))
                    } catch {
                        return (request.id, .failure(error))
                    }
                }
            }
            
            for await (id, result) in group {
                switch result {
                case .success(let value):
                    results[id] = value
                case .failure:
                    // Error handling done at higher level
                    break
                }
            }
        }
        
        return results
    }
    
    private func waitForBatchCompletion<T>(_ batch: [PendingRequest]) async throws -> [T] {
        // Wait for batch to be processed
        let checkInterval: TimeInterval = 0.05 // 50ms
        let maxWaitTime: TimeInterval = 10.0 // 10 seconds timeout
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < maxWaitTime {
            // Check if our requests are still pending
            let stillPending = batch.contains { request in
                pendingRequests.contains { $0.id == request.id }
            }
            
            if !stillPending {
                // Our batch has been processed
                break
            }
            
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
        
        throw BlendError.batch(.timeout)
    }
    
    // MARK: - Statistics
    
    private func updateStatistics(batchSize: Int, duration: TimeInterval) {
        totalBatches += 1
        totalRequests += batchSize
        
        // Update rolling average
        let currentAverage = averageBatchSize
        averageBatchSize = (currentAverage * Double(totalBatches - 1) + Double(batchSize)) / Double(totalBatches)
        
        BlendLogger.debug("""
            Batch statistics:
            - Total batches: \(totalBatches)
            - Total requests: \(totalRequests)
            - Average batch size: \(String(format: "%.1f", averageBatchSize))
            - Last batch duration: \(String(format: "%.3f", duration))s
            """, category: BlendLogger.network)
    }
    
    public func getStatistics() -> BatchingStatistics {
        return BatchingStatistics(
            totalBatches: totalBatches,
            totalRequests: totalRequests,
            averageBatchSize: averageBatchSize,
            pendingRequests: pendingRequests.count,
            maxBatchSize: maxBatchSize,
            maxWaitTime: maxWaitTime
        )
    }
}

// MARK: - Supporting Types

private struct PendingRequest {
    let id: UUID
    let request: BatchableRequest
    let addedAt: Date
}

public struct BatchableRequest {
    public let type: BatchableRequestType
    public let priority: RequestPriority
    
    public init(type: BatchableRequestType, priority: RequestPriority = .normal) {
        self.type = type
        self.priority = priority
    }
}

public enum BatchableRequestType: Hashable {
    case getLedgerEntry(key: String)
    case getAccount(accountId: String)
    case simulateTransaction(operation: stellarsdk.Operation)
    case custom(handler: ([BatchableRequest]) async throws -> [UUID: Any])
    
    public static func == (lhs: BatchableRequestType, rhs: BatchableRequestType) -> Bool {
        switch (lhs, rhs) {
        case (.getLedgerEntry(let lKey), .getLedgerEntry(let rKey)):
            return lKey == rKey
        case (.getAccount(let lId), .getAccount(let rId)):
            return lId == rId
        case (.simulateTransaction, .simulateTransaction):
            // Can't compare operations directly, so we consider them equal if they're both simulation requests
            // This is a simplification for hashability
            return true
        case (.custom, .custom):
            // Can't compare functions directly, use pointer equality
            return false // Always treat custom handlers as different
        default:
            return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .getLedgerEntry(let key):
            hasher.combine(0) // Type discriminator
            hasher.combine(key)
        case .getAccount(let accountId):
            hasher.combine(1) // Type discriminator
            hasher.combine(accountId)
        case .simulateTransaction:
            hasher.combine(2) // Type discriminator
            // Can't hash Operation directly
        case .custom:
            hasher.combine(3) // Type discriminator
            // Can't hash functions directly
        }
    }
}

public enum RequestPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    public static func < (lhs: RequestPriority, rhs: RequestPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public struct BatchingStatistics {
    public let totalBatches: Int
    public let totalRequests: Int
    public let averageBatchSize: Double
    public let pendingRequests: Int
    public let maxBatchSize: Int
    public let maxWaitTime: TimeInterval
}

// MARK: - Errors

extension BlendError {
    public enum BatchError: LocalizedError {
        case requestNotFound
        case typeMismatch
        case timeout
        case batchFailed
        
        public var errorDescription: String? {
            switch self {
            case .requestNotFound:
                return "Request not found in batch results"
            case .typeMismatch:
                return "Result type does not match expected type"
            case .timeout:
                return "Batch processing timeout"
            case .batchFailed:
                return "Batch processing failed"
            }
        }
    }
    
    public static func batch(_ error: BatchError) -> BlendError {
        switch error {
        case .requestNotFound:
            return .initialization("Request not found in batch results")
        case .typeMismatch:
            return .validation(.invalidResponse)
        case .timeout:
            return .network(.timeout)
        case .batchFailed:
            return .unknown
        }
    }
} 