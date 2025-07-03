import { DeployV2Args, PoolContractV2, PoolFactoryContractV2 } from '@blend-capital/blend-sdk';
import { addressBook } from '../../utils/address-book.js';
import { bumpContractInstance } from '../../utils/contract.js';
import { TxParams, invokeSorobanOperation } from '../../utils/tx.js';

export async function setupPool(
  deployPoolArgs: DeployV2Args,
  txParams: TxParams
): Promise<PoolContractV2> {
  const poolFactory = new PoolFactoryContractV2(addressBook.getContractId('poolFactoryV2'));
  const poolAddress = await invokeSorobanOperation(
    poolFactory.deployPool(deployPoolArgs),
    PoolFactoryContractV2.parsers.deployPool,
    txParams
  );
  if (!poolAddress) {
    throw new Error('Failed to deploy pool');
  }
  addressBook.setContractId(deployPoolArgs.name, poolAddress);
  addressBook.writeToFile();
  await bumpContractInstance(deployPoolArgs.name, txParams);
  console.log(`Successfully deployed ${deployPoolArgs.name} pool.\n`);
  return new PoolContractV2(poolAddress);
}
