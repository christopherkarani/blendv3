# Blend Protocol: Oracle Pricing Integration Report

**Objective**: This report details the oracle pricing mechanism employed by the Blend Protocol. It is intended to guide a coding agent in understanding and integrating with this system to fetch and utilize asset prices.

**Date**: 2025-05-28

### 1. Overview of Oracle Pricing in Blend Protocol

Blend Protocol, like many DeFi applications, relies on oracles to provide external asset price information to its smart contracts and off-chain components. Accurate and timely price feeds are crucial for various protocol functions, including:
*   Calculating the value of collateral and debt.
*   Determining borrowing capacity and loan health (liquidation thresholds).
*   Valuing reserves and overall pool liquidity.
*   Calculating APYs for lending and borrowing, especially when emissions are involved.

The system uses a combination of on-chain Soroban smart contracts (written in Rust) and an SDK for interaction. While the primary existing SDK is in JavaScript/TypeScript, this section will describe how a similar interaction layer would be structured in Swift.

### 2. Core Oracle Smart Contract (Rust Interface)

The foundation of the pricing system is a Soroban smart contract. Based on the provided interface, its key characteristics are:

*   **Storage**: Prices are stored as `i128` fixed-point numbers. Timestamps are `u64`.
*   **Configuration**:
    *   `set_data(admin: address, base: Asset, assets: vec<Asset>, decimals: u32, resolution: u32)`: Initializes or updates the oracle's configuration. This includes the admin, the base asset against which prices are quoted, a list of supported assets, the number of decimals for price precision, and the price update resolution.
*   **Price Updates**:
    *   `set_price(prices: vec<i128>, timestamp: u64)`: Allows an authorized entity (likely the admin or a trusted feed) to update prices for assets at a specific timestamp.
    *   `set_price_stable(prices: vec<i128>)`: A specialized function for updating prices, possibly for stablecoins where timestamps might be less critical or managed differently.
*   **Price Retrieval**:
    *   `base() -> Asset`: Returns the base asset (e.g., USDC, XLM).
    *   `assets() -> vec<Asset>`: Returns a list of all assets for which the oracle can provide prices.
    *   `decimals() -> u32`: **Crucial function**. Returns the number of decimal places used in the stored `i128` prices. For example, if `decimals` is 7, a stored price of `123456789` represents `12.3456789`.
    *   `resolution() -> u32`: Indicates the intended frequency or granularity of price updates.
    *   `price(asset: Asset, timestamp: u64) -> option<PriceData>`: Retrieves the price for a specific asset at a given timestamp. Returns an option, meaning a price might not be available.
    *   `prices(asset: Asset, records: u32) -> option<vec<PriceData>>`: Retrieves a series of historical price records for an asset.
    *   `lastprice(asset: Asset) -> option<PriceData>`: **Most commonly used function for current valuation**. Retrieves the latest available price for a given asset.
*   **Data Structures**:
    *   `PriceData { price: i128, timestamp: u64 }`: The structure returned by price retrieval functions.
    *   `Asset { Stellar(address), Other(symbol) }`: An enum representing either a Stellar-native asset (identified by its contract address) or an off-chain/other asset (identified by a symbol).

### 3. Swift SDK Interaction Layer (Hypothetical Implementation)

A Swift SDK would provide abstractions to interact with the Blend Protocol's oracle contract, similar to the existing JavaScript SDK. This involves defining data structures, creating services to call Soroban contracts, and handling numeric conversions.

*   **Core Data Structures (Swift)**:

    ```swift
    import Foundation // For Decimal
    // Assuming a BigInt library for Int128, or careful String conversion if not available
    // For simplicity, we might represent i128 as String from contract and convert to Decimal
    // Or use a library that supports Int128. Let's assume a typealias for clarity:
    typealias Int128 = String // Placeholder: In a real scenario, use a proper BigInt/Int128 library

    struct OraclePriceData: Decodable { // Assuming JSON parsing from RPC response
        let price: Int128 // Representing the fixed-point i128 value
        let timestamp: UInt64
    }

    struct OracleDecimalsInfo {
        let decimals: UInt32
        let latestLedger: UInt64 // Or appropriate ledger type
    }

    // Network configuration
    struct Network {
        let rpcURL: URL
        let passphrase: String
        // Other options like stellarSdk.Horizon.Options in JS
    }
    ```

*   **Soroban Interaction Service (Swift)**:
    A service class would encapsulate the logic for making calls to the Soroban smart contract.

    ```swift
    class SorobanService {
        let network: Network
        // Dependency for actual RPC calls (e.g., a Stellar SDK instance)
        // let stellarSDKClient: StellarSDKClient 

        init(network: Network /*, stellarSDKClient: StellarSDKClient */) {
            self.network = network
            // self.stellarSDKClient = stellarSDKClient
        }

        func getOraclePrice(oracleContractId: String, tokenId: String) async throws -> OraclePriceData {
            // 1. Construct Soroban contract call for "lastprice" function.
            //    This involves creating ScVal arguments for the asset.
            // 2. Use the Stellar SDK's equivalent of simulateTransaction.
            //    Example: try await stellarSDKClient.simulateTransaction(...)
            // 3. Parse the XDR ScVal response into OraclePriceData.
            //    This might involve decoding from base64 XDR string.
            
            // Placeholder implementation:
            print("Simulating call to \(oracleContractId).lastprice for token \(tokenId)")
            // Replace with actual network call and parsing logic
            guard let url = URL(string: "https://rpc.example.com/simulate") else {
                 throw URLError(.badURL)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            // Add body with contract call details
            // let (data, _) = try await URLSession.shared.data(for: request)
            // let decodedResponse = try JSONDecoder().decode(SorobanRpcResponse<OraclePriceData>.self, from: data)
            // return decodedResponse.result
            throw NSError(domain: "SorobanService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
        }

        func getOracleDecimals(oracleContractId: String) async throws -> OracleDecimalsInfo {
            // 1. Construct Soroban contract call for "decimals" function.
            // 2. Simulate transaction.
            // 3. Parse response.
            
            // Placeholder implementation:
            print("Simulating call to \(oracleContractId).decimals()")
            throw NSError(domain: "SorobanService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
        }
    }
    ```

*   **PoolOracle Service (Swift)**:
    Manages oracle data for a specific pool, analogous to `PoolOracle` in JS.

    ```swift
    class PoolOracleService {
        let oracleContractId: String
        private(set) var prices: [String: OraclePriceData] // Asset ID (token_id) -> PriceData
        private(set) var decimals: UInt32
        private(set) var latestLedger: UInt64
        
        private let sorobanService: SorobanService

        init(oracleContractId: String, prices: [String: OraclePriceData], decimals: UInt32, latestLedger: UInt64, sorobanService: SorobanService) {
            self.oracleContractId = oracleContractId
            self.prices = prices
            self.decimals = decimals
            self.latestLedger = latestLedger
            self.sorobanService = sorobanService
        }

        static func load(network: Network, oracleContractId: String, assetIds: [String]) async throws -> PoolOracleService {
            let service = SorobanService(network: network)
            
            async let decimalsInfoResult = try service.getOracleDecimals(oracleContractId: oracleContractId)
            
            var fetchedPrices: [String: OraclePriceData] = [:]
            try await withThrowingTaskGroup(of: (String, OraclePriceData).self) { group in
                for assetId in assetIds {
                    group.addTask {
                        let priceData = try await service.getOraclePrice(oracleContractId: oracleContractId, tokenId: assetId)
                        return (assetId, priceData)
                    }
                }
                for try await (assetId, priceData) in group {
                    fetchedPrices[assetId] = priceData
                }
            }
            
            let resolvedDecimalsInfo = try await decimalsInfoResult
            return PoolOracleService(
                oracleContractId: oracleContractId,
                prices: fetchedPrices,
                decimals: resolvedDecimalsInfo.decimals,
                latestLedger: resolvedDecimalsInfo.latestLedger,
                sorobanService: service
            )
        }

        func getPriceRaw(assetId: String) -> Int128? { // Returns the fixed-point i128 string
            return prices[assetId]?.price
        }

        func getPriceDecimal(assetId: String) -> Decimal? {
            guard let priceData = prices[assetId],
                  let priceBigInt = Decimal(string: priceData.price) else { // Convert i128 string to Decimal
                return nil
            }
            return priceBigInt / pow(Decimal(10), Int(self.decimals))
        }
    }
    ```

*   **Numeric Utilities (Swift)**:
    Swift's `Decimal` type is suitable for financial calculations. For `i128`, a BigInt library or careful string manipulation would be needed.

    ```swift
    struct MathUtils {
        // Converts a Decimal to a fixed-point string representation (simulating i128)
        static func toFixed(value: Decimal, decimals: UInt32) -> Int128 { // Returns String
            let scaledValue = value * pow(Decimal(10), Int(decimals))
            // Further rounding or truncation might be needed to match contract behavior
            var rounded = Decimal()
            NSDecimalRound(&rounded, &scaledValue, 0, .plain) // Round to nearest integer
            return rounded.description 
        }

        // Converts a fixed-point i128 string to Decimal
        static func toDecimal(fixedPointValue: Int128, decimals: UInt32) -> Decimal? {
            guard let value = Decimal(string: fixedPointValue) else { return nil }
            return value / pow(Decimal(10), Int(decimals))
        }

        // Multiplication and division functions (mulDivFloor, mulDivCeil) would require
        // careful implementation using Decimal or a BigInt library to match the
        // precision and rounding behavior of the JS/Rust versions.
    }
    ```

*   **Price Fetcher Contract Interaction (Swift)**:
    If a "price fetcher" contract is used (as suggested by `stellar_rpc.ts` in the JS SDK), the `SorobanService` would need a method to call its `get_prices` function.

    ```swift
    // Inside SorobanService
    func getOraclePricesViaFetcher(fetcherContractId: String, oracleId: String, tokenIds: [String]) async throws -> [String: OraclePriceData] {
        // 1. Construct Soroban contract call for "get_prices" on fetcherContractId.
        //    Arguments would include the primary oracleId and a list of assets.
        // 2. Simulate transaction.
        // 3. Parse the response, which would likely be a map or array of PriceData.
        // Placeholder:
        print("Simulating call to \(fetcherContractId).get_prices for oracle \(oracleId)")
        throw NSError(domain: "SorobanService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }
    ```
    The `PoolOracleService.load` method could then be updated to optionally use this fetcher.

This Swift structure mirrors the JavaScript SDK's approach, adapting to Swift's type system, concurrency model (async/await, TaskGroup), and numeric types. The key is accurate Soroban contract interaction and precise handling of fixed-point numbers.

### 4. Data Flow: On-Chain Oracle to Application

1.  **Configuration**: The application needs the `oracle_id` associated with a lending pool. This is typically part of the pool's metadata.
2.  **Fetch Decimals**: The `decimals` for the oracle are fetched first (e.g., via `SorobanService.getOracleDecimals`). This determines how to interpret the fixed-point prices.
3.  **Fetch Prices**:
    *   The `lastprice` function of the oracle contract is called for each required asset (e.g., via `SorobanService.getOraclePrice`).
    *   This is done via simulating a Soroban transaction.
    *   A Swift equivalent of `PoolOracle.load()` (e.g., `PoolOracleService.load`) would parallelize these calls.
    *   If a "price fetcher" contract is available, its batch-fetching function would be used.
4.  **Data Processing**:
    *   Raw prices are returned as `i128` (represented as `String` or `BigInt` in Swift) from the contract.
    *   The `PoolOracleService` stores these raw prices along with the fetched `decimals`.
5.  **Consumption**:
    *   Application logic (e.g., UI views, calculation engines) uses methods like `PoolOracleService.getPriceDecimal(assetId:)` to get human-readable prices as `Decimal`.
    *   Internal calculations requiring high precision would use `Decimal` types or operate on the `i128` representation with custom math functions.

### 5. Price Usage within Blend Protocol (Example: `reserve.ts` logic adapted to Swift)

The logic within `reserve.ts` for token conversions and effective collateral/liability calculations would be ported to Swift. Oracle prices are applied *after* these reserve-specific calculations determine base asset amounts.
*   **Token Conversions**: Functions converting dTokens/bTokens to underlying asset amounts would be implemented in Swift.
    `let assetAmount = try reserveService.toAssetFromBToken(bTokenAmount: someAmount)`
*   **Valuation**: The resulting asset amounts are then valued using oracle prices:
    `let assetValueUSD = assetAmountDecimal * (try await poolOracleService.getPriceDecimal(assetId: someAssetId) ?? Decimal.zero)`
*   **Interest Rate Model**: The value of supplied and borrowed assets (which determines utilization in monetary terms) ultimately relies on oracle prices.

### 6. Integration Guide for a Coding Agent

To integrate with Blend Protocol's oracle pricing using a Swift-based system:

**A. Prerequisites:**
*   Access to a Stellar network (RPC endpoint, network passphrase).
*   A Swift Stellar SDK (e.g., StellarSwiftSDK) for transaction building, Soroban contract interaction, and XDR handling.
*   A library for handling 128-bit integers (like `Int128`) if precise representation is needed beyond `Decimal` for intermediate steps, or use `Decimal` throughout with care. Swift's `Decimal` is good for financial math.

**B. Integration Steps:**

1.  **Obtain Oracle ID**: For a given lending pool, retrieve its associated `oracle_id`.

2.  **Fetch Oracle Decimals**:
    *   Call the `decimals()` function on the `oracle_id` contract using your Swift Soroban interaction layer.
    *   Store this `decimals` value (`UInt32`).
    *   *Conceptual Call (Swift)*: `let decimalsInfo = try await sorobanService.getOracleDecimals(oracleContractId: "ORACLE_ID")`

3.  **Fetch Asset Prices (Latest)**:
    *   For each asset:
        *   Prepare the asset identifier in the `ScVal` format expected by the Soroban contract.
        *   Call the `lastprice(asset: Asset)` function on the `oracle_id` contract.
        *   This returns an `Optional<OraclePriceData>`. Handle `nil` cases.
        *   The `OraclePriceData` struct contains `price: Int128` (fixed-point) and `timestamp: UInt64`.
    *   *Conceptual Call (Swift)*: `let priceData = try await sorobanService.getOraclePrice(oracleContractId: "ORACLE_ID", tokenId: "ASSET_CONTRACT_ID")`
    *   **Batching**: Implement parallel fetching using `TaskGroup` as shown in `PoolOracleService.load`, or use a dedicated batch-fetching contract function if available.

4.  **Store and Manage Prices (e.g., in `PoolOracleService`)**:
    *   Store fetched `decimals`.
    *   Store a `[String: OraclePriceData]` dictionary.
    *   Provide methods to get raw `Int128` (String/BigInt) prices and converted `Decimal` prices.
    *   Implement caching and refreshing logic as needed.

5.  **Numeric Handling (Crucial in Swift)**:
    *   **Store Raw Prices**: Store prices as fetched (e.g., `String` representing `i128`).
    *   **Conversion to `Decimal`**: For display or calculations:
        `guard let priceString = rawPriceData.price, let fixedPointPrice = Decimal(string: priceString) else { /* handle error */ }`
        `let displayPrice = fixedPointPrice / pow(Decimal(10), Int(oracleDecimals))`
        Swift's `Decimal` type is designed for base-10 arithmetic and is suitable for financial values.
    *   **Fixed-Point Arithmetic**: For complex intermediate calculations requiring absolute precision matching the contract, either use `Decimal` carefully or, if `i128`'s specific behavior is critical, use a BigInt library that supports 128-bit integers and replicate the fixed-point math.

6.  **Using Prices in Application Logic**:
    *   **Valuation**:
        `let tokenAmountDecimal = MathUtils.toDecimal(fixedPointTokenAmount, assetDecimals)`
        `let priceDecimal = poolOracleService.getPriceDecimal(assetId: "ASSET_ID") ?? Decimal.zero`
        `let valueInBaseCurrency = tokenAmountDecimal * priceDecimal`

**C. Error Handling & Considerations (Swift Specifics):**
*   **Swift Error Handling**: Use `do-catch` blocks and `throws` for functions that can fail (network calls, parsing).
*   **Optional Handling**: Safely unwrap optionals (e.g., `guard let`, `if let`) when dealing with prices that might not be available.
*   **Concurrency**: Utilize Swift's structured concurrency (async/await, `TaskGroup`) for efficient, non-blocking network operations.
*   **Type Safety**: Leverage Swift's strong type system.
*   **Memory Management**: ARC handles most memory management, but be mindful of retain cycles in closures if using older patterns (less common with modern Swift concurrency).

### 7. Example Snippet (Conceptual Python-like Pseudocode)

```python
class MyOracleIntegrator:
    def __init__(self, rpc_server, oracle_contract_id):
        self.rpc = rpc_server
        self.oracle_id = oracle_contract_id
        self.decimals = self._fetch_oracle_decimals()
        self.price_cache = {} # asset_id -> {price: BigInt, timestamp: int}

    def _fetch_oracle_decimals(self):
        # response = self.rpc.simulate_contract_call(self.oracle_id, "decimals")
        # return parse_response_to_int(response)
        pass # Placeholder

    def get_last_price(self, asset_id_str, asset_contract_address=None):
        # asset_scval = prepare_asset_scval(asset_id_str, asset_contract_address) # Format for Soroban
        # response = self.rpc.simulate_contract_call(self.oracle_id, "lastprice", asset_scval)
        # price_data = parse_price_data_option(response) # Handles Option<>
        # if price_data:
        #     self.price_cache[asset_id_str] = price_data
        #     return price_data
        # return None
        pass # Placeholder

    def get_price_float(self, asset_id_str): # In Swift, this would return Decimal
        if asset_id_str not in self.price_cache:
            self.get_last_price(asset_id_str) # Fetch if not cached

        cached_data = self.price_cache.get(asset_id_str)
        if cached_data and self.decimals is not None:
            # Use Decimal type for precision
            return Decimal(cached_data['price']) / (Decimal(10) ** self.decimals)
        return None

# Usage:
# integrator = MyOracleIntegrator(rpc_server_instance, "ORACLE_CONTRACT_ID_HERE")
# price_xlm_float = integrator.get_price_float("XLM")
# if price_xlm_float:
# print(f"Current price of XLM: {price_xlm_float}")
```

This report provides a comprehensive overview. The integrating agent should refer to the specific Blend Protocol SDK source files for exact implementation details and adapt the patterns to its target language and environment.
const result = await stellarRpc.simulateTransaction(operation);
```

### Data Parsing

Contract responses are parsed into TypeScript objects:

```typescript
const config = poolContract.parseConfig(result);
```

### Fixed-Point Math

Financial calculations use fixed-point arithmetic for precision:

```typescript
const supplyApr = FixedMath.toFloat(
  FixedMath.mulFloor(curIr, supplyCapture, FixedMath.SCALAR_7),
  7
);
```

### Timestamp Handling

Data is projected to the current timestamp to ensure up-to-date values:

```typescript
const timestamp = Math.floor(Date.now() / 1000);
reserve.accrue(backstopTakeRate, timestamp);
```

---

This architecture enables the Blend Protocol UI to efficiently retrieve and display comprehensive pool data while maintaining good performance and user experience. The separation of concerns between smart contracts, SDK, hooks, and UI components creates a maintainable and extensible system.
