import { PoolContractV1, PoolV1, PositionsEstimate } from '@blend-capital/blend-sdk';
import { config } from '../../utils/env_config.js';
import { invokeSorobanOperation, TxParams } from '../../utils/tx.js';

export async function createUserLiquidation(
  txParams: TxParams,
  poolId: string,
  user: string,
  liquidation_percent: bigint | undefined
) {
  const pool = new PoolContractV1(poolId);
  const network = {
    rpc: config.rpc.serverURL.toString(),
    passphrase: config.passphrase,
    opts: { allowHttp: true },
  };
  const poolData = await PoolV1.load(network, poolId);
  const poolOracle = await poolData.loadOracle();
  const userData = await poolData.loadUser(user);
  const userEst = PositionsEstimate.build(poolData, poolOracle, userData.positions);
  if (liquidation_percent === undefined) {
    const avgInverseLF = userEst.totalEffectiveLiabilities / userEst.totalBorrowed;
    const avgCF = userEst.totalEffectiveCollateral / userEst.totalSupplied;
    const estIncentive = 1 + (1 - avgCF / avgInverseLF) / 2;
    const numberator = userEst.totalEffectiveLiabilities * 1.1 - userEst.totalEffectiveCollateral;
    const denominator = avgInverseLF * 1.1 - avgCF * estIncentive;
    liquidation_percent = BigInt(
      Math.round((numberator / denominator / userEst.totalBorrowed) * 100)
    );
    if (liquidation_percent > 100) {
      liquidation_percent = BigInt(100);
    } else if (liquidation_percent <= 0) {
      liquidation_percent = BigInt(0);
    } else {
      liquidation_percent = BigInt(liquidation_percent);
    }
  }
  await invokeSorobanOperation(
    pool.newLiquidationAuction({
      user,
      percent_liquidated: liquidation_percent,
    }),
    PoolContractV1.parsers.newLiquidationAuction,
    txParams
  );
}

export async function createBadDebtAuction(txParams: TxParams, poolId: string) {
  const pool = new PoolContractV1(poolId);
  await invokeSorobanOperation(pool.newBadDebtAuction(), PoolContractV1.parsers.badDebt, txParams);
}

export async function createInterestAuction(txParams: TxParams, poolId: string, assets: string[]) {
  const pool = new PoolContractV1(poolId);
  await invokeSorobanOperation(
    pool.newInterestAuction(assets),
    PoolContractV1.parsers.newInterestAuction,
    txParams
  );
}
