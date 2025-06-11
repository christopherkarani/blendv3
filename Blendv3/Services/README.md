# Blend v3 Services Architecture

This document outlines the refactored service architecture for the Blend v3 project, implementing a clean separation of concerns with proper delegation patterns.

## Architecture Overview

The services have been refactored to follow a **three-layer architecture**:

1. **Core Services Layer** - `NetworkService` and `BlendParser`
2. **Business Logic Layer** - Domain-specific services  
3. **UI Layer** - SwiftUI views (not included in this refactoring)

```
┌─────────────────────┐    ┌─────────────────────┐
│   UI Layer          │    │   UI Layer          │
│   (SwiftUI Views)   │    │   (SwiftUI Views)   │
└─────────┬───────────┘    └─────────┬───────────┘
          │                          │
          ▼                          ▼
┌─────────────────────┐    ┌─────────────────────┐
│ Business Services   │    │ Business Services   │
│ ┌─────────────────┐ │    │ ┌─────────────────┐ │
│ │ OracleService   │ │    │ │ PoolService     │ │
│ │ UserPosService  │ │    │ │ BackstopService │ │
│ └─────────────────┘ │    │ └─────────────────┘ │
└─────────┬───────────┘    └─────────┬───────────┘
          │                          │
          ▼                          ▼
┌─────────────────────┐    ┌─────────────────────┐
│  NetworkService     │    │   BlendParser       │
│  ┌───────────────┐  │    │  ┌───────────────┐  │
│  │ Soroban RPC   │  │    │  │ XDR Decoding  │  │
│  │ Horizon API   │  │    │  │ SCVal Parsing │  │
│  │ Contract Calls│  │    │  │ Type Convert  │  │
│  └───────────────┘  │    │  └───────────────┘  │
└─────────────────────┘    └─────────────────────┘
```

## Core Services

### NetworkService.swift
**Responsibility**: All Soroban/Stellar networking operations
- Contract invocation (`invokeContract`)
- Transaction simulation (`simulateTransaction`) 
- Contract data retrieval (`getContractData`)
- Event retrieval (`getEvents`)
- Account loading (`loadAccount`)
- Transaction submission (`submitTransaction`)

**Key Features**:
- Async/await pattern for modern concurrency
- Proper error handling with custom `NetworkError` types
- Network configuration management (testnet/mainnet)
- Resource management and fee calculation

### BlendParser.swift  
**Responsibility**: All data parsing and type conversion operations
- SCVal parsing to Swift types (`parseString`, `parseUInt64`, etc.)
- XDR decoding and transaction result parsing
- Contract data extraction (`parseContractData`)
- Event parsing (`parseEvents`, `parseEventTopics`)
- Type creation for contract calls (`createSCVal`, `createAddressSCVal`)

**Key Features**:
- Singleton pattern for efficient reuse
- Comprehensive type safety with proper error handling
- Support for optional parsing with fallbacks
- Utility methods for complex data structures

## Business Logic Services

### OracleNetworkService.swift
**Business Logic**: Oracle price feed operations
- Price retrieval (`getPrice`, `getBatchPrices`)
- Price data with metadata (`getPriceWithTimestamp`)
- Event subscription (`subscribeToOracleEvents`)

**Dependencies**: NetworkService + BlendParser

### BlendOracleService.swift
**Business Logic**: Blend protocol oracle operations  
- Pool asset price management (`getAssetPrice`, `getPoolAssetPrices`)
- Oracle metadata (`getAssetPriceData`)
- Historical price data (`getHistoricalPrices`)
- Price updates (`updateOraclePrice`)

**Dependencies**: NetworkService + BlendParser

### PoolService.swift + PoolServiceProtocol.swift
**Business Logic**: Lending pool operations
- Pool information (`getPoolConfig`, `getPoolReserves`)
- Liquidity operations (`supply`, `withdraw`)
- Borrowing operations (`borrow`, `repay`)
- Risk management (`getPositionHealth`, `canLiquidate`)

**Dependencies**: NetworkService + BlendParser

### BackstopContractService.swift
**Business Logic**: Backstop insurance operations
- Backstop deposits/withdrawals (`deposit`, `withdraw`)
- Liquidation support (`canCoverLiquidation`, `executeLiquidation`)
- Rewards management (`claimRewards`, `getClaimableRewards`)

**Dependencies**: NetworkService + BlendParser

### UserPositionService.swift + UserPositionServiceProtocol.swift
**Business Logic**: User position analytics and management
- Position overview (`getUserPosition`, `getUserNetWorth`) 
- Supply/borrow tracking (`getSupplyPositions`, `getBorrowPositions`)
- Health monitoring (`getOverallHealthFactor`, `isAtLiquidationRisk`)
- Portfolio analytics (`getAssetAllocation`, `getYieldStatistics`)

**Dependencies**: NetworkService + BlendParser + PoolService + BlendOracleService

## Key Benefits of This Architecture

### 1. **Separation of Concerns**
- **NetworkService**: Pure networking logic, no business rules
- **BlendParser**: Pure parsing logic, no networking or business rules  
- **Business Services**: Only domain logic, no networking or parsing details

### 2. **Reusability**
- Core services can be reused across all business services
- Business services can be composed together (e.g., UserPositionService uses PoolService)
- Easy to test individual components in isolation

### 3. **Maintainability**
- Clear responsibilities make code easier to understand
- Changes to networking logic only require updates to NetworkService
- Changes to parsing logic only require updates to BlendParser
- Business logic changes are isolated to specific services

### 4. **Testability**
- Each service can be tested independently
- Easy to mock dependencies for unit testing
- Clear interfaces defined by protocols

### 5. **Scalability**
- Easy to add new business services following the same pattern
- Core services handle scaling concerns (connection pooling, caching, etc.)
- Business services focus on domain-specific optimizations

## Usage Examples

### Basic Oracle Price Retrieval
```swift
let oracleService = OracleNetworkService()
let price = try await oracleService.getPrice(
    for: "USDC",
    oracleContract: "ORACLE_CONTRACT_ADDRESS"
)
```

### Pool Operations
```swift
let poolService = PoolService()
let txHash = try await poolService.supply(
    poolAddress: "POOL_CONTRACT_ADDRESS",
    assetId: "USDC", 
    amount: 1000_000_000, // 1000 USDC
    sourceKeyPair: userKeyPair
)
```

### User Position Analysis
```swift
let positionService = UserPositionService()
let userPosition = try await positionService.getUserPosition(
    userAddress: "USER_ACCOUNT_ADDRESS"
)
print("Health Factor: \(userPosition.overallHealthFactor)")
print("Net Worth: $\(userPosition.netWorth)")
```

## Error Handling

Each service defines its own error types for domain-specific failures:
- `NetworkError` - Network and RPC related errors
- `ParseError` - Data parsing and type conversion errors  
- `OracleError` - Oracle-specific business logic errors
- `PoolServiceError` - Pool operation errors
- `BackstopError` - Backstop operation errors
- `UserPositionError` - Position analysis errors

## Next Steps

To complete the integration:

1. **Add Stellar SDK Dependency**: Update the Xcode project to include the stellar-ios-mac-sdk
2. **Dependency Injection**: Implement proper dependency injection for KeyPair management
3. **Configuration**: Add network configuration management
4. **Caching**: Add intelligent caching for frequently accessed data
5. **Testing**: Implement comprehensive unit and integration tests
6. **Documentation**: Add detailed API documentation for each service

## File Structure

```
Blendv3/Services/
├── README.md                      # This documentation
├── NetworkService.swift           # Core networking service
├── BlendParser.swift             # Core parsing service
├── OracleNetworkService.swift    # Oracle price feeds
├── BlendOracleService.swift      # Blend protocol oracles
├── PoolServiceProtocol.swift     # Pool service interface
├── PoolService.swift             # Pool operations implementation
├── BackstopContractService.swift # Backstop insurance
├── UserPositionServiceProtocol.swift  # User position interface
└── UserPositionService.swift     # User position implementation
```

This architecture successfully eliminates code duplication while maintaining clean separation of concerns and enabling easy testing and maintenance.