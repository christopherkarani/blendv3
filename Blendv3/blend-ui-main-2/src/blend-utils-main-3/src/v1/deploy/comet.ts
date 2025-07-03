import { Address, scValToNative, xdr } from '@stellar/stellar-sdk';
import { randomBytes } from 'crypto';
import { CometContract, CometFactoryContract } from '../../external/comet.js';
import { addressBook } from '../../utils/address-book.js';
import { config } from '../../utils/env_config.js';
import { TxParams, invokeSorobanOperation } from '../../utils/tx.js';

export async function deployComet(
  cometFactory: CometFactoryContract,
  txParams: TxParams,
  tokens: string[],
  weights: bigint[],
  balances: bigint[],
  swap_fee: bigint,
  nullAddress: string
): Promise<CometContract> {
  const comet = await invokeSorobanOperation<Address>(
    cometFactory.newCometPool(
      randomBytes(32),
      config.admin.publicKey(),
      tokens,
      weights,
      balances,
      swap_fee
    ),
    (result: string) => scValToNative(xdr.ScVal.fromXDR(result, 'base64')) as Address,
    txParams
  );
  if (!comet) {
    throw new Error('Failed to deploy Comet contract.');
  }
  const cometContract = new CometContract(comet.toString());
  // revoke controller
  await invokeSorobanOperation<Address>(
    cometContract.setController(nullAddress),
    (result: string) => scValToNative(xdr.ScVal.fromXDR(result, 'base64')) as Address,
    txParams
  );

  addressBook.setContractId('comet', comet.toString());
  addressBook.writeToFile();
  console.log('Successfully deployed Comet contract.\n');
  return cometContract;
}
