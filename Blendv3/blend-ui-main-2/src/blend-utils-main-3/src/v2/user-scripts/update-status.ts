import { PoolContractV2 } from '@blend-capital/blend-sdk';
import { addressBook } from '../../utils/address-book.js';
import { config } from '../../utils/env_config.js';
import { TxParams, invokeSorobanOperation, signWithKeypair } from '../../utils/tx.js';

/**
 * Update the status of a Blend lending pool
 * this script will update the pool status permissionlessly based on the pools current backstop state
 */

if (process.argv.length < 4) {
  throw new Error('Arguments required: `network` `user` `pool`');
}

const user = config.getUser(process.argv[3]);
const poolName = process.argv[4];

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

await updateStatus(poolName, txParams);

async function updateStatus(poolName: string, txParams: TxParams) {
  const pool = new PoolContractV2(addressBook.getContractId(poolName));
  await invokeSorobanOperation(pool.updateStatus(), PoolContractV2.parsers.updateStatus, txParams);
  console.log(`Updated ${poolName} pool status`);
}
