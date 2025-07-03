import { config } from '../../utils/env_config.js';
import { signWithKeypair, TxParams } from '../../utils/tx.js';
import { setPrice } from './oracle.js';

const adminTxParams: TxParams = {
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

if (process.argv.length < 5) {
  throw new Error('Arguments required (in decimal): `network` `VOL` `HIGH_INT` `NO_COL`');
}

const vol_price = Number(process.argv[3]);
const high_int_price = Number(process.argv[4]);
const no_col_price = Number(process.argv[5]);
if (isNaN(vol_price) || isNaN(high_int_price) || isNaN(no_col_price)) {
  throw new Error('Invalid price arguments');
}

await setPrice(adminTxParams, vol_price, high_int_price, no_col_price);
