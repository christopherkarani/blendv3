//
//  CacheServiceProtocol.swift
//  Blendv3
//
//  Created by Chris Karani on 06/06/2025.
//

import Foundation

/// A protocol defining a thread-safe caching service for storing and retrieving `Codable` objects.
///
/// `CacheServiceProtocol` provides an abstraction layer for caching operations that can be
/// implemented using various storage backends (memory, disk, network, etc.) while maintaining
/// a consistent API. All operations are asynchronous and designed for Swift concurrency.
///
/// Implementations should ensure:
/// - Thread safety across all operations
/// - Proper error handling for serialization failures
/// - Efficient memory management
/// - Adherence to TTL (time-to-live) specifications
@preconcurrency
public protocol CacheServiceProtocol: Sendable {
    
    /// Retrieves a cached value associated with the specified key.
    ///
    /// This method attempts to fetch a previously cached value and decode it to the requested type.
    /// If no value exists for the key or if the value has expired, `nil` is returned.
    ///
    /// - Parameters:
    ///   - key: The unique identifier for the cached value.
    ///   - type: The expected type of the cached value (must conform to `Codable`).
    /// - Returns: The cached value of type `T` if it exists and hasn't expired, otherwise `nil`.
    /// - Note: This method safely handles decoding failures by returning `nil` rather than throwing.
    func get<T: Codable>(_ key: String, type: T.Type) async -> T?
    
    /// Stores a value in the cache with an associated key and time-to-live duration.
    ///
    /// This method serializes the provided value and stores it in the cache with the
    /// specified expiration time. If a value already exists for the given key,
    /// it will be replaced.
    ///
    /// - Parameters:
    ///   - value: The value to cache (must conform to `Codable`).
    ///   - key: The unique identifier to associate with the cached value.
    ///   - ttl: Time-to-live duration in seconds after which the cached value expires.
    ///          Use `TimeInterval.infinity` for values that should never expire.
    /// - Note: Implementation should handle serialization failures gracefully.
    func set<T: Codable>(_ value: T, key: String, ttl: TimeInterval) async
    
    /// Removes a specific cached value associated with the given key.
    ///
    /// This method deletes the value for the specified key if it exists.
    /// If no value exists for the key, this operation has no effect.
    ///
    /// - Parameter key: The unique identifier of the cached value to remove.
    func remove(_ key: String) async
    
    /// Removes all values from the cache.
    ///
    /// This method purges the entire cache, removing all stored values regardless of
    /// their expiration status. Use with caution as this operation cannot be undone.
    func clear() async
} 
