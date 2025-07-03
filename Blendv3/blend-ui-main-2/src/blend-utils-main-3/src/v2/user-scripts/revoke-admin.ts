import { PoolContractV2 } from '@blend-capital/blend-sdk';
import { Operation } from '@stellar/stellar-sdk';

import { addressBook } from '../../utils/address-book.js';
import { airdropAccount } from '../../utils/contract.js';
import { config } from '../../utils/env_config.js';
import {
  TxParams,
  invokeClassicOp,
  invokeSorobanOperation,
  signWithKeypair,
} from '../../utils/tx.js';

/**
 * Revoke a pool's admin by transferring ownership to a new account and revoking its signing power
 * example: node ./lib/user-scripts/revoke-admin.js testnet PairTrade
 */

if (process.argv.length < 4) {
  throw new Error('Arguments required: `network` `pool_name`, `new_admin`');
}

async function revokeAdmin() {
  const pool_name = process.argv[3];
  const network = process.argv[2];
  const poolAddress = addressBook.getContractId(pool_name);
  const newAdmin = config.getUser(process.argv[4]);

  const txParams: TxParams = {
    account: await config.rpc.getAccount(config.admin.publicKey()),
    txBuilderOptions: {
      fee: '10000',
      timebounds: { minTime: 0, maxTime: 0 },
      networkPassphrase: config.passphrase,
    },
    signerFunction: async (txXDR: string) => {
      return signWithKeypair(txXDR, config.passphrase, config.admin);
    },
  };

  if (network !== 'mainnet') {
    await airdropAccount(newAdmin);
  }
  const pool = new PoolContractV2(poolAddress);

  //propose new admin
  await invokeSorobanOperation(
    pool.proposeAdmin(newAdmin.publicKey()),
    PoolContractV2.parsers.proposeAdmin,
    txParams
  );
  console.log(`Proposed ${newAdmin.publicKey()} as new admin`);

  //accept new admin
  const newAdminTxParams: TxParams = {
    ...txParams,
    account: await config.rpc.getAccount(newAdmin.publicKey()),
  };
  await invokeSorobanOperation(
    pool.acceptAdmin(),
    PoolContractV2.parsers.acceptAdmin,
    newAdminTxParams
  );

  // revoke new admin signing power
  const revokeOp = Operation.setOptions({
    masterWeight: 0,
  });
  txParams.account = await config.rpc.getAccount(newAdmin.publicKey());
  txParams.signerFunction = async (txXDR: string) => {
    return signWithKeypair(txXDR, config.passphrase, newAdmin);
  };
  await invokeClassicOp(revokeOp.toXDR('base64'), txParams);
}

await revokeAdmin();
