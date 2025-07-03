import { PoolContractV2, PoolV2, PositionsEstimate, AuctionType } from '@blend-capital/blend-sdk';
import { config } from '../../utils/env_config.js';
import { invokeSorobanOperation, TxParams } from '../../utils/tx.js';
import { addressBook } from '../../utils/address-book.js';

export async function createUserLiquidation(
  txParams: TxParams,
  poolId: string,
  user: string,
  lot: string[],
  bid: string[],
  liquidation_percent: number | undefined
) {
  const pool = new PoolContractV2(poolId);
  const network = {
    rpc: config.rpc.serverURL.toString(),
    passphrase: config.passphrase,
    opts: { allowHttp: true },
  };
  const poolData = await PoolV2.load(network, poolId);
  const poolOracle = await poolData.loadOracle();
  const userData = await poolData.loadUser(user);
  const userEst = PositionsEstimate.build(poolData, poolOracle, userData.positions);
  if (liquidation_percent === undefined) {
    const avgInverseLF = userEst.totalEffectiveLiabilities / userEst.totalBorrowed;
    const avgCF = userEst.totalEffectiveCollateral / userEst.totalSupplied;
    const estIncentive = 1 + (1 - avgCF / avgInverseLF) / 2;
    const numberator = userEst.totalEffectiveLiabilities * 1.1 - userEst.totalEffectiveCollateral;
    const denominator = avgInverseLF * 1.1 - avgCF * estIncentive;
    liquidation_percent = Math.round((numberator / denominator / userEst.totalBorrowed) * 100);
    if (liquidation_percent > 100) {
      liquidation_percent = 100;
    } else if (liquidation_percent < 0) {
      liquidation_percent = 0;
    }
  }
  await invokeSorobanOperation(
    pool.newAuction({
      auction_type: AuctionType.Liquidation,
      user: user,
      bid,
      lot,
      percent: liquidation_percent,
    }),
    PoolContractV2.parsers.newAuction,
    txParams
  );
}

export async function createBadDebtAuction(
  txParams: TxParams,
  poolId: string,
  bid: string[],
  percent = 100
) {
  const pool = new PoolContractV2(poolId);
  await invokeSorobanOperation(
    pool.newAuction({
      auction_type: AuctionType.BadDebt,
      user: addressBook.getContractId('backstopV2'),
      bid,
      lot: [addressBook.getContractId('comet')],
      percent,
    }),
    PoolContractV2.parsers.newAuction,
    txParams
  );
}

export async function createInterestAuction(
  txParams: TxParams,
  poolId: string,
  lot: string[],
  percent = 100
) {
  const pool = new PoolContractV2(poolId);
  await invokeSorobanOperation(
    pool.newAuction({
      auction_type: AuctionType.Interest,
      user: addressBook.getContractId('backstopV2'),
      bid: [addressBook.getContractId('comet')],
      lot,
      percent: percent,
    }),
    PoolContractV2.parsers.newAuction,
    txParams
  );
}
