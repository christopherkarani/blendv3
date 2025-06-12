# 🎯 Pool Stats Implementation Plan
## Comprehensive Analysis & Implementation Strategy

### 🔍 Available Contract Functions (From Debug Window)
```rust
// Pool Configuration & Info
get_config() → PoolConfig
get_admin() → address
get_reserve_list() → vec<address>

// Reserve Data (Per Asset)
get_reserve(asset) → Reserve

// User Positions & Data
get_positions(address) → Positions

// Emissions System
get_reserve_emissions(reserve_token_index) → option<ReserveEmissionData>
get_user_emissions(user, reserve_token_index) → option<UserEmissionData>
claim(from, reserve_token_ids, to) → i128
gulp_emissions() → i128

// Auction System
get_auction(auction_type, user) → AuctionData
new_auction(auction_type, user, bid, lot, percent) → AuctionData

// Pool Operations
submit(from, spender, to, requests) → Positions
update_status() → u32
gulp(asset) → i128
```

### 📊 Return Types (Provided)
```rust
struct PoolConfig {
  bstop_rate: u32,        // Backstop rate
  max_positions: u32,     // Maximum positions per user
  min_collateral: i128,   // Minimum collateral required
  oracle: address,        // Oracle contract address
  status: u32            // Pool status
}

struct Reserve {
  asset: address,         // Asset contract address
  config: ReserveConfig,  // Reserve configuration
  data: ReserveData,      // Reserve data (supplies, borrows, etc.)
  scalar: i128           // Scalar for calculations
}
```

## 🎯 Implementation Strategy

### Phase 1: Pool-Wide Statistics (HIGH PRIORITY)
**Target Values**: Supplied=$111.28k, Borrowed=$55.50k, Backstop=$353.75k

#### Step 1.1: Get All Pool Assets
- Use `get_reserve_list()` to get `vec<address>` of all assets
- Log all asset addresses for debugging

#### Step 1.2: Fetch Reserve Data for Each Asset
- For each asset in reserve list: call `get_reserve(asset) → Reserve`
- Parse `ReserveData` from each Reserve struct
- Apply `scalar` for proper decimal conversion

#### Step 1.3: Aggregate Pool Totals
- Sum `totalSupplied` across all reserves
- Sum `totalBorrowed` across all reserves
- Convert to USD using oracle prices
- Calculate utilization: `totalBorrowed / totalSupplied`

#### Step 1.4: Get Pool Configuration
- Use `get_config() → PoolConfig` for backstop rate and pool status
- Extract `bstop_rate` for backstop calculations

### Phase 2: Backstop Functionality (MEDIUM PRIORITY)
#### Step 2.1: Backstop Balance Discovery
- Test backstop-related functions from different contracts
- Use `bstop_rate` from PoolConfig for calculations
- Find the correct way to get backstop TVL ($353.75k target)

#### Step 2.2: Backstop Operations
- Implement backstop deposit/withdraw functionality
- Add backstop APY calculations
- Show backstop utilization and health

### Phase 3: Emissions System (MEDIUM PRIORITY)
#### Step 3.1: Reserve Emissions
- Use `get_reserve_emissions(reserve_token_index)` for each reserve
- Parse `ReserveEmissionData` to get emission rates

#### Step 3.2: User Emissions
- Use `get_user_emissions(user, reserve_token_index)` for user's claimable rewards
- Implement `claim(from, reserve_token_ids, to)` for claiming rewards
- Add "Claim All Emissions" functionality

#### Step 3.3: Emissions UI
- Show claimable emissions per asset
- Show total claimable emissions
- Add claim buttons and transaction handling

### Phase 4: Enhanced Pool Analytics (LOW PRIORITY)
#### Step 4.1: Position Tracking
- Use `get_positions(address)` to show user's positions across all assets
- Calculate user's total supplied/borrowed across pool

#### Step 4.2: Auction Monitoring
- Use `get_auction(auction_type, user)` to monitor liquidation auctions
- Show auction data and opportunities

## 🛠️ Technical Implementation Plan

### 1. Data Models Update
```swift
// New comprehensive reserve data model
struct PoolReserveData {
    let asset: String          // Asset address
    let symbol: String         // Human readable symbol
    let totalSupplied: Decimal // From ReserveData
    let totalBorrowed: Decimal // From ReserveData
    let utilizationRate: Decimal
    let supplyAPY: Decimal
    let borrowAPY: Decimal
    let scalar: Decimal        // For decimal conversion
    let price: Decimal         // From oracle
}

// Pool-wide aggregated statistics
struct TruePoolStats {
    let totalSuppliedUSD: Decimal    // Target: $111.28k
    let totalBorrowedUSD: Decimal    // Target: $55.50k
    let backstopBalanceUSD: Decimal  // Target: $353.75k
    let overallUtilization: Decimal
    let backstopRate: Decimal        // From PoolConfig
    let poolStatus: UInt32           // From PoolConfig
    let reserves: [PoolReserveData]  // All assets
    let lastUpdated: Date
}
```

### 2. Service Methods
```swift
// Core pool data fetching
func fetchAllPoolReserves() async throws -> [PoolReserveData]
func getPoolConfig() async throws -> PoolConfig
func getTruePoolStats() async throws -> TruePoolStats

// Emissions functionality
func getUserEmissions(for user: String) async throws -> [EmissionData]
func claimEmissions(reserveTokenIds: [UInt32]) async throws -> String
func getClaimableEmissionsTotal() async throws -> Decimal

// Backstop functionality
func getBackstopBalance() async throws -> Decimal
func getBackstopAPY() async throws -> Decimal
```

### 3. UI Components
- **Pool Overview Card**: Shows $111.28k supplied, $55.50k borrowed, $353.75k backstop
- **Asset Breakdown Table**: Individual asset statistics
- **Emissions Panel**: Claimable rewards with claim buttons
- **Backstop Panel**: Backstop balance, APY, and operations

## 🔬 Debug Strategy
1. **Log Function Calls**: Log every contract function call with parameters and results
2. **Return Type Parsing**: Log the exact structure of returned data
3. **Scalar Application**: Test different scalar applications for decimal conversion
4. **Cross-Reference**: Compare our calculations with dashboard values

## 🚀 Success Metrics
- ✅ Total Supplied matches $111.28k
- ✅ Total Borrowed matches $55.50k  
- ✅ Backstop balance matches $353.75k
- ✅ Individual asset breakdowns match dashboard
- ✅ Emissions claiming works correctly
- ✅ Pool utilization calculation is accurate

---

**Next Step**: Implement Phase 1.1 - Get all pool assets using `get_reserve_list()` 