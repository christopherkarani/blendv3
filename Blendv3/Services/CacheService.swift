import Foundation

/// Cache service implementation with TTL support
public final class CacheService: CacheServiceProtocol {
    
    // MARK: - Types
    
    private struct CacheEntry<T: Codable>: Codable {
        let value: T
        let expirationDate: Date
        
        var isExpired: Bool {
            return Date() > expirationDate
        }
        
        init(value: T, expirationDate: Date) {
            self.value = value
            self.expirationDate = expirationDate
        }
    }
    
    // MARK: - Properties
    
    private let cache = NSCache<NSString, NSData>()
    private let queue = DispatchQueue(label: "com.blend.cache", attributes: .concurrent)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    public init() {
        BlendLogger.info("Cache service initialized", category: BlendLogger.cache)
        setupCache()
    }
    
    // MARK: - CacheServiceProtocol
    
    public func get<T: Codable>(_ key: String, type: T.Type) -> T? {
        return queue.sync { () -> T? in
            BlendLogger.debug("Attempting to retrieve cache entry for key: \(key)", category: BlendLogger.cache)
            
            guard let data = cache.object(forKey: NSString(string: key)) as Data? else {
                BlendLogger.cache(operation: "GET", key: key, hit: false)
                return nil
            }
            
            do {
                let entry = try decoder.decode(CacheEntry<T>.self, from: data)
                
                if entry.isExpired {
                    BlendLogger.warning("Cache entry expired for key: \(key)", category: BlendLogger.cache)
                    cache.removeObject(forKey: NSString(string: key))
                    BlendLogger.cache(operation: "EXPIRED", key: key)
                    return nil
                }
                
                BlendLogger.cache(operation: "GET", key: key, hit: true)
                return entry.value
                
            } catch {
                BlendLogger.error("Failed to decode cache entry for key: \(key)", error: error, category: BlendLogger.cache)
                cache.removeObject(forKey: NSString(string: key))
                return nil
            }
        }
    }
    
    public func set<T: Codable>(_ value: T, key: String, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            BlendLogger.debug("Setting cache entry for key: \(key) with TTL: \(ttl)s", category: BlendLogger.cache)
            
            let expirationDate = Date().addingTimeInterval(ttl)
            let entry = CacheEntry(value: value, expirationDate: expirationDate)
            
            do {
                let data = try self.encoder.encode(entry)
                self.cache.setObject(data as NSData, forKey: NSString(string: key))
                BlendLogger.cache(operation: "SET", key: key)
                
            } catch {
                BlendLogger.error("Failed to encode cache entry for key: \(key)", error: error, category: BlendLogger.cache)
            }
        }
    }
    
    public func remove(_ key: String) {
        queue.async(flags: .barrier) {
            BlendLogger.debug("Removing cache entry for key: \(key)", category: BlendLogger.cache)
            self.cache.removeObject(forKey: NSString(string: key))
            BlendLogger.cache(operation: "REMOVE", key: key)
        }
    }
    
    public func clear() {
        queue.async(flags: .barrier) {
            BlendLogger.info("Clearing all cache entries", category: BlendLogger.cache)
            self.cache.removeAllObjects()
            BlendLogger.cache(operation: "CLEAR", key: "ALL")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupCache() {
        // Set cache limits
        cache.countLimit = 100 // Maximum 100 entries
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB limit
        
        BlendLogger.info("Cache configured with countLimit: 100, totalCostLimit: 10MB", category: BlendLogger.cache)
    }
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