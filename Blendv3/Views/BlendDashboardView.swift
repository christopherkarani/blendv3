//
//  BlendDashboardView.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

struct BlendDashboardView: View {
    @EnvironmentObject var viewModel: BlendViewModel
    @State private var showDepositSheet = false
    @State private var showWithdrawSheet = false
    @State private var showTransactionHistory = false
    @State private var showDebugLogs = false
    @State private var showTestView = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Account Info Card
                accountInfoCard
                
                // Account Status Card (if not ready)
                if let status = viewModel.accountStatus, !status.isReady {
                    accountStatusCard
                }
                
                // Pool Stats Card
                poolStatsCard
                
                // Action Buttons
                actionButtons
                
                // Messages
                if let errorMessage = viewModel.errorMessage {
                    MessageBanner(message: errorMessage, type: .error)
                }
                
                if let successMessage = viewModel.successMessage {
                    MessageBanner(message: successMessage, type: .success)
                }
                
                // Debug section (temporary)
                #if DEBUG
                VStack(spacing: 12) {
                    Text("Debug Tools")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        Task {
                            print("🎯 DEBUG: Manual refresh triggered")
                            await viewModel.checkAccountStatus()
                        }
                    }) {
                        Label("Check Account", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        Task {
                            print("🎯 DEBUG: Manual stats refresh triggered")
                            await viewModel.refreshStats()
                        }
                    }) {
                        Label("Refresh Stats", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        showTestView = true
                    }) {
                        Label("Run SDK Tests", systemImage: "hammer.circle")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                #endif
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await viewModel.refreshStats()
        }
        .sheet(isPresented: $showDepositSheet) {
            TransactionSheet(type: .deposit)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showWithdrawSheet) {
            TransactionSheet(type: .withdrawal)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showTransactionHistory) {
            TransactionHistoryView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showDebugLogs) {
            DebugLogView()
        }
        .sheet(isPresented: $showTestView) {
            TestView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        showDebugLogs = true
                    }) {
                        Image(systemName: "ant.circle")
                    }
                    
                    Button(action: {
                        showTransactionHistory = true
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var accountInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connected Account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.shortPublicKey)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if let status = viewModel.accountStatus {
                    Image(systemName: status.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(status.isReady ? .green : .orange)
                        .font(.title2)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Divider()
            
            HStack {
                Label("Testnet", systemImage: "network")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let status = viewModel.accountStatus {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("XLM: \(formatDecimal(status.xlmBalance))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if status.hasUSDCTrustline {
                            Text("USDC: \(formatDecimal(status.usdcBalance))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    UIPasteboard.general.string = viewModel.publicKey
                    viewModel.successMessage = "Public key copied!"
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var accountStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Account Setup Required")
                        .font(.headline)
                    
                    if let status = viewModel.accountStatus {
                        Text(status.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if let status = viewModel.accountStatus {
                if status.needsFunding {
                    VStack(spacing: 8) {
                        Text("Fund your account with XLM on testnet:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Link("Get Testnet XLM", 
                             destination: URL(string: "https://laboratory.stellar.org/#account-creator?network=test")!)
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                    }
                } else if status.needsUSDCTrustline {
                    Button(action: {
                        Task {
                            await viewModel.createUSDCTrustline()
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create USDC Trustline")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(16)
    }
    
    private var poolStatsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Pool Statistics")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let stats = viewModel.poolStats {
                VStack(spacing: 12) {
                    StatRow(
                        title: "Total Supplied",
                        value: formatUSDC(stats.totalSupplied),
                        icon: "dollarsign.circle.fill",
                        color: .blue
                    )
                    
                    StatRow(
                        title: "Total Borrowed",
                        value: formatUSDC(stats.totalBorrowed),
                        icon: "arrow.up.circle.fill",
                        color: .orange
                    )
                    
                    StatRow(
                        title: "Available Liquidity",
                        value: formatUSDC(stats.availableLiquidity),
                        icon: "drop.circle.fill",
                        color: .green
                    )
                    
                    StatRow(
                        title: "Current APY",
                        value: formatPercentage(stats.currentAPY),
                        icon: "percent",
                        color: .purple
                    )
                    
                    StatRow(
                        title: "Utilization Rate",
                        value: formatPercentage(stats.utilizationRate),
                        icon: "chart.pie.fill",
                        color: .indigo
                    )
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("Loading pool data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            ActionButton(
                title: "Deposit",
                icon: "arrow.down.circle.fill",
                color: .green,
                action: {
                    showDepositSheet = true
                }
            )
            
            ActionButton(
                title: "Withdraw",
                icon: "arrow.up.circle.fill",
                color: .orange,
                action: {
                    showWithdrawSheet = true
                }
            )
        }
    }
    
    // MARK: - Helpers
    
    private func formatUSDC(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    private func formatPercentage(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        let decimalValue = value / 100
        return formatter.string(from: decimalValue as NSDecimalNumber) ?? "0.00%"
    }
    
    private func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 7
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "0.00"
    }
}

// MARK: - Supporting Views

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

struct MessageBanner: View {
    let message: String
    let type: MessageType
    
    enum MessageType {
        case success
        case error
        
        var color: Color {
            switch self {
            case .success:
                return .green
            case .error:
                return .red
            }
        }
        
        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.triangle.fill"
            }
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(type.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
} 