import { Address, Contract, nativeToScVal } from '@stellar/stellar-sdk';

export class BlendLockupContract extends Contract {
  public init(owner: string, emitter: string, bootstrapper: string, unlock: bigint): string {
    const invokeArgs = {
      method: 'initialize',
      args: [
        ((i) => Address.fromString(i).toScVal())(owner),
        ((i) => Address.fromString(i).toScVal())(emitter),
        ((i) => Address.fromString(i).toScVal())(bootstrapper),
        ((i) => nativeToScVal(i, { type: 'u64' }))(unlock),
      ],
    };
    return this.call(invokeArgs.method, ...invokeArgs.args).toXDR('base64');
  }
}
