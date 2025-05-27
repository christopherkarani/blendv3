//
//  TransactionSheet.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

struct TransactionSheet: View {
    @EnvironmentObject var viewModel: BlendViewModel
    @Environment(\.dismiss) var dismiss
    
    let type: TransactionType
    @State private var amountText = ""
    @State private var isProcessing = false
    @FocusState private var isAmountFieldFocused: Bool
    
    enum TransactionType {
        case deposit
        case withdrawal
        
        var title: String {
            switch self {
            case .deposit:
                return "Deposit USDC"
            case .withdrawal:
                return "Withdraw USDC"
            }
        }
        
        var buttonTitle: String {
            switch self {
            case .deposit:
                return "Deposit"
            case .withdrawal:
                return "Withdraw"
            }
        }
        
        var icon: String {
            switch self {
            case .deposit:
                return "arrow.down.circle.fill"
            case .withdrawal:
                return "arrow.up.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .deposit:
                return .green
            case .withdrawal:
                return .orange
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: type.icon)
                        .font(.system(size: 60))
                        .foregroundColor(type.color)
                    
                    Text(type.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top, 40)
                
                // Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.headline)
                    
                    HStack {
                        Text("$")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        TextField("0.00", text: $amountText)
                            .font(.title)
                            .keyboardType(.decimalPad)
                            .focused($isAmountFieldFocused)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    if let stats = viewModel.poolStats {
                        HStack {
                            Text("Available: ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatUSDC(type == .deposit ? Decimal(1000000) : stats.availableLiquidity))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(type.color)
                        }
                    }
                }
                
                // Quick Amount Buttons
                HStack(spacing: 12) {
                    ForEach([10, 50, 100, 500], id: \.self) { amount in
                        Button(action: {
                            amountText = "\(amount)"
                        }) {
                            Text("$\(amount)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
                
                // Action Button
                Button(action: performTransaction) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: type.icon)
                            Text(type.buttonTitle)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidAmount ? type.color : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isValidAmount || isProcessing)
                
                // Info Text
                Text("Transaction will be submitted to Stellar testnet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isAmountFieldFocused = true
        }
    }
    
    // MARK: - Computed Properties
    
    private var amount: Decimal? {
        guard let value = Decimal(string: amountText), value > 0 else {
            return nil
        }
        return value
    }
    
    private var isValidAmount: Bool {
        guard let amount = amount else { return false }
        
        if type == .withdrawal, let stats = viewModel.poolStats {
            return amount <= stats.availableLiquidity
        }
        
        return amount > 0 && amount <= 1000000 // Reasonable max limit
    }
    
    // MARK: - Methods
    
    private func performTransaction() {
        guard let amount = amount else { return }
        
        isProcessing = true
        
        Task {
            switch type {
            case .deposit:
                await viewModel.deposit(amount: amount)
            case .withdrawal:
                await viewModel.withdraw(amount: amount)
            }
            
            await MainActor.run {
                isProcessing = false
                if viewModel.errorMessage == nil {
                    dismiss()
                }
            }
        }
    }
    
    private func formatUSDC(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
} 