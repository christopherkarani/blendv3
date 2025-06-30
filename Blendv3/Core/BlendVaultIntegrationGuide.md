# BlendVault Integration Guide

## Overview

BlendVault is the primary interface for interacting with Blend Protocol liquidity pools and backstop. This guide shows how to integrate BlendVault into your Swift application.

## Installation & Setup

### 1. Import Required Modules

```swift
import Foundation
import stellarsdk
```

### 2. Initialize BlendVault

```swift
// Create configuration
let config = BlendVaultConfig(
    network: .testnet,                              // or .mainnet
    poolIDs: [
        "POOL_ID_1",
        "POOL_ID_2"
    ],
    primaryPoolID: "POOL_ID_1",                     // Default pool for operations
    cacheConfig: BlendVaultConfig.CacheConfig(
        statsTTL: 300,                              // 5 minutes
        assetDataTTL: 600,                          // 10 minutes  
        userPositionTTL: 60                         // 1 minute
    )
)

// Initialize with KeyPair
do {
    let keyPair = try KeyPair(secretSeed: "YOUR_SECRET_KEY")
    let vault = try await BlendVault(
        keyPair: keyPair,
        userAddress: keyPair.accountId,
        config: config
    )
} catch {
    print("Initialization failed: \(error)")
}
```

## Basic Usage Examples

### Getting Pool Statistics

```swift
// Get stats for primary pool
let poolStats = try await vault.getPoolStats()
print("Total Supplied: \(poolStats.totalSuppliedUSD.asCurrency())")
print("Utilization: \(poolStats.utilizationRate.asPercentage())")

// Get stats for specific pool
let specificStats = try await vault.getPoolStats(poolID: "SPECIFIC_POOL_ID")

// Get all pools stats
let allStats = try await vault.getAllPoolsStats()
print("Total TVL: \(allStats.totalValueLocked.asCurrency())")
```

### Getting User Statistics

```swift
let userStats = try await vault.getUserStats()
print("Health Factor: \(userStats.healthFactor)")
print("Total Collateral: \(userStats.totalCollateralUSD.asCurrency())")
print("Total Borrowed: \(userStats.totalBorrowedUSD.asCurrency())")

// Check if user is healthy
if userStats.isHealthy {
    print("✅ Position is healthy")
} else {
    print("⚠️ Warning: Low health factor")
}
```

### Pool Operations

#### Deposit to Pool

```swift
do {
    // Deposit 100 USDC
    let result = try await vault.depositToPool(
        amount: Decimal(100),
        assetID: "USDC_CONTRACT_ID"
    )
    
    print("✅ Deposit successful: \(result.transactionHash)")
} catch BlendVaultError.insufficientBalance(let required, let available) {
    print("❌ Insufficient balance. Need: \(required), Have: \(available)")
} catch {
    print("❌ Deposit failed: \(error)")
}
```

#### Withdraw from Pool

```swift
// Estimate withdrawal first
let estimate = try await vault.estimatePoolWithdrawal(
    amount: Decimal(50),
    assetID: "USDC_CONTRACT_ID"
)

if !estimate.warnings.isEmpty {
    print("⚠️ Warnings: \(estimate.warnings)")
}

// Execute withdrawal
let result = try await vault.withdrawFromPool(
    amount: Decimal(50),
    assetID: "USDC_CONTRACT_ID"
)
```

### Backstop Operations

#### Deposit to Backstop (Auto Token Handling)

```swift
// Deposit $1000 to backstop - automatically handles BLND/USDC ratio
let backstopResult = try await vault.depositToBackstop(
    amount: Decimal(1000)
)

if let details = backstopResult.details {
    print("Shares received: \(details.sharesReceived ?? 0)")
    print("Tokens used: \(details.tokensUsed ?? [:])")
}
```

#### Queue Backstop Withdrawal

```swift
// Queue withdrawal of 100 shares
let queueResult = try await vault.queueBackstopWithdrawal(
    amount: Decimal(100)
)

// Check withdrawal queue
let queue = try await vault.getWithdrawalQueue()
for withdrawal in queue {
    print("Amount: \(withdrawal.amount)")
    print("Available: \(withdrawal.availableAt.timeRemainingDescription)")
}
```

#### Execute Backstop Withdrawal

```swift
// Check for available withdrawals
if let nextWithdrawal = try await vault.getNextAvailableWithdrawal() {
    let result = try await vault.executeBackstopWithdrawal(
        amount: nextWithdrawal.amount,
        poolID: nextWithdrawal.poolID
    )
    print("✅ Withdrawn: \(result.amount)")
}
```

#### Claim Rewards

```swift
// Claim rewards from all pools
let claimResult = try await vault.claimBackstopRewards()
print("🎁 Claimed: \(claimResult.amount) BLND")
```

### Asset Information

```swift
// Get all available assets
let assets = try await vault.getAvailableAssets()
for asset in assets {
    print("\(asset.symbol): \(asset.price.asCurrency())")
}

// Get specific asset
let usdcAsset = try await vault.getAssetByContractID("USDC_CONTRACT_ID")
print("USDC Price: \(usdcAsset.price)")
```

### Health Monitoring

```swift
// Get backstop health status
let healthStatus = try await vault.getBackstopHealthStatus()
print("Health: \(healthStatus.overallHealth.emoji) \(healthStatus.overallHealth)")

// Check for alerts
let alerts = try await vault.getBackstopHealthAlerts()
for alert in alerts.bySeverity(.critical) {
    print("🚨 CRITICAL: \(alert.message)")
    print("   Action: \(alert.recommendedAction ?? "Monitor situation")")
}
```

## Advanced Usage

### Error Handling Best Practices

```swift
do {
    let result = try await vault.depositToPool(
        amount: amount,
        assetID: assetID
    )
} catch let error as BlendVaultError {
    // Handle specific BlendVault errors
    switch error {
    case .insufficientBalance(let required, let available):
        showError("Need \(required), but only have \(available)")
        
    case .healthFactorTooLow(let current, let minimum):
        showError("Health factor \(current) is below minimum \(minimum)")
        
    case .networkError(let message, let retryable):
        if retryable && error.isRetryable {
            // Retry operation
            retryOperation()
        } else {
            showError(message)
        }
        
    default:
        showError(error.localizedDescription)
    }
    
    // Show recovery suggestion if available
    if let suggestion = error.recoverySuggestion {
        showRecoverySuggestion(suggestion)
    }
} catch {
    // Handle other errors
    showError("Unexpected error: \(error)")
}
```

### Concurrent Operations

```swift
// Fetch multiple data points concurrently
async let poolStats = vault.getPoolStats()
async let userStats = vault.getUserStats()
async let backstopStats = vault.getBackstopStats()

let (pool, user, backstop) = try await (poolStats, userStats, backstopStats)
```

### Refreshing Data

```swift
// Refresh user positions after transaction
let updatedStats = try await vault.refreshUserPositions()

// Subscribe to periodic updates (example)
Task {
    while !Task.isCancelled {
        do {
            let stats = try await vault.getUserStats()
            updateUI(with: stats)
            try await Task.sleep(for: .seconds(30))
        } catch {
            handleError(error)
        }
    }
}
```

## Multi-Pool Support

```swift
// Work with multiple pools
let config = BlendVaultConfig(
    network: .testnet,
    poolIDs: ["POOL_1", "POOL_2", "POOL_3"],
    primaryPoolID: "POOL_1"
)

// Get stats for all pools
let allPoolStats = try await vault.getAllPoolsStats()

// Deposit to specific pool
let result = try await vault.depositToPool(
    amount: Decimal(100),
    assetID: "USDC",
    poolID: "POOL_2"  // Specific pool
)

// Claim rewards from all pools
let rewards = try await vault.claimBackstopRewards() // Claims from all configured pools
```

## Best Practices

1. **Always Handle Errors**: Use proper error handling for all operations
2. **Check Estimates First**: Use estimate methods before executing transactions
3. **Monitor Health**: Regularly check health status and alerts
4. **Cache Appropriately**: BlendVault handles caching internally, but you can adjust TTL values
5. **Use Concurrent Operations**: Leverage Swift concurrency for better performance
6. **Validate Inputs**: Check amounts and asset IDs before operations

## Troubleshooting

### Common Issues

1. **"Vault not initialized"**
   - Ensure you're awaiting the async initializer
   - Check that all required services are available

2. **"Asset not supported"**
   - Verify the asset contract ID is correct
   - Ensure the asset is available in the pool

3. **"Insufficient balance"**
   - Check the error for required vs available amounts
   - Ensure you have the tokens in your wallet

4. **"Health factor too low"**
   - Deposit more collateral before withdrawing
   - Repay some borrowed assets

### Debug Information

```swift
// Enable verbose logging (if implemented)
BlendLogger.shared.logLevel = .debug

// Get comprehensive stats for debugging
let allStats = try await vault.getAllStats()
print("Protocol Overview:")
print("- Total TVL: \(allStats.totalSuppliedUSD.asCurrency())")
print("- Utilization: \(allStats.overallUtilization.asPercentage())")
print("- Backstop Health: \(allStats.backstopUtilization.asPercentage())")
```

## Migration from Old API

If migrating from the previous implementation:

1. Replace hardcoded KeyPair with injection
2. Update service initialization to use BlendVault
3. Replace direct service calls with BlendVault methods
4. Update error handling to use BlendVaultError

Example migration:
```swift
// Old
let positions = try! await userService.getPositions()

// New
let userStats = try await vault.getUserStats()
let positions = userStats.positions
``` 