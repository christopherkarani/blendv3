# Blend v3 - iOS Application

A native iOS application for interacting with the Blend lending and borrowing protocol on the Stellar blockchain.

## Overview

Blend v3 provides a secure and intuitive interface for:
- 📊 Lending assets to earn interest
- 💰 Borrowing against collateral
- 🛡️ Backstop insurance participation
- 🪙 BLND token management
- ⚡ Real-time position monitoring

## Architecture

The application follows MVVM architecture with protocol-oriented design:

```
Blendv3/
├── Core/
│   ├── Models/          # Data models for Blend protocol
│   ├── Networking/      # Stellar & Soroban services
│   ├── Protocols/       # Protocol definitions
│   ├── Constants/       # Global constants
│   ├── Extensions/      # Swift extensions
│   └── Utilities/       # Helper utilities
├── Features/
│   └── Wallet/         # Wallet management feature
│       ├── Services/   # Business logic
│       ├── ViewModels/ # State management
│       └── Views/      # SwiftUI views
└── Tests/              # Unit tests
```

## Phase 1 Implementation ✅

### Completed
- ✅ Project structure with modular architecture
- ✅ Stellar iOS SDK integration
- ✅ Secure wallet management with Keychain
- ✅ Core data models for Blend protocol
- ✅ Network service abstractions
- ✅ Basic wallet UI with account display
- ✅ Unit test framework

### Key Components

#### Wallet Service
- Secure keypair generation and storage
- Keychain integration with biometric protection
- Multi-wallet support

#### Network Services
- Stellar Horizon API integration
- Soroban RPC for smart contracts
- Real-time account streaming

#### Data Models
- Type-safe Blend protocol representations
- Lending pool and position tracking
- Error handling

## Getting Started

### Requirements
- Xcode 15.0+
- iOS 16.0+
- Swift 5.9+

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-repo/Blendv3.git
cd Blendv3
```

2. Open in Xcode:
```bash
open Blendv3.xcodeproj
```

3. Build and run the project (⌘+R)

### Dependencies
- [Stellar iOS SDK](https://github.com/Soneso/stellar-ios-mac-sdk) - v3.1.0
- [KeychainSwift](https://github.com/evgenyneu/keychain-swift) - v20.0.0

## Usage

### Creating a Wallet
```swift
let viewModel = WalletViewModel()
await viewModel.createNewWallet()
```

### Importing a Wallet
```swift
await viewModel.importWallet(secretSeed: "SABC...")
```

## Testing

Run unit tests with:
```bash
swift test
```

Or in Xcode: ⌘+U

## Security

- All private keys are stored in the iOS Keychain
- Biometric authentication supported
- No keys are ever transmitted to servers
- Transaction signing happens locally

## Roadmap

### Phase 2: Lending Pool Integration
- Pool discovery and listing
- Deposit/withdraw functionality
- Interest rate display
- Real-time balance updates

### Phase 3: Borrowing Features
- Collateral management
- Borrow/repay functionality
- Health factor monitoring
- Liquidation warnings

### Phase 4: Backstop Module
- Backstop deposits
- Reward claiming
- Pool insurance status

### Phase 5: Advanced Features
- BLND token integration
- Portfolio analytics
- Push notifications
- Performance optimization

## Contributing

Please read our contributing guidelines before submitting PRs.

## License

[License Type] - See LICENSE file for details