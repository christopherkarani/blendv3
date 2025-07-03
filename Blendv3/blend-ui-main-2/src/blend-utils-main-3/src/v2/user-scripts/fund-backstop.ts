import { BackstopContractV2 } from '@blend-capital/blend-sdk';
import { addressBook } from '../../utils/address-book.js';
import { config } from '../../utils/env_config.js';
import { TxParams, invokeSorobanOperation, signWithKeypair } from '../../utils/tx.js';

/**
 * Deposit LP tokens into a specific pool's backstop
 *
 * example: node ./lib/user-scripts/fund-backstop.js testnet admin PairTrade 60000e7
 */

if (process.argv.length < 5) {
  throw new Error('Arguments required: `network` `user` `pool` `amount`');
}

const user = config.getUser(process.argv[3]);
const poolName = process.argv[4];
const amount = BigInt(process.argv[5]);

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

await fundBackstop(poolName, amount, txParams);

async function fundBackstop(poolName: string, amount: bigint, txParams: TxParams) {
  const backstop = new BackstopContractV2(addressBook.getContractId('backstopV2'));
  await invokeSorobanOperation(
    backstop.deposit({
      from: txParams.account.accountId(),
      pool_address: addressBook.getContractId(poolName),
      amount: amount,
    }),
    BackstopContractV2.parsers.deposit,
    txParams
  );
  console.log(`Deposited ${amount} LP tokens into ${poolName} backstop`);
}
