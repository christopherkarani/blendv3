import {
  I128MAX,
  PoolContractV2,
  ReserveConfigV2,
  ReserveEmissionMetadata,
} from '@blend-capital/blend-sdk';
import { randomBytes } from 'crypto';
import { setupPool } from '../pool/pool-setup.js';
import { setupReserve } from '../pool/reserve-setup.js';
import { addressBook } from '../../utils/address-book.js';
import { config } from '../../utils/env_config.js';
import { TxParams, invokeSorobanOperation, signWithKeypair } from '../../utils/tx.js';

/**
 * Deploy a pool with the following parameters (Parameters can be changed as needed)
 * example: node ./lib/user-scripts/deploy-pool.js testnet true
 */

if (process.argv.length < 3) {
  throw new Error('Arguments required: `network`');
}

const txParams: TxParams = {
  account: await config.rpc.getAccount(config.admin.publicKey()),
  txBuilderOptions: {
    fee: '10000',
    timebounds: {
      minTime: 0,
      maxTime: 0,
    },
    networkPassphrase: config.passphrase,
  },
  signerFunction: async (txXDR: string) => {
    return signWithKeypair(txXDR, config.passphrase, config.admin);
  },
};

/// Deployment Constants
const pool_name = 'PairTrade';
const backstop_take_rate = 0.5e7;
const max_positions = 2;
const min_collateral = BigInt(0); // Set to 0 for no minimum collateral requirement
const reserves = ['XLM', 'wBTC'];
const reserve_configs: ReserveConfigV2[] = [
  {
    index: 0, // Does not matter
    decimals: 7,
    c_factor: 980_0000, // (0_9800000)
    l_factor: 980_0000, // (0_9800000)
    util: 900_0000, // (0_9000000) must be under 950_0000
    max_util: 980_0000, // (0_9800000) must be greater than util
    r_base: 50000, // (0_0050000)
    r_one: 500000, // (0_0500000)
    r_two: 1000000, // (0_1000000)
    r_three: 1_0000000,
    reactivity: 1000, // must be 1000 or under
    supply_cap: I128MAX,
    enabled: true,
  },
  {
    index: 0,
    decimals: 7,
    c_factor: 980_0000, // (0_9800000)
    l_factor: 980_0000, // (0_9800000)
    util: 900_0000, // (0_9000000)
    max_util: 980_0000, // (0_9800000)
    r_base: 50000, // (0_0050000)
    r_one: 500000, // (0_0500000)
    r_two: 1000000, // (0_1000000)
    r_three: 1_0000000,
    reactivity: 1000,
    supply_cap: I128MAX,
    enabled: true,
  },
];
const poolEmissionMetadata: ReserveEmissionMetadata[] = [
  {
    res_index: 0, // first reserve
    res_type: 1, // 0 for borrow emissions : 1 for supply emissions
    share: BigInt(0.5e7), // Share of total emissions
  },
  {
    res_index: 1, // second reserve
    res_type: 1, // 0 for borrow emissions : 1 for supply emissions
    share: BigInt(0.5e7), // Share of total emissions
  },
];

async function deploy() {
  console.log('Deploy Pool\n');
  const poolSalt = randomBytes(32);

  const newPool = await setupPool(
    {
      admin: config.admin.publicKey(),
      name: pool_name,
      salt: poolSalt,
      oracle: addressBook.getContractId('oracle'),
      backstop_take_rate: backstop_take_rate,
      max_positions: max_positions,
      min_collateral: min_collateral,
    },
    txParams
  );

  console.log('Setup pool reserves and emissions\n');

  for (let i = 0; i < reserves.length; i++) {
    const reserve_name = reserves[i];
    const reserve_config = reserve_configs[i];
    await setupReserve(
      newPool.contractId(),
      {
        asset: addressBook.getContractId(reserve_name),
        metadata: reserve_config,
      },
      txParams
    );
  }

  await invokeSorobanOperation(
    newPool.setEmissionsConfig(poolEmissionMetadata),
    PoolContractV2.parsers.setEmissionsConfig,
    txParams
  );
}

await deploy();
