import { CometContract } from '../../external/comet.js';
import { addressBook } from '../../utils/address-book.js';
import { config } from '../../utils/env_config.js';
import { TxParams, invokeSorobanOperation, signWithKeypair } from '../../utils/tx.js';

/**
 * Mint Comet LP tokens using BLND, USDC, or both
 * Deposit types:
 * 0 = BLND only
 * 1 = USDC only
 * 2 = Both BLND and USDC
 *
 * example: node ./lib/user-scripts/mint-lp.js testnet admin 2 60000e7
 */

if (process.argv.length < 5) {
  throw new Error('Arguments required: `network` `user` `deposit_type` `mint_amount`');
}

const user = config.getUser(process.argv[3]);
const deposit_type = BigInt(process.argv[4]);
const mint_amount = BigInt(process.argv[5]);

// Constants for max deposits
const blnd_max = BigInt(9_000_000e7);
const usdc_max = BigInt(100_000e7);

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

await mintLP(deposit_type, mint_amount, txParams);

async function mintLP(deposit_type: bigint, mint_amount: bigint, txParams: TxParams) {
  const comet = new CometContract(addressBook.getContractId('comet'));

  if (deposit_type === BigInt(0)) {
    // Mint LP with BLND only
    await invokeSorobanOperation(
      comet.deposit_single_max_in(
        addressBook.getContractId('BLND'),
        blnd_max,
        mint_amount,
        txParams.account.accountId()
      ),
      () => undefined,
      txParams
    );
    console.log(`Minted ${mint_amount} LP tokens using BLND`);
  } else if (deposit_type === BigInt(1)) {
    // Mint LP with USDC only
    await invokeSorobanOperation(
      comet.deposit_single_max_in(
        addressBook.getContractId('USDC'),
        usdc_max,
        mint_amount,
        txParams.account.accountId()
      ),
      () => undefined,
      txParams
    );
    console.log(`Minted ${mint_amount} LP tokens using USDC`);
  } else {
    // Mint LP with both BLND and USDC
    await invokeSorobanOperation(
      comet.joinPool(mint_amount, [blnd_max, usdc_max], txParams.account.accountId()),
      () => undefined,
      txParams
    );
    console.log(`Minted ${mint_amount} LP tokens using both BLND and USDC`);
  }
}
