//
//  TransactionHistoryView.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

struct TransactionHistoryView: View {
    @EnvironmentObject var viewModel: BlendViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.transactionHistory.isEmpty {
                    emptyStateView
                } else {
                    transactionList
                }
            }
            .navigationTitle("Transaction History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Transactions Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your deposit and withdrawal history will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var transactionList: some View {
        List {
            ForEach(viewModel.transactionHistory) { transaction in
                TransactionRow(transaction: transaction)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

struct TransactionRow: View {
    let transaction: TransactionRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Icon
                Image(systemName: transaction.type.icon)
                    .foregroundColor(transaction.type.color)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(transaction.type.color.opacity(0.1))
                    .cornerRadius(20)
                
                // Transaction Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.type.title)
                        .font(.headline)
                    
                    Text(formatDate(transaction.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Amount
                Text(formatUSDC(transaction.amount))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.type.color)
            }
            
            // Transaction Hash
            HStack {
                Text("Tx Hash:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(shortHash(transaction.txHash))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
                
                Spacer()
                
                Button(action: {
                    copyToClipboard(transaction.txHash)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatUSDC(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        let prefix = transaction.type == .deposit ? "+" : "-"
        let formattedAmount = formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
        return "\(prefix)\(formattedAmount)"
    }
    
    private func shortHash(_ hash: String) -> String {
        guard hash.count > 12 else { return hash }
        return "\(hash.prefix(6))...\(hash.suffix(6))"
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
} 