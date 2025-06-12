//
//  BlendSigner.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import stellarsdk

/// Protocol for signing transactions in a wallet-agnostic way
/// This allows different key sources (hardware wallets, software wallets, etc.) to be used
public protocol BlendSigner {
    
    /// The public key of the signer
    var publicKey: String { get }
    
    /// Sign a transaction with the signer's private key
    /// - Parameters:
    ///   - transaction: The transaction to sign
    ///   - network: The Stellar network (testnet or mainnet)
    /// - Returns: The signed transaction
    /// - Throws: An error if signing fails
    func sign(transaction: stellarsdk.Transaction, network: Network) async throws -> stellarsdk.Transaction
    
    /// Get the KeyPair for account operations (may only contain public key)
    /// - Returns: A KeyPair instance
    func getKeyPair() throws -> KeyPair
}



/// Errors that can occur during signing
public enum BlendSignerError: LocalizedError {
    case noPrivateKey
    case signingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .noPrivateKey:
            return "No private key available for signing"
        case .signingFailed(let message):
            return "Transaction signing failed: \(message)"
        }
    }
} 
