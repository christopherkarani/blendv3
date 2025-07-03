import { PoolContractV1, SetReserveArgs } from '@blend-capital/blend-sdk';
import { TxParams, invokeSorobanOperation } from '../../utils/tx.js';

export async function setupReserve(
  poolAddress: string,
  initReserveArgs: SetReserveArgs,
  txParams: TxParams
) {
  const pool = new PoolContractV1(poolAddress);

  await invokeSorobanOperation(
    pool.queueSetReserve(initReserveArgs),
    PoolContractV1.parsers.queueSetReserve,
    txParams
  );

  // @DEV Setting reserve can fail if the queue time not reached
  try {
    await invokeSorobanOperation(
      pool.setReserve(initReserveArgs.asset),
      PoolContractV1.parsers.setReserve,
      txParams
    );
    console.log(`Successfully set ${initReserveArgs.asset} reserve.\n`);
  } catch (e) {
    console.log('Reserve not set', e);
  }
}
