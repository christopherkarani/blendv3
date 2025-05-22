//
//  WalletProtocol.swift
//  Blendv3
//
//  Core wallet management protocols
//

import Foundation
import stellarsdk

/// Protocol defining wallet management capabilities
protocol WalletServiceProtocol {
    /// Creates a new wallet with a random keypair
    func createWallet() throws -> KeyPair
    
    /// Imports a wallet from a secret seed
    func importWallet(secretSeed: String) throws -> KeyPair
    
    /// Securely stores a keypair
    func storeKeyPair(_ keyPair: KeyPair, identifier: String) throws
    
    /// Retrieves a stored keypair
    func retrieveKeyPair(identifier: String) throws -> KeyPair?
    
    /// Removes a stored keypair
    func removeKeyPair(identifier: String) throws
    
    /// Lists all stored wallet identifiers
    func listWalletIdentifiers() -> [String]
}

/// Protocol for wallet state management
protocol WalletStateProtocol: ObservableObject {
    /// Current active wallet
    var activeWallet: KeyPair? { get }
    
    /// Current account details
    var accountDetails: AccountResponse? { get }
    
    /// Loading state
    var isLoading: Bool { get }
    
    /// Error state
    var error: WalletError? { get }
    
    /// Sets the active wallet
    func setActiveWallet(_ keyPair: KeyPair) async
    
    /// Refreshes account details
    func refreshAccountDetails() async
}