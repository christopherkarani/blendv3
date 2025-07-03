import { Address } from '@stellar/stellar-sdk';
import { addressBook } from '../../utils/address-book.js';
import { createUserLiquidation } from './auctions.js';
import { config } from '../../utils/env_config.js';
import { signWithKeypair } from '../../utils/tx.js';

if (process.argv.length < 7) {
  throw new Error(
    'Arguments required (in decimal): `network` `account name` `pool name` `user` `lot assets` `bid assets` `liquidation percent (optional)`'
  );
}
const keypair = config.getUser(process.argv[3]);
const pool = addressBook.getContractId(process.argv[4]);
const user = config.getUser(process.argv[5]);
const lot: string[] = JSON.parse(process.argv[6]);
lot.forEach((asset, index) => (lot[index] = addressBook.getContractId(asset)));
const bid: string[] = JSON.parse(process.argv[7]);
bid.forEach((asset, index) => (bid[index] = addressBook.getContractId(asset)));
const liquidationPercent = Number(process.argv[8]);

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
await createUserLiquidation(
  txParams,
  pool,
  user.publicKey(),
  lot,
  bid,
  !isNaN(liquidationPercent) && liquidationPercent > 0 ? liquidationPercent : undefined
);
