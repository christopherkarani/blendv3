//
//  CacheServiceTests.swift
//  Blendv3Tests
//
//  Unit tests for CacheService
//

import XCTest
@testable import Blendv3

final class CacheServiceTests: XCTestCase {
    
    var sut: CacheService!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = CacheService(maxEntries: 5, maxMemoryUsage: 1024) // Small limits for testing
    }
    
    override func tearDown() async throws {
        await sut.clear()
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Operations Tests
    
    func testSetAndGet_ValidData_ReturnsCorrectValue() async {
        // Given
        let key = "test_key"
        let value = "test_value"
        let ttl: TimeInterval = 60
        
        // When
        await sut.set(value, key: key, ttl: ttl)
        let retrieved = await sut.get(key, type: String.self)
        
        // Then
        XCTAssertEqual(retrieved, value)
    }
    
    func testGet_NonExistentKey_ReturnsNil() async {
        // When
        let retrieved = await sut.get("non_existent", type: String.self)
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testRemove_ExistingKey_RemovesEntry() async {
        // Given
        let key = "test_key"
        await sut.set("value", key: key, ttl: 60)
        
        // When
        await sut.remove(key)
        let retrieved = await sut.get(key, type: String.self)
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testClear_RemovesAllEntries() async {
        // Given
        await sut.set("value1", key: "key1", ttl: 60)
        await sut.set("value2", key: "key2", ttl: 60)
        await sut.set("value3", key: "key3", ttl: 60)
        
        // When
        await sut.clear()
        
        // Then
        let retrieved1 = await sut.get("key1", type: String.self)
        let retrieved2 = await sut.get("key2", type: String.self)
        let retrieved3 = await sut.get("key3", type: String.self)
        
        XCTAssertNil(retrieved1)
        XCTAssertNil(retrieved2)
        XCTAssertNil(retrieved3)
    }
    
    // MARK: - TTL Tests
    
    func testGet_ExpiredEntry_ReturnsNil() async {
        // Given
        let key = "test_key"
        let value = "test_value"
        let ttl: TimeInterval = 0.1 // 100ms
        
        await sut.set(value, key: key, ttl: ttl)
        
        // When - Wait for expiration
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        let retrieved = await sut.get(key, type: String.self)
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testGet_NotExpiredEntry_ReturnsValue() async {
        // Given
        let key = "test_key"
        let value = "test_value"
        let ttl: TimeInterval = 10 // 10 seconds
        
        await sut.set(value, key: key, ttl: ttl)
        
        // When - Don't wait
        let retrieved = await sut.get(key, type: String.self)
        
        // Then
        XCTAssertEqual(retrieved, value)
    }
    
    // MARK: - LRU Eviction Tests
    
    func testLRUEviction_ExceedsMaxEntries_EvictsOldestAccessed() async {
        // Given - maxEntries is 5
        for i in 1...5 {
            await sut.set("value\(i)", key: "key\(i)", ttl: 60)
        }
        
        // Access some entries to update their access time
        _ = await sut.get("key1", type: String.self)
        _ = await sut.get("key3", type: String.self)
        
        // When - Add one more entry (should trigger eviction)
        await sut.set("value6", key: "key6", ttl: 60)
        
        // Then - Least recently accessed entries should be evicted
        // key2, key4, key5 were not accessed, so some of them should be evicted
        let stats = await sut.getStatistics()
        XCTAssertLessThanOrEqual(stats.entryCount, 5)
        
        // key1 and key3 should still exist (they were accessed)
        XCTAssertNotNil(await sut.get("key1", type: String.self))
        XCTAssertNotNil(await sut.get("key3", type: String.self))
        XCTAssertNotNil(await sut.get("key6", type: String.self))
    }
    
    func testLRUEviction_ExceedsMemoryLimit_EvictsToFreeMemory() async {
        // Given - maxMemoryUsage is 1024 bytes
        let largeValue = String(repeating: "a", count: 300) // ~300 bytes each
        
        // Add entries that will exceed memory limit
        await sut.set(largeValue, key: "key1", ttl: 60)
        await sut.set(largeValue, key: "key2", ttl: 60)
        await sut.set(largeValue, key: "key3", ttl: 60)
        await sut.set(largeValue, key: "key4", ttl: 60) // Should trigger eviction
        
        // Then
        let stats = await sut.getStatistics()
        XCTAssertLessThanOrEqual(stats.memoryUsage, 1024)
        XCTAssertLessThan(stats.entryCount, 4) // Some entries should be evicted
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentAccess_MultipleReadsAndWrites_MaintainsConsistency() async {
        // Given
        let iterations = 100
        let group = TaskGroup<Void>()
        
        // When - Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Writers
            for i in 0..<iterations {
                group.addTask {
                    await self.sut.set("value\(i)", key: "key\(i)", ttl: 60)
                }
            }
            
            // Readers
            for i in 0..<iterations {
                group.addTask {
                    _ = await self.sut.get("key\(i)", type: String.self)
                }
            }
            
            // Removers
            for i in 0..<iterations/2 {
                group.addTask {
                    await self.sut.remove("key\(i)")
                }
            }
        }
        
        // Then - Cache should be in consistent state
        let stats = await sut.getStatistics()
        XCTAssertGreaterThanOrEqual(stats.entryCount, 0)
        XCTAssertLessThanOrEqual(stats.entryCount, 5) // maxEntries
        XCTAssertLessThanOrEqual(stats.memoryUsage, 1024) // maxMemoryUsage
    }
    
    // MARK: - Complex Type Tests
    
    struct TestModel: Codable, Equatable {
        let id: Int
        let name: String
        let values: [Double]
    }
    
    func testSetAndGet_ComplexType_WorksCorrectly() async {
        // Given
        let model = TestModel(
            id: 123,
            name: "Test Model",
            values: [1.1, 2.2, 3.3]
        )
        let key = "model_key"
        
        // When
        await sut.set(model, key: key, ttl: 60)
        let retrieved = await sut.get(key, type: TestModel.self)
        
        // Then
        XCTAssertEqual(retrieved, model)
    }
    
    // MARK: - Statistics Tests
    
    func testGetStatistics_ReturnsCorrectValues() async {
        // Given
        await sut.set("value1", key: "key1", ttl: 60)
        await sut.set("value2", key: "key2", ttl: 60)
        
        // When
        let stats = await sut.getStatistics()
        
        // Then
        XCTAssertEqual(stats.entryCount, 2)
        XCTAssertGreaterThan(stats.memoryUsage, 0)
        XCTAssertEqual(stats.maxMemoryUsage, 1024)
    }
    
    // MARK: - Update Access Time Tests
    
    func testGet_UpdatesAccessTime() async {
        // Given
        await sut.set("value1", key: "key1", ttl: 60)
        await sut.set("value2", key: "key2", ttl: 60)
        await sut.set("value3", key: "key3", ttl: 60)
        
        // When - Access key2 multiple times
        _ = await sut.get("key2", type: String.self)
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        _ = await sut.get("key2", type: String.self)
        
        // Add more entries to trigger eviction
        await sut.set("value4", key: "key4", ttl: 60)
        await sut.set("value5", key: "key5", ttl: 60)
        await sut.set("value6", key: "key6", ttl: 60) // Should trigger eviction
        
        // Then - key2 should still exist (it was accessed recently)
        XCTAssertNotNil(await sut.get("key2", type: String.self))
    }
} 