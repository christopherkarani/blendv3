//
//  BlendApp.swift
//  Blendv3
//
//  Main entry point for the Blendv3 application
//

import Foundation
import stellarsdk

// MARK: - Extension Methods (Fix for compilation)

extension Decimal {
    func asCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }
    
    func asPercentage() -> String {
        let percentage = self * 100
        return String(format: "%.2f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }
}

extension HealthLevel {
    var emoji: String {
        switch self {
        case .excellent:
            return "✅"
        case .good:
            return "👍"
        case .moderate:
            return "⚠️"
        case .poor:
            return "⚡"
        case .critical:
            return "🚨"
        }
    }
}

extension Array where Element == BackstopHealthAlert {
    func bySeverity(_ severity: AlertSeverity) -> [BackstopHealthAlert] {
        return filter { $0.severity == severity }
    }
}

@main
struct BlendApp {
    static func main() async {
        print("🚀 BlendVault API Demo Started")
        print("=" * 50)
        
        do {
            // Initialize KeyPair
            print("🔑 Initializing KeyPair...")
            let account = try KeyPair(secretSeed: "SATOWQKPSRAP7D77C6EMT65OIF543WQUOV6DJBPW4SGUNTP2XSIEVUKP")
            print("✅ KeyPair initialized for account: \(account.accountId)")
            
            // Create configuration
            print("\n⚙️ Creating BlendVault configuration...")
            let config = BlendVaultConfig(
                network: .testnet,
                poolIDs: [
                    BlendConstants.Testnet.xlmUsdcPool
                ],
                primaryPoolID: BlendConstants.Testnet.xlmUsdcPool,
                cacheConfig: BlendVaultConfig.CacheConfig(
                    statsTTL: 300,
                    assetDataTTL: 600,
                    userPositionTTL: 60
                )
            )
            print("✅ Configuration created for \(config.network) with \(config.poolIDs.count) pool(s)")
            
            // Initialize BlendVault
            print("\n🏗️ Initializing BlendVault...")
            let vault = try await BlendVault(
                keyPair: account,
                userAddress: account.accountId,
                config: config
            )
            print("✅ BlendVault initialized successfully!")
            
            // Demo the API
            await demonstrateAPI(vault: vault)
            
        } catch let error as BlendVaultError {
            print("\n❌ BlendVault Error: \(error.localizedDescription)")
            if let suggestion = error.recoverySuggestion {
                print("💡 Suggestion: \(suggestion)")
            }
        } catch {
            print("\n❌ Unexpected Error: \(error.localizedDescription)")
        }
        
        print("\n🏁 BlendVault API Demo Completed")
    }
    
    /// Demonstrate various BlendVault API features
    static func demonstrateAPI(vault: BlendVault) async {
        print("\n" + "=" * 50)
        print("📊 DEMONSTRATING BLENDVAULT API")
        print("=" * 50)
        
        // 1. Pool Statistics
        await demonstratePoolStats(vault: vault)
        
        // 2. User Statistics
        await demonstrateUserStats(vault: vault)
        
        // 3. Asset Information
        await demonstrateAssetInfo(vault: vault)
        
        // 4. Backstop Information
        await demonstrateBackstopInfo(vault: vault)
        
        // 5. Health Monitoring
        await demonstrateHealthMonitoring(vault: vault)
        
        // 6. Overall Protocol Stats
        await demonstrateProtocolStats(vault: vault)
    }
    
    static func demonstratePoolStats(vault: BlendVault) async {
        print("\n📈 POOL STATISTICS")
        print("-" * 30)
        
        do {
            let poolStats = try await vault.getPoolStats()
            print("Pool ID: \(poolStats.poolID)")
            print("Name: \(poolStats.name)")
            print("Total Supplied: \(poolStats.totalSuppliedUSD.asCurrency())")
            print("Total Borrowed: \(poolStats.totalBorrowedUSD.asCurrency())")
            print("Utilization Rate: \(poolStats.utilizationRate.asPercentage())")
            print("Net APY: \(poolStats.netAPY.asPercentage())")
            print("TVL: \(poolStats.tvl.asCurrency())")
            print("Reserves Count: \(poolStats.reserves.count)")
            
            // Show individual reserves
            for (index, reserve) in poolStats.reserves.enumerated() {
                print("  Reserve \(index + 1): \(reserve.symbol)")
                print("    Supplied: \(reserve.totalSuppliedUSD.asCurrency())")
                print("    Borrowed: \(reserve.totalBorrowedUSD.asCurrency())")
                print("    Supply APY: \(reserve.supplyAPY.asPercentage())")
                print("    Borrow APY: \(reserve.borrowAPY.asPercentage())")
            }
            
        } catch {
            print("❌ Failed to get pool stats: \(error.localizedDescription)")
        }
    }
    
    static func demonstrateUserStats(vault: BlendVault) async {
        print("\n👤 USER STATISTICS")
        print("-" * 30)
        
        do {
            let userStats = try await vault.getUserStats()
            print("User Address: \(userStats.userAddress)")
            print("Health Factor: \(userStats.healthFactor)")
            print("Is Healthy: \(userStats.isHealthy ? "✅ Yes" : "⚠️ No")")
            print("Total Collateral: \(userStats.totalCollateralUSD.asCurrency())")
            print("Total Borrowed: \(userStats.totalBorrowedUSD.asCurrency())")
            print("Net APY: \(userStats.netAPY.asPercentage())")
            print("Positions Count: \(userStats.positions.count)")
            
            // Show backstop stats
            let backstop = userStats.backstopStats
            print("Backstop Value: \(backstop.totalBackstopValue.asCurrency())")
            print("Claimable Rewards: \(backstop.totalClaimableRewards.asCurrency())")
            print("Queued Withdrawals: \(backstop.totalQueuedWithdrawals.asCurrency())")
            
        } catch {
            print("❌ Failed to get user stats: \(error.localizedDescription)")
        }
    }
    
    static func demonstrateAssetInfo(vault: BlendVault) async {
        print("\n💰 ASSET INFORMATION")
        print("-" * 30)
        
        do {
            let assets = try await vault.getAvailableAssets()
            print("Available Assets: \(assets.count)")
            
            for (index, asset) in assets.enumerated() {
                print("  Asset \(index + 1):")
                print("    Symbol: \(asset.symbol)")
                print("    Name: \(asset.name)")
                print("    Price: \(asset.price.asCurrency())")
                print("    Decimals: \(asset.decimals)")
                print("    Contract: \(asset.contractAddress)")
            }
            
        } catch {
            print("❌ Failed to get asset info: \(error.localizedDescription)")
        }
    }
    
    static func demonstrateBackstopInfo(vault: BlendVault) async {
        print("\n🛡️ BACKSTOP INFORMATION")
        print("-" * 30)
        
        do {
            let backstopStats = try await vault.getBackstopStats()
            print("Pool ID: \(backstopStats.poolID)")
            print("Total Liquidity: \(backstopStats.totalBackstopLiquidity.asCurrency())")
            print("Backstop APY: \(backstopStats.backstopAPY.asPercentage())")
            print("Total Shares: \(backstopStats.totalShares)")
            print("Queued Withdrawals: \(backstopStats.queuedWithdrawals.asCurrency())")
            print("Utilization Rate: \(backstopStats.utilizationRate.asPercentage())")
            print("BLND Balance: \(backstopStats.blndBalance.asCurrency())")
            print("USDC Balance: \(backstopStats.usdcBalance.asCurrency())")
            
        } catch {
            print("❌ Failed to get backstop info: \(error.localizedDescription)")
        }
    }
    
    static func demonstrateHealthMonitoring(vault: BlendVault) async {
        print("\n🏥 HEALTH MONITORING")
        print("-" * 30)
        
        do {
            let healthStatus = try await vault.getBackstopHealthStatus()
            print("Overall Health: \(healthStatus.overallHealth.emoji) \(healthStatus.overallHealth)")
            print("Utilization Trend: \(healthStatus.utilizationTrend)")
            print("Alerts Count: \(healthStatus.alerts.count)")
            print("Recommendations: \(healthStatus.recommendations.count)")
            
            // Show alerts by severity
            let criticalAlerts = healthStatus.alerts.bySeverity(.critical)
            let warningAlerts = healthStatus.alerts.bySeverity(.warning)
            let infoAlerts = healthStatus.alerts.bySeverity(.info)
            
            if !criticalAlerts.isEmpty {
                print("🚨 Critical Alerts: \(criticalAlerts.count)")
                for alert in criticalAlerts {
                    print("  - \(alert.message)")
                }
            }
            
            if !warningAlerts.isEmpty {
                print("⚠️ Warning Alerts: \(warningAlerts.count)")
                for alert in warningAlerts {
                    print("  - \(alert.message)")
                }
            }
            
            if !infoAlerts.isEmpty {
                print("ℹ️ Info Alerts: \(infoAlerts.count)")
            }
            
            // Show recommendations
            if !healthStatus.recommendations.isEmpty {
                print("💡 Recommendations:")
                for rec in healthStatus.recommendations {
                    print("  - \(rec)")
                }
            }
            
        } catch {
            print("❌ Failed to get health monitoring: \(error.localizedDescription)")
        }
    }
    
    static func demonstrateProtocolStats(vault: BlendVault) async {
        print("\n🌐 PROTOCOL OVERVIEW")
        print("-" * 30)
        
        do {
            let allStats = try await vault.getAllStats()
            print("Total Supplied (Protocol): \(allStats.totalSuppliedUSD.asCurrency())")
            print("Total Borrowed (Protocol): \(allStats.totalBorrowedUSD.asCurrency())")
            print("Total Backstop Liquidity: \(allStats.totalBackstopLiquidity.asCurrency())")
            print("Overall Utilization: \(allStats.overallUtilization.asPercentage())")
            print("Backstop Utilization: \(allStats.backstopUtilization.asPercentage())")
            print("Backstop APY Range: \(allStats.backstopAPYRange.min.asPercentage()) - \(allStats.backstopAPYRange.max.asPercentage())")
            print("Number of Pools: \(allStats.numberOfPools)")
            print("Number of Assets: \(allStats.numberOfAssets)")
            print("Last Updated: \(allStats.lastUpdated)")
            
        } catch {
            print("❌ Failed to get protocol stats: \(error.localizedDescription)")
        }
    }
}

// MARK: - String Extension for Formatting

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
} 



