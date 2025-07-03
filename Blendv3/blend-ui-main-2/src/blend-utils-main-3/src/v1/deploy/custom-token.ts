import { TokenContract } from '../../external/token.js';
import {
  bumpContractCode,
  bumpContractInstance,
  deployContract,
  installContract,
} from '../../utils/contract.js';
import { TxParams, invokeSorobanOperation } from '../../utils/tx.js';

async function deployCustomToken(
  admin: string,
  name: string,
  symbol: string,
  decimals: number,
  txParams: TxParams
) {
  await installContract('token', txParams);
  await bumpContractCode('token', txParams);
  const tokenAddress = await deployContract(symbol, 'token', txParams);
  await bumpContractInstance(symbol, txParams);
  const token = new TokenContract(tokenAddress);
  await invokeSorobanOperation(
    token.initialize(admin, decimals, name, symbol),
    () => undefined,
    txParams
  );
  console.log(`Successfully deployed ${name} token contract.\n`);
  return token;
}
