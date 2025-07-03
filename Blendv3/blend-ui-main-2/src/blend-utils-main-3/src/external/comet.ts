import { Address, Contract, nativeToScVal, xdr } from '@stellar/stellar-sdk';

export class CometFactoryContract extends Contract {
  public init(comet_hash: Buffer): string {
    const invokeArgs = {
      method: 'init',
      args: [((i) => xdr.ScVal.scvBytes(i))(comet_hash)],
    };
    return this.call(invokeArgs.method, ...invokeArgs.args).toXDR('base64');
  }

  public newCometPool(
    salt: Buffer,
    user: string,
    tokens: Array<string>,
    weights: Array<bigint>,
    balances: Array<bigint>,
    swap_fee: bigint
  ): string {
    const invokeArgs = {
      method: 'new_c_pool',
      args: [
        ((i) => xdr.ScVal.scvBytes(i))(salt),
        ((i) => Address.fromString(i).toScVal())(user),
        ((i) => xdr.ScVal.scvVec(i.map((i) => Address.fromString(i).toScVal())))(tokens),
        ((i) => xdr.ScVal.scvVec(i.map((i) => nativeToScVal(i, { type: 'i128' }))))(weights),
        ((i) => xdr.ScVal.scvVec(i.map((i) => nativeToScVal(i, { type: 'i128' }))))(balances),
        ((i) => nativeToScVal(i, { type: 'i128' }))(swap_fee),
      ],
    };
    return this.call(invokeArgs.method, ...invokeArgs.args).toXDR('base64');
  }
}

export class CometContract extends Contract {
  constructor(address: string) {
    super(address);
  }

  public joinPool(pool_amount_out: bigint, max_amounts_in: Array<bigint>, user: string) {
    const invokeArgs = {
      method: 'join_pool',
      args: [
        ((i) => nativeToScVal(i, { type: 'i128' }))(pool_amount_out),
        ((i) => xdr.ScVal.scvVec(i.map((i) => nativeToScVal(i, { type: 'i128' }))))(max_amounts_in),
        ((i) => Address.fromString(i).toScVal())(user),
      ],
    };
    return this.call(invokeArgs.method, ...invokeArgs.args).toXDR('base64');
  }

  public deposit_single_max_in(
    token_in: string,
    pool_amount_out: bigint,
    max_amount_in: bigint,
    user: string
  ) {
    const invokeArgs = {
      method: 'dep_lp_tokn_amt_out_get_tokn_in',
      args: [
        ((i) => Address.fromString(i).toScVal())(token_in),
        ((i) => nativeToScVal(i, { type: 'i128' }))(pool_amount_out),
        ((i) => nativeToScVal(i, { type: 'i128' }))(max_amount_in),
        ((i) => Address.fromString(i).toScVal())(user),
      ],
    };
    return this.call(invokeArgs.method, ...invokeArgs.args).toXDR('base64');
  }

  public setController(manager: string) {
    const invokeArgs = {
      method: 'set_controller',
      args: [((i) => Address.fromString(i).toScVal())(manager)],
    };
    return this.call(invokeArgs.method, ...invokeArgs.args).toXDR('base64');
  }

  public getTotalSupply() {
    const invokeArgs = {
      method: 'get_total_supply',
      args: [],
    };
    return this.call(invokeArgs.method, ...invokeArgs.args).toXDR('base64');
  }
}
