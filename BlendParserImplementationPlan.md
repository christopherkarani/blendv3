# BlendParser Implementation Plan
**Soroban Network Refactoring - Step 1**  
*Date: June 11, 2025*

---

## Implementation Strategy

### Approach
- **Start with Step 1**: Design and implement `BlendParser` foundation
- **Breaking changes**: Acceptable - no backward compatibility required
- **Structure**: Single monolithic parser at `Core/Parsing/BlendParser.swift`
- **DI**: Initializer parameter injection
- **Testing**: TDD approach - write tests first, then implement
- **Migration**: Incremental service-by-service with zero compiler errors
- **Data**: Use real contract responses, no mock data
- **Philosophy**: Keep solutions simple

---

## Step 1: BlendParser Foundation

### 1.1 Create Test Structure First
```
Blendv3Tests/
├── Core/
│   └── Parsing/
│       ├── BlendParserTests.swift
│       ├── I128ParsingTests.swift
│       ├── AddressParsingTests.swift
│       ├── MapParsingTests.swift
│       └── EnumParsingTests.swift
```

### 1.2 Create Implementation Structure
```
Blendv3/Core/
├── Parsing/
│   ├── BlendParser.swift
│   ├── BlendParsingContext.swift
│   └── BlendParsingError.swift
```

### 1.3 Core Parser Interface
```swift
public final class BlendParser {
    // Single entry point for all parsing
    public func parse<T>(_ value: SCValXDR, as type: T.Type, context: BlendParsingContext) throws -> T
    
    // Utility methods (internal)
    internal func parseI128ToDecimal(_ i128: Int128XDR) -> Decimal
    internal func parseAddress(_ address: SCAddressXDR) -> String
    internal func parseMap(_ map: [SCMapEntryXDR]) -> [String: SCValXDR]
    internal func parseEnumVariant(_ value: SCValXDR, expectedSymbol: String) throws -> SCValXDR
}
```

### 1.4 Parsing Context
```swift
public struct BlendParsingContext {
    let functionName: String
    let contractType: ContractType
    let additionalInfo: [String: Any]
    
    enum ContractType {
        case oracle, pool, backstop, userPosition
    }
}
```

---

## Implementation Steps

### Phase 1: Foundation (Tests First)
1. **Create test files** with expected parsing scenarios
2. **Implement BlendParser** to make tests pass
3. **Add utility methods** for common parsing patterns
4. **Validate** with real contract response data

### Phase 2: Service Integration (One at a Time)
1. **PoolService** - Simplest case, direct SorobanClient usage
2. **BlendOracleService** - Complex parsing, multiple parsers
3. **BackstopContractService** - Medium complexity
4. **UserPositionService** - Heavy parsing logic
5. **Clean up** - Remove duplicate parsing code

### Phase 3: NetworkService Consolidation
1. **Centralize** all contract calls through NetworkService
2. **Remove** duplicate retry mechanisms
3. **Update** service interfaces to use BlendParser
4. **Test** end-to-end functionality

---

## Success Criteria for Step 1

### Compiler Requirements
- ✅ Zero compilation errors after each incremental change
- ✅ All existing tests continue to pass
- ✅ Swift 6.0 strict concurrency compliance

### Functional Requirements
- ✅ BlendParser handles all identified parsing patterns:
  - i128 ↔ Decimal conversion
  - SCAddress extraction
  - Map traversal and key extraction
  - Enum variant parsing
  - Vector/array parsing
- ✅ Comprehensive test coverage (>90%)
- ✅ Error handling for malformed responses
- ✅ Performance equivalent to existing parsing

### Integration Requirements
- ✅ PoolService successfully migrated to use BlendParser
- ✅ No regression in PoolService functionality
- ✅ Clear path established for remaining services

---

## Next Steps After Step 1

1. **Validate** BlendParser works with PoolService
2. **Document** parsing patterns and add examples
3. **Plan** BlendOracleService migration (most complex)
4. **Continue** incremental service migration
5. **Consolidate** NetworkService responsibilities

---

## Questions for Implementation

### Before Starting
- Should BlendParser be a **class** or **struct**?
- Do we need **async parsing** or is synchronous sufficient?
- Should parsing context be **optional** or **required**?

### During Implementation
- How should we handle **unknown/unexpected** SCVal types?
- Should we **cache** parsed results or parse fresh each time?
- What level of **logging** do we want in the parser?

---

## Ready to Begin

**Current Status**: Plan approved, ready to implement  
**Next Action**: Create test files and begin TDD implementation  
**Expected Duration**: 2-3 hours for Step 1 foundation  

Let's start with creating the test structure and basic BlendParser implementation.
