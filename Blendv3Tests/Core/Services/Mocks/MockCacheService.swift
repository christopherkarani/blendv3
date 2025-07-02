import Foundation
@testable import Blendv3

/// Comprehensive mock implementation of CacheServiceProtocol for testing
/// Provides thread-safe operations, call tracking, and configurable behavior
actor MockCacheService: CacheServiceProtocol {
    
    // MARK: - Storage
    
    private var storage: [String: CacheEntry] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Call Tracking Properties (Thread-Safe)
    
    private(set) var getCalled: Bool = false
    private(set) var setCalled: Bool = false
    private(set) var removeCalled: Bool = false
    private(set) var clearCalled: Bool = false
    
    private(set) var getCallCount: Int = 0
    private(set) var setCallCount: Int = 0
    private(set) var removeCallCount: Int = 0
    private(set) var clearCallCount: Int = 0
    
    private(set) var lastGetKey: String?
    private(set) var lastSetKey: String?
    private(set) var lastRemoveKey: String?
    
    // Track all operations for detailed analysis
    private(set) var allOperations: [CacheOperation] = []
    
    // MARK: - Configuration Properties
    
    private var simulateLatency: Bool = false
    private var latencyDuration: TimeInterval = 0.01 // 10ms default
    private var shouldFailOperations: Bool = false
    private var failureRate: Double = 0.0 // 0.0 = never fail, 1.0 = always fail
    
    // MARK: - Thread Safety Validation
    
    private var concurrentOperationCount: Int = 0
    private var maxConcurrentOperations: Int = 0
    
    /// Indicates if the cache service is handling concurrent operations safely
    var isThreadSafe: Bool {
        // This is a simple heuristic - in a real implementation, you'd have more sophisticated checks
        return maxConcurrentOperations <= 10 // Reasonable concurrency level
    }
    
    // MARK: - CacheServiceProtocol Implementation
    
    func get<T: Codable>(_ key: String, type: T.Type) async -> T? {
        await trackOperation(.get(key: key))
        await simulateLatencyIfEnabled()
        
        getCalled = true
        getCallCount += 1
        lastGetKey = key
        
        concurrentOperationCount += 1
        maxConcurrentOperations = max(maxConcurrentOperations, concurrentOperationCount)
        defer { concurrentOperationCount -= 1 }
        
        if await shouldSimulateFailure() {
            return nil
        }
        
        guard let entry = storage[key] else {
            return nil
        }
        
        // Check if entry has expired
        if entry.expirationDate <= Date() {
            storage.removeValue(forKey: key)
            return nil
        }
        
        // Attempt to decode the stored data
        do {
            return try decoder.decode(T.self, from: entry.data)
        } catch {
            // If decoding fails, remove the corrupted entry
            storage.removeValue(forKey: key)
            return nil
        }
    }
    
    func set<T: Codable>(_ value: T, key: String, ttl: TimeInterval) async {
        await trackOperation(.set(key: key, ttl: ttl))
        await simulateLatencyIfEnabled()
        
        setCalled = true
        setCallCount += 1
        lastSetKey = key
        
        concurrentOperationCount += 1
        maxConcurrentOperations = max(maxConcurrentOperations, concurrentOperationCount)
        defer { concurrentOperationCount -= 1 }
        
        if await shouldSimulateFailure() {
            return
        }
        
        do {
            let data = try encoder.encode(value)
            let expirationDate: Date
            
            if ttl == TimeInterval.infinity {
                expirationDate = Date.distantFuture
            } else {
                expirationDate = Date().addingTimeInterval(ttl)
            }
            
            let entry = CacheEntry(data: data, expirationDate: expirationDate, createdAt: Date())
            storage[key] = entry
        } catch {
            // Silently fail encoding errors in mock (real implementation might log)
        }
    }
    
    func remove(_ key: String) async {
        await trackOperation(.remove(key: key))
        await simulateLatencyIfEnabled()
        
        removeCalled = true
        removeCallCount += 1
        lastRemoveKey = key
        
        concurrentOperationCount += 1
        maxConcurrentOperations = max(maxConcurrentOperations, concurrentOperationCount)
        defer { concurrentOperationCount -= 1 }
        
        if await shouldSimulateFailure() {
            return
        }
        
        storage.removeValue(forKey: key)
    }
    
    func clear() async {
        await trackOperation(.clear)
        await simulateLatencyIfEnabled()
        
        clearCalled = true
        clearCallCount += 1
        
        concurrentOperationCount += 1
        maxConcurrentOperations = max(maxConcurrentOperations, concurrentOperationCount)
        defer { concurrentOperationCount -= 1 }
        
        if await shouldSimulateFailure() {
            return
        }
        
        storage.removeAll()
    }
    
    // MARK: - Mock Configuration Methods
    
    /// Enable/disable simulated network latency
    func setLatencySimulation(enabled: Bool, duration: TimeInterval = 0.01) {
        simulateLatency = enabled
        latencyDuration = duration
    }
    
    /// Configure operation failure simulation
    func setFailureSimulation(enabled: Bool, failureRate: Double = 0.1) {
        shouldFailOperations = enabled
        self.failureRate = min(max(failureRate, 0.0), 1.0) // Clamp between 0 and 1
    }
    
    /// Reset all tracking and configuration
    func reset() {
        storage.removeAll()
        
        getCalled = false
        setCalled = false
        removeCalled = false
        clearCalled = false
        
        getCallCount = 0
        setCallCount = 0
        removeCallCount = 0
        clearCallCount = 0
        
        lastGetKey = nil
        lastSetKey = nil
        lastRemoveKey = nil
        
        allOperations.removeAll()
        
        simulateLatency = false
        latencyDuration = 0.01
        shouldFailOperations = false
        failureRate = 0.0
        
        concurrentOperationCount = 0
        maxConcurrentOperations = 0
    }
    
    // MARK: - Testing Helper Methods
    
    /// Check if a key exists in the cache (including expired entries)
    func hasKey(_ key: String) -> Bool {
        return storage[key] != nil
    }
    
    /// Check if a key exists and is not expired
    func hasValidKey(_ key: String) -> Bool {
        guard let entry = storage[key] else { return false }
        return entry.expirationDate > Date()
    }
    
    /// Get the number of entries in the cache
    func entryCount() -> Int {
        return storage.count
    }
    
    /// Get the number of valid (non-expired) entries
    func validEntryCount() -> Int {
        let now = Date()
        return storage.values.filter { $0.expirationDate > now }.count
    }
    
    /// Force expire an entry (for testing expiration behavior)
    func forceExpire(_ key: String) {
        if var entry = storage[key] {
            entry.expirationDate = Date().addingTimeInterval(-1) // 1 second ago
            storage[key] = entry
        }
    }
    
    /// Get all cache keys (for testing purposes)
    func getAllKeys() -> [String] {
        return Array(storage.keys)
    }
    
    /// Get detailed statistics about cache usage
    func getStatistics() -> CacheStatistics {
        let now = Date()
        let validEntries = storage.values.filter { $0.expirationDate > now }
        let expiredEntries = storage.values.filter { $0.expirationDate <= now }
        
        return CacheStatistics(
            totalEntries: storage.count,
            validEntries: validEntries.count,
            expiredEntries: expiredEntries.count,
            getCallCount: getCallCount,
            setCallCount: setCallCount,
            removeCallCount: removeCallCount,
            clearCallCount: clearCallCount,
            maxConcurrentOperations: maxConcurrentOperations
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func simulateLatencyIfEnabled() async {
        if simulateLatency && latencyDuration > 0 {
            try? await Task.sleep(nanoseconds: UInt64(latencyDuration * 1_000_000_000))
        }
    }
    
    private func shouldSimulateFailure() async -> Bool {
        if !shouldFailOperations { return false }
        return Double.random(in: 0...1) < failureRate
    }
    
    private func trackOperation(_ operation: CacheOperation) {
        allOperations.append(operation)
    }
}

// MARK: - Supporting Types

/// Represents a cached entry with metadata
private struct CacheEntry {
    let data: Data
    var expirationDate: Date
    let createdAt: Date
}

/// Represents different cache operations for tracking
enum CacheOperation {
    case get(key: String)
    case set(key: String, ttl: TimeInterval)
    case remove(key: String)
    case clear
    
    var operationType: String {
        switch self {
        case .get: return "GET"
        case .set: return "SET"
        case .remove: return "REMOVE"
        case .clear: return "CLEAR"
        }
    }
    
    var key: String? {
        switch self {
        case .get(let key), .set(let key, _), .remove(let key):
            return key
        case .clear:
            return nil
        }
    }
}

/// Statistics about cache usage and performance
struct CacheStatistics {
    let totalEntries: Int
    let validEntries: Int
    let expiredEntries: Int
    let getCallCount: Int
    let setCallCount: Int
    let removeCallCount: Int
    let clearCallCount: Int
    let maxConcurrentOperations: Int
    
    var hitRate: Double {
        guard getCallCount > 0 else { return 0.0 }
        // This is a simplified calculation - real implementation would track hits vs misses
        return Double(validEntries) / Double(getCallCount)
    }
    
    var description: String {
        return """
        Cache Statistics:
        - Total Entries: \(totalEntries)
        - Valid Entries: \(validEntries)
        - Expired Entries: \(expiredEntries)
        - GET Calls: \(getCallCount)
        - SET Calls: \(setCallCount)
        - REMOVE Calls: \(removeCallCount)
        - CLEAR Calls: \(clearCallCount)
        - Max Concurrent Operations: \(maxConcurrentOperations)
        - Estimated Hit Rate: \(String(format: "%.2f%%", hitRate * 100))
        """
    }
} 