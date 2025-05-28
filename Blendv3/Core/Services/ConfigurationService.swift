//
//  ConfigurationService.swift
//  Blendv3
//
//  Configuration management service
//

import Foundation

/// Service for managing configuration across different environments
final class ConfigurationService: ConfigurationServiceProtocol {
    
    // MARK: - Properties
    
    let networkType: BlendUSDCConstants.NetworkType
    
    // MARK: - Computed Properties
    
    var contractAddresses: ContractAddresses {
        let addresses = BlendUSDCConstants.addresses(for: networkType)
        return ContractAddresses(
            poolAddress: addresses.primaryPool,
            backstopAddress: addresses.backstop,
            emissionsAddress: addresses.emitter,
            usdcAddress: BlendUSDCConstants.usdcAssetContractAddress
        )
    }
    
    var rpcEndpoint: String {
        switch networkType {
        case .testnet:
            return BlendUSDCConstants.RPC.testnet
        case .mainnet:
            return BlendUSDCConstants.RPC.mainnet
        }
    }
    
    // MARK: - Initialization
    
    init(networkType: BlendUSDCConstants.NetworkType) {
        self.networkType = networkType
    }
    
    // MARK: - ConfigurationServiceProtocol
    
    func getRetryConfiguration() -> RetryConfiguration {
        return RetryConfiguration(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 30.0,
            exponentialBase: 2.0,
            jitterRange: 0.0...0.3
        )
    }
    
    func getTimeoutConfiguration() -> TimeoutConfiguration {
        return TimeoutConfiguration(
            networkTimeout: 30.0,
            transactionTimeout: 300.0, // 5 minutes for transactions
            initializationTimeout: 60.0
        )
    }
    
    // MARK: - Additional Configuration Methods
    
    /// Get cache configuration
    func getCacheConfiguration() -> CacheConfiguration {
        return CacheConfiguration(
            priceCacheTTL: 300, // 5 minutes
            poolStatsCacheTTL: 60, // 1 minute
            reserveDataCacheTTL: 120, // 2 minutes
            maxCacheSize: 100,
            maxMemoryUsage: 10 * 1024 * 1024 // 10MB
        )
    }
    
    /// Get batching configuration
    func getBatchingConfiguration() -> BatchingConfiguration {
        return BatchingConfiguration(
            maxBatchSize: 10,
            maxWaitTime: 0.5, // 500ms
            categories: [
                "price": 20,      // Up to 20 price requests
                "reserve": 10,    // Up to 10 reserve requests
                "position": 5     // Up to 5 position requests
            ]
        )
    }
    
    /// Get rate limiting configuration
    func getRateLimitConfiguration() -> RateLimitConfiguration {
        return RateLimitConfiguration(
            requestsPerSecond: 10,
            burstCapacity: 20,
            cooldownPeriod: 60.0
        )
    }
}

// MARK: - Additional Configuration Types

public struct CacheConfiguration {
    public let priceCacheTTL: TimeInterval
    public let poolStatsCacheTTL: TimeInterval
    public let reserveDataCacheTTL: TimeInterval
    public let maxCacheSize: Int
    public let maxMemoryUsage: Int
    
    public init(priceCacheTTL: TimeInterval, poolStatsCacheTTL: TimeInterval, reserveDataCacheTTL: TimeInterval, maxCacheSize: Int, maxMemoryUsage: Int) {
        self.priceCacheTTL = priceCacheTTL
        self.poolStatsCacheTTL = poolStatsCacheTTL
        self.reserveDataCacheTTL = reserveDataCacheTTL
        self.maxCacheSize = maxCacheSize
        self.maxMemoryUsage = maxMemoryUsage
    }
}

struct BatchingConfiguration {
    let maxBatchSize: Int
    let maxWaitTime: TimeInterval
    let categories: [String: Int]
}

struct RateLimitConfiguration {
    let requestsPerSecond: Int
    let burstCapacity: Int
    let cooldownPeriod: TimeInterval
} 