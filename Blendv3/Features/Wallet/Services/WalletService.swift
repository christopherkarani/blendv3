//
//  WalletService.swift
//  Blendv3
//
//  Secure wallet management service implementation
//

import Foundation
import stellarsdk
import KeychainSwift

/// Service responsible for secure wallet management
final class WalletService: WalletServiceProtocol {
    
    // MARK: - Properties
    
    private let keychain: KeychainSwift
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    init(keychain: KeychainSwift = KeychainSwift()) {
        self.keychain = keychain
        self.keychain.synchronizable = false
    }
    
    // MARK: - WalletServiceProtocol Implementation
    
    func createWallet() throws -> KeyPair {
        do {
            return try KeyPair.generateRandomKeyPair()
        } catch {
            throw WalletError.keychainError("Failed to generate keypair: \(error.localizedDescription)")
        }
    }
    
    func importWallet(secretSeed: String) throws -> KeyPair {
        do {
            return try KeyPair(secretSeed: secretSeed)
        } catch {
            throw WalletError.invalidSecretSeed
        }
    }
    
    func storeKeyPair(_ keyPair: KeyPair, identifier: String) throws {
        guard let secretSeed = keyPair.secretSeed else {
            throw WalletError.keychainError("No secret seed available")
        }        
        // Store in keychain with encryption
        let stored = keychain.set(
            secretSeed,
            forKey: keyForIdentifier(identifier),
            withAccess: .accessibleWhenUnlockedThisDeviceOnly
        )
        
        if !stored {
            throw WalletError.keychainError("Failed to store wallet")
        }
    }
    
    func retrieveKeyPair(identifier: String) throws -> KeyPair? {
        guard let secretSeed = keychain.get(keyForIdentifier(identifier)) else {
            return nil
        }
        
        return try KeyPair(secretSeed: secretSeed)
    }
    
    func removeKeyPair(identifier: String) throws {
        let removed = keychain.delete(keyForIdentifier(identifier))
        if !removed {
            throw WalletError.walletNotFound
        }
    }
    
    func listWalletIdentifiers() -> [String] {
        return keychain.allKeys
            .filter { $0.hasPrefix("wallet_") }
            .compactMap { $0.replacingOccurrences(of: "wallet_", with: "") }
    }
    
    // MARK: - Private Methods
    
    private func keyForIdentifier(_ identifier: String) -> String {
        return "wallet_\(identifier)"
    }
}