import { DeployV1Args, PoolContractV1, PoolFactoryContractV1 } from '@blend-capital/blend-sdk';
import { addressBook } from '../../utils/address-book.js';
import { bumpContractInstance } from '../../utils/contract.js';
import { TxParams, invokeSorobanOperation } from '../../utils/tx.js';

export async function setupPool(
  deployPoolArgs: DeployV1Args,
  txParams: TxParams
): Promise<PoolContractV1> {
  const poolFactory = new PoolFactoryContractV1(addressBook.getContractId('poolFactory'));
  const poolAddress = await invokeSorobanOperation(
    poolFactory.deployPool(deployPoolArgs),
    PoolFactoryContractV1.parsers.deployPool,
    txParams
  );
  if (!poolAddress) {
    throw new Error('Failed to deploy pool');
  }
  addressBook.setContractId(deployPoolArgs.name, poolAddress);
  addressBook.writeToFile();
  await bumpContractInstance(deployPoolArgs.name, txParams);
  console.log(`Successfully deployed ${deployPoolArgs.name} pool.\n`);
  return new PoolContractV1(poolAddress);
}
