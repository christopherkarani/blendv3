# Blend Protocol Swift - Developer Quick Start Guide

## 🚀 Getting Started

This guide helps developers quickly understand and work with the Blend Protocol Swift implementation. The codebase is modular, well-tested, and production-ready.

## 📁 Project Structure

```
Blendv3/
├── Core/
│   ├── Utils/
│   │   ├── FixedMath.swift              # Precise decimal arithmetic
│   │   └── Logger.swift                 # Categorized logging system
│   ├── Protocols/
│   │   ├── BlendRateCalculatorProtocol.swift
│   │   ├── BlendOracleServiceProtocol.swift
│   │   └── CacheServiceProtocol.swift
│   ├── Services/
│   │   ├── BlendRateCalculator.swift    # Core rate calculations
│   │   ├── EnhancedBlendRateCalculator.swift # Reactive rate adjustments
│   │   ├── BlendOracleService.swift     # Oracle integration
│   │   ├── NetworkService.swift         # Stellar/Soroban RPC
│   │   ├── CacheService.swift           # Intelligent caching
│   │   └── BackstopCalculatorService.swift # Backstop mechanisms
│   ├── Models/
│   │   ├── ReactiveRateModifier.swift   # Dynamic rate adjustments
│   │   └── BackstopModels.swift         # Backstop data models
│   └── DependencyInjection/
│       └── DependencyContainer.swift    # Service injection
├── ViewModels/
│   └── PoolViewModel.swift              # MVVM presentation logic
├── Views/
│   └── PoolStatisticsView.swift         # SwiftUI components
├── Tests/                               # Comprehensive unit tests
└── Documentation/                       # Implementation guides
```

## 🔧 Core Components

### 1. Fixed-Point Arithmetic (`FixedMath.swift`)

All financial calculations use 7-decimal fixed-point arithmetic for precision:

```swift
// Convert to fixed-point
let fixedValue = FixedMath.toFixed(value: 0.05, decimals: 7) // 5% = 500000

// Perform calculations
let result = FixedMath.mulFloor(amount, rate, scalar: FixedMath.SCALAR_7)

// Convert back to float
let percentage = FixedMath.toFloat(value: result, decimals: 7)
```

### 2. Rate Calculator (`BlendRateCalculator.swift`)

Calculate supply and borrow rates using the three-slope model:

```swift
let calculator = BlendRateCalculator()

// Calculate supply APR
let supplyAPR = calculator.calculateSupplyAPR(
    curIr: currentInterestRate,
    curUtil: currentUtilization,
    backstopTakeRate: backstopTakeRate
)

// Calculate borrow APR
let borrowAPR = calculator.calculateBorrowAPR(
    utilization: utilization,
    config: interestRateConfig
)
```

### 3. Enhanced Rate Calculator with Reactive Modifiers

For dynamic rate adjustments based on market conditions:

```swift
let enhancedCalculator = EnhancedBlendRateCalculator(
    baseCalculator: BlendRateCalculator()
)

// Calculate with reactive adjustments
let reactiveRate = enhancedCalculator.calculateReactiveInterestRate(
    utilization: currentUtilization,
    config: rateConfig,
    modifier: rateModifier
)

// Update rate modifier based on conditions
let updatedModifier = enhancedCalculator.updateRateModifier(
    currentModifier: modifier,
    currentUtilization: utilization,
    targetUtilization: targetUtil,
    deltaTime: timeElapsed
)
```

### 4. Oracle Service (`BlendOracleService.swift`)

Fetch asset prices with fallback and caching:

```swift
let oracleService = BlendOracleService(
    networkService: networkService,
    cacheService: cacheService
)

// Get single asset price
let priceData = try await oracleService.getPrice(asset: "USDC")

// Get multiple asset prices
let prices = try await oracleService.getPrices(assets: ["USDC", "XLM", "BTC"])
```

### 5. Backstop Calculator (`BackstopCalculatorService.swift`)

Comprehensive backstop calculations:

```swift
let backstopCalculator = BackstopCalculatorService(
    oracleService: oracleService,
    cacheService: cacheService
)

// Calculate backstop APR
let backstopAPR = try await backstopCalculator.calculateBackstopAPRFromReserves(
    backstopPool: pool,
    poolReserves: reserves
)

// Calculate claimable emissions
let updatedUserState = backstopCalculator.calculateClaimableEmissions(
    userState: userEmissionsState,
    emissionsData: poolEmissions,
    backstopPool: pool
)

// Validate auction bid
let bidValidation = backstopCalculator.validateAuctionBid(
    auction: auctionData,
    bidAmount: bidAmount,
    bidder: userAddress
)
```

## 🔍 Logging & Debugging

### Categorized Logging System

```swift
// Rate calculation logging
BlendLogger.rateCalculation(
    operation: "calculateSupplyAPR",
    inputs: ["utilization": utilization, "rate": interestRate],
    result: supplyAPR
)

// Oracle price logging
BlendLogger.oraclePrice(
    asset: "USDC",
    price: priceData.price,
    staleness: staleness
)

// Network operation logging
BlendLogger.network("Fetching prices for assets: \(assetIds)")

// Cache operation logging
BlendLogger.cache("Cache hit for key: \(key), TTL: \(ttl)")

// Error logging
BlendLogger.error("Failed to fetch price for \(asset): \(error)")
```

### Performance Measurement

```swift
// Automatic performance measurement
let result = measurePerformance(operation: "calculateBorrowAPR", category: .rateCalculation) {
    return calculator.calculateBorrowAPR(utilization: util, config: config)
}
// Automatically logs: "calculateBorrowAPR completed in 0.8ms"
```

### Log Filtering Commands

```bash
# View rate calculations
log stream --predicate 'subsystem == "com.blend.protocol" AND eventMessage CONTAINS "calculateSupplyAPR"'

# View oracle operations
log stream --predicate 'subsystem == "com.blend.protocol" AND eventMessage CONTAINS "oraclePrice"'

# View cache operations
log stream --predicate 'subsystem == "com.blend.protocol" AND eventMessage CONTAINS "cache"'

# View performance metrics
log stream --predicate 'subsystem == "com.blend.protocol" AND eventMessage CONTAINS "completed in"'
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme Blendv3Tests

# Run specific test class
xcodebuild test -scheme Blendv3Tests -only-testing:BlendRateCalculatorTests

# Run with coverage
xcodebuild test -scheme Blendv3Tests -enableCodeCoverage YES
```

### Test Structure

```swift
// Example test structure
final class BlendRateCalculatorTests: XCTestCase {
    private var sut: BlendRateCalculator!
    
    override func setUp() {
        super.setUp()
        sut = BlendRateCalculator()
    }
    
    func testCalculateSupplyAPR_withValidInputs_returnsCorrectAPR() {
        // Given
        let curIr = FixedMath.toFixed(value: 0.05, decimals: 7)
        let curUtil = FixedMath.toFixed(value: 0.8, decimals: 7)
        let backstopTakeRate = FixedMath.toFixed(value: 0.1, decimals: 7)
        
        // When
        let result = sut.calculateSupplyAPR(
            curIr: curIr,
            curUtil: curUtil,
            backstopTakeRate: backstopTakeRate
        )
        
        // Then
        XCTAssertGreaterThan(result, 0)
        XCTAssertLessThan(result, curIr) // Should be less than borrow rate
    }
}
```

## 🔧 Dependency Injection

### Setting Up Services

```swift
// Create dependency container
let container = DependencyContainer()

// Register services
container.register(CacheServiceProtocol.self) { CacheService() }
container.register(NetworkServiceProtocol.self) { NetworkService() }
container.register(BlendOracleServiceProtocol.self) { 
    BlendOracleService(
        networkService: container.resolve(NetworkServiceProtocol.self)!,
        cacheService: container.resolve(CacheServiceProtocol.self)!
    )
}

// Use in ViewModels
class PoolViewModel: ObservableObject {
    private let rateCalculator: BlendRateCalculatorProtocol
    private let oracleService: BlendOracleServiceProtocol
    
    init(container: DependencyContainer) {
        self.rateCalculator = container.resolve(BlendRateCalculatorProtocol.self)!
        self.oracleService = container.resolve(BlendOracleServiceProtocol.self)!
    }
}
```

## 📊 Common Use Cases

### 1. Calculate Pool APRs

```swift
func calculatePoolAPRs(poolData: PoolData) async throws -> PoolAPRs {
    // Get current oracle prices
    let prices = try await oracleService.getPrices(assets: poolData.assetIds)
    
    // Calculate utilization
    let utilization = poolData.totalBorrowed / poolData.totalSupplied
    
    // Calculate rates
    let borrowAPR = rateCalculator.calculateBorrowAPR(
        utilization: utilization,
        config: poolData.interestRateConfig
    )
    
    let supplyAPR = rateCalculator.calculateSupplyAPR(
        curIr: borrowAPR,
        curUtil: utilization,
        backstopTakeRate: poolData.backstopTakeRate
    )
    
    return PoolAPRs(supply: supplyAPR, borrow: borrowAPR)
}
```

### 2. Handle Backstop Operations

```swift
func processBackstopWithdrawal(
    withdrawal: QueuedWithdrawal,
    pool: BackstopPool
) -> WithdrawalResult {
    // Check if withdrawal is executable
    guard withdrawal.isExecutable else {
        return .notReady(timeRemaining: withdrawal.timeUntilExecutable)
    }
    
    // Calculate impact
    let impact = backstopCalculator.calculateWithdrawalImpact(
        withdrawal: withdrawal,
        backstopPool: pool
    )
    
    // Check severity
    if impact.impactSeverity == .critical {
        return .blocked(reason: "Would breach minimum threshold")
    }
    
    return .approved(impact: impact)
}
```

### 3. Validate Interest Rate Configuration

```swift
func validateRateConfig(_ config: InterestRateConfig) -> ValidationResult {
    let enhancedCalculator = EnhancedBlendRateCalculator(
        baseCalculator: BlendRateCalculator()
    )
    
    let validation = enhancedCalculator.validateThreeSlopeModel(config)
    
    if !validation.isValid {
        BlendLogger.error("Invalid rate configuration: \(validation.issues)")
        return .invalid(issues: validation.issues)
    }
    
    return .valid
}
```

## 🚀 Performance Best Practices

### 1. Use Caching Effectively

```swift
// Cache expensive calculations
let cacheKey = "pool_\(poolId)_apr_\(Date().timeIntervalSince1970 / 300)" // 5-min buckets
if let cachedAPR = cacheService.get(cacheKey, as: Decimal.self) {
    return cachedAPR
}

let apr = calculateAPR(poolData)
cacheService.set(apr, forKey: cacheKey, ttl: 300) // 5 minutes
return apr
```

### 2. Batch Oracle Requests

```swift
// Instead of multiple individual requests
let usdcPrice = try await oracleService.getPrice(asset: "USDC")
let xlmPrice = try await oracleService.getPrice(asset: "XLM")

// Use batch request
let prices = try await oracleService.getPrices(assets: ["USDC", "XLM"])
```

### 3. Use Fixed-Point Arithmetic

```swift
// Avoid floating-point calculations
let percentage = 0.05 // ❌ Floating-point
let rate = FixedMath.toFixed(value: 0.05, decimals: 7) // ✅ Fixed-point
```

## 🔒 Error Handling

### Common Error Types

```swift
// Oracle errors
catch OracleError.priceNotFound(let asset) {
    BlendLogger.error("Price not found for asset: \(asset)")
    // Handle gracefully with fallback
}

// Network errors
catch NetworkError.requestTimeout {
    BlendLogger.error("Network request timed out")
    // Retry with exponential backoff
}

// Calculation errors
catch CalculationError.invalidInput(let message) {
    BlendLogger.error("Invalid calculation input: \(message)")
    // Validate inputs and show user-friendly error
}
```

### Graceful Degradation

```swift
func getAssetPrice(asset: String) async -> Decimal? {
    do {
        return try await oracleService.getPrice(asset: asset).price
    } catch {
        BlendLogger.error("Failed to get price for \(asset): \(error)")
        
        // Try cache as fallback
        if let cachedPrice = cacheService.get("price_\(asset)", as: PriceData.self) {
            BlendLogger.warning("Using cached price for \(asset)")
            return cachedPrice.price
        }
        
        return nil
    }
}
```

## 📱 SwiftUI Integration

### ViewModel Pattern

```swift
@MainActor
class PoolViewModel: ObservableObject {
    @Published var supplyAPR: Double = 0
    @Published var borrowAPR: Double = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let rateCalculator: BlendRateCalculatorProtocol
    private let oracleService: BlendOracleServiceProtocol
    
    func refreshRates() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let rates = try await calculateCurrentRates()
            supplyAPR = FixedMath.toFloat(value: rates.supply, decimals: 7)
            borrowAPR = FixedMath.toFloat(value: rates.borrow, decimals: 7)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load rates: \(error.localizedDescription)"
            BlendLogger.error("Rate calculation failed: \(error)")
        }
    }
}
```

### View Implementation

```swift
struct PoolStatisticsView: View {
    @StateObject private var viewModel: PoolViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView("Loading rates...")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Supply APR")
                        Spacer()
                        Text("\(viewModel.supplyAPR, specifier: "%.2f")%")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Borrow APR")
                        Spacer()
                        Text("\(viewModel.borrowAPR, specifier: "%.2f")%")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .task {
            await viewModel.refreshRates()
        }
    }
}
```

## 🎯 Next Steps

1. **Explore the codebase**: Start with `BlendRateCalculator.swift` for core functionality
2. **Run the tests**: Understand expected behavior through comprehensive test suite
3. **Check the logs**: Use the logging system to understand data flow
4. **Read the documentation**: Detailed implementation guides in `/Documentation`
5. **Experiment**: Use the playground-style test methods to explore calculations

## 📚 Additional Resources

- **Architecture Overview**: `Documentation/ARCHITECTURE.md`
- **Implementation Details**: `Documentation/PRIORITY_*_IMPLEMENTATION.md`
- **Project Completion**: `Documentation/PROJECT_COMPLETION_SUMMARY.md`
- **Test Examples**: All test files in `Tests/` directory

The codebase is designed to be self-documenting with comprehensive logging, clear naming conventions, and extensive test coverage. Happy coding! 🚀 