//
//  Example_Usage.swift
//  Blendv3
//
//  Example usage of BlendUSDCVault
//

import Foundation
import stellarsdk
import Blendv3

// MARK: - Example Usage

func exampleUsage() async {
    do {
        // 1. Create a signer with your secret key
        let secretKey = "YOUR_SECRET_KEY_HERE" // Replace with actual secret key
        let signer = try KeyPairSigner(secretSeed: secretKey)
        
        // 2. Initialize the vault (defaults to testnet)
        let vault = BlendUSDCVault(signer: signer, network: .testnet)
        
        // 3. Deposit USDC
        print("Depositing 100 USDC...")
        let depositTxHash = try await vault.deposit(amount: 100.0)
        print("Deposit successful! Transaction: \(depositTxHash)")
        
        // 4. Fetch and display pool statistics
        try await vault.refreshPoolStats()
        if let stats = vault.poolStats {
            print("\n--- Pool Statistics ---")
            print("Total Supplied: \(stats.totalSupplied) USDC")
            print("Total Borrowed: \(stats.totalBorrowed) USDC")
            print("Available Liquidity: \(stats.availableLiquidity) USDC")
            print("Current APY: \(stats.currentAPY)%")
            print("Utilization Rate: \(stats.utilizationRate * 100)%")
            print("Backstop Reserve: \(stats.backstopReserve) USDC")
            print("Last Updated: \(stats.lastUpdated)")
        }
        
        // 5. Withdraw USDC
        print("\nWithdrawing 50 USDC...")
        let withdrawTxHash = try await vault.withdraw(amount: 50.0)
        print("Withdrawal successful! Transaction: \(withdrawTxHash)")
        
    } catch {
        print("Error: \(error)")
    }
}

// MARK: - SwiftUI Example

import SwiftUI
import Combine

class BlendViewModel: ObservableObject {
    private let vault: BlendUSDCVault
    private var cancellables = Set<AnyCancellable>()
    
    @Published var poolStats: BlendPoolStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(signer: BlendSigner) {
        self.vault = BlendUSDCVault(signer: signer, network: .testnet)
        
        // Bind vault state to view model
        vault.$poolStats
            .assign(to: &$poolStats)
        
        vault.$isLoading
            .assign(to: &$isLoading)
        
        vault.$error
            .map { $0?.localizedDescription }
            .assign(to: &$errorMessage)
    }
    
    func deposit(amount: Decimal) async {
        do {
            _ = try await vault.deposit(amount: amount)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func withdraw(amount: Decimal) async {
        do {
            _ = try await vault.withdraw(amount: amount)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func refreshStats() async {
        do {
            try await vault.refreshPoolStats()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BlendView: View {
    @StateObject private var viewModel: BlendViewModel
    @State private var amountText = ""
    
    init(signer: BlendSigner) {
        _viewModel = StateObject(wrappedValue: BlendViewModel(signer: signer))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Pool Stats
            if let stats = viewModel.poolStats {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pool Statistics")
                        .font(.headline)
                    
                    HStack {
                        Text("Total Supplied:")
                        Spacer()
                        Text("\(stats.totalSupplied) USDC")
                    }
                    
                    HStack {
                        Text("Current APY:")
                        Spacer()
                        Text("\(stats.currentAPY)%")
                    }
                    
                    HStack {
                        Text("Available:")
                        Spacer()
                        Text("\(stats.availableLiquidity) USDC")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Amount Input
            TextField("Amount (USDC)", text: $amountText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
            
            // Action Buttons
            HStack(spacing: 20) {
                Button("Deposit") {
                    if let amount = Decimal(string: amountText) {
                        Task {
                            await viewModel.deposit(amount: amount)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
                
                Button("Withdraw") {
                    if let amount = Decimal(string: amountText) {
                        Task {
                            await viewModel.withdraw(amount: amount)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)
            }
            
            // Error Message
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            // Loading Indicator
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .padding()
        .task {
            await viewModel.refreshStats()
        }
    }
} 