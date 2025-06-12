//
//  ContractAddresses.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Contract Configuration

/// Legacy contract addresses for ConfigurationServiceProtocol compatibility
public struct ContractAddresses {
    public let poolContract: String
    public let backstopContract: String
    public let blendLockupContract: String
    public let usdcContract: String
    
    public init(poolContract: String, backstopContract: String, blendLockupContract: String, usdcContract: String) {
        self.poolContract = poolContract
        self.backstopContract = backstopContract
        self.blendLockupContract = blendLockupContract
        self.usdcContract = usdcContract
    }
}

// MARK: - Cache Configuration

/// Cache configuration for services
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
