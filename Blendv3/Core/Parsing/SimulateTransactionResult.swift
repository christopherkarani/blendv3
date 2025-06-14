//
//  SimulateTransactionResult.swift
//  Blendv3
//
//  Created by Chris Karani on 09/06/2025.
//

import Foundation

/// Individual result from a Soroban transaction simulation
public struct SimulateTransactionResult: Sendable {
    /// The XDR string result from the simulation
    public let xdr: String?
    
    /// Authorization entries if required
    public let auth: [String]?
    
    /// Create a new simulation result
    /// - Parameters:
    ///   - xdr: The XDR string result
    ///   - auth: Authorization entries
    public init(xdr: String?, auth: [String]? = nil) {
        self.xdr = xdr
        self.auth = auth
    }
}
