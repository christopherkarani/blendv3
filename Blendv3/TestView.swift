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
            
            // Test 4: Test Oracle Service
            await testOracleService()
            
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
    
    func testOracleService() async {
        await addResult("\n📝 Test 4: Oracle Service")
        
        do {
            // Test oracle service with the correct functions
            await addResult("🔮 Testing oracle service with correct functions...")
            let oracleService = DependencyContainer.shared.oracleService
            
            // Test oracle decimals (if available)
            do {
                let decimals = try await oracleService.getOracleDecimals()
                await addResult("✅ Oracle decimals: \(decimals)")
            } catch {
                await addResult("⚠️ Oracle decimals not available: \(error.localizedDescription)")
            }
            
            // Test oracle price for USDC using lastprice()
            await addResult("🔮 Testing oracle lastprice() for USDC...")
            let usdcAddress = BlendUSDCConstants.Testnet.usdc
            
            do {
                let priceData = try await oracleService.getPrice(asset: usdcAddress)
                await addResult("✅ USDC price fetched successfully")
                await addResult("   Price: \(priceData.priceInUSD)")
                await addResult("   Timestamp: \(priceData.timestamp)")
                await addResult("   Asset ID: \(priceData.assetId)")
                await addResult("   Age: \(Date().timeIntervalSince(priceData.timestamp)) seconds")
                
            } catch OracleError.priceNotFound(let asset) {
                await addResult("⚠️ No price data available for asset: \(asset)")
                
            } catch OracleError.noDataAvailable {
                await addResult("⚠️ No oracle data available")
                
            } catch {
                await addResult("❌ Oracle price fetch failed: \(error.localizedDescription)")
            }
            
            // Test multiple assets
            await addResult("🔮 Testing multiple assets...")
            let testAssets = [
                BlendUSDCConstants.Testnet.usdc,
                BlendUSDCConstants.Testnet.xlm,
                BlendUSDCConstants.Testnet.blnd,
                BlendUSDCConstants.Testnet.wbtc,
                BlendUSDCConstants.Testnet.weth
            ]
            
            do {
                let prices = try await oracleService.getPrices(assets: testAssets)
                await addResult("✅ Fetched prices for \(prices.count) assets:")
                
                for (asset, priceData) in prices {
                    let symbol = getAssetSymbol(for: asset)
                    await addResult("   \(symbol): $\(priceData.priceInUSD)")
                }
                
            } catch {
                await addResult("❌ Multiple asset price fetch failed: \(error.localizedDescription)")
            }
            
        } catch {
            await addResult("❌ Oracle service test failed: \(error.localizedDescription)")
            
            // Provide more specific error information
            if let oracleError = error as? OracleError {
                switch oracleError {
                case .priceNotFound(let asset, _):
                    await addResult("   Price not found for asset: \(asset)")
                case .priceNotAvailable(let asset, _):
                    await addResult("   Price data not available for asset: \(asset)")
                case .noDataAvailable:
                    await addResult("   No oracle data available")
                case .maxRetriesExceeded:
                    await addResult("   Maximum retry attempts exceeded")
                case .invalidResponse:
                    await addResult("   Invalid response from oracle")
                case .networkError(let networkError, let context):
                    await addResult("   Network error: \(networkError.localizedDescription)\(context != nil ? ", Context: \(context!)" : "")")
                case .contractError(let code, let message):
                    await addResult("   Contract error [\(code)]: \(message)")
                case .assetParameterError(let asset, let reason):
                    await addResult("   Asset parameter error for \(asset): \(reason)")
                case .parsingError(let field, let expectedType, let actualType):
                    await addResult("   Parsing error for field '\(field)': expected \(expectedType), got \(actualType)")
                case .simulationError(let transactionHash, let error):
                    let txInfo = transactionHash != nil ? " (tx: \(transactionHash!))" : ""
                    await addResult("   Transaction simulation failed\(txInfo): \(error)")
                case .rpcError(let endpoint, let statusCode, let message):
                    let statusInfo = statusCode != nil ? " (status: \(statusCode!))" : ""
                    await addResult("   RPC error from \(endpoint)\(statusInfo): \(message)")

                }
            }
        }
    }
    
    /// Helper function to get asset symbol from address
    private func getAssetSymbol(for address: String) -> String {
        print("Address code: ", address)
        let assetMapping = [
            BlendUSDCConstants.Testnet.usdc: "USDC",
            BlendUSDCConstants.Testnet.xlm: "XLM",
            BlendUSDCConstants.Testnet.blnd: "BLND",
            BlendUSDCConstants.Testnet.weth: "wETH",
            BlendUSDCConstants.Testnet.wbtc: "wBTC"
        ]
        return assetMapping[address] ?? "UNKNOWN"
    }
}

// Preview
struct TestView_Previews: PreviewProvider {
    static var previews: some View {
        TestView()
    }
} 
