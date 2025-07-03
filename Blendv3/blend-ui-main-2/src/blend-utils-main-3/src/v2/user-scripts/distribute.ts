import { BackstopContractV2, EmitterContract, PoolContractV2 } from '@blend-capital/blend-sdk';
import { addressBook } from '../../utils/address-book.js';
import { config } from '../../utils/env_config.js';
import { TxParams, invokeSorobanOperation, signWithKeypair } from '../../utils/tx.js';

/**
 * Distribute emissions to pools and backstop
 * example: node ./lib/user-scripts/distribute.js testnet user1 '["pool1","pool2"]' true
 *
 * Distribute emissions to just pools
 * example: node ./lib/user-scripts/distribute.js testnet user1 '["pool1","pool2"]' false
 */

if (process.argv.length < 4) {
  throw new Error(
    'Arguments required: `network` `user` `pools` `includeBackstop`(Optional Argument Default: true)'
  );
}

const user = config.getUser(process.argv[3]);
const pools = (JSON.parse(process.argv[4]) as string[]).map((pool) =>
  addressBook.getContractId(pool)
);
const includeBackstop = process.argv[5] === undefined ? true : process.argv[5] === 'true';

const txParams: TxParams = {
  account: await config.rpc.getAccount(user.publicKey()),
  txBuilderOptions: {
    fee: '10000',
    timebounds: {
      minTime: 0,
      maxTime: 0,
    },
    networkPassphrase: config.passphrase,
  },
  signerFunction: async (txXDR: string) => {
    return signWithKeypair(txXDR, config.passphrase, user);
  },
};
// The name of the pool in the address book

await distribute(pools, includeBackstop, txParams);

export async function distribute(pools: string[], includeBackstop: boolean, txParams: TxParams) {
  const emitter = new EmitterContract(addressBook.getContractId('emitter'));
  await invokeSorobanOperation(emitter.distribute(), EmitterContract.parsers.distribute, txParams);
  console.log('Emitter distributed');

  if (includeBackstop) {
    const backstop = new BackstopContractV2(addressBook.getContractId('backstop'));
    await invokeSorobanOperation(
      backstop.distribute(),
      BackstopContractV2.parsers.distribute,
      txParams
    );
    console.log('Backstop gulped');
  }

  for (const poolId of pools) {
    const pool = new PoolContractV2(poolId);
    await invokeSorobanOperation(
      pool.gulpEmissions(),
      PoolContractV2.parsers.gulpEmissions,
      txParams
    );
    console.log(`Gulped Pool with ID: ${poolId}`);
  }
}
