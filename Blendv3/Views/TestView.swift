//
//  TestView.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import SwiftUI
import stellarsdk

struct TestView: View {
    @State private var testResults: [String] = []
    @State private var isRunning = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("SDK Test Suite")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Button(action: runTests) {
                    if isRunning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Run Tests")
                            .fontWeight(.semibold)
                    }
                }
                .frame(width: 200, height: 50)
                .background(isRunning ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isRunning)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(testResults, id: \.self) { result in
                            Text(result)
                                .font(.system(.caption, design: .monospaced))
                                .padding(5)
                                .background(result.contains("✅") ? Color.green.opacity(0.1) : 
                                          result.contains("❌") ? Color.red.opacity(0.1) : 
                                          Color.gray.opacity(0.1))
                                .cornerRadius(5)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                .cornerRadius(10)
            }
            .padding()
            .navigationTitle("SDK Tests")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func runTests() {
        isRunning = true
        testResults = []
        
        Task {
            await addResult("🚀 Starting SDK tests...")
            
            // Test 1: Create KeyPair
            await testKeyPair()
            
            // Test 2: Test Horizon Connection
            await testHorizonConnection()
            
            // Test 3: Test Soroban RPC
            await testSorobanRPC()
            
            await MainActor.run {
                isRunning = false
            }
            await addResult("🏁 Tests completed!")
        }
    }
    
    func addResult(_ message: String) async {
        await MainActor.run {
            testResults.append(message)
            print("TEST: \(message)")
        }
    }
    
    func testKeyPair() async {
        await addResult("\n📝 Test 1: KeyPair Creation")
        
        do {
            let secretKey = "SDYH3V6ICEM463OTM7EEK7SNHYILXZRHPY45AYZOSK3N4NLF3NQUI4PQ"
            let keyPair = try KeyPair(secretSeed: secretKey)
            await addResult("✅ KeyPair created successfully")
            await addResult("   Public Key: \(keyPair.accountId)")
        } catch {
            await addResult("❌ KeyPair creation failed: \(error)")
        }
    }
    
    func testHorizonConnection() async {
        await addResult("\n📝 Test 2: Horizon Connection")
        
        let horizonUrl = "https://horizon-testnet.stellar.org"
        let sdk = StellarSDK(withHorizonUrl: horizonUrl)
        
        let publicKey = "GDQERENWDDSQZS7R7WKHZI3BSOYMV3FSWR7TFUYFTKQ447PIX6NREOJM"
        let accountResponseEnum = await sdk.accounts.getAccountDetails(accountId: publicKey)
        
        switch accountResponseEnum {
        case .success(let accountDetails):
            await addResult("✅ Horizon connection successful")
            await addResult("   Account found on testnet")
            await addResult("   Sequence: \(accountDetails.sequenceNumber)")
            await addResult("   Balances: \(accountDetails.balances.count)")
            
            // Show XLM balance
            if let xlmBalance = accountDetails.balances.first(where: { $0.assetType == AssetTypeAsString.NATIVE }) {
                await addResult("   XLM Balance: \(xlmBalance.balance)")
            }
            
        case .failure(let error):
            if case .notFound = error {
                await addResult("⚠️ Account not found on testnet (needs funding)")
            } else {
                await addResult("❌ Horizon error: \(error)")
            }
        }
    }
    
    func testSorobanRPC() async {
        await addResult("\n📝 Test 3: Soroban RPC Connection")
        
        let rpcUrl = "https://soroban-testnet.stellar.org"
        let sorobanServer = SorobanServer(endpoint: rpcUrl)
        sorobanServer.enableLogging = true
        
        let healthEnum = await sorobanServer.getHealth()
        
        switch healthEnum {
        case .success(let health):
            await addResult("✅ Soroban RPC connection successful")
            await addResult("   Status: \(health.status)")
            await addResult("   Latest Ledger: \(health.latestLedger)")
        case .failure(let error):
            await addResult("❌ Soroban RPC failed: \(error)")
            
            // Try to get more details
            switch error {
            case .requestFailed(let message):
                await addResult("   Request failed: \(message)")
            case .errorResponse(let errorData):
                await addResult("   Error response: \(errorData)")
            case .parsingResponseFailed(let message, _):
                await addResult("   Parsing failed: \(message)")
            }
        }
    }
}

// Preview
struct TestView_Previews: PreviewProvider {
    static var previews: some View {
        TestView()
    }
} 