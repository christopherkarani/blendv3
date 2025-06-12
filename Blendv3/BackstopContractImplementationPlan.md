# Backstop Contract Service Implementation Plan

## Overview
Implement a complete BackstopContractService class following the established patterns in BlendOracleService.swift, maintaining architectural consistency and Swift 6.0 compliance.

## Architecture Analysis

### Reference Pattern: BlendOracleService
- **Service Class**: Main service class with dependency injection
- **Protocol**: Interface definition for testability
- **Error Handling**: Custom error types with detailed messaging
- **Caching**: TTL-based caching for performance
- **Retry Logic**: Robust retry mechanisms with exponential backoff
- **Logging**: Comprehensive debug logging throughout
- **Type Safety**: Strong typing with proper conversions

### Core Components Required

#### 1. Models (`/BackstopContract/Models/`)
```swift
// BackstopModels.swift - All contract structs
- PoolBackstopData
- PoolBalance  
- Q4W (Queue for Withdrawal)
- UserBalance
- BackstopEmissionConfig
- BackstopEmissionsData
- UserEmissionData
- PoolUserKey
- BackstopDataKey (enum)
- BackstopError (enum)
```

#### 2. Protocols (`/BackstopContract/Protocols/`)
```swift
// BackstopContractServiceProtocol.swift - Service interface
- All contract function signatures
- Error handling specifications
- Async/await patterns
```

#### 3. Services (`/BackstopContract/Services/`)
```swift
// BackstopContractService.swift - Main implementation
- Dependency injection (NetworkService, CacheService)
- Contract address configuration
- All function implementations
```

#### 4. Extensions (`/BackstopContract/Extensions/`)
```swift
// BackstopContractService+Parsing.swift - Response parsing
// BackstopContractService+Utils.swift - Helper utilities
// BackstopContractService+Parameters.swift - Parameter creation
```

## Function Implementation Mapping

### Contract Functions Analysis

#### Core Functions
1. **initialize** - Setup function (typically called once)
2. **deposit** - Stake tokens, returns shares
3. **queue_withdrawal** - Queue withdrawal, returns Q4W
4. **dequeue_withdrawal** - Cancel queued withdrawal
5. **withdraw** - Execute withdrawal, returns amount
6. **user_balance** - Get user balance data
7. **pool_data** - Get pool backstop data

#### Token/Emission Functions  
8. **backstop_token** - Get backstop token address
9. **gulp_emissions** - Process global emissions
10. **add_reward** - Add/remove reward tokens
11. **gulp_pool_emissions** - Process pool emissions
12. **claim** - Claim rewards from pools

#### Administrative Functions
13. **drop** - Emergency airdrop function
14. **draw** - Emergency withdrawal from pool
15. **donate** - Donate to pool
16. **update_tkn_val** - Update token values

## Implementation Standards

### Swift 6.0 Features
- **Strict Concurrency**: All async functions properly marked
- **Typed Throws**: Specific error types for each function
- **Sendable Protocols**: Thread-safe data structures
- **Actor Isolation**: Proper isolation for shared state

### SOLID Principles Application
- **Single Responsibility**: Each class has one clear purpose
- **Open/Closed**: Extensible through protocols
- **Liskov Substitution**: Protocol implementations are interchangeable
- **Interface Segregation**: Focused, minimal interfaces
- **Dependency Inversion**: Depend on abstractions, not concretions

### Error Handling Strategy
```swift
enum BackstopError: LocalizedError, CustomDebugStringConvertible {
    case contractError(BackstopContractError)
    case networkError(Error)
    case parsingError(String)
    case invalidParameters(String)
    case cacheError(Error)
    case simulationError(String)
}
```

### Caching Strategy
- **User Balances**: 60 seconds TTL (frequent changes)
- **Pool Data**: 300 seconds TTL (moderate changes)  
- **Token Addresses**: 3600 seconds TTL (rarely changes)
- **Emission Data**: 120 seconds TTL (periodic updates)

### Logging Categories
- `BackstopService.deposits` - Deposit/withdrawal operations
- `BackstopService.queries` - Balance and data queries
- `BackstopService.emissions` - Emission-related operations
- `BackstopService.admin` - Administrative functions

## Type Conversion Patterns

### Address Handling
```swift
// Follow existing stellarsdk patterns
private func createAddressParameter(_ address: String) throws -> SCValXDR {
    return SCValXDR.address(try Address(address))
}
```

### Amount Conversions
```swift
// i128 handling following Oracle service patterns
private func createAmountParameter(_ amount: Decimal) throws -> SCValXDR {
    let scaledAmount = amount * 10_000_000 // 7 decimals
    return SCValXDR.int128(Int128(truncating: scaledAmount as NSNumber))
}
```

### Response Parsing
```swift
// Parse contract responses to Swift types
private func parsePoolBackstopData(_ response: SCValXDR) throws -> PoolBackstopData {
    // Extract struct fields and convert types
}
```

## Testing Strategy

### Unit Tests Structure
```
BackstopContractServiceTests/
├── BackstopContractServiceTests.swift
├── BackstopModelsTests.swift  
├── BackstopParsingTests.swift
└── BackstopMockService.swift
```

### Test Coverage Requirements
- All public functions: 100%
- Error scenarios: All error types
- Edge cases: Boundary values, empty responses
- Performance: Caching effectiveness
- Integration: Real contract calls (optional)

## Performance Benchmarks

### Response Time Targets
- Cached responses: < 10ms
- Network calls: < 2000ms
- Batch operations: < 5000ms

### Memory Usage Targets  
- Service instance: < 1MB baseline
- Cache storage: < 10MB total
- Response parsing: < 100KB per operation

## File Organization

```
BackstopContract/
├── Models/
│   └── BackstopModels.swift
├── Protocols/
│   └── BackstopContractServiceProtocol.swift
├── Services/
│   └── BackstopContractService.swift
└── Extensions/
    ├── BackstopContractService+Parsing.swift
    ├── BackstopContractService+Utils.swift
    └── BackstopContractService+Parameters.swift
```

## Implementation Phases

### Phase 1: Foundation (Models & Protocols)
1. Create all model structs
2. Define service protocol
3. Implement error types
4. Set up basic structure

### Phase 2: Core Service Implementation
1. Main service class
2. Dependency injection setup
3. Configuration and initialization
4. Basic contract call infrastructure

### Phase 3: Function Implementation
1. Query functions (user_balance, pool_data, backstop_token)
2. Deposit/withdrawal functions
3. Emission functions  
4. Administrative functions

### Phase 4: Extensions & Utilities
1. Response parsing extensions
2. Parameter creation utilities
3. Caching implementation
4. Logging and debugging

### Phase 5: Testing & Validation
1. Unit tests for all functions
2. Integration testing
3. Performance benchmarking
4. Documentation completion

## Validation Criteria

### Code Quality
- [ ] Swift 6.0 compilation without warnings
- [ ] All functions implemented and tested
- [ ] Error handling for all scenarios
- [ ] Proper documentation throughout

### Architecture Compliance  
- [ ] Follows BlendOracleService patterns
- [ ] SOLID principles implemented
- [ ] Protocol-oriented design
- [ ] Dependency injection used

### Performance Requirements
- [ ] Caching implemented and effective
- [ ] Response times meet targets
- [ ] Memory usage within limits
- [ ] Retry logic working properly

### Integration
- [ ] Compatible with existing services
- [ ] Uses established network layer
- [ ] Follows project conventions
- [ ] Ready for production use

## Next Steps

1. **Create Models**: Start with BackstopModels.swift
2. **Define Protocol**: BackstopContractServiceProtocol.swift  
3. **Implement Service**: BackstopContractService.swift
4. **Add Extensions**: Parsing, utilities, parameters
5. **Test Everything**: Comprehensive test suite
6. **Document**: Code documentation and usage examples

This plan ensures a robust, maintainable, and well-tested implementation that follows established patterns while meeting all technical requirements.
