import {
  AuctionData,
  AuctionType,
  BackstopToken,
  FixedMath,
  Pool,
  PoolOracle,
} from '@blend-capital/blend-sdk';

export function calculateAuctionOracleProfit(
  auction: AuctionData,
  type: AuctionType,
  pool: Pool,
  oracle: PoolOracle,
  backstopToken: BackstopToken
):
  | {
      lot: Map<string, number>;
      bid: Map<string, number>;
      totalLotValue: number;
      totalBidValue: number;
    }
  | undefined {
  let lot = new Map<string, number>();
  let bid = new Map<string, number>();
  let totalLotValue = 0;
  let totalBidValue = 0;

  for (const [asset, amount] of Array.from(auction.lot.entries())) {
    let reserve = pool.reserves.get(asset);
    let price = oracle.getPriceFloat(asset);
    switch (type) {
      case AuctionType.BadDebt:
        const lotValue = FixedMath.toFloat(amount, 7) * backstopToken.lpTokenPrice;
        lot.set(asset, lotValue);
        totalLotValue += lotValue;
        break;
      case AuctionType.Interest:
        if (reserve === undefined || price === undefined) {
          return undefined;
        } else {
          const lotValue = FixedMath.toFloat(amount, reserve.config.decimals) * price;
          lot.set(asset, lotValue);
          totalLotValue += lotValue;
        }
        break;
      case AuctionType.Liquidation:
        if (reserve === undefined || price === undefined) {
          return undefined;
        } else {
          const lotValue = reserve.toAssetFromBTokenFloat(amount) * price;
          lot.set(asset, lotValue);
          totalLotValue += lotValue;
        }
    }
  }
  for (const [asset, amount] of Array.from(auction.bid.entries())) {
    switch (type) {
      case AuctionType.Interest:
        const bidValue = FixedMath.toFloat(amount, 7) * backstopToken.lpTokenPrice;
        bid.set(asset, bidValue);
        totalBidValue += bidValue;
        break;
      default:
        const reserve = pool.reserves.get(asset);
        const price = oracle.getPriceFloat(asset);
        if (reserve === undefined || price === undefined) {
          return undefined;
        } else {
          const bidValue = reserve.toAssetFromDTokenFloat(amount) * price;
          bid.set(asset, bidValue);
          totalBidValue += bidValue;
        }
    }
  }
  return {
    totalBidValue,
    totalLotValue,
    lot,
    bid,
  };
}
