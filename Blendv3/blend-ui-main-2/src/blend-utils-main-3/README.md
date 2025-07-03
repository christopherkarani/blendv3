# blend-utils

Deployment and utility scripts for interacting with the Blend Protocol and setting up mock environments.

## Setup

1. Install Node.JS dependencies:

```bash
npm i
```

2. Compile the scripts

```bash
npm run build
```

3. Create a `.env` file based on the `.env.example` file

## Test environment

Test environments optionally come with default data. The `mock` script does a few things to help make interacting with Blend in a test environment easier:

1. Creates a handful of test tokens, including XLM's Stellar Asset Contract (SAC), USDC, wETH, and wBTC.
2. Sets prices for the test tokens on the mock oracle.
3. Creates a pool with the assets.
4. Deposits into the backstop for the pools with `WHALE` key and adds the pools into the reward zone.
5. Deposits and borrows assets from each pool from `WHALE`.

To add mock data to the Blend protocol in a the "network_name" test network, run:

```bash
node ./lib/testing-scripts/mock-example.js network_name
```

## Pool Deployment

Blend utils also helps deploy blend pools. The `deploy-pool` script takes in a single "network" parameter that defines what network the pool is deployed on.

The script requires that the `<NETWORK-NAME>.contracts.json` file exists and is up to date. If they wish to use a different oracle than standard they should update the file with the address of the oracle smart contract they wish to use. Additionally, all the token contracts that the pool will use must be defined in the file.

Finally, the user must have the `ADMIN` key defined in the `.env` file as well as the network passphrase and rpc url.

The `ADMIN` account must be sufficiently funded to pay for the deployment transaction fees and the initial pool backstop deposit.

The following constants must also be defined in the `deploy-pool` script:

### Pool Deployment Parameters

| Parameter                   | Description                                                                                 | Valid Range      | Notes                                                                                                        |
| --------------------------- | ------------------------------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------ |
| `pool_name`                 | Name of the pool to be deployed                                                             | String           |                                                                                                              |
| `backstop_take_rate`        | Percent of borrower interest sent to backstop depositors                                    | 0 to 100         |                                                                                                              |
| `max_positions`             | Maximum number of positions in the pool                                                     | > 0              | High values may cause liquidation issues due to Soroban resource limits. 8 is a good max for standard setups |
| `reserves`                  | Vector of initial reserve asset names                                                       | Array of strings | Asset contracts must be defined in `<NETWORK-NAME>.contracts.json`                                           |
| `reserve_configs`           | Vector of `ReserveConfig` structs. These should be set in the same order as the reserves.   | Array            |                                                                                                              |
| `reserve_emission_metadata` | Vector of `ReserveEmissionMetadata` structs. Needs to be in the same order as the reserves. | Array            | Governs percent of total pool emissions per reserve                                                          |

#### `ReserveConfig` Parameters

| Parameter        | Description                                       | Valid Range | Documentation                                                                             |
| ---------------- | ------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------- |
| `index`          | Reserve index in reserves vector                  | Integer     | Must match order in reserves array                                                        |
| `decimals`       | Number of decimals for underlying token           | Integer     |                                                                                           |
| `c_factor`       | Collateral factor                                 | 0 to 1e7    | [Risk Parameters](https://docs.blend.capital/pool-creators/adding-assets/risk-parameters) |
| `l_factor`       | Liability factor                                  | 0 to 1e7    | [Risk Parameters](https://docs.blend.capital/pool-creators/adding-assets/risk-parameters) |
| `util`           | Utilization target                                | < max_util  | [Risk Parameters](https://docs.blend.capital/pool-creators/adding-assets/risk-parameters) |
| `max_util`       | Maximum utilization                               | > util      | [Risk Parameters](https://docs.blend.capital/pool-creators/adding-assets/risk-parameters) |
| `r_base`         | Base interest rate                                | ≥ 0         | Set low unless fixed-rate asset                                                           |
| `r_one`          | Interest rate increase below target util          | ≥ 0         | [Interest Rates](https://docs.blend.capital/pool-creators/adding-assets/interest-rates)   |
| `r_two`          | Interest rate increase above target util          | ≥ 0         | [Interest Rates](https://docs.blend.capital/pool-creators/adding-assets/interest-rates)   |
| `r_three`        | Interest rate increase above 95% util             | ≥ 0         | [Interest Rates](https://docs.blend.capital/pool-creators/adding-assets/interest-rates)   |
| `reactivity`     | Speed of interest rate changes                    | ≤ 1000      | [Interest Rates](https://docs.blend.capital/pool-creators/adding-assets/interest-rates)   |
| `supply_cap` | Maximum amount of collateral that can be borrowed | ≥ 0         | [Risk Parameters](https://docs.blend.capital/pool-creators/adding-assets/risk-parameters) |
| `enabled`        | Whether the reserve is enabled                    | Boolean     |                                                                                           |

#### `ReserveEmissionMetadata` Parameters

| Parameter       | Description                     | Valid Range | Notes                          |
| --------------- | ------------------------------- | ----------- | ------------------------------ |
| `reserve_index` | Index of the reserve            | Integer     | Must match ReserveConfig index |
| `res_type`      | Type of emission                | 0 or 1      | 0=lenders, 1=borrowers         |
| `share`         | Percent of total pool emissions | 0 to 1e7    | Sum of all shares must be 1e7  |

Once the constants are set, the user can run the `deploy-pool` script to deploy the pool. The script takes two arguments:

- `NETWORK-NAME` - The name of the network to deploy the pool on. Valid options are `mainnet`, `testnet`, or `local`.

To run the script, use the following command:

```bash
node ./lib/v2/user-scripts/deploy-pool.js <NETWORK-NAME> <REVOKE-ADMIN>
```

## Checking the Backstop Threshold Requirements

If you want to add the pool to the reward zone, or enable it, it's backstop deposits will have to meet the backstop threshold. You can check the current backstop threshold requirements by running the `get-backstop-threshold.ts` script. The script has the following parameters defined as constants:

- `network` - The name of the network to deploy the pool on. Valid options are `mainnet`, `testnet`, or `local`.
- `user` - Any account that has funds on mainnet. The accounts secret key must be defined in the `.env` file.
  EX: ME=S.....

To run the script, use the following command:

```bash
node ./lib/v2/user-scripts/get-backstop-threshold.js <NETWORK-NAME> <USER>
```

The script will log the required lp tokens to meet the backstop threshold as well as the blend and usdc requirements for a balanced deposit, a solo BLND deposit, and a solo USDC deposit.

## Minting Liquidity Pool Tokens

The Blend backstop contract accepts deposits of BLND:USDC LP tokens to fund the deployed pool's backstop. You can mint these tokens by procuring blend, usdc, or both and calling the `mint-lp.ts` script. The script has the following parameters defined as constants:

- `blnd_max` - The maximum amount of BLND that can be deposited into the liquidity pool. This parameter is not used if the `deposit_asset` isn't `0` or `2`.
- `usdc_max` - The maximum amount of USDC that can be deposited into the liquidity pool. This parameter is not used if the `deposit_asset` isn't `1` or `2`.

and takes the following arguments:

- `network` - The name of the network to deploy the pool on. Valid options are `mainnet`, `testnet`, or `local`.
- `user` - The user that will be depositing the assets into the liquidity pool. The accounts secret key must be defined in the `.env` file.
  EX: ME=S.....
- `deposit_asset` - The asset that will be deposited into the BLND:USDC pool to fund the deployed pool's backstop. `0` denotes BLND, `1` denotes USDC, and `2` denotes a balanced deposit of both BLND and USDC.
- `mint_amount` - The number of liquidity pool tokens to mint for the user. This is number seven decimal places and should be input as a fixed point number (so 1.2345678 should be input as 12345678).

To run the script, use the following command:

```bash
node ./lib/v2/user-scripts/mint-lp.js <NETWORK-NAME> <USER> <DEPOSIT-ASSET> <MINT-AMOUNT>
```

## Depositing into the pools Backstop

The Blend backstop contract accepts deposits of BLND:USDC LP tokens to fund the deployed pool's backstop. Funding a pool's backstop is required in order to add the pool to the reward zone or enable it.
You can deposit these tokens by calling the `fund-backstop.ts` script. The script takes the following arguments:

- `network` - The name of the network to deploy the pool on. Valid options are `mainnet`, `testnet`, or `local`.
- `user` - Any account that has funds on mainnet. The accounts secret key must be defined in the `.env` file.
  EX: ME=S.....
- `pool` - The name of the pool to fund the backstop of.
- `amount` - The amount of BLND:USDC LP tokens to deposit into the backstop. This is number seven decimal places and should be input as a fixed point number (so 1.2345678 should be input as 12345678).

To run the script, use the following command:

```bash
node ./lib/v2/user-scripts/fund-backstop.js <NETWORK-NAME> <USER> <POOL> <AMOUNT>
```

- `starting_status` - The initial status the admin wishes to set for the pool. The status can be one of the following: `0` for `Admin-Active`, `2` for `Admin-On-Ice`, `3` for `On-Ice`, and `4` for `Admin-Frozen`. For more information on pool status see: https://docs.blend.capital/tech-docs/core-contracts/lending-pool/pool-management
- `add_to_reward_zone` - A boolean value that determines whether the pool is added to the reward zone. If `true`, the pool will be added to the reward zone. If `false`, the pool will not be added to the reward zone.
- `pool_to_remove` - The name of the pool to remove from the reward zone. This parameter is only used if `add_to_reward_zone` is `true`.

After setting the constants, the user can run the `deploy-pool` script to deploy the pool.

```bash
node ./lib/user-scripts/deploy-pool.js network_name
```

## Setting Pool Status

For owned pools, admins can set the pool status by calling the `set-status.ts` script. The script takes the following arguments:

- `network` - The name of the network to deploy the pool on. Valid options are `mainnet`, `testnet`, or `local`.
- `user` - Must be the pool admin. The accounts secret key must be defined in the `.env` file.
  EX: ADMIN=S.....
- `pool` - The name of the pool to set the status of.
- `status` - The status to set the pool to.
  - Status values:
    - 0 = Active
    - 2 = Admin On Ice
    - 3 = On Ice
    - 4 = Admin Frozen

To run the script, use the following command:

```bash
node ./lib/v2/user-scripts/set-status.js <NETWORK-NAME> <ADMIN> <POOL> <STATUS>
```

## Updating Pool Status

For non-owned pools, the pool admin can update the pool status by calling the `update-status.ts` script. The script takes the following arguments:

- `network` - The name of the network to deploy the pool on. Valid options are `mainnet`, `testnet`, or `local`.
- `user` - Any account that has funds on mainnet. The accounts secret key must be defined in the `.env` file.
  EX: ME=S.....
- `pool` - The name of the pool to update the status of.

To run the script, use the following command:

```bash
node ./lib/v2/user-scripts/update-status.js <NETWORK-NAME> <USER> <POOL>
```

## Adding a Pool to the Reward Zone

Add or replace pools in the reward zone using the `reward-zone-add` script. The script takes the following arguments:

- `network`: Network to run on (`mainnet`, `testnet`, `local`)
- `user`: User from config with admin privileges
- `pool_to_add`: Name of pool to add
- `pool_to_remove`: (Optional) Name of pool to replace

To run the script, use the following command:

```bash
node ./lib/v2/user-scripts/reward-zone-add.js <NETWORK-NAME> <USER> <POOL-TO-ADD> [POOL-TO-REMOVE]
```

## Revoking Pool Admin

For owned pools, admins can permanently revoke admin access by calling the `revoke-admin` script. This transfers ownership to a new account and revokes its signing power, making the pool immutable.

### Usage

```bash
node ./lib/v2/user-scripts/revoke-admin.js <NETWORK-NAME> <POOL-NAME>
```

### Parameters

- `network`: Network to run on (`mainnet`, `testnet`, `local`)
- `pool_name`: Name of pool to revoke admin for

## Docker

To setup a local network instance run

```
docker build . \
 --tag soroban-protocol:20 \
 --force-rm \
 --rm
```

```
sh quickstart.sh local
```
