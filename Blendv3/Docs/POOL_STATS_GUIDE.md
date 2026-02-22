# Comprehensive Pool Statistics Guide

## Overview

The Blend pool now supports comprehensive statistics that aggregate data across **all assets** in the pool, not just USDC. This provides a complete view of the pool's health, utilization, and performance.

## Key Features

### 🏊 Pool-Wide Metrics
- **Total Value Locked (TVL)**: Aggregate value across all assets
- **Overall Utilization**: Weighted utilization across all reserves
- **Health Score**: Calculated based on utilization and diversification
- **Active Reserves**: Number of assets with active liquidity

### 📊 Individual Asset Data
- **Per-Asset Statistics**: Supply, borrow, APY, utilization for each asset
- **Asset Breakdown**: USDC, XLM, BLND, wETH, wBTC
- **Real-time Rates**: Live APR/APY calculations from smart contracts

## Usage Examples

### Basic Pool Statistics

```swift
// Refresh comprehensive pool stats
try await vault.refreshPoolStats()

// Access comprehensive data
if let stats = vault.comprehensivePoolStats {
    print("Total Value Locked: \(stats.poolData.totalValueLocked)")
    print("Overall Utilization: \(stats.poolData.overallUtilization * 100)%")
    print("Health Score: \(stats.poolData.healthScore)")
    print("Active Reserves: \(stats.poolData.activeReserves)")
}
```

### Individual Asset Analysis

```swift
// Get data for specific assets
if let usdcData = stats.allReserves["USDC"] {
    print("USDC Supplied: \(usdcData.totalSupplied)")
    print("USDC APY: \(usdcData.supplyApy)%")
    print("USDC Utilization: \(usdcData.utilizationRate * 100)%")
}

// Iterate through all assets
for (symbol, assetData) in stats.allReserves {
    print("\(symbol): TVL=\(assetData.totalSupplied), APY=\(assetData.supplyApy)%")
}
```

### Quick Summary

```swift
// Get simplified summary
if let summary = vault.getPoolSummary() {
    print("TVL: \(summary.totalValueLocked)")
    print("Available Liquidity: \(summary.availableLiquidity)")
    print("Top Asset: \(summary.topAssetByTVL)")
    print("Average APY: \(summary.averageSupplyAPY)%")
}
```

## Data Models

### ComprehensivePoolStats
```swift
public struct ComprehensivePoolStats {
    public let poolData: PoolLevelData           // Pool-wide metrics
    public let allReserves: [String: AssetReserveData]  // Per-asset data
    public let backstopData: BackstopData        // Insurance data
    public let lastUpdated: Date                 // Timestamp
}
```

### AssetReserveData
```swift
public struct AssetReserveData {
    public let symbol: String                    // "USDC", "XLM", etc.
    public let contractAddress: String           // Asset contract address
    public let totalSupplied: Decimal            // Total supplied amount
    public let totalBorrowed: Decimal            // Total borrowed amount
    public let utilizationRate: Decimal          // Asset utilization
    public let supplyApr: Decimal                // Supply APR
    public let supplyApy: Decimal                // Supply APY
    public let borrowApr: Decimal                // Borrow APR
    public let borrowApy: Decimal                // Borrow APY
    public let collateralFactor: Decimal         // Collateral factor
    public let liabilityFactor: Decimal          // Liability factor
}
```

### PoolSummary
```swift
public struct PoolSummary {
    public let totalValueLocked: Decimal         // Total TVL
    public let totalBorrowed: Decimal            // Total borrowed
    public let overallUtilization: Decimal       // Overall utilization
    public let healthScore: Decimal              // Pool health (0-1)
    public let activeAssets: Int                 // Number of active assets
    public let topAssetByTVL: String            // Highest TVL asset
    public let averageSupplyAPY: Decimal         // Average APY across assets
}
```

## Smart Contract Functions Used

The comprehensive stats leverage multiple smart contract functions:

1. **`get_reserve(asset)`** - Called for each asset (USDC, XLM, BLND, wETH, wBTC)
2. **Pool-level aggregation** - Calculated from individual reserve data
3. **Health scoring** - Based on utilization and diversification metrics

## Health Score Calculation

The pool health score (0-1) considers:
- **Utilization (70% weight)**: Lower utilization = higher stability
- **Diversification (30% weight)**: More active reserves = better risk distribution

```swift
let utilizationScore = max(0, 1 - utilization)  // 1.0 at 0% util, 0.0 at 100%
let diversificationScore = min(1, activeReserves / 5)  // Max score at 5+ reserves
let healthScore = (utilizationScore * 0.7) + (diversificationScore * 0.3)
```

## Migration from USDC-Only Stats

### Backward Compatibility
The original `BlendPoolStats` is still available for backward compatibility:

```swift
// Legacy USDC-only stats (still works)
if let legacyStats = vault.poolStats {
    print("USDC Supplied: \(legacyStats.usdcReserveData.totalSupplied)")
}

// New comprehensive stats
if let comprehensiveStats = vault.comprehensivePoolStats {
    print("Pool TVL: \(comprehensiveStats.poolData.totalValueLocked)")
}
```

### UI Updates
The dashboard now shows:
- Pool-wide metrics at the top
- Individual asset breakdown below
- Fallback to legacy view if comprehensive data unavailable

## Performance Considerations

- **Parallel Fetching**: Asset data is fetched concurrently where possible
- **Error Resilience**: If one asset fails, others continue loading
- **Caching**: Stats are cached until explicitly refreshed
- **Efficient Parsing**: Optimized contract response parsing

## Best Practices

1. **Use Comprehensive Stats**: Prefer `comprehensivePoolStats` over legacy `poolStats`
2. **Handle Errors Gracefully**: Individual assets may fail to load
3. **Monitor Health Score**: Values below 0.7 may indicate risk
4. **Track Utilization**: High utilization (>90%) may affect liquidity
5. **Regular Refresh**: Call `refreshPoolStats()` periodically for live data

## Example Implementation

```swift
class PoolMonitor: ObservableObject {
    @Published var poolHealth: Decimal = 0
    @Published var totalTVL: Decimal = 0
    @Published var riskLevel: RiskLevel = .low
    
    func monitorPool() async {
        try await vault.refreshPoolStats()
        
        guard let stats = vault.comprehensivePoolStats else { return }
        
        await MainActor.run {
            self.poolHealth = stats.poolData.healthScore
            self.totalTVL = stats.poolData.totalValueLocked
            self.riskLevel = calculateRiskLevel(stats)
        }
    }
    
    private func calculateRiskLevel(_ stats: ComprehensivePoolStats) -> RiskLevel {
        let utilization = stats.poolData.overallUtilization
        let health = stats.poolData.healthScore
        
        if health > 0.8 && utilization < 0.7 { return .low }
        if health > 0.6 && utilization < 0.85 { return .medium }
        return .high
    }
}
```

This comprehensive approach gives you complete visibility into the entire Blend pool ecosystem, enabling better risk management and investment decisions. 