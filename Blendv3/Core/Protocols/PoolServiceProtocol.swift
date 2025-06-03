//
//  PoolServiceProtocol.swift
//  Blendv3
//
//  Created by Chris Karani on 30/05/2025.
//


protocol PoolServiceProtocol {
    func fetchPoolConfig() async throws -> PoolConfig
    func getPoolStatus() async throws
}
