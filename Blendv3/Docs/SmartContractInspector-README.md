# Smart Contract Inspector for Stellar/Soroban

A comprehensive Swift solution for inspecting Stellar Soroban smart contracts, retrieving WASM binaries, and presenting contract data in human-readable formats.

## ✅ Issue Fixed

**Problem**: `Value of type 'SCSpecUDTUnionCaseV0XDR' has no member 'kind'`

**Solution**: Updated the `parseUnion` method to correctly handle the `SCSpecUDTUnionCaseV0XDR` enum structure. The union cases are now properly parsed using pattern matching:

```swift
switch unionCase {
case .voidV0(let voidCase):
    return UnionCase(kind: .voidV0, name: voidCase.name, type: nil, doc: voidCase.doc)
case .tupleV0(let tupleCase):
    let typeStrings = tupleCase.type.map { formatType($0) }.joined(separator: ", ")
    return UnionCase(kind: .tupleV0, name: tupleCase.name, type: "tuple<\(typeStrings)>", doc: tupleCase.doc)
}
```

## 🔖 Oracle Implementation To-Do List

- [ ] **Model Updates**
  - [ ] Update `PriceData.swift` model to align with contract structure
  - [ ] Create `OracleAsset` enum if needed for Asset type representation

- [ ] **Protocol Updates**
  - [ ] Update `BlendOracleServiceProtocol.swift` with contract-aligned methods
  - [ ] Add documentation for new methods

- [ ] **Service Implementation**
  - [ ] Implement `getOracleDecimals()` method
  - [ ] Implement `getOracleResolution()` method
  - [ ] Update `getPrice(asset:)` with correct contract call format
  - [ ] Implement `getPrice(asset:timestamp:)` for historical prices
  - [ ] Implement `getPrices(asset:records:)` for price history
  - [ ] Update price parsing logic to handle i128 with proper scaling

- [ ] **Testing**
  - [ ] Update mock services to simulate contract responses
  - [ ] Add unit tests for all contract functions
  - [ ] Test with different price values and decimal scales
  - [ ] Add integration tests with mock contract

- [ ] **Integration**
  - [ ] Update `DataService` to use enhanced oracle service
  - [ ] Verify consistency in decimal handling
  - [ ] Add end-to-end tests

## Testing

Run the included test to verify everything works:

```swift
Task {
    await SmartContractInspectorTest.runAllTests()
}
```

## Overview

I've created a powerful tool that allows you to:

1. **Inspect Smart Contracts** - Retrieve and parse contract metadata, functions, and custom types
2. **Download WASM Binaries** - Extract the compiled WebAssembly code from deployed contracts
3. **Query Contract Data** - Read and format contract storage entries
4. **Present Human-Readable Output** - Convert complex blockchain data into easy-to-understand formats

## Key Components

### 1. SmartContractInspector.swift

The main class that provides all inspection functionality:

```swift
// Initialize the inspector
let inspector = SmartContractInspector(
    rpcEndpoint: "https://soroban-testnet.stellar.org",
    network: Network.testnet
)

// Inspect a contract
let result = try await inspector.inspectContract(contractId: "YOUR_CONTRACT_ID")
print(result.summary())
```

### 2. Key Features

#### Contract Introspection
- Lists all available functions with parameters and return types
- Identifies custom types (structs, enums, unions, errors)
- Extracts contract metadata (name, version, description)
- Retrieves the interface version

#### WASM Binary Retrieval
```swift
let wasmData = try await inspector.getContractWasmBinary(contractId: contractId)
// Save to file or analyze further
```

#### Contract Data Queries
```swift
let key = SCValXDR.symbol("balance")
let dataResult = try await inspector.getContractData(
    contractId: contractId,
    key: key,
    durability: .persistent
)
```

### 3. Data Formatting

The inspector automatically formats various Soroban data types:

| Type | Example Output |
|------|----------------|
| Numbers | `u64: 1000000`, `i128(0:5000000)` |
| Addresses | `account(GABC123...)`, `contract(0x123...)` |
| Collections | `[item1, item2]`, `{key: value}` |
| Options | `Some(42)`, `None` |
| Bytes | `bytes(0x48656c6c6f)` |
| Strings | `"Hello, Soroban!"` |

## Example Output

When you inspect a contract, you'll get a formatted report like this:

```
📋 Smart Contract Inspection Report
═══════════════════════════════════

Contract ID: CCFZRNQVZZUQIGGPXNLC7UHIUA4AW3TBQ3QOBHSKOCE2AF5GBARHHXKL
Interface Version: 85899345921

📌 Metadata:
  • name: Token Contract
  • version: 1.0.0
  • description: A simple token implementation

🔧 Available Functions (8):

  ▸ initialize(admin: address, decimal: u32, name: string, symbol: string)
    📖 Initialize the token with a name, symbol, and decimals

  ▸ mint(to: address, amount: i128)
    📖 Mint new tokens to an address

  ▸ balance(id: address) → i128
    📖 Get the balance of an address

📦 Custom Types:

  Structs:
    • TokenMetadata
    • AllowanceValue

  Errors:
    • TokenError
```

## Additional Information You Can Provide

To enhance the contract inspection, you can provide:

### 1. **ABI Definitions**
If you have the contract's ABI in JSON format, it can help verify the parsed functions.

### 2. **Interface Specs**
Contract interface specifications in the format:
```json
{
    "functions": [
        {
            "name": "transfer",
            "arguments": [
                {"name": "from", "type": "address"},
                {"name": "to", "type": "address"},
                {"name": "amount", "type": "i128"}
            ],
            "returns": "bool"
        }
    ]
}
```

### 3. **On-chain Metadata**
- Contract deployment transaction hash
- Deployment ledger number
- Creator account address

### 4. **Sample Transactions**
Provide transaction hashes or logs showing:
- Successful function calls
- Event emissions
- State changes

### 5. **Contract Source Code**
If available, the original source code (Rust, AssemblyScript) helps understand:
- Function implementations
- State variable meanings
- Business logic

## Integration with Your App

### SwiftUI Integration
The included `ContractInspectorView` provides a ready-to-use UI:

```swift
struct ContentView: View {
    var body: some View {
        ContractInspectorView()
    }
}
```

### Combine Integration
You can easily wrap the inspector in Combine publishers:

```swift
extension SmartContractInspector {
    func inspectContractPublisher(contractId: String) -> AnyPublisher<ContractInspectionResult, Error> {
        Future { promise in
            Task {
                do {
                    let result = try await self.inspectContract(contractId: contractId)
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
```

## Advanced Usage

### Custom Data Formatting
Extend the `formatSCVal` method to handle your specific data types:

```swift
private func formatCustomType(_ val: SCValXDR) -> String {
    // Add your custom formatting logic
}
```

### Caching Results
Implement caching for frequently accessed contracts:

```swift
class CachedContractInspector {
    private var cache: [String: ContractInspectionResult] = [:]
    private let inspector: SmartContractInspector
    
    func inspectWithCache(contractId: String) async throws -> ContractInspectionResult {
        if let cached = cache[contractId] {
            return cached
        }
        let result = try await inspector.inspectContract(contractId: contractId)
        cache[contractId] = result
        return result
    }
}
```

## Troubleshooting

### Common Issues

1. **RPC Connection Failed**
   - Verify the RPC endpoint is accessible
   - Check network connectivity
   - Ensure the correct network (testnet/mainnet) is specified

2. **Contract Not Found**
   - Verify the contract ID is correct
   - Ensure the contract is deployed on the specified network
   - Check if the contract has been archived or removed

3. **Parsing Errors**
   - The contract might use unsupported features
   - The WASM binary might be corrupted
   - The contract might not include proper metadata

## Next Steps

1. **Extend Data Types** - Add support for more complex custom types
2. **Add Filtering** - Filter functions by visibility or type
3. **Export Formats** - Add JSON/CSV export capabilities
4. **Performance** - Implement batch operations for multiple contracts
5. **Monitoring** - Add real-time contract state monitoring

## Resources

- [Stellar Documentation](https://developers.stellar.org/)
- [Soroban Documentation](https://soroban.stellar.org/)
- [Stellar iOS SDK](https://github.com/Soneso/stellar-ios-mac-sdk)
- [Soroban Examples](https://github.com/stellar/soroban-examples) 