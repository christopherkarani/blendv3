import { PoolContractV2 } from '@blend-capital/blend-sdk';
import { addressBook } from '../../utils/address-book.js';
import { config } from '../../utils/env_config.js';
import { TxParams, invokeSorobanOperation, signWithKeypair } from '../../utils/tx.js';

/**
 * Set the status of a Blend lending pool
 * Status values:
 * 0 = Active
 * 2 = Admin On Ice
 * 3 = On Ice
 * 4 = Admin Frozen
 *
 * example: node ./lib/user-scripts/set-status.js testnet admin PairTrade 2
 */

if (process.argv.length < 5) {
  throw new Error('Arguments required: `network` `user` `pool` `status`');
}

const user = config.getUser(process.argv[3]);
const poolName = process.argv[4];
const status = parseInt(process.argv[5]);

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

await setStatus(poolName, status, txParams);

async function setStatus(poolName: string, status: number, txParams: TxParams) {
  const pool = new PoolContractV2(addressBook.getContractId(poolName));
  await invokeSorobanOperation(pool.setStatus(status), PoolContractV2.parsers.setStatus, txParams);
  console.log(`Set ${poolName} pool status to: ${status}`);
}
