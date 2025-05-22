//
//  WalletView.swift
//  Blendv3
//
//  Main wallet view for displaying account information
//

import SwiftUI

struct WalletView: View {
    @StateObject private var viewModel = WalletViewModel()
    @State private var showImportSheet = false
    @State private var importSeed = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView("Loading...")
                            .padding()
                    } else if let wallet = viewModel.activeWallet {
                        walletContent(wallet: wallet)
                    } else {
                        emptyWalletView
                    }
                }
                .padding()
            }
            .navigationTitle("Wallet")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.activeWallet != nil {
                        Button("Refresh") {
                            Task {
                                await viewModel.refreshAccountDetails()
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showImportSheet) {
            importWalletSheet
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }    
    // MARK: - Subviews
    
    private var emptyWalletView: some View {
        VStack(spacing: 30) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No wallet connected")
                .font(.title2)
                .foregroundColor(.secondary)
            
            VStack(spacing: 15) {
                Button(action: {
                    Task {
                        await viewModel.createNewWallet()
                    }
                }) {
                    Label("Create New Wallet", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    showImportSheet = true
                }) {
                    Label("Import Wallet", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 50)
    }
    
    private func walletContent(wallet: KeyPair) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Account ID Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Account ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(wallet.accountId)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(Constants.UI.cornerRadius)            
            // Account Details Section
            if let account = viewModel.accountDetails {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Balances")
                        .font(.headline)
                    
                    ForEach(account.balances, id: \.assetCode) { balance in
                        HStack {
                            Text(balance.assetType == AssetTypeAsString.NATIVE ? "XLM" : balance.assetCode ?? "")
                                .font(.subheadline)
                            Spacer()
                            Text(balance.balance)
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(Constants.UI.cornerRadius)
            }
        }
    }
    
    private var importWalletSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Enter your secret seed")
                    .font(.headline)
                
                SecureField("Secret Seed", text: $importSeed)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                
                Button("Import") {
                    Task {
                        await viewModel.importWallet(secretSeed: importSeed)
                        showImportSheet = false
                        importSeed = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(importSeed.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Import Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showImportSheet = false
                        importSeed = ""
                    }
                }
            }
        }
    }
}