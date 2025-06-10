//
//  BlendViewModel.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

//import Foundation
//import Combine
//import stellarsdk
//import SwiftUI
//
//@MainActor
//class BlendViewModel: ObservableObject {
//    // MARK: - Logger
//    
//    private let logger = DebugLogger(subsystem: "com.blendv3.viewmodel", category: "BlendViewModel")
//    
//    // Debug logger specifically for debug functions that should appear in DebugLogView
//    private let debugLogger = DebugLogger(subsystem: "com.blendv3.debug", category: "ViewModelDebug")
//    
//    // MARK: - Published Properties
//    
//    @Published var poolStats: BlendPoolStats?
//    @Published var isLoading = false
//    @Published var errorMessage: String?
//    @Published var successMessage: String?
//    @Published var transactionHistory: [TransactionRecord] = []
//    @Published var accountStatus: AccountStatus?
//    
//    // MARK: - Private Properties
//    
//     let vault: BlendUSDCVault
//    private let signer: BlendSigner
//    private let accountChecker: AccountChecker
//    private var cancellables = Set<AnyCancellable>()
//    
//    // MARK: - Computed Properties
//    
//    var publicKey: String {
//        return signer.publicKey
//    }
//    
//    var shortPublicKey: String {
//        let key = publicKey
//        return "\(key.prefix(4))...\(key.suffix(4))"
//    }
//    
//    // MARK: - Initialization
//    
//    init(signer: BlendSigner) {
//        self.signer = signer
//        self.vault = BlendUSDCVault(signer: signer, network: .testnet)
//   
//      
//    
//        self.accountChecker = AccountChecker(network: .testnet)
//        
//        logger.info("Initializing BlendViewModel")
//        logger.info("Signer public key: \(signer.publicKey)")
//        
//        setupBindings()
//        
//        // Initial load
//        Task {
//            logger.info("Starting initial setup")
//            await checkAccountStatus()
//            
//            // Only refresh stats if account is ready
//            if accountStatus?.isReady == true {
//                logger.info("Account is ready, refreshing pool stats")
//                await refreshStats()
//            } else {
//                logger.warning("Account not ready, skipping pool stats refresh")
//            }
//        }
//    }
//    
//    // MARK: - Setup
//    
//    private func setupBindings() {
//        logger.debug("Setting up bindings")
//        Task {
//            let result = await self.vault.initializeSorobanClient()
//        }
//        // Bind vault state to view model
//        vault.$poolStats
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] stats in
//                self?.logger.debug("Pool stats updated: \(stats != nil ? "Available" : "Nil")")
//            }
//            .store(in: &cancellables)
//        
//        vault.$poolStats
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$poolStats)
//        
//        vault.$isLoading
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] loading in
//                self?.logger.debug("Loading state changed: \(loading)")
//            }
//            .store(in: &cancellables)
//        
//        vault.$isLoading
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$isLoading)
//        
//        vault.$error
//            .receive(on: DispatchQueue.main)
//            .map { $0?.localizedDescription }
//            .sink { [weak self] error in
//                if let error = error {
//                    self?.logger.error("Vault error received: \(error)")
//                    self?.errorMessage = error
//                    self?.successMessage = nil
//                }
//            }
//            .store(in: &cancellables)
//    }
//    
//    // MARK: - Public Methods
//    
//    func checkAccountStatus() async {
//        logger.info("Checking account status")
//        
//        do {
//            let status = try await accountChecker.checkAccount(publicKey: publicKey)
//            accountStatus = status
//            
//            
//            if !status.isReady {
//                errorMessage = status.statusMessage
//            }
//        } catch {
//            logger.error("Failed to check account status: \(error.localizedDescription)")
//            errorMessage = "Failed to check account: \(error.localizedDescription)"
//        }
//    }
//    
//    func createUSDCTrustline() async {
//        logger.info("Creating USDC trustline")
//        clearMessages()
//        
//        do {
//            let txHash = try await accountChecker.createUSDCTrustline(signer: signer)
//            logger.info("Trustline created successfully: \(txHash)")
//            successMessage = "USDC trustline created!"
//            
//            // Re-check account status
//            await checkAccountStatus()
//            
//            // If account is now ready, refresh stats
//            if accountStatus?.isReady == true {
//                await refreshStats()
//            }
//        } catch {
//            logger.error("Failed to create trustline: \(error.localizedDescription)")
//            errorMessage = error.localizedDescription
//        }
//    }
//    
//    func deposit(amount: Decimal) async {
////        // Check if account is ready
////        guard accountStatus?.isReady == true else {
////            logger.warning("Account not ready for deposit")
////            errorMessage = accountStatus?.statusMessage ?? "Account not ready"
////            return
////        }
////        
////        logger.info("Deposit requested: \(amount) USDC")
////        clearMessages()
////        
////        do {
////            let txHash = try await vault.deposit(amount: amount)
////            logger.info("Deposit successful: \(txHash)")
////            successMessage = "Deposit successful!"
////            errorMessage = nil
////            
////            // Add to transaction history
////            let record = TransactionRecord(
////                type: .deposit,
////                amount: amount,
////                txHash: txHash,
////                timestamp: Date()
////            )
////            transactionHistory.insert(record, at: 0)
////            logger.debug("Added transaction to history")
////            
////            // Refresh stats after deposit
////            await refreshStats()
////        } catch {
////            logger.error("Deposit failed: \(error.localizedDescription)")
////            errorMessage = error.localizedDescription
////            successMessage = nil
////        }
//    }
//    
////    func withdraw(amount: Decimal) async {
////        // Check if account is ready
////        guard accountStatus?.isReady == true else {
////            logger.warning("Account not ready for withdrawal")
////            errorMessage = accountStatus?.statusMessage ?? "Account not ready"
////            return
////        }
////        
////        logger.info("Withdrawal requested: \(amount) USDC")
////        clearMessages()
////        
////        do {
////            let txHash = try await vault.withdraw(amount: amount)
////            logger.info("Withdrawal successful: \(txHash)")
////            successMessage = "Withdrawal successful!"
////            errorMessage = nil
////            
////            // Add to transaction history
////            let record = TransactionRecord(
////                type: .withdrawal,
////                amount: amount,
////                txHash: txHash,
////                timestamp: Date()
////            )
////            transactionHistory.insert(record, at: 0)
////            logger.debug("Added transaction to history")
////            
////            // Refresh stats after withdrawal
////            await refreshStats()
////        } catch {
////            logger.error("Withdrawal failed: \(error.localizedDescription)")
////            errorMessage = error.localizedDescription
////            successMessage = nil
////        }
////    }
//    
//    func refreshStats() async {
//        // Check if account is ready
//        guard accountStatus?.isReady == true else {
//            logger.warning("Account not ready for stats refresh")
//            return
//        }
//        
//        logger.info("Refreshing pool statistics")
//        clearMessages()
//        
//        do {
//            try await vault.refreshPoolStats()
//            logger.info("Pool stats refresh successful")
//            errorMessage = nil
//        } catch {
//            logger.error("Failed to refresh stats: \(error.localizedDescription)")
//            errorMessage = "Failed to refresh stats: \(error.localizedDescription)"
//        }
//    }
//    
//    
//    
//    func clearMessages() {
//        logger.debug("Clearing messages")
//        errorMessage = nil
//        successMessage = nil
//    }
//}
//
//// MARK: - Transaction Record
//
//struct TransactionRecord: Identifiable {
//    let id = UUID()
//    let type: TransactionType
//    let amount: Decimal
//    let txHash: String
//    let timestamp: Date
//    
//    enum TransactionType {
//        case deposit
//        case withdrawal
//        
//        var title: String {
//            switch self {
//            case .deposit:
//                return "Deposit"
//            case .withdrawal:
//                return "Withdrawal"
//            }
//        }
//        
//        var icon: String {
//            switch self {
//            case .deposit:
//                return "arrow.down.circle.fill"
//            case .withdrawal:
//                return "arrow.up.circle.fill"
//            }
//        }
//        
//        var color: Color {
//            switch self {
//            case .deposit:
//                return .green
//            case .withdrawal:
//                return .orange
//            }
//        }
//    }
//} 
