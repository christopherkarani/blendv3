// SimulateTransactionResponse.swift
// Blendv3
//
// Created on 2025-06-07
// Copyright 2025 Blend. All rights reserved.

import Foundation

/// Response model for Soroban transaction simulation results with Blend-specific processing
@Observable public final class SimulateTransactionResponse: Sendable {
    
    /// The raw XDR strings extracted from the simulation results
    public let xdrStrings: [String]
    
    /// Cost information from the simulation
    public let cost: TransactionCost
    
    /// Footprint data from the simulation
    public let footprint: TransactionFootprint
    
    /// Individual simulation results
    public let results: [SimulateTransactionResult]?
    
    /// Error message if simulation failed
    public let error: String?
    
    /// Create a new simulation response
    /// - Parameters:
    ///   - xdrStrings: The raw XDR strings from the simulation
    ///   - cost: Cost information from the simulation
    ///   - footprint: Footprint data from the simulation
    ///   - results: Individual simulation results
    ///   - error: Error message if any
    public init(
        xdrStrings: [String],
        cost: TransactionCost,
        footprint: TransactionFootprint,
        results: [SimulateTransactionResult]? = nil,
        error: String? = nil
    ) {
        self.xdrStrings = xdrStrings
        self.cost = cost
        self.footprint = footprint
        self.results = results
        self.error = error
    }
}

/// Represents the cost information for a transaction
public struct TransactionCost: Sendable {
    /// CPU instructions used
    public let cpuInstructions: UInt64
    
    /// Memory bytes used
    public let memoryBytes: UInt64
    
    /// Total resource fee in stroops
    public let resourceFee: UInt32
    
    /// Create a new transaction cost
    /// - Parameters:
    ///   - cpuInstructions: CPU instructions used
    ///   - memoryBytes: Memory bytes used
    ///   - resourceFee: Total resource fee in stroops
    public init(cpuInstructions: UInt64, memoryBytes: UInt64, resourceFee: UInt32) {
        self.cpuInstructions = cpuInstructions
        self.memoryBytes = memoryBytes
        self.resourceFee = resourceFee
    }
}

/// Represents the transaction footprint data
public struct TransactionFootprint: Sendable {
    /// Read-only ledger entry keys
    public let readOnly: [String]
    
    /// Read-write ledger entry keys
    public let readWrite: [String]
    
    /// Create a new transaction footprint
    /// - Parameters:
    ///   - readOnly: Read-only ledger entry keys
    ///   - readWrite: Read-write ledger entry keys
    public init(readOnly: [String], readWrite: [String]) {
        self.readOnly = readOnly
        self.readWrite = readWrite
    }
}
