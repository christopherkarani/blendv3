# Blend USDC Vault SwiftUI Interface

This is a complete SwiftUI interface for interacting with the Blend USDC lending pool on Stellar.

## Features

- **Dashboard View**: Shows pool statistics including total supplied, borrowed, available liquidity, APY, and utilization rate
- **Deposit/Withdraw**: Easy-to-use sheets for depositing and withdrawing USDC
- **Transaction History**: Track all your deposits and withdrawals with transaction hashes
- **Real-time Updates**: Pull-to-refresh to update pool statistics
- **Error Handling**: Clear error and success messages for all operations

## Architecture

The interface follows MVVM architecture:

- **Views**: SwiftUI views for the UI
  - `ContentView`: Main entry point
  - `BlendDashboardView`: Main dashboard with pool stats
  - `TransactionSheet`: Modal for deposits/withdrawals
  - `TransactionHistoryView`: List of past transactions

- **ViewModel**: `BlendViewModel` manages state and coordinates with the vault
  - Publishes pool stats, loading states, and messages
  - Handles all async operations
  - Maintains transaction history

- **Model**: Uses the existing `BlendUSDCVault` service

## Usage

The app is initialized with the provided secret key:
```
SDYH3V6ICEM463OTM7EEK7SNHYILXZRHPY45AYZOSK3N4NLF3NQUI4PQ
```

This corresponds to the public key:
```
GDQERENWDDSQZS7R7WKHZI3BSOYMV3FSWR7TFUYFTKQ447PIX6NREOJM
```

## Running the App

1. Make sure you have the Stellar SDK properly integrated in your Xcode project
2. Build and run the app
3. The interface will automatically connect to Stellar testnet
4. Pool statistics will load automatically
5. Use the Deposit/Withdraw buttons to interact with the pool

## Important Notes

- The app is configured for **testnet** by default
- Make sure the account has some XLM for transaction fees
- The account needs to have a trustline to USDC before depositing
- All amounts are in standard USDC units (e.g., 100.50 for $100.50)

## UI Features

### Pool Statistics
- **Total Supplied**: Total USDC deposited in the pool
- **Total Borrowed**: Total USDC borrowed from the pool
- **Available Liquidity**: USDC available for withdrawal
- **Current APY**: Annual percentage yield for suppliers
- **Utilization Rate**: Percentage of supplied funds that are borrowed

### Transaction Flow
1. Tap Deposit or Withdraw
2. Enter amount (or use quick amount buttons)
3. Confirm transaction
4. View success/error message
5. Check transaction history for details

### Visual Design
- Clean, modern interface inspired by Cash App
- Color-coded actions (green for deposits, orange for withdrawals)
- Loading states for all async operations
- Pull-to-refresh for updating stats

## Error Handling

The interface handles various error cases:
- Invalid amounts
- Insufficient balance for withdrawals
- Network errors
- Transaction failures

All errors are displayed clearly to the user with actionable messages. 