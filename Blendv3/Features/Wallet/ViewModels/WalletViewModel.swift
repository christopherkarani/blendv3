//
//  WalletViewModel.swift
//  Blendv3
//
//  ViewModel for wallet management
//

import Foundation
import Combine
import stellarsdk

/// ViewModel responsible for wallet state management
@MainActor
final class WalletViewModel: WalletStateProtocol {
    
    // MARK: - Published Properties
    
    @Published private(set) var activeWallet: KeyPair?
    @Published private(set) var accountDetails: AccountResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var error: WalletError?
    
    // MARK: - Private Properties
    
    private let walletService: WalletServiceProtocol
    private let networkService: NetworkServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var accountStreamCancellable: AnyCancellable?
    
    // MARK: - Initialization
    
    init(
        walletService: WalletServiceProtocol = WalletService(),
        networkService: NetworkServiceProtocol = StellarNetworkService()
    ) {
        self.walletService = walletService
        self.networkService = networkService
        
        // Load active wallet on init
        Task {
            await loadActiveWallet()
        }
    }
    
    // MARK: - WalletStateProtocol Implementation
    
    func setActiveWallet(_ keyPair: KeyPair) async {
        activeWallet = keyPair
        error = nil        
        // Store as active wallet
        do {
            try walletService.storeKeyPair(keyPair, identifier: "active")
            UserDefaults.standard.set("active", forKey: Constants.Keychain.activeWalletKey)
        } catch {
            self.error = error as? WalletError ?? .keychainError(error.localizedDescription)
        }
        
        // Start streaming account updates
        setupAccountStream()
        
        // Fetch initial account details
        await refreshAccountDetails()
    }
    
    func refreshAccountDetails() async {
        guard let wallet = activeWallet else { return }
        
        isLoading = true
        error = nil
        
        do {
            accountDetails = try await networkService.getAccountDetails(accountId: wallet.accountId)
        } catch {
            self.error = error as? WalletError ?? .networkError(error.localizedDescription)
            accountDetails = nil
        }
        
        isLoading = false
    }
    
    // MARK: - Public Methods
    
    func createNewWallet() async {
        isLoading = true
        error = nil
        
        do {
            let keyPair = try walletService.createWallet()
            await setActiveWallet(keyPair)
        } catch {
            self.error = error as? WalletError ?? .keychainError(error.localizedDescription)
        }
        
        isLoading = false
    }    
    func importWallet(secretSeed: String) async {
        isLoading = true
        error = nil
        
        do {
            let keyPair = try walletService.importWallet(secretSeed: secretSeed)
            await setActiveWallet(keyPair)
        } catch {
            self.error = error as? WalletError ?? .invalidSecretSeed
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func loadActiveWallet() async {
        guard let activeIdentifier = UserDefaults.standard.string(forKey: Constants.Keychain.activeWalletKey) else {
            return
        }
        
        do {
            if let keyPair = try walletService.retrieveKeyPair(identifier: activeIdentifier) {
                await setActiveWallet(keyPair)
            }
        } catch {
            self.error = error as? WalletError ?? .walletNotFound
        }
    }
    
    private func setupAccountStream() {
        // Cancel previous stream
        accountStreamCancellable?.cancel()
        
        guard let wallet = activeWallet else { return }
        
        // Setup new stream
        accountStreamCancellable = networkService.streamAccountUpdates(accountId: wallet.accountId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error as? WalletError ?? .networkError(error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] accountResponse in
                    self?.accountDetails = accountResponse
                }
            )
    }
}