//
//  PoolServiceProtocol.swift
//  Blendv3
//
//  Created by Chris Karani on 30/05/2025.
//

/// `PoolServiceProtocol` defines the interface for interacting with liquidity pools in the system.
/// 
/// This protocol abstracts the underlying implementation details of pool-related operations,
/// allowing for easier testing and dependency injection while enforcing a consistent API
/// for all pool service implementations. Implementations should be `Sendable` compliant.
@preconcurrency
protocol PoolServiceProtocol: Sendable {
    
    /// Fetches the current configuration of the pool.
    /// 
    /// This method retrieves all necessary configuration parameters that define the pool's
    /// behavior, including fee structure, price ranges, asset pairs, and other pool-specific settings.
    /// 
    /// - Returns: A `PoolConfig` object containing the complete pool configuration.
    /// - Throws: Pool-related errors such as network failures, invalid response data, or authentication issues.
    func fetchPoolConfig(contractId: String) async throws -> PoolConfig
    
    /// Retrieves the current status of the pool.
    /// 
    /// This method gets the real-time status information about the pool including liquidity levels,
    /// current exchange rates, volume statistics, and other operational metrics.
    /// 
    /// - Throws: Pool-related errors such as network failures, invalid response data, or authentication issues.
    func getPoolStatus(contractId: String) async throws
}
