import Foundation
@preconcurrency import stellarsdk

@main
struct BlendVaultDebugTest {
    static func main() async {
        print("🔧 Starting BlendVault Debug Test...")
        
        do {
            // Test 1: Try to create a BlendVault instance
            print("📋 Test 1: Creating BlendVault instance...")
            let keyPair = try KeyPair.generateRandomKeyPair()
            let userAddress = keyPair.accountId
            
            let config = BlendVaultConfig(
                network: .testnet,
                primaryPoolID: BlendConstants.Testnet.xlmUsdcPool,
                poolIDs: [BlendConstants.Testnet.xlmUsdcPool]
            )
            
            let vault = try await BlendVault(
                keyPair: keyPair,
                userAddress: userAddress,
                config: config
            )
            
            print("✅ BlendVault created successfully")
            
            // Test 2: Try to get available assets
            print("\n📋 Test 2: Getting available assets...")
            let assets = try await vault.getAvailableAssets()
            print("✅ Found \(assets.count) assets")
            for asset in assets {
                print("  - \(asset.symbol) (\(asset.contractAddress))")
            }
            
            // Test 3: Try to get pool stats
            print("\n📋 Test 3: Getting pool stats...")
            let poolStats = try await vault.getPoolStats()
            print("✅ Pool stats retrieved:")
            print("  - Pool ID: \(poolStats.poolID)")
            print("  - Total Supplied: $\(poolStats.totalSuppliedUSD)")
            print("  - Total Borrowed: $\(poolStats.totalBorrowedUSD)")
            print("  - Utilization: \(poolStats.utilizationRate * 100)%")
            
            // Test 4: Try to get user stats
            print("\n📋 Test 4: Getting user stats...")
            let userStats = try await vault.getUserStats()
            print("✅ User stats retrieved:")
            print("  - Address: \(userStats.userAddress)")
            print("  - Positions: \(userStats.positions.count)")
            print("  - Total Collateral: $\(userStats.totalCollateralUSD)")
            print("  - Health Factor: \(userStats.healthFactor)")
            
            print("\n🎉 All tests completed successfully!")
            
        } catch {
            print("❌ Test failed with error:")
            print("   Type: \(type(of: error))")
            print("   Message: \(error.localizedDescription)")
            
            if let blendError = error as? BlendVaultError {
                print("   Blend Error Details: \(blendError.debugDescription)")
                if let suggestion = blendError.recoverySuggestion {
                    print("   Suggestion: \(suggestion)")
                }
            }
            
            print("\n🔍 Debug Information:")
            print("   Thread: \(Thread.current)")
            print("   Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        }
    }
} 