# Oracle Implementation To-Do List

## Phase One: Smart Contract Alignment

### 1. Model Updates

#### OracleAsset.swift
- [x] Create OracleAsset enum with Stellar and Other cases
- [x] Add Codable conformance
- [x] Add SCValXDR conversion methods
- [x] Add utility methods for string representation
- [x] Write unit tests for OracleAsset

#### PriceData.swift
- [x] Update struct to align with contract (price as i128, timestamp as u64)
- [x] Add proper type conversion methods
- [x] Update initializers with required parameters
- [x] Ensure proper Decimal handling with scaling
- [x] Add helper methods for formatted values
- [x] Write unit tests for PriceData conversions

#### OraclePrice.swift
- [x] Add resolution parameter
- [x] Update constructors to handle resolution
- [x] Add proper scaling with decimals and resolution
- [x] Write unit tests for OraclePrice

### 2. Protocol Updates

#### BlendOracleServiceProtocol.swift
- [x] Add getOracleResolution() method
- [x] Add getPrice(asset:timestamp:) method
- [x] Add getPriceHistory(asset:records:) method
- [x] Add getBaseAsset() method
- [x] Add getSupportedAssets() method
- [x] Update documentation for all methods

### 3. Service Implementation

#### BlendOracleService.swift Core Updates
- [x] Verify stellarsdk import
- [x] Implement getOracleResolution() method
- [x] Update asset parameter handling for OracleAsset type
- [x] Write unit tests for core functionality

#### Price Data Handling
- [x] Enhance parseI128ToDecimal with resolution parameter
- [x] Create utility functions for numeric conversions
- [x] Add validation for conversions
- [x] Write unit tests for data parsing

#### Contract Function Implementations
- [x] Implement prices(asset:records:) for history
- [x] Implement assets() and base() functions
- [x] Update and optimize existing implementations
- [x] Add proper caching for all methods
- [x] Write unit tests for all contract functions

### 4. Testing & Validation

- [x] Create mock responses for all contract functions
- [x] Test edge cases (large/small numbers)
- [x] Test proper scaling with different decimal/resolution values
- [x] Test error handling paths
- [x] Verify compilation of the entire app

## Implementation Progress

| Date       | Completed Tasks | Notes |
|------------|----------------|-------|
| 2025-05-28 | Initial planning and setup | Created to-do list |
| 2025-05-28 | Model & protocol implementation | Updated OracleAsset, OraclePrice, PriceData models and BlendOracleServiceProtocol |
| 2025-05-28 | Service implementation | Added extension to BlendOracleService with contract-aligned methods |
| 2025-05-28 | Build verification | Successfully built project with updated Oracle implementation |
| 2025-05-28 | Test implementation | Created comprehensive test coverage for models and service methods |
