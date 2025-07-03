import {
  bumpContractCode,
  bumpContractInstance,
  deployContract,
  installContract,
} from '../../utils/contract.js';
import { TxParams, invokeSorobanOperation } from '../../utils/tx.js';
import { TokenLockupContract, Unlock } from '../../external/tokenLockup.js';
import { BlendLockupContract } from '../../external/blendLockup.js';

export async function installLockups(txParams: TxParams): Promise<void> {
  await installContract('blendLockup', txParams);
  await installContract('tokenLockup', txParams);
  await bumpContractCode('blendLockup', txParams);
  await bumpContractCode('tokenLockup', txParams);
  console.log('Successfully installed lockup contracts\n');
}

export async function deployTokenLockup(txParams: TxParams): Promise<TokenLockupContract> {
  const tokenLockupAddress = await deployContract('tokenLockup', 'tokenLockup', txParams);
  await bumpContractInstance('tokenLockup', txParams);

  console.log('Successfully deployed token lockup contract\n');
  return new TokenLockupContract(tokenLockupAddress);
}

export async function deployBlendLockup(txParams: TxParams): Promise<BlendLockupContract> {
  const blendLockupAddress = await deployContract('blendLockup', 'blendLockup', txParams);
  await bumpContractInstance('blendLockup', txParams);
  console.log('Successfully deployed blend lockup contract\n');

  return new BlendLockupContract(blendLockupAddress);
}

export async function initTokenLockup(
  txParams: TxParams,
  tokenLockupAddress: string,
  admin: string,
  owner: string,
  unlocks: Array<Unlock>
): Promise<TokenLockupContract> {
  const lockupContract = new TokenLockupContract(tokenLockupAddress);

  await invokeSorobanOperation(
    lockupContract.init(admin, owner, unlocks),
    () => undefined,
    txParams
  );

  console.log('Successfully initialized Token Lockup contract for: \n', owner);
  return lockupContract;
}

export async function initBlendLockup(
  txParams: TxParams,
  blendLockupAddress: string,
  bootstrapper: string,
  emitter: string,
  owner: string,
  unlock: bigint
): Promise<BlendLockupContract> {
  const lockupContract = new BlendLockupContract(blendLockupAddress);

  await invokeSorobanOperation(
    lockupContract.init(owner, emitter, bootstrapper, unlock),
    () => undefined,
    txParams
  );

  console.log('Successfully initialized Blend Lockup contract for: \n', owner);
  return lockupContract;
}
