import {
  BackstopToken,
  FixedMath,
  Reserve,
  ReserveData,
  ReserveV1,
  ReserveV2,
} from '@blend-capital/blend-sdk';

/**
 * Estimate the emissions apr for a reserve
 * @param emissionsPerAsset emissions per asset per year as a float
 * @param backstopToken backstop token
 * @param assetPrice asset price
 */
export function estimateEmissionsApr(
  emissionsPerAssetPerYear: number,
  backstopToken: BackstopToken,
  assetPrice: number
): number {
  const usdcPerBlnd =
    FixedMath.toFloat(backstopToken.usdc, 7) /
    0.2 /
    (FixedMath.toFloat(backstopToken.blnd, 7) / 0.8);
  return (emissionsPerAssetPerYear * usdcPerBlnd) / assetPrice;
}

/**
 * Estimate the interest rate for a reserve given a utilization ratio
 * @param util utilization ratio as a float
 * @param ir_mod interest rate modifier as a float
 * @param reserve The reserve to estimate the interest rate for
 * @param backstopTakeRate The backstop take rate as a fixed point number
 */
export function estimateInterestRate(
  util: number,
  ir_mod: number,
  reserve: Reserve,
  backstopTakeRate: bigint
): number {
  const RATE_SCALAR = FixedMath.toFixed(1, reserve.rateDecimals);
  // setup reserve with util and ir_mod
  let ir_resData = new ReserveData(
    RATE_SCALAR,
    RATE_SCALAR,
    FixedMath.toFixed(ir_mod, reserve.irmodDecimals),
    FixedMath.toFixed(util, reserve.config.decimals),
    FixedMath.toFixed(1, reserve.config.decimals),
    BigInt(0),
    0
  );
  let ir_reserve =
    reserve.rateDecimals === 9
      ? new ReserveV1('', '', reserve.config, ir_resData, undefined, undefined, 0, 0, 0, 0, 0)
      : new ReserveV2('', '', reserve.config, ir_resData, undefined, undefined, 0, 0, 0, 0, 0);
  ir_reserve.setRates(backstopTakeRate);
  return ir_reserve.borrowApr;
}
