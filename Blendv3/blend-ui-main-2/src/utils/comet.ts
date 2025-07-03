import { BackstopToken, FixedMath } from '@blend-capital/blend-sdk';
import { Contract, nativeToScVal, xdr } from '@stellar/stellar-sdk';

/**
 * Estimate the amount of BLND and USDC that will be deposited into the pool during a join
 */
export function estJoinPool(
  pool_data: BackstopToken,
  toMint: bigint,
  maxSlippage: number
): { blnd: number; usdc: number } {
  const ratio = Number(pool_data.shares + toMint) / Number(pool_data.shares) - 1;
  let blnd = (Number(pool_data.blnd) / 1e7) * ratio * (1 + maxSlippage);
  let usdc = (Number(pool_data.usdc) / 1e7) * ratio * (1 + maxSlippage);
  return { blnd, usdc };
}

/**
 * Estimate the comet lp shares that will be minted during a single sided deposit
 * @param token - The token being deposited
 * @param backstopToken - The backstop token
 * @param amount - The amount being deposited
 */
export function estSingleSidedDeposit(
  token: 'blnd' | 'usdc',
  backstopToken: BackstopToken,
  amount: bigint
): number {
  let weight = token === 'blnd' ? 0.8 : 0.2;
  let swapFee = 0.03;
  let weightedFee = (1.0 - weight) * swapFee;
  let amountNetFees = FixedMath.toFloat(amount, 7) * (1.0 - weightedFee);
  let ratio =
    1.0 +
    amountNetFees /
      FixedMath.toFloat(token === 'blnd' ? backstopToken.blnd : backstopToken.usdc, 7);
  let weightedRatio = ratio ** weight - 1;
  return FixedMath.toFloat(backstopToken.shares, 7) * weightedRatio;
}

/**
 * Estimate the amount of BLND and USDC that will be deposited into the pool during a join
 */
export function estLPTokenViaJoin(
  pool_data: BackstopToken,
  blnd: bigint,
  usdc: bigint,
  maxSlippage: number
): number {
  // calc join amount with all blnd
  const blndNetSlippage = (Number(blnd) / 1e7) * (1 - maxSlippage);
  const blndRatio = blndNetSlippage / (Number(pool_data.blnd) / 1e7);
  const blndJoinAmount = blndRatio * (Number(pool_data.shares) / 1e7);
  // calc join amount with all usdc
  const usdcNetSlippage = (Number(usdc) / 1e7) * (1 - maxSlippage);
  const usdcRatio = usdcNetSlippage / (Number(pool_data.usdc) / 1e7);
  const usdcJoinAmount = usdcRatio * (Number(pool_data.shares) / 1e7);
  return Math.min(blndJoinAmount, usdcJoinAmount);
}

/**
 * Estimate the amount of BLND and USDC that will be withdrawn from the pool during an exit
 */
export function estExitPool(
  pool_data: BackstopToken,
  toBurn: bigint,
  maxSlippage: number
): { blnd: number; usdc: number } {
  const ratio = 1 - Number(pool_data.shares - toBurn) / Number(pool_data.shares);
  let blnd = (Number(pool_data.blnd) / 1e7) * ratio * (1 - maxSlippage);
  let usdc = (Number(pool_data.usdc) / 1e7) * ratio * (1 - maxSlippage);
  return { blnd, usdc };
}

export interface CometSingleSidedDepositArgs {
  depositTokenAddress: string;
  depositTokenAmount: bigint;
  minLPTokenAmount: bigint;
  user: string;
}

export interface CometLiquidityArgs {
  poolAmount: bigint;
  blndLimitAmount: bigint;
  usdcLimitAmount: bigint;
  user: string;
}

export class CometClient {
  comet: Contract;

  constructor(address: string) {
    this.comet = new Contract(address);
  }

  /**
   * Create a single sided deposit operation for the Comet pool
   * @param args - Arguments for the deposit operation
   * @returns - An XDR operation
   */
  public depositTokenInGetLPOut(args: CometSingleSidedDepositArgs): xdr.Operation {
    const invokeArgs = {
      method: 'dep_tokn_amt_in_get_lp_tokns_out',
      args: [
        nativeToScVal(args.depositTokenAddress, { type: 'address' }),
        nativeToScVal(args.depositTokenAmount, { type: 'i128' }),
        nativeToScVal(args.minLPTokenAmount, { type: 'i128' }),
        nativeToScVal(args.user, { type: 'address' }),
      ],
    };
    return this.comet.call(invokeArgs.method, ...invokeArgs.args);
  }

  /**
   * Create a join operation for the Comet pool
   * @param cometLiquidityArgs - Arguments for the join operation
   * @returns - An XDR operation
   */
  public join(args: CometLiquidityArgs): xdr.Operation {
    const invokeArgs = {
      method: 'join_pool',
      args: [
        nativeToScVal(args.poolAmount, { type: 'i128' }),
        nativeToScVal([args.blndLimitAmount, args.usdcLimitAmount], { type: 'i128' }),
        nativeToScVal(args.user, { type: 'address' }),
      ],
    };
    return this.comet.call(invokeArgs.method, ...invokeArgs.args);
  }

  /**
   * Create an exit operation for the Comet pool
   * @param cometLiquidityArgs - Arguments for the join operation
   * @returns - An XDR operation
   */
  public exit(args: CometLiquidityArgs): xdr.Operation {
    const invokeArgs = {
      method: 'exit_pool',
      args: [
        nativeToScVal(args.poolAmount, { type: 'i128' }),
        nativeToScVal([args.blndLimitAmount, args.usdcLimitAmount], { type: 'i128' }),
        nativeToScVal(args.user, { type: 'address' }),
      ],
    };
    return this.comet.call(invokeArgs.method, ...invokeArgs.args);
  }
}
