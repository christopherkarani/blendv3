//
//  KeyPairSigner.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import stellarsdk


/// Default implementation using a KeyPair with secret seed
public struct KeyPairSigner: BlendSigner {
    private let keyPair: KeyPair
    
    public var publicKey: String {
        return keyPair.accountId
    }
    
    /// Initialize with a KeyPair that contains the secret seed
    /// - Parameter keyPair: The KeyPair with secret seed for signing
    public init(keyPair: KeyPair) {
        self.keyPair = keyPair
    }
    
    /// Initialize with a secret seed string
    /// - Parameter secretSeed: The secret seed string (starts with 'S')
    /// - Throws: An error if the secret seed is invalid
    public init(secretSeed: String) throws {
        self.keyPair = try KeyPair(secretSeed: secretSeed)
    }
    
    public func sign(transaction: stellarsdk.Transaction, network: Network) async throws -> stellarsdk.Transaction {
        // Ensure the keypair has a private key
        guard keyPair.privateKey != nil else {
            throw BlendSignerError.noPrivateKey
        }
        
        // Sign the transaction
        try transaction.sign(keyPair: keyPair, network: network)
        return transaction
    }
    
    public func getKeyPair() throws -> KeyPair {
        return keyPair
    }
}
