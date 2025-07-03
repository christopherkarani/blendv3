import { BackstopContractV2 } from '@blend-capital/blend-sdk';
import { addressBook } from '../../utils/address-book.js';
import { config } from '../../utils/env_config.js';
import { TxParams, invokeSorobanOperation, signWithKeypair } from '../../utils/tx.js';

/**
 * Add a pool to the reward zone, optionally replacing an existing pool
 *
 * example: node ./lib/user-scripts/reward-zone-add.js testnet admin PairTrade Stellar
 * example (no replacement): node ./lib/user-scripts/reward-zone-add.js testnet admin PairTrade
 */

if (process.argv.length < 4) {
  throw new Error('Arguments required: `network` `user` `pool_to_add` `pool_to_remove`(Optional)');
}

const user = config.getUser(process.argv[3]);
const poolToAdd = process.argv[4];
const poolToRemove = process.argv[5];

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

await addToRewardZone(poolToAdd, poolToRemove, txParams);

async function addToRewardZone(
  poolToAdd: string,
  poolToRemove: string | undefined,
  txParams: TxParams
) {
  const backstop = new BackstopContractV2(addressBook.getContractId('backstopV2'));
  await invokeSorobanOperation(
    backstop.addReward(
      addressBook.getContractId(poolToAdd),
      poolToRemove ? addressBook.getContractId(poolToRemove) : undefined
    ),
    BackstopContractV2.parsers.addReward,
    txParams
  );

  if (poolToRemove) {
    console.log(`Added ${poolToAdd} to reward zone, replacing ${poolToRemove}`);
  } else {
    console.log(`Added ${poolToAdd} to reward zone`);
  }
}
