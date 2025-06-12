//
//  BlendDefaultSigner.swift
//  Blendv3
//
//  Created on 2025-05-26.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import stellarsdk

/// Default implementation of BlendSigner that provides a basic signer for testing and development
/// This is used as the default signer in the DependencyContainer
public class BlendDefaultSigner: BlendSigner {
    private let keyPair: KeyPair
    
    public var publicKey: String {
        return keyPair.accountId
    }
    
    /// Initialize with a default test keypair
    /// For production use, replace with a secure key management solution
    public init() {
        // Use a test keypair for development - this is just for initialization purposes
        // In production, this should be replaced with a secure implementation
        do {
            // This is a test keypair that should be replaced in production
            let testSeed = "SDJIFQIGUSSDQKKAPFJSADJFKLASDJIASDJIASDIASDNMZXCNVJAHWEG23423"
            self.keyPair = try KeyPair(secretSeed: testSeed)
        } catch {
            // Fallback to a generated keypair if the test seed fails
            do {
                self.keyPair = try KeyPair.generateRandomKeyPair()
            } catch {
                // If random keypair generation also fails, use a last resort approach
                // This should never happen in practice, but provides a safety net
                fatalError("Failed to create a keypair: \(error.localizedDescription)")
            }
        }
    }
    
    /// Initialize with a specific KeyPair
    /// - Parameter keyPair: The KeyPair to use for signing
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
