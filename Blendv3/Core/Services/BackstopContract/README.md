# BackstopContractService

A comprehensive Swift service for interacting with the Blend Protocol Backstop smart contract on Stellar Soroban.

## Overview

The `BackstopContractService` provides a full-featured, production-ready interface for all Backstop contract operations including deposits, withdrawals, queuing, emissions management, and administrative functions. Built with Swift 6.0, it follows SOLID principles and modern async/await patterns.

## Features

- ✅ **Complete Contract Coverage**: All 16 Backstop contract functions implemented
- ✅ **Swift 6.0 Compatible**: Strict concurrency, typed throws, Sendable protocols
- ✅ **Protocol-Oriented**: Dependency injection ready with `BackstopContractServiceProtocol`
- ✅ **Error Handling**: Comprehensive error types with contract-specific error mapping
- ✅ **Caching**: TTL-based caching for performance optimization
- ✅ **Retry Logic**: Exponential backoff for network resilience
- ✅ **Logging**: Detailed debug logging with operation timing
- ✅ **Batch Operations**: Concurrent processing for multiple pool operations
- ✅ **Type Safety**: Robust type conversions and parameter validation
- ✅ **Testing**: Comprehensive unit test coverage with mocks

## Architecture

```
BackstopContract/
├── Models/                    # Data models and enums
│   └── BackstopModels.swift   # Contract structs, enums, results
├── Protocols/                 # Service interfaces
│   └── BackstopContractServiceProtocol.swift
├── Services/                  # Main service implementation
│   └── BackstopContractService.swift
├── Extensions/                # Service extensions
│   ├── BackstopContractService+Parsing.swift
│   ├── BackstopContractService+Utils.swift
│   └── BackstopContractService+Functions.swift
└── README.md                  # This documentation
```

## Quick Start

### Basic Setup

```swift
import Blendv3

// Create service dependencies
let networkService = NetworkService()
let cacheService = CacheService()

// Initialize for testnet
let backstopService = BackstopContractService.createTestnetService(
    networkService: networkService,
    cacheService: cacheService
)

// Or for mainnet
let mainnetService = BackstopContractService.createMainnetService(
    networkService: networkService,
    cacheService: cacheService
)
```

### Custom Configuration

```swift
let config = BackstopServiceConfig(
    contractAddress: "YOUR_CONTRACT_ADDRESS",
    rpcUrl: "https://soroban-testnet.stellar.org",
    network: .testnet
)

let service = BackstopContractService(
    networkService: networkService,
    cacheService: cacheService,
    config: config
)
```

## Usage Examples

### Core Operations

#### Deposit Tokens

```swift
do {
    let result = try await backstopService.deposit(
        from: "GA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLTJJFC7MGXUA74P7UJVSGZ",
        poolAddress: "GDGPVOKHGQHS2JTZFV6HNPSKXBDLC6RJZLTYSNL55J5EJABSUHVDVBZT",
        amount: Decimal(1000.50)
    )
    print("Received \(result.sharesReceived) backstop shares")
} catch {
    print("Deposit failed: \(error)")
}
```

#### Queue Withdrawal

```swift
do {
    let result = try await backstopService.queueWithdrawal(
        from: userAddress,
        poolAddress: poolAddress,
        amount: Decimal(500)
    )
    print("Queued \(result.sharesQueued) shares for withdrawal")
} catch {
    print("Queue withdrawal failed: \(error)")
}
```

#### Get User Balance

```swift
do {
    let balance = try await backstopService.getUserBalance(
        pool: poolAddress,
        user: userAddress
    )
    print("Shares: \(balance.shares)")
    print("Queued: \(balance.q4w.amount) (epoch \(balance.q4w.epoch))")
} catch {
    print("Failed to get balance: \(error)")
}
```

### Query Operations

#### Get Pool Data

```swift
do {
    let poolData = try await backstopService.getPoolData(pool: poolAddress)
    print("Pool Balance: \(poolData.balance.tokens) tokens, \(poolData.balance.shares) shares")
    print("Emissions Index: \(poolData.emissions.index)")
    print("Last Emission Time: \(Date(timeIntervalSince1970: Double(poolData.emissions.lastTime)))")
} catch {
    print("Failed to get pool data: \(error)")
}
```

#### Get Backstop Token Address

```swift
do {
    let tokenAddress = try await backstopService.getBackstopToken()
    print("Backstop token: \(tokenAddress)")
} catch {
    print("Failed to get token address: \(error)")
}
```

### Emission Operations

#### Claim Rewards

```swift
do {
    let result = try await backstopService.claim(
        from: userAddress,
        poolAddresses: [poolAddress1, poolAddress2],
        to: rewardRecipientAddress
    )
    print("Claimed \(result.totalClaimed) reward tokens")
} catch {
    print("Claim failed: \(error)")
}
```

#### Gulp Pool Emissions

```swift
do {
    let distributed = try await backstopService.gulpPoolEmissions(poolAddress: poolAddress)
    print("Distributed \(distributed) emission tokens")
} catch {
    print("Gulp emissions failed: \(error)")
}
```

### Batch Operations

#### Get Multiple User Balances

```swift
do {
    let pools = [poolAddress1, poolAddress2, poolAddress3]
    let balances = try await backstopService.getUserBalances(
        user: userAddress,
        pools: pools
    )
    
    for (pool, balance) in balances {
        print("Pool \(pool): \(balance.shares) shares")
    }
} catch {
    print("Batch balance query failed: \(error)")
}
```

#### Get Multiple Pool Data

```swift
do {
    let pools = [poolAddress1, poolAddress2]
    let poolDataBatch = try await backstopService.getPoolDataBatch(pools: pools)
    
    for (pool, data) in poolDataBatch {
        print("Pool \(pool): \(data.balance.tokens) tokens")
    }
} catch {
    print("Batch pool data query failed: \(error)")
}
```

## Data Models

### Core Structures

```swift
// User balance information
struct UserBalance {
    let shares: Int128      // Backstop shares owned
    let q4w: Q4W           // Queued for withdrawal data
}

// Queue for withdrawal data
struct Q4W {
    let amount: Int128     // Queued amount
    let epoch: UInt32      // Withdrawal epoch
}

// Pool backstop data
struct PoolBackstopData {
    let balance: PoolBalance           // Current pool balance
    let emissions: BackstopEmissionsData  // Emission tracking
    let q4w: PoolBalance              // Queued withdrawals
}

// Pool balance (shares vs tokens)
struct PoolBalance {
    let shares: Int128     // Share tokens
    let tokens: Int128     // Underlying tokens
}
```

### Result Types

```swift
struct DepositResult {
    let sharesReceived: Int128
}

struct WithdrawalQueueResult {
    let sharesQueued: Int128
}

struct WithdrawResult {
    let amountWithdrawn: Int128
}

struct ClaimResult {
    let totalClaimed: Int128
}

struct TokenValueUpdateResult {
    let blndValue: Int128
    let usdcValue: Int128
}
```

## Error Handling

The service provides comprehensive error handling through the `BackstopError` enum:

```swift
enum BackstopError: Error {
    case networkError(String, Error?)
    case invalidAddress(String)
    case invalidAmount(String)
    case invalidParameters(String)
    case missingRequiredParameter(String)
    case contractError(BackstopContractError)
    case simulationError(String, Error?)
    case parsingError(String, expectedType: String, actualType: String)
    case cacheError(String, Error?)
    case retryExhausted(String, lastError: Error?)
    case configurationError(String)
}
```

### Contract-Specific Errors

```swift
enum BackstopContractError: UInt32, CaseIterable {
    case insufficientFunds = 1
    case insufficientShares = 2
    case invalidPoolAddress = 3
    case withdrawalNotReady = 4
    case noEmissionsToGulp = 5
    case unauthorized = 6
    case poolNotInitialized = 7
    case invalidEpoch = 8
    case zeroAmount = 9
    case contractPaused = 10
    case invalidTokenAddress = 11
    case emissionConfigNotFound = 12
    case rewardAlreadyAdded = 13
    case maxRewardsReached = 14
    case invalidRewardToken = 15
    case tokenValueUpdateFailed = 16
}
```

## Configuration

### Service Configuration

```swift
struct BackstopServiceConfig {
    let contractAddress: String     // Backstop contract address
    let rpcUrl: String             // Soroban RPC endpoint
    let network: Network           // Stellar network (.testnet or .public)
}
```

### Cache Configuration

```swift
struct BackstopCacheConfig {
    let userBalanceTTL: TimeInterval = 30        // 30 seconds
    let poolDataTTL: TimeInterval = 60           // 1 minute
    let emissionDataTTL: TimeInterval = 300      // 5 minutes
    let tokenAddressTTL: TimeInterval = 3600     // 1 hour
}
```

## Performance Considerations

### Caching Strategy

- **User Balances**: 30-second TTL (frequently changing)
- **Pool Data**: 1-minute TTL (moderately changing)
- **Emission Data**: 5-minute TTL (slowly changing)
- **Token Address**: 1-hour TTL (rarely changing)

### Batch Operations

Use batch operations for multiple queries to improve performance:

```swift
// ✅ Good: Concurrent batch operation
let balances = try await service.getUserBalances(user: userAddress, pools: pools)

// ❌ Avoid: Sequential individual calls
var balances: [String: UserBalance] = [:]
for pool in pools {
    balances[pool] = try await service.getUserBalance(pool: pool, user: userAddress)
}
```

### Retry Configuration

The service uses exponential backoff with these defaults:
- Maximum retries: 3
- Initial delay: 1 second
- Backoff multiplier: 2.0

## Testing

The service includes comprehensive unit tests covering:

- ✅ All contract function calls
- ✅ Error scenarios and edge cases
- ✅ Parameter validation
- ✅ Response parsing
- ✅ Caching behavior
- ✅ Retry logic
- ✅ Batch operations

### Running Tests

```swift
// In Xcode
// Navigate to Blendv3Tests/BackstopContract/BackstopContractServiceTests.swift
// Run tests individually or as a suite
```

### Mock Services

Tests use mock implementations of dependencies:

```swift
class MockNetworkService: NetworkService { /* ... */ }
class MockCacheService: CacheServiceProtocol { /* ... */ }
```

## Integration

### Dependency Injection

The service is designed for dependency injection:

```swift
protocol BackstopContractServiceProtocol {
    // All service methods...
}

class BackstopContractService: BackstopContractServiceProtocol {
    init(
        networkService: NetworkService,
        cacheService: CacheServiceProtocol,
        config: BackstopServiceConfig
    )
}
```

### SwiftUI Integration

```swift
@StateObject private var backstopService = BackstopContractService.createTestnetService(
    networkService: NetworkService(),
    cacheService: CacheService()
)

var body: some View {
    VStack {
        // UI components
    }
    .task {
        await loadBackstopData()
    }
}

private func loadBackstopData() async {
    do {
        let balance = try await backstopService.getUserBalance(
            pool: poolAddress,
            user: userAddress
        )
        // Update UI state
    } catch {
        // Handle error
    }
}
```

## Best Practices

### Parameter Validation

Always validate inputs before contract calls:

```swift
// ✅ Good: Service handles validation
try await service.deposit(from: userAddress, poolAddress: poolAddress, amount: amount)

// ❌ Avoid: Manual validation before every call
guard !userAddress.isEmpty else { return }
guard amount > 0 else { return }
// ... validation logic
```

### Error Handling

Use specific error handling for better user experience:

```swift
do {
    let result = try await service.deposit(...)
    // Handle success
} catch BackstopError.contractError(.insufficientFunds) {
    // Show "insufficient funds" message
} catch BackstopError.invalidAmount(let message) {
    // Show amount validation error
} catch BackstopError.networkError(let message, _) {
    // Show network connectivity error
} catch {
    // Show generic error
}
```

### Async/Await Usage

Use proper async/await patterns:

```swift
// ✅ Good: Structured concurrency
await withTaskGroup(of: UserBalance.self) { group in
    for pool in pools {
        group.addTask {
            try await service.getUserBalance(pool: pool, user: user)
        }
    }
    // Collect results
}

// ❌ Avoid: Blocking or callback-based patterns
```

## Debugging

### Logging

The service provides detailed logging for debugging:

```swift
// Enable debug logging
let config = BackstopServiceConfig(...)
let service = BackstopContractService(...)

// Logs include:
// 🛡️ ▶️ Starting deposit
// 🛡️ 📝 from: GA7QYN...
// 🛡️ 📝 poolAddress: GDGPVO...
// 🛡️ 📝 amount: 1000.50
// 🛡️ ✅ deposit completed in 0.85s
```

### Common Issues

1. **Invalid Address Format**: Ensure addresses are valid Stellar account/contract IDs
2. **Network Timeouts**: Check RPC endpoint availability
3. **Amount Precision**: Use Decimal type for monetary amounts
4. **Contract Errors**: Check contract state and user permissions

## License

This service is part of the Blendv3 iOS application and follows the project's licensing terms.

## Contributing

When contributing to the BackstopContractService:

1. Follow existing architectural patterns
2. Add comprehensive tests for new functionality
3. Update documentation for API changes
4. Ensure Swift 6.0 compatibility
5. Follow SOLID principles and protocol-oriented design
