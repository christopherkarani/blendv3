import { Address } from '@stellar/stellar-sdk';
import { addressBook } from '../../utils/address-book.js';
import { submit } from './user.js';
import { config } from '../../utils/env_config.js';
import { signWithKeypair } from '../../utils/tx.js';

if (process.argv.length < 8) {
  throw new Error(
    'Arguments required (in decimal): `network` `Tx submitter` `pool name` `asset name` `action` `amount`'
  );
}
const keypair = config.getUser(process.argv[3]);
const txParams = {
  account: await config.rpc.getAccount(keypair.publicKey()),
  txBuilderOptions: {
    fee: '10000',
    timebounds: {
      minTime: 0,
      maxTime: 0,
    },
    networkPassphrase: config.passphrase,
  },
  signerFunction: async (txXDR: string) => {
    return signWithKeypair(txXDR, config.passphrase, keypair);
  },
};
const pool = addressBook.getContractId(process.argv[4]);
const asset = addressBook.getContractId(process.argv[5]);
const action = Number(process.argv[6]);
const amount = Number(process.argv[7]);

try {
  Address.fromString(pool);
} catch (e) {
  throw new Error('Invalid pool id');
}
try {
  Address.fromString(asset);
} catch (e) {
  throw new Error('Invalid asset id');
}
if (isNaN(action) || action < 0 || action > 9) {
  throw new Error('Invalid action');
}
if (isNaN(amount) || amount <= 0) {
  throw new Error('Invalid amount');
}

const bigintAmount = BigInt(amount);
await submit(txParams, pool, asset, action, bigintAmount);
