//
//  SorobanTypes.swift
//  Blendv3
//
//  Created on 10/06/2025.
//

import Foundation

/**
 * Represents the storage footprint of a Soroban transaction.
 * Tracks which ledger entries the transaction will read or write.
 */
struct TransactionFootprint {
    /// Ledger entries that will be read but not modified
    let readOnly: [String]
    
    /// Ledger entries that will be read and possibly modified
    let readWrite: [String]
}

/**
 * Represents the resource costs of executing a Soroban transaction.
 * Includes computational and storage costs, as well as the fee.
 */
struct TransactionCost {
    /// Number of CPU instructions executed
    let cpuInstructions: UInt64
    
    /// Memory used in bytes
    let memoryBytes: UInt64
    
    /// Fee required for resources used
    let resourceFee: UInt32
}

/**
 * Represents the result of a single simulated transaction.
 * Used to hold XDR data from the simulation response.
 */
struct SimulateTransactionResult {
    /// The XDR-encoded result string
    let xdr: String?
}

/**
 * Represents a response from simulating a Soroban transaction.
 * Contains the results, cost information, and any errors.
 */
struct SimulateTransactionResponse {
    /// XDR strings from simulation results
    let xdrStrings: [String]
    
    /// Resource usage and cost information
    let cost: TransactionCost
    
    /// Storage footprint of the transaction
    let footprint: TransactionFootprint
    
    /// Array of simulation results
    let results: [SimulateTransactionResult]?
    
    /// Error message if simulation failed
    let error: String?
}