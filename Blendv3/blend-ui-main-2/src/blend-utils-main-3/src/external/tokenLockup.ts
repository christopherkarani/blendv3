import { Address, Contract, nativeToScVal } from '@stellar/stellar-sdk';

export interface Unlock {
  /// The ledger time (in seconds) the unlock occurs
  time: number;
  /// The amount of current tokens (in bps) to unlock
  percent: number;
}
export class TokenLockupContract extends Contract {
  public init(admin: string, owner: string, unlocks: Array<Unlock>): string {
    const invokeArgs = {
      method: 'initialize',
      args: [
        ((i) => Address.fromString(i).toScVal())(admin),
        ((i) => Address.fromString(i).toScVal())(owner),
        ((i) => nativeToScVal(i, { type: { time: 'u64', percent: 'u32' } }))(unlocks),
      ],
    };
    return this.call(invokeArgs.method, ...invokeArgs.args).toXDR('base64');
  }
}
