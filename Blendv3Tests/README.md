# Blend v3 Test Suite

This directory contains comprehensive unit and integration tests for the Blend v3 iOS application, with a focus on the Oracle service, BlendUSDCVault, and other core components.

## Test Structure

### Unit Tests
- **BlendOracleServiceTests.swift** - Comprehensive unit tests for the Oracle service with mocked dependencies
- **BlendUSDCVaultTests.swift** - Comprehensive unit tests for the main vault service with mocked dependencies
- **BlendRateCalculatorTests.swift** - Tests for interest rate calculations
- **BlendModelsTests.swift** - Tests for data models and structures

### Integration Tests
- **BlendOracleServiceIntegrationTests.swift** - Real oracle contract interaction tests
- **BlendUSDCVaultIntegrationTests.swift** - Real vault contract interaction tests
- Requires network connectivity and testnet access

### Test Utilities
- **TestConfiguration.swift** - Test configuration, utilities, and constants
- **README.md** - This documentation

## BlendUSDCVault Tests

The BlendUSDCVault tests comprehensively cover the main lending pool service that handles deposits, withdrawals, and pool statistics.

### Core Functionality Tested
1. **Initialization** - Proper setup with different network configurations
2. **Deposit Operations** - Amount validation, transaction handling, state management
3. **Withdraw Operations** - Amount validation, balance checks, transaction processing
4. **Pool Stats Refresh** - Data fetching, parsing, and state updates
5. **Extended Pool Functions** - Status, config, user positions, emissions
6. **True Pool Stats** - Comprehensive multi-asset pool statistics
7. **Error Handling** - Network errors, invalid responses, state management
8. **Performance** - Response time validation and concurrent operations

### Test Categories

#### 🧪 Unit Tests (BlendUSDCVaultTests)
- ✅ **Initialization Testing**: Network configuration, signer setup
- ✅ **Deposit/Withdraw Operations**: Amount validation, transaction flow, error handling
- ✅ **State Management**: Loading states, error states, published properties
- ✅ **Pool Statistics**: Data refresh, parsing, validation
- ✅ **Extended Functions**: Pool status, config, user data, emissions
- ✅ **Error Scenarios**: Network failures, invalid responses, uninitialized states
- ✅ **Performance Testing**: Operation timing, concurrent requests
- ✅ **Edge Cases**: Large amounts, small amounts, concurrent operations
- ✅ **Mock Integration**: Comprehensive mocking with call tracking

#### 🌐 Integration Tests (BlendUSDCVaultIntegrationTests)
- ✅ **Real Contract Calls**: Actual testnet pool contract interactions
- ✅ **Pool Data Validation**: TVL, utilization, APR/APY ranges
- ✅ **Multi-Asset Support**: USDC, XLM, BLND, wETH, wBTC reserves
- ✅ **Configuration Retrieval**: Pool config, oracle address, backstop rate
- ✅ **User Data**: Positions, emissions, collateral, liabilities
- ✅ **State Consistency**: Loading states, error handling with real data
- ✅ **Performance**: Real-world response times and concurrent operations
- ✅ **Data Integrity**: Comprehensive validation of all returned data

## Oracle Service Tests

The Oracle service tests are designed to comprehensively test all three oracle functions:

### Functions Tested
1. **`lastprice(asset: Asset) -> Option<PriceData>`** - Get current price for an asset
2. **`price(asset: Asset, timestamp: u64) -> Option<PriceData>`** - Get price at specific timestamp
3. **`prices(asset: Asset, records: u32) -> Option<Vec<PriceData>>`** - Get historical price records

### Test Categories

#### 🧪 Unit Tests (BlendOracleServiceTests)
- ✅ **Function Testing**: All three oracle functions with various parameters
- ✅ **Error Handling**: Network errors, invalid responses, missing data
- ✅ **Caching**: Cache hits, misses, stale data handling
- ✅ **Retry Logic**: Transient failures and retry mechanisms
- ✅ **Performance**: Response time validation and batch operations
- ✅ **Edge Cases**: Large numbers, zero prices, old timestamps
- ✅ **Data Validation**: Price format, timestamp validation, asset ID matching

#### 🌐 Integration Tests (BlendOracleServiceIntegrationTests)
- ✅ **Real Oracle Calls**: Actual testnet oracle contract interactions
- ✅ **Price Validation**: USDC ~$1.00, XLM, BLND price ranges
- ✅ **Historical Data**: Timestamp-based price retrieval
- ✅ **Multiple Assets**: Batch price fetching from real oracle
- ✅ **Cache Integration**: Real data caching and retrieval
- ✅ **Error Scenarios**: Invalid assets, network issues
- ✅ **Performance**: Real-world response times
- ✅ **Data Integrity**: Comprehensive price data validation

## Running Tests

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ Simulator or Device
- Network connectivity for integration tests

### Unit Tests Only (Default)
```bash
# Run all unit tests (fast, no network required)
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Blendv3Tests/BlendUSDCVaultTests
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Blendv3Tests/BlendOracleServiceTests
```

### Integration Tests
```bash
# Enable integration tests (requires network)
export RUN_INTEGRATION_TESTS=1
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15'

# Run only vault integration tests
export RUN_INTEGRATION_TESTS=1
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Blendv3Tests/BlendUSDCVaultIntegrationTests

# Run only oracle integration tests
export RUN_INTEGRATION_TESTS=1
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Blendv3Tests/BlendOracleServiceIntegrationTests
```

### Performance Tests
```bash
# Enable performance tests (may be slow)
export RUN_PERFORMANCE_TESTS=1
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Verbose Logging
```bash
# Enable detailed test logging
export VERBOSE_TEST_LOGGING=1
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15'
```

### All Tests with Full Configuration
```bash
# Run everything with verbose output
export RUN_INTEGRATION_TESTS=1
export RUN_PERFORMANCE_TESTS=1
export VERBOSE_TEST_LOGGING=1
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Test Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RUN_INTEGRATION_TESTS` | Enable tests that require network connectivity | `0` |
| `RUN_PERFORMANCE_TESTS` | Enable performance/stress tests | `0` |
| `VERBOSE_TEST_LOGGING` | Enable detailed logging during tests | `0` |

## BlendUSDCVault Test Coverage

### ✅ Comprehensive Coverage Achieved

#### Core Functionality
- [x] Initialization with testnet/mainnet configurations
- [x] Deposit operations with amount validation and transaction handling
- [x] Withdraw operations with balance checks and error handling
- [x] Pool stats refresh with data parsing and validation
- [x] Extended pool functions (status, config, positions, emissions)
- [x] True pool stats with multi-asset aggregation

#### State Management
- [x] Loading state management during operations
- [x] Error state handling and clearing
- [x] Published property updates via Combine
- [x] Concurrent operation handling

#### Error Handling
- [x] Network connectivity issues
- [x] Invalid amount validation
- [x] Uninitialized client scenarios
- [x] Invalid response parsing
- [x] Transaction failures

#### Performance & Reliability
- [x] Response time validation (< 30s for pool stats, < 45s for true stats)
- [x] Concurrent operation handling
- [x] Large/small amount edge cases
- [x] Memory usage optimization

#### Integration Scenarios
- [x] Real testnet contract interactions
- [x] Pool data validation (TVL, utilization, APR/APY)
- [x] Multi-asset reserve data fetching
- [x] User position and emission data
- [x] Configuration and status retrieval
- [x] Data consistency between different stat types

## Oracle Test Coverage

### ✅ Comprehensive Coverage Achieved

#### Core Functionality
- [x] `lastprice()` function with valid/invalid assets
- [x] `price()` function with timestamps
- [x] `prices()` function with record counts
- [x] Batch price fetching for multiple assets
- [x] Oracle decimals retrieval

#### Error Handling
- [x] Network connectivity issues
- [x] Invalid asset addresses
- [x] Malformed responses
- [x] Timeout scenarios
- [x] Retry logic with exponential backoff

#### Performance & Reliability
- [x] Response time validation (< 5s for single, < 10s for batch)
- [x] Cache performance (< 0.1s retrieval)
- [x] Concurrent request handling
- [x] Large batch request processing
- [x] Memory usage optimization

#### Data Validation
- [x] Price format validation (positive, not NaN/infinite)
- [x] Timestamp validation (reasonable range)
- [x] Asset ID matching
- [x] Decimal precision handling
- [x] Price range validation for known assets

#### Edge Cases
- [x] Zero prices
- [x] Very large prices (> $1M)
- [x] Historical timestamps (Unix epoch)
- [x] Future timestamps
- [x] Empty asset arrays
- [x] Duplicate assets in batch requests

#### Integration Scenarios
- [x] Real testnet oracle contract calls
- [x] USDC price validation (~$1.00)
- [x] Multiple asset price fetching
- [x] Historical data retrieval
- [x] Cache integration with real data
- [x] Mixed valid/invalid asset handling

## Test Metrics

### Performance Benchmarks
- **Single Oracle Call**: < 5 seconds
- **Batch Oracle Call (100 assets)**: < 10 seconds
- **Vault Pool Stats Refresh**: < 30 seconds
- **Vault True Pool Stats**: < 45 seconds
- **Cache Retrieval**: < 0.1 seconds
- **Cache Speedup**: 10x faster than network calls

### Coverage Goals
- **Unit Test Coverage**: > 95%
- **Integration Test Coverage**: > 80%
- **Error Path Coverage**: > 90%
- **Performance Test Coverage**: > 70%

## Troubleshooting

### Common Issues

#### Integration Tests Failing
```bash
# Check network connectivity
ping soroban-testnet.stellar.org

# Verify contract addresses
echo "Pool: $(grep poolContractAddress Blendv3/Core/Constants/BlendConstants.swift)"

# Enable verbose logging
export VERBOSE_TEST_LOGGING=1
```

#### Performance Tests Slow
```bash
# Run on device instead of simulator for better performance
xcodebuild test -scheme Blendv3 -destination 'platform=iOS,name=Your Device'

# Disable other tests to isolate performance tests
export RUN_INTEGRATION_TESTS=0
export RUN_PERFORMANCE_TESTS=1
```

#### Cache Tests Failing
```bash
# Clear test caches
rm -rf ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug-iphonesimulator/Blendv3Tests.xctest

# Restart simulator
xcrun simctl shutdown all
xcrun simctl boot "iPhone 15"
```

#### Vault Tests Failing
```bash
# Check signer configuration
echo "Test Public Key: GDQERENWDDSQZS7R7WKHZI3BSOYMV3FSWR7TFUYFTKQ447PIX6NREOJM"

# Verify pool contract address
grep -r "poolContractAddress" Blendv3/Core/Constants/

# Test individual components
export RUN_INTEGRATION_TESTS=1
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Blendv3Tests/BlendUSDCVaultTests/testInit_withValidSigner_initializesCorrectly
```

## Contributing

When adding new tests:

1. **Follow the Pattern**: Use the established test structure and naming conventions
2. **Mock Dependencies**: Unit tests should use mocks, integration tests use real services
3. **Test Edge Cases**: Include error scenarios and boundary conditions
4. **Performance Aware**: Add performance assertions for time-critical operations
5. **Documentation**: Update this README when adding new test categories

### Test Naming Convention
```swift
func test[Component]_[Scenario]_[ExpectedResult]() {
    // Given
    // When  
    // Then
}
```

### Example
```swift
func testDeposit_withValidAmount_returnsTransactionHash() async throws {
    // Given
    let amount = Decimal(100.50)
    mockSigner.shouldSucceed = true
    mockSigner.mockTransactionHash = "abc123"
    
    // When
    let result = try await sut.deposit(amount: amount)
    
    // Then
    XCTAssertEqual(result, "abc123")
    XCTAssertTrue(mockSigner.depositCalled)
}
```

## Contract Information

### Pool Contract
- **Contract Address**: See `BlendConstants.Testnet.xlmUsdcPool`
- **Network**: Stellar Testnet
- **RPC Endpoint**: `https://soroban-testnet.stellar.org`