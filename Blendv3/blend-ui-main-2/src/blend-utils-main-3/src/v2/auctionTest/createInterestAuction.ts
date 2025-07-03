import { Address } from '@stellar/stellar-sdk';
import { addressBook } from '../../utils/address-book.js';
import { createInterestAuction } from './auctions.js';
import { config } from '../../utils/env_config.js';
import { signWithKeypair } from '../../utils/tx.js';

if (process.argv.length < 6) {
  throw new Error(
    'Arguments required (in decimal): `network` `account name` `pool name` `lot assets`'
  );
}
const keypair = config.getUser(process.argv[3]);
const pool = addressBook.getContractId(process.argv[4]);
const assets: string[] = JSON.parse(process.argv[5]);
assets.forEach((asset, index) => (assets[index] = addressBook.getContractId(asset)));

try {
  Address.fromString(pool);
} catch (e) {
  throw new Error('Invalid pool id');
}

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
await createInterestAuction(txParams, pool, assets);
