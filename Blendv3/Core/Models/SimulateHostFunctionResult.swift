// SimulateHostFunctionResult.swift
// Blendv3
//
// Created on 2025-06-07
// Copyright © 2025 Blend. All rights reserved.

import Foundation

/// Result model for Soroban host function simulation with Blend-specific processing
public final class SimulateHostFunctionResult: Sendable {
    
    /// Authorization entries for the transaction
    public let auth: [SorobanAuthorizationEntryXDR]?
    
    /// Transaction data containing resources and other information
    public let transactionData: SorobanTransactionDataXDR
    
    /// Returned value from the host function call
    public let returnedValue: SCValXDR
    
    /// Cost information for resource calculation
    public let cost: Int64
    
    /// Footprint data as optional string representation
    public let footprint: String?
    
    /// Create a new simulation result
    /// - Parameters:
    ///   - transactionData: Transaction data containing resources and other information
    ///   - returnedValue: Returned value from the host function call
    ///   - auth: Authorization entries for the transaction
    ///   - cost: Cost information for resource calculation
    ///   - footprint: Footprint data as optional string representation
    public init(
        transactionData: SorobanTransactionDataXDR,
        returnedValue: SCValXDR,
        auth: [SorobanAuthorizationEntryXDR]? = nil,
        cost: Int64 = 0,
        footprint: String? = nil
    ) {
        self.auth = auth
        self.transactionData = transactionData
        self.returnedValue = returnedValue
        self.cost = cost
        self.footprint = footprint
    }
    
    /// Convert to the SimulationResult type used by NetworkService
    public func toSimulationResult() -> SimulationResult {
        return SimulationResult(
            result: returnedValue,
            cost: cost,
            footprint: footprint
        )
    }
}
