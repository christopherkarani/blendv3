# Smart Contract Explorer for Stellar/Soroban

A comprehensive Swift solution for exploring, analyzing, and inspecting Stellar Soroban smart contracts. This system provides detailed insights into contract functionality, data structures, and WASM binaries.

## 🚀 Quick Start

### Basic Usage

```swift
// Explore all known contracts
Task {
    await exploreAllSmartContracts()
}

// Deep dive into a specific contract
Task {
    await exploreUSDCContract()
}

// Run the complete demonstration
Task {
    await runSmartContractDemo()
}
```

## 📁 File Structure

- **`SmartContractInspector.swift`** - Core inspection engine
- **`SmartContractExplorer.swift`** - High-level exploration interface
- **`RunSmartContractExploration.swift`** - Easy-to-use runner functions
- **`TestSmartContractExploration.swift`** - Testing and verification
- **`SmartContractInspectorExample.swift`** - Usage examples and SwiftUI components

## 🔍 What You Can Explore

### 1. Contract Functions
- Function names and signatures
- Input parameters with types and documentation
- Return types
- Function documentation

### 2. Custom Types
- **Structs**: Field names, types, and documentation
- **Enums**: Case names, values, and descriptions
- **Unions**: Different case types and structures
- **Errors**: Error codes and descriptions

### 3. Contract Metadata
- Interface version
- Contract name and description
- Custom metadata fields

### 4. WASM Binary Analysis
- Binary size and validation
- WASM header information
- Magic number verification

### 5. Contract Data
- Persistent and temporary storage entries
- Key-value pairs
- Data formatting and interpretation

## 🎯 Exploration Options

### Option 1: Explore All Known Contracts

```swift
Task {
    await exploreAllSmartContracts()
}
```

**Output Example:**
```
🚀 Starting Comprehensive Smart Contract Exploration
═══════════════════════════════════════════════════════
Analyzing 2 known smart contracts...

[1/2] 🔍 Inspecting: Stellar Asset Contract (USDC)
Contract ID: CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA
Description: Standard Stellar Asset Contract for USDC token
─────────────────────────────────────────────────────
✅ Successfully inspected contract!

📊 Contract Overview:
  • Interface Version: 1
  • Total Functions: 12
  • Custom Types: 3 structs, 2 enums

🔧 Function Signatures:
  • transfer(from: address, to: address, amount: i128) → bool
  • balance(id: address) → i128
  • approve(from: address, spender: address, amount: i128, expiration_ledger: u32) → void
  • allowance(from: address, spender: address) → i128
  • decimals() → u32
  ... and 7 more functions
```

### Option 2: Deep Dive Analysis

```swift
Task {
    await exploreUSDCContract()
}
```

**Features:**
- Complete function analysis with documentation
- Detailed custom type breakdown
- WASM binary inspection
- Contract data exploration
- Comprehensive summary

### Option 3: Custom Contract Exploration

```swift
Task {
    await SmartContractExplorationRunner.exploreSpecificContract(
        contractId: "YOUR_CONTRACT_ID_HERE",
        name: "Your Contract Name"
    )
}
```

## 📊 Sample Output

### Function Analysis
```
📝 Function: transfer
   Description: Transfer tokens from one account to another
   Parameters:
     • from: address
       └─ The account to transfer from
     • to: address
       └─ The account to transfer to
     • amount: i128
       └─ The amount to transfer
   Returns: bool
```

### Custom Types
```
📋 Struct: TokenMetadata
   Description: Metadata for the token
   Fields:
     • name: string
       └─ The name of the token
     • symbol: string
       └─ The symbol of the token
     • decimals: u32
       └─ Number of decimal places
```

### WASM Analysis
```
💾 WASM Binary Analysis:
═══════════════════════
✅ WASM binary retrieved successfully
   • Size: 45.2 KB
   • First 16 bytes: 00 61 73 6d 01 00 00 00 01 07 01 60 02 7f 7f 01
   • Valid WASM magic number detected
   • WASM version: 1
```

## 🛠️ Advanced Usage

### Testing the System

```swift
// Run comprehensive tests
Task {
    await runSmartContractTests()
}

// Run demonstration
Task {
    await demonstrateSmartContractExploration()
}
```

### Error Handling

The explorer includes robust error handling for:
- Invalid contract IDs
- Network connectivity issues
- Parsing failures
- Missing data

### Adding New Contracts

To explore additional contracts, add them to the `knownContracts` array in `SmartContractExplorer.swift`:

```swift
private let knownContracts = [
    ContractInfo(
        id: "YOUR_CONTRACT_ID",
        name: "Your Contract Name",
        description: "Description of your contract"
    ),
    // ... existing contracts
]
```

## 🔧 Technical Details

### Architecture

1. **SmartContractInspector**: Core engine for contract introspection
2. **SmartContractExplorer**: High-level analysis and presentation
3. **Runner Classes**: Easy-to-use interfaces for different exploration modes

### Dependencies

- **stellarsdk**: Stellar iOS/macOS SDK for Soroban interaction
- **Foundation**: Core Swift framework

### Network Configuration

Currently configured for Stellar testnet:
- RPC Endpoint: `https://soroban-testnet.stellar.org`
- Network: `Network.testnet`

To use with mainnet, update the configuration in the explorer classes.

## 📈 Exploration Statistics

The system provides comprehensive statistics:
- Total contracts analyzed
- Successful vs failed inspections
- Total functions discovered
- Custom types found
- Average functions per contract

## 🎉 Getting Started

1. **Basic Exploration**: Start with `exploreAllSmartContracts()`
2. **Specific Analysis**: Use `exploreUSDCContract()` for a detailed example
3. **Custom Contracts**: Add your contract IDs and explore them
4. **Testing**: Run `runSmartContractTests()` to verify functionality

## 🔍 What's Next?

The Smart Contract Explorer provides a foundation for:
- Contract auditing and analysis
- Developer tooling
- Educational purposes
- Integration testing
- Documentation generation

Start exploring and discover the rich functionality of Stellar Soroban smart contracts!

---

**Note**: This explorer is designed for Stellar testnet. For mainnet usage, update the network configuration accordingly. 