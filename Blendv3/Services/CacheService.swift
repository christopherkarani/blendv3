import Foundation
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#endif

/// Thread-safe cache service with actor isolation, TTL support, and LRU eviction
public actor CacheService: CacheServiceProtocol {
    
    // MARK: - Types
    
    private struct CacheEntry<T: Codable>: Codable {
        let value: T
        let expirationDate: Date
        var lastAccessDate: Date
        let size: Int
        
        var isExpired: Bool {
            return Date() > expirationDate
        }
        
        init(value: T, expirationDate: Date, size: Int) {
            self.value = value
            self.expirationDate = expirationDate
            self.lastAccessDate = Date()
            self.size = size
        }
        
        func withUpdatedAccessDate() -> CacheEntry<T> {
            var updated = self
            updated.lastAccessDate = Date()
            return updated
        }
    }
    
    // MARK: - Properties
    
    private var storage: [String: Data] = [:]
    private var metadata: [String: CacheMetadata] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Configuration
    private let maxEntries: Int
    private let maxMemoryUsage: Int
    private var currentMemoryUsage: Int = 0
    
    // Memory pressure monitoring
    private var memoryPressureObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    public init(maxEntries: Int = 100, maxMemoryUsage: Int = 10 * 1024 * 1024) {
        self.maxEntries = maxEntries
        self.maxMemoryUsage = maxMemoryUsage
        
        BlendLogger.info("Cache service initialized with maxEntries: \(maxEntries), maxMemory: \(maxMemoryUsage)", category: BlendLogger.cache)
        
        Task {
            await setupMemoryPressureMonitoring()
        }
    }
    
    deinit {
        if let observer = memoryPressureObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - CacheServiceProtocol
    
    public func get<T: Codable>(_ key: String, type: T.Type) async -> T? {
        BlendLogger.debug("Attempting to retrieve cache entry for key: \(key)", category: BlendLogger.cache)
        
        guard let data = storage[key] else {
            BlendLogger.cache(operation: "GET", key: key, hit: false)
            return nil
        }
        
        do {
            let entry = try decoder.decode(CacheEntry<T>.self, from: data)
            
            if entry.isExpired {
                BlendLogger.warning("Cache entry expired for key: \(key)", category: BlendLogger.cache)
                await remove(key)
                BlendLogger.cache(operation: "EXPIRED", key: key)
                return nil
            }
            
            // Update access time for LRU
            let updatedEntry = entry.withUpdatedAccessDate()
            if let updatedData = try? encoder.encode(updatedEntry) {
                storage[key] = updatedData
                metadata[key]?.lastAccessDate = Date()
            }
            
            BlendLogger.cache(operation: "GET", key: key, hit: true)
            return entry.value
            
        } catch {
            BlendLogger.error("Failed to decode cache entry for key: \(key)", error: error, category: BlendLogger.cache)
            await remove(key)
            return nil
        }
    }
    
    public func set<T: Codable>(_ value: T, key: String, ttl: TimeInterval) async {
        BlendLogger.debug("Setting cache entry for key: \(key) with TTL: \(ttl)s", category: BlendLogger.cache)
        
        let expirationDate = Date().addingTimeInterval(ttl)
        
        do {
            // Calculate size
            let tempData = try encoder.encode(value)
            let size = tempData.count
            
            // Check if we need to evict entries
            await evictIfNeeded(additionalSize: size)
            
            let entry = CacheEntry(value: value, expirationDate: expirationDate, size: size)
            let data = try encoder.encode(entry)
            
            // Remove old entry if exists
            if let oldData = storage[key],
               let oldMetadata = metadata[key] {
                currentMemoryUsage -= oldMetadata.size
            }
            
            storage[key] = data
            metadata[key] = CacheMetadata(
                size: size,
                expirationDate: expirationDate,
                lastAccessDate: Date()
            )
            currentMemoryUsage += size
            
            BlendLogger.cache(operation: "SET", key: key)
            
        } catch {
            BlendLogger.error("Failed to encode cache entry for key: \(key)", error: error, category: BlendLogger.cache)
        }
    }
    
    public func remove(_ key: String) async {
        BlendLogger.debug("Removing cache entry for key: \(key)", category: BlendLogger.cache)
        
        if let metadata = metadata[key] {
            currentMemoryUsage -= metadata.size
        }
        
        storage.removeValue(forKey: key)
        metadata.removeValue(forKey: key)
        
        BlendLogger.cache(operation: "REMOVE", key: key)
    }
    
    public func clear() {
        BlendLogger.info("Clearing all cache entries", category: BlendLogger.cache)
        
        storage.removeAll()
        metadata.removeAll()
        currentMemoryUsage = 0
        
        BlendLogger.cache(operation: "CLEAR", key: "ALL")
    }
    
    // MARK: - Memory Management
    
    private func evictIfNeeded(additionalSize: Int) async {
        // Check memory limit
        if currentMemoryUsage + additionalSize > maxMemoryUsage {
            await evictLRU(targetSize: maxMemoryUsage / 2) // Free up to 50%
        }
        
        // Check entry count limit
        if storage.count >= maxEntries {
            await evictLRU(targetCount: maxEntries / 2) // Remove 50% of entries
        }
    }
    
    private func evictLRU(targetSize: Int? = nil, targetCount: Int? = nil) async {
        BlendLogger.info("Starting LRU eviction", category: BlendLogger.cache)
        
        // Sort entries by last access date
        let sortedEntries = metadata.sorted { $0.value.lastAccessDate < $1.value.lastAccessDate }
        
        var evictedCount = 0
        var freedMemory = 0
        
        for (key, meta) in sortedEntries {
            // Check if we've reached our targets
            if let targetSize = targetSize, currentMemoryUsage <= targetSize {
                break
            }
            if let targetCount = targetCount, storage.count <= targetCount {
                break
            }
            
            // Evict entry
            storage.removeValue(forKey: key)
            metadata.removeValue(forKey: key)
            currentMemoryUsage -= meta.size
            freedMemory += meta.size
            evictedCount += 1
            
            BlendLogger.cache(operation: "EVICT", key: key)
        }
        
        BlendLogger.info("LRU eviction completed: evicted \(evictedCount) entries, freed \(freedMemory) bytes", category: BlendLogger.cache)
    }
    
    private func setupMemoryPressureMonitoring() {
        #if os(iOS) || os(tvOS) || os(watchOS)
        memoryPressureObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleMemoryPressure()
            }
        }
        #elseif os(macOS)
        // macOS memory pressure handling would go here
        #endif
    }
    
    private func handleMemoryPressure() async {
        BlendLogger.warning("Memory pressure detected, clearing cache", category: BlendLogger.cache)
        await clear()
    }
    
    // MARK: - Statistics
    
    public func getStatistics() -> CacheStatistics {
        return CacheStatistics(
            entryCount: storage.count,
            memoryUsage: currentMemoryUsage,
            maxMemoryUsage: maxMemoryUsage,
            hitRate: 0.0 // Would need to track hits/misses for this
        )
    }
}

// MARK: - Supporting Types

private struct CacheMetadata {
    let size: Int
    let expirationDate: Date
    var lastAccessDate: Date
}

public struct CacheStatistics {
    public let entryCount: Int
    public let memoryUsage: Int
    public let maxMemoryUsage: Int
    public let hitRate: Double
}

// MARK: - Cache Keys

public enum CacheKeys {
    public static let oraclePrices = "oracle_prices"
    public static let poolConfig = "pool_config"
    public static let reserveData = "reserve_data"
    
    public static func oraclePrice(asset: String) -> String {
        return "oracle_price_\(asset)"
    }
    
    public static func poolData(poolId: String) -> String {
        return "pool_data_\(poolId)"
    }
    
    public static func reserveData(poolId: String, assetId: String) -> String {
        return "reserve_\(poolId)_\(assetId)"
    }
} 