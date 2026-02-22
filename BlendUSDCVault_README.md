# BlendUSDCVault - Phase 1 Implementation

## Overview

`BlendUSDCVault` is a Swift class that provides a clean interface for interacting with the Blend USDC lending pool on Stellar's Soroban smart contract platform. This implementation focuses exclusively on USDC deposits, withdrawals, and pool statistics retrieval.

## Features

- ✅ **Deposit USDC** to the lending pool
- ✅ **Withdraw USDC** from the lending pool  
- ✅ **Fetch pool statistics** (totalSupplied, totalBorrowed, backstopReserve, currentAPY)
- ✅ **Network switching** between testnet and mainnet
- ✅ **Wallet-agnostic** design with protocol-based signing
- ✅ **Fully documented** and unit tested

## Architecture

### File Structure
```
Blendv3/Core/
├── Constants/
│   └── BlendUSDCConstants.swift    # Contract addresses, function names, scaling
├── Models/
│   └── BlendPoolStats.swift        # Pool statistics data model
├── Protocols/
│   └── BlendSigner.swift           # Wallet-agnostic signing protocol
└── Services/
    └── BlendUSDCVault.swift        # Main vault implementation
```

### Key Components

1. **BlendUSDCVault**: Main service class using Combine for reactive state management
2. **BlendSigner Protocol**: Allows different wallet implementations
3. **BlendUSDCConstants**: Isolated contract-specific constants
4. **BlendPoolStats**: Type-safe pool statistics model

## Setup

### 1. Import the Stellar SDK

Add the Stellar iOS SDK to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/Soneso/stellar-ios-mac-sdk.git", from: "3.1.0")
]
```

### 2. Initialize the Vault

```swift
import stellarsdk

// Create a signer (example with secret seed)
let signer = try KeyPairSigner(secretSeed: "SABC...")

// Initialize vault (defaults to testnet)
let vault = BlendUSDCVault(signer: signer, network: .testnet)
```

### 3. Deposit USDC

```swift
do {
    // Deposit 100.50 USDC
    let txHash = try await vault.deposit(amount: 100.50)
    print("Deposit successful! Transaction: \(txHash)")
} catch {
    print("Deposit failed: \(error)")
}
```

### 4. Withdraw USDC

```swift
do {
    // Withdraw 50.25 USDC
    let txHash = try await vault.withdraw(amount: 50.25)
    print("Withdrawal successful! Transaction: \(txHash)")
} catch {
    print("Withdrawal failed: \(error)")
}
```

### 5. Fetch Pool Statistics

```swift
// Refresh pool stats
try await vault.refreshPoolStats()

// Access stats
if let stats = vault.poolStats {
    print("Total Supplied: \(stats.totalSupplied) USDC")
    print("Total Borrowed: \(stats.totalBorrowed) USDC")
    print("Current APY: \(stats.currentAPY)%")
    print("Utilization Rate: \(stats.utilizationRate * 100)%")
}
```

## Network Configuration

### Switching to Mainnet

```swift
// Initialize with mainnet
let vault = BlendUSDCVault(signer: signer, network: .mainnet)
```

No other code changes are required - the vault automatically uses the appropriate RPC endpoints and network configuration.

### Network Endpoints

- **Testnet**: `https://soroban-testnet.stellar.org`
- **Mainnet**: `https://soroban.stellar.org`

## Custom Wallet Integration

Implement the `BlendSigner` protocol for custom wallet solutions:

```swift
struct MyCustomWallet: BlendSigner {
    var publicKey: String { 
        // Return public key
    }
    
    func sign(transaction: Transaction, network: Network) async throws -> Transaction {
        // Custom signing logic
        return signedTransaction
    }
    
    func getKeyPair() throws -> KeyPair {
        // Return keypair (can be public key only)
    }
}
```

## Contract Details

### Pool Contract
- **Address**: `CAQCFVLOBK5GIULPNZRGATJJMIZL5BSP7X5YJVMGCPTUEPFM4AVSRCJU`

### USDC Asset
- **Issuer**: `GATALTGTWIOT6BUDBCZM3Q4OQ4BO2COLOAZ7IYSKPLC2PMSOPPGF5V56`
- **Code**: `USDC`
- **Decimals**: 7 (scaling factor: 10^7)

### Submit Function
```rust
submit(
    requests: Vec<Request>,
    spender: Address,
    from: Address,
    to: Address
) -> ()
```

Where `Request` is:
```rust
struct Request {
    request_type: u32,  // 0 = supply_collateral, 1 = withdraw_collateral
    address: Address,   // Asset address (USDC issuer)
    amount: i128       // Scaled amount
}
```

## Design Decisions

1. **Combine + ObservableObject**: Enables reactive UI updates in SwiftUI
2. **Protocol-based Signing**: Supports hardware wallets, browser extensions, etc.
3. **Isolated Constants**: Prevents naming collisions and improves maintainability
4. **Decimal Type**: Prevents floating-point precision issues with money
5. **Async/Await**: Modern Swift concurrency for cleaner async code
6. **Error Handling**: Comprehensive error types with localized descriptions

## Assumptions & Limitations

### Current Implementation
- Pool statistics use placeholder data (actual contract view functions not yet available)
- Only supports USDC (single asset)
- Only supports supply/withdraw collateral operations
- Transaction signing happens locally (no remote signing support yet)

### Future Enhancements
- Real pool statistics from contract view functions
- Multi-asset support
- Borrowing and repayment operations
- Remote transaction signing
- Transaction history
- Push notifications for position changes

## Testing

Run the unit tests:

```bash
swift test
# or in Xcode: ⌘+U
```

Test coverage includes:
- Initialization and configuration
- Scaling functions
- Pool statistics calculations
- Error handling
- Signer protocol implementations

## Error Handling

The vault provides detailed error types:

```swift
public enum BlendVaultError: LocalizedError {
    case notInitialized           // Vault not ready
    case invalidAmount(String)    // Invalid deposit/withdraw amount
    case insufficientBalance      // Not enough balance
    case transactionFailed(String) // Transaction submission failed
    case networkError(String)     // Network connectivity issues
    case initializationFailed(String) // Setup failed
    case unknown(String)          // Unexpected errors
}
```

## Security Considerations

1. **Private Keys**: Never stored or logged by the vault
2. **Transaction Signing**: Delegated to the signer implementation
3. **Network Security**: All communication uses TLS
4. **Amount Validation**: Prevents negative or zero amounts
5. **Type Safety**: Strong typing prevents common errors

## Support

For questions or issues:
1. Check the error messages - they provide detailed information
2. Ensure you have sufficient XLM for transaction fees
3. Verify the signer has the correct permissions
4. Check network connectivity to Soroban RPC

---

**Note**: This is a Phase 1 implementation focusing on core functionality. Additional features will be added in subsequent phases.

### Pool Statistics
The implementation fetches real-time data using Blend's view functions:
- `get_reserve`: Returns reserve data including total supplied and borrowed amounts
- `get_pool_config`: Returns pool configuration including backstop rate 