# Blend Protocol Data Fetching Architecture

This document provides a comprehensive explanation of how the Blend Protocol retrieves and manages pool data, focusing on the data flow from smart contracts to the user interface.

## Table of Contents

1. [Overview](#overview)
2. [Data Flow Architecture](#data-flow-architecture)
3. [Key Components](#key-components)
4. [Detailed Process Flow](#detailed-process-flow)
5. [Caching and Performance Optimizations](#caching-and-performance-optimizations)
6. [Error Handling](#error-handling)
7. [Version Compatibility](#version-compatibility)
8. [Technical Implementation Details](#technical-implementation-details)

## Overview

The Blend Protocol UI needs to display comprehensive information about lending pools, including supply and borrow rates, total liquidity, utilization ratios, and user positions. This data resides on the blockchain and must be efficiently retrieved, processed, and presented to users.

The data fetching architecture follows a layered approach that separates concerns:

1. **Smart Contract Layer**: The on-chain contracts that store pool state
2. **SDK Layer**: JavaScript classes that interact with the blockchain
3. **Hook Layer**: React hooks that provide data to the UI components
4. **UI Layer**: Components that display the data to users

## Data Flow Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │     │                 │
│  Soroban Smart  │     │   Blend SDK     │     │   React Hooks   │     │  UI Components  │
│    Contracts    │────▶│   (JS/TS)       │────▶│  (React Query)  │────▶│                 │
│                 │     │                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │                       │
        │                       │                       │                       │
        ▼                       ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │     │                 │
│ Contract State  │     │   Data Models   │     │  Cached State   │     │  Rendered UI    │
│                 │     │                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Key Components

### 1. Smart Contract Interfaces

The Blend Protocol uses two primary contract types for pools:

- **PoolContractV1**: First version of the lending pool contract
- **PoolContractV2**: Enhanced version with additional features

These contracts expose methods like:
- `getConfig()`: Retrieves pool configuration
- `getReserveList()`: Gets the list of assets in the pool
- `getReserve(asset)`: Gets data for a specific asset reserve

### 2. SDK Data Models

The SDK defines TypeScript classes that represent blockchain data:

- **PoolMetadata**: Basic information about a pool
- **Pool**: Complete pool data including all reserves
- **Reserve**: Data for a specific asset in the pool
- **PoolUser**: User positions in a pool

### 3. React Query Hooks

Custom React hooks using React Query (Tanstack Query) for data fetching:

- **usePoolMeta**: Fetches pool metadata
- **usePool**: Fetches complete pool data
- **usePoolOracle**: Fetches price data for pool assets
- **usePoolUser**: Fetches user positions in a pool

## Detailed Process Flow

### Step 1: Fetching Pool Metadata

The process begins with fetching basic pool metadata:

```typescript
// In a React component
const { data: poolMeta } = usePoolMeta(poolId);
```

The `usePoolMeta` hook:

```typescript
export function usePoolMeta(
  poolId: string,
  enabled: boolean = true
): UseQueryResult<PoolMeta, Error> {
  const { network } = useSettings();
  return useQuery({
    staleTime: DEFAULT_STALE_TIME,
    queryKey: ['pool-meta', poolId],
    enabled: enabled && poolId !== '',
    queryFn: async () => {
      try {
        return await PoolMetadata.load(network, poolId);
      } catch (e: any) {
        console.error('Error fetching pool metadata', e);
        throw e;
      }
    },
  });
}
```

The `PoolMetadata.load` method:

```typescript
public static async load(network: Network, id: string): Promise<PoolMetadata> {
  const stellarRpc = new rpc.Server(network.rpc, network.opts);
  
  // Create contract instance based on version detection
  const poolContract = await PoolMetadata.getPoolContract(network, id);
  
  // Call the getConfig method on the smart contract
  const operation = xdr.Operation.fromXDR(poolContract.getConfig(), 'base64');
  const result = await stellarRpc.simulateTransaction(operation);
  
  if (rpc.Api.isSimulationSuccess(result)) {
    // Parse the config from the contract response
    const config = poolContract.parseConfig(result);
    
    // Get reserve list from contract
    const reserveListOp = xdr.Operation.fromXDR(poolContract.getReserveList(), 'base64');
    const reserveListResult = await stellarRpc.simulateTransaction(reserveListOp);
    
    if (rpc.Api.isSimulationSuccess(reserveListResult)) {
      const reserveList = poolContract.parseReserveList(reserveListResult);
      
      // Create and return the PoolMetadata object
      return new PoolMetadata(
        id,
        config.name,
        config.oracle,
        config.bstop_rate.toString(),
        config.status,
        reserveList,
        poolContract.version
      );
    }
  }
  
  throw new Error('Failed to load pool metadata');
}
```

### Step 2: Fetching Complete Pool Data

Once the metadata is available, the complete pool data can be fetched:

```typescript
// In a React component
const { data: pool } = usePool(poolMeta);
```

The `usePool` hook:

```typescript
export function usePool(
  poolMeta: PoolMeta | undefined,
  enabled: boolean = true
): UseQueryResult<Pool, Error> {
  const { network } = useSettings();
  return useQuery({
    staleTime: DEFAULT_STALE_TIME,
    queryKey: ['pool', poolMeta?.id],
    enabled: enabled && poolMeta !== undefined,
    queryFn: async () => {
      if (poolMeta !== undefined) {
        try {
          if (poolMeta.version === Version.V2) {
            return await PoolV2.loadWithMetadata(network, poolMeta.id, poolMeta);
          } else {
            return await PoolV1.loadWithMetadata(network, poolMeta.id, poolMeta);
          }
        } catch (e: any) {
          console.error('Error fetching pool data', e);
          throw e;
        }
      }
    },
  });
}
```

The `PoolV2.loadWithMetadata` method:

```typescript
public static async loadWithMetadata(
  network: Network,
  id: string,
  metadata: PoolMetadata
): Promise<PoolV2> {
  const timestamp = Math.floor(Date.now() / 1000);

  const reserveList = await ReserveV2.loadList(
    network,
    id,
    BigInt(metadata.backstopRate),
    metadata.reserveList,
    timestamp
  );
  const reserves = new Map<string, Reserve>();
  for (const reserve of reserveList) {
    reserves.set(reserve.assetId, reserve);
  }

  return new PoolV2(network, id, metadata, reserves, timestamp);
}
```

### Step 3: Loading Reserve Data

The `ReserveV2.loadList` method loads data for all reserves in the pool:

```typescript
static async loadList(
  network: Network,
  poolId: string,
  backstopTakeRate: bigint,
  reserveList: string[],
  timestamp?: number
): Promise<Reserve[]> {
  const reserves = new Array<Reserve>();
  const stellarRpc = new rpc.Server(network.rpc, network.opts);

  // Create ledger keys for all the data we need
  const ledgerKeys: xdr.LedgerKey[] = [];
  for (const [index, reserveId] of reserveList.entries()) {
    const dTokenIndex = index * 2;
    const bTokenIndex = index * 2 + 1;
    ledgerKeys.push(
      ...[
        ReserveConfigV2.ledgerKey(poolId, reserveId),
        ReserveData.ledgerKey(poolId, reserveId),
        ReserveEmissionConfig.ledgerKey(poolId, bTokenIndex),
        ReserveEmissionData.ledgerKey(poolId, bTokenIndex),
        ReserveEmissionConfig.ledgerKey(poolId, dTokenIndex),
        ReserveEmissionData.ledgerKey(poolId, dTokenIndex),
      ]
    );
  }

  // Make a batch RPC call to get all the data
  const reserveLedgerEntries = await stellarRpc.getLedgerEntries(...ledgerKeys);

  // Process the data
  const reserveConfigMap = new Map();
  const reserveDataMap = new Map();
  const emissionDataMap = new Map();

  // Parse ledger entries into appropriate data structures
  // ...

  // Create Reserve objects
  for (const reserveId of reserveList) {
    const reserveConfig = reserveConfigMap.get(reserveId);
    const reserveData = reserveDataMap.get(reserveId);
    
    // Create and configure the Reserve object
    // ...
    
    reserves.push(reserve);
  }

  return reserves;
}
```

### Step 4: Calculating Derived Values

Once the raw data is loaded, the Reserve class calculates derived values like APR and APY:

```typescript
public accrue(backstopTakeRate: bigint, timestamp: number): void {
  // Update interest rates based on current utilization
  this.accrueInterest(timestamp);
  
  // Calculate APR and APY values
  this.setRates(backstopTakeRate);
}

private setRates(backstopTakeRate: bigint): void {
  const curUtil = this.data.utilization;
  const curIr = this.data.interestRate;
  
  // Calculate borrow APR
  this.borrowApr = FixedMath.toFloat(curIr, 7);
  
  // Calculate supply APR (accounting for backstop take rate)
  const supplyCapture = FixedMath.mulFloor(
    FixedMath.SCALAR_7 - backstopTakeRate,
    curUtil,
    FixedMath.SCALAR_7
  );
  this.supplyApr = FixedMath.toFloat(
    FixedMath.mulFloor(curIr, supplyCapture, FixedMath.SCALAR_7),
    7
  );
  
  // Calculate APY values with compounding
  this.borrowApy = (1 + this.borrowApr / 365) ** 365 - 1;
  this.supplyApy = (1 + this.supplyApr / 52) ** 52 - 1;
}
```

## Caching and Performance Optimizations

The Blend Protocol implements several optimizations to ensure efficient data fetching:

### 1. React Query Caching

React Query provides automatic caching of fetched data:

```typescript
return useQuery({
  staleTime: DEFAULT_STALE_TIME,  // Data remains fresh for this duration
  queryKey: ['pool', poolMeta?.id],  // Unique key for caching
  // ...
});
```

### 2. Batch RPC Calls

Instead of making separate RPC calls for each piece of data, the protocol batches requests:

```typescript
// Get all ledger entries in a single call
const reserveLedgerEntries = await stellarRpc.getLedgerEntries(...ledgerKeys);
```

### 3. Data Dependencies

Hooks depend on each other's data to prevent redundant fetching:

```typescript
// usePool depends on poolMeta from usePoolMeta
const { data: poolMeta } = usePoolMeta(poolId);
const { data: pool } = usePool(poolMeta);
```

### 4. Conditional Fetching

Queries only execute when their dependencies are available:

```typescript
enabled: enabled && poolMeta !== undefined
```

## Error Handling

The data fetching architecture includes comprehensive error handling:

```typescript
try {
  // Data fetching logic
} catch (e: any) {
  console.error('Error fetching pool data', e);
  throw e;  // Propagate to React Query for UI handling
}
```

UI components can then handle these errors:

```typescript
const { data: pool, error, isLoading } = usePool(poolMeta);

if (isLoading) return <LoadingIndicator />;
if (error) return <ErrorDisplay error={error} />;
```

## Version Compatibility

The architecture supports multiple contract versions transparently:

```typescript
if (poolMeta.version === Version.V2) {
  return await PoolV2.loadWithMetadata(network, poolMeta.id, poolMeta);
} else {
  return await PoolV1.loadWithMetadata(network, poolMeta.id, poolMeta);
}
```

This allows the UI to work with both V1 and V2 pools without requiring changes to the components.

## Technical Implementation Details

### Smart Contract Interaction

The SDK uses Stellar's SDK to interact with Soroban smart contracts:

```typescript
const operation = xdr.Operation.fromXDR(poolContract.getConfig(), 'base64');
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
