import { PoolContractV2, Request, RequestType } from '@blend-capital/blend-sdk';
import { Asset } from '@stellar/stellar-sdk';
import { TokenContract } from '../../external/token.js';
import { AddressBook, addressBook } from '../../utils/address-book.js';
import { airdropAccount } from '../../utils/contract.js';
import { config } from '../../utils/env_config.js';
import {
  TxParams,
  invokeClassicOp,
  invokeSorobanOperation,
  signWithKeypair,
} from '../../utils/tx.js';

async function submit(addressBook: AddressBook) {
  const txParams: TxParams = {
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

  const whale = config.getUser('OLDWHALE');
  console.log('OLDWHALE: ', whale.publicKey());
  await airdropAccount(whale);
  const usdc_token = new TokenContract(
    addressBook.getContractId('USDC'),
    new Asset('USDC', config.admin.publicKey())
  );
  await invokeClassicOp(usdc_token.classic_trustline(whale.publicKey()), txParams);
  await invokeClassicOp(usdc_token.classic_mint(whale.publicKey(), '100000'), txParams);

  const signWithWhale = (txXdr: string) => signWithKeypair(txXdr, config.passphrase, whale);

  const stellarPool = new PoolContractV2(addressBook.getContractId('Stellar'));

  const stellarRequests: Request[] = [
    {
      amount: BigInt(1e7),
      request_type: RequestType.SupplyCollateral,
      address: addressBook.getContractId('USDC'),
    },
    {
      amount: BigInt(10e7),
      request_type: RequestType.Borrow,
      address: addressBook.getContractId('XLM'),
    },
  ];

  txParams.account = await config.rpc.getAccount(whale.publicKey());
  txParams.signerFunction = signWithWhale;
  await invokeSorobanOperation(
    stellarPool.submit({
      from: whale.publicKey(),
      spender: whale.publicKey(),
      to: whale.publicKey(),
      requests: stellarRequests,
    }),
    PoolContractV2.parsers.submit,
    txParams
  );
}

await submit(addressBook);
