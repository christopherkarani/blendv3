# BlendOracleService Test Suite Documentation

## Overview

This document describes the comprehensive test suite for the `BlendOracleService` class, including test strategy, implementation details, and maintenance guidelines.

## Test Architecture

### Test Class Structure

The test suite is organized into `BlendOracleServiceEnhancedTests`, which provides comprehensive coverage of all public methods and edge cases.

```swift
@MainActor
final class BlendOracleServiceEnhancedTests: XCTestCase
```

### Mock Infrastructure

#### MockNetworkService
- **Purpose**: Simulates network operations for contract function calls
- **Features**:
  - Configurable responses for different contract functions
  - Error simulation (network failures, timeouts, contract errors)
  - Call tracking and metrics
  - Retry scenario simulation
  - Network latency simulation

#### MockCacheService
- **Purpose**: Simulates caching operations with full thread safety
- **Features**:
  - In-memory storage with TTL support
  - Thread-safe operations using Swift Actor model
  - Call tracking and statistics
  - Cache hit/miss simulation
  - Memory management validation

## Test Categories

### 1. Initialization Tests
- **Purpose**: Verify proper service initialization
- **Coverage**:
  - Valid parameter initialization
  - Edge case parameter handling
  - Dependency injection validation

### 2. Core Functionality Tests

#### Price Retrieval Methods
- `getPrice(asset:)` - Current price fetching
- `getPrice(asset:timestamp:)` - Historical price at specific timestamp
- `getLastPrice(asset:)` - Most recent price for asset
- `getPriceHistory(asset:records:)` - Historical price series
- `getPrices(assets:)` - Batch price fetching

#### Configuration Methods
- `getOracleDecimals()` - Oracle decimal precision
- `getOracleResolution()` - Oracle resolution factor
- `getBaseAsset()` - Base asset configuration
- `getSupportedAssets()` - Available assets
- `assets()` - Asset ID listing

### 3. Error Handling Tests
- **Network Errors**: Connection failures, timeouts
- **Contract Errors**: Invalid function calls, parameter validation
- **Parsing Errors**: Malformed responses, type mismatches
- **Validation Errors**: Invalid asset formats, parameter ranges

### 4. Retry Logic Tests
- **Transient Failures**: Network hiccups, temporary service unavailability
- **Persistent Failures**: Long-term outages, service degradation
- **Retry Configuration**: Max attempts, delay intervals, exponential backoff

### 5. Caching Tests
- **Cache Hits**: Reducing network calls with valid cached data
- **Cache Misses**: Fallback to network when cache is empty/expired
- **Cache Invalidation**: Proper cleanup of stale data
- **TTL Management**: Time-based expiration handling

### 6. Concurrency Tests
- **Thread Safety**: Multiple simultaneous requests
- **Data Race Conditions**: Shared resource access
- **Resource Contention**: Cache and network resource management
- **Performance Under Load**: Behavior with high concurrent usage

### 7. Performance Tests
- **Single Request Performance**: Response time benchmarks
- **Batch Request Performance**: Scalability with multiple assets
- **Memory Usage**: Resource consumption monitoring
- **Cache Efficiency**: Hit rate optimization

### 8. Edge Cases and Validation
- **Extreme Values**: Very large/small prices, edge timestamps
- **Invalid Data**: Malformed assets, negative values
- **Boundary Conditions**: Zero records, empty arrays, null responses
- **Data Type Handling**: Decimal precision, timestamp accuracy

### 9. Integration Tests
- **End-to-End Workflows**: Complete Oracle service usage patterns
- **Service Interaction**: Network + Cache + Parser integration
- **Error Recovery**: Graceful degradation and recovery
- **State Management**: Service state consistency

## Test Data Management

### Test Constants
```swift
private let testPoolId = "test-pool-id"
private let testOracleAddress = BlendConstants.Testnet.oracle
private let testUSDCAsset = OracleAsset.stellar(address: BlendConstants.Testnet.usdc)
private let testXLMAsset = OracleAsset.stellar(address: BlendConstants.Testnet.xlm)
private let testTimestamp: UInt64 = 1640995200 // 2022-01-01 00:00:00 UTC
```

### Mock Data Creation
The `createMockPriceDataXDR(from:)` helper method creates realistic XDR structures that match the expected contract response format.

## Running the Tests

### Prerequisites
- Xcode 15.0 or later
- Swift 6.0 support
- All project dependencies resolved

### Execution Commands

#### Run All Oracle Service Tests
```bash
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Blendv3Tests/BlendOracleServiceEnhancedTests
```

#### Run Specific Test Categories
```bash
# Performance tests only
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Blendv3Tests/BlendOracleServiceEnhancedTests/testGetPrice_performance_completesWithinTimeLimit

# Concurrency tests only
xcodebuild test -scheme Blendv3 -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Blendv3Tests/BlendOracleServiceEnhancedTests/testConcurrentRequests_handledCorrectly
```

#### Continuous Integration
```yaml
# GitHub Actions example
- name: Run Oracle Service Tests
  run: |
    xcodebuild test \
      -scheme Blendv3 \
      -destination 'platform=iOS Simulator,name=iPhone 15' \
      -only-testing:Blendv3Tests/BlendOracleServiceEnhancedTests \
      -enableCodeCoverage YES
```

## Test Metrics and Coverage

### Coverage Goals
- **Public Method Coverage**: 100%
- **Error Path Coverage**: 95%
- **Edge Case Coverage**: 90%
- **Integration Scenario Coverage**: 85%

### Performance Benchmarks
- **Single Price Fetch**: < 1 second
- **Batch Price Fetch (20 assets)**: < 3 seconds
- **Cache Hit Response**: < 10ms
- **Concurrent Request Handling**: 10+ simultaneous requests

### Quality Metrics
- **Test Execution Time**: Full suite < 30 seconds
- **Mock Reliability**: 99.9% success rate
- **Memory Efficiency**: No detectable leaks
- **Thread Safety**: Zero race conditions

## Maintenance Guidelines

### Adding New Tests

1. **Follow Naming Convention**:
   ```swift
   func test[MethodName]_with[Scenario]_[ExpectedOutcome]()
   ```

2. **Use Arrange-Act-Assert Pattern**:
   ```swift
   func testExample() async throws {
       // Given - Setup test conditions
       
       // When - Execute the method under test
       
       // Then - Verify the results
   }
   ```

3. **Include Error Cases**:
   For every successful test, include corresponding error scenarios.

### Updating Mock Behavior

1. **MockNetworkService Updates**:
   - Add new response configurations for new contract functions
   - Update error simulation scenarios
   - Maintain call tracking accuracy

2. **MockCacheService Updates**:
   - Ensure thread safety for new operations
   - Update statistics tracking
   - Maintain TTL behavior consistency

### Test Data Maintenance

1. **Keep Constants Updated**:
   - Sync with latest contract addresses
   - Update test asset configurations
   - Maintain realistic test data

2. **XDR Structure Alignment**:
   - Verify mock XDR structures match actual contract responses
   - Update parsing logic when contracts change
   - Maintain type safety in mock data

## Debugging Test Issues

### Common Issues and Solutions

1. **Async/Await Test Failures**:
   ```swift
   // Ensure proper async context
   func testAsyncMethod() async throws {
       // Use await for all async calls
       let result = try await sut.someAsyncMethod()
   }
   ```

2. **Mock Configuration Errors**:
   ```swift
   // Reset mocks between tests
   override func setUp() async throws {
       await super.setUp()
       await mockCacheService.reset()
       mockNetworkService.reset()
   }
   ```

3. **Timing-Sensitive Tests**:
   ```swift
   // Use reasonable timeouts
   XCTAssertLessThan(duration, 1.0, accuracy: 0.1)
   ```

### Debugging Tools

1. **Mock State Inspection**:
   ```swift
   // Check mock call history
   XCTAssertEqual(mockNetworkService.simulationCallCount, expectedCallCount)
   let stats = await mockCacheService.getStatistics()
   print("Cache stats: \(stats.description)")
   ```

2. **Performance Profiling**:
   ```swift
   // Measure execution time
   let startTime = CFAbsoluteTimeGetCurrent()
   // ... test execution
   let duration = CFAbsoluteTimeGetCurrent() - startTime
   ```

## Integration with CI/CD

### Automated Testing
- Tests run on every pull request
- Performance regression detection
- Coverage tracking and reporting
- Failure notification system

### Release Validation
- Full test suite execution before releases
- Performance benchmark validation
- Integration test scenarios
- Backwards compatibility verification

## Future Enhancements

### Planned Improvements
1. **Snapshot Testing**: Capture and verify complex response structures
2. **Property-Based Testing**: Generate random test inputs for edge case discovery
3. **Load Testing**: Stress test with thousands of concurrent requests
4. **Integration Environment**: Test against actual testnet contracts

### Monitoring and Observability
1. **Test Analytics**: Track test execution patterns and failure rates
2. **Performance Trending**: Monitor test execution time over time
3. **Coverage Tracking**: Automated coverage reporting and trending
4. **Quality Gates**: Prevent regression with automated quality checks

---

## Contact and Support

For questions about the test suite or contributions:
- Review test implementation in `BlendOracleServiceEnhancedTests.swift`
- Check mock implementations in `Mocks/` directory
- Follow established patterns for new test additions
- Ensure all tests pass before submitting changes

This comprehensive test suite ensures the `BlendOracleService` is robust, reliable, and ready for production use in the Blend Protocol ecosystem. 