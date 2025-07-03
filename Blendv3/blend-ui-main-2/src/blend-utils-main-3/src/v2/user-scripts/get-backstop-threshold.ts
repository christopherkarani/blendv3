import { Account, Keypair, scValToNative, xdr } from '@stellar/stellar-sdk';
import { CometContract } from '../../external/comet.js';
import { TokenContract } from '../../external/token.js';
import { addressBook } from '../../utils/address-book.js';
import { config } from '../../utils/env_config.js';
import { simulationOperationResult } from '../../utils/tx.js';
import { signWithKeypair } from '../../utils/tx.js';
import { TxParams } from '../../utils/tx.js';
import { BackstopPoolV2 } from '@blend-capital/blend-sdk';

/**
 * Calculate required LP tokens to mint based on current balances and k threshold
 * Formula: k = A^0.8 * B^0.2 where k >= 100,000
 *
 * example: node ./lib/user-scripts/get-backstop-threshold.js testnet
 */

if (process.argv.length < 4) {
  throw new Error('Arguments required: `network` `pool`');
}

const K_THRESHOLD = BigInt(100_000);

async function getRequiredLP() {
  const pool = addressBook.getContractId(process.argv[3] ?? '');
  const comet_address = addressBook.getContractId('comet');
  const comet = new CometContract(comet_address);
  const usdc_contract = new TokenContract(addressBook.getContractId('USDC'));
  const blnd_contract = new TokenContract(addressBook.getContractId('BLND'));

  const txParams: TxParams = {
    account: new Account('GANXGJV2RNOFMOSQ2DTI3RKDBAVERXUVFC27KW3RLVQCLB3RYNO3AAI4', '123'),
    txBuilderOptions: {
      fee: '10000',
      timebounds: {
        minTime: 0,
        maxTime: 0,
      },
      networkPassphrase: config.passphrase,
    },
    signerFunction: async (txXDR: string) => {
      return signWithKeypair(txXDR, config.passphrase, Keypair.random());
    },
  };

  // Get current balances from the pool
  let blndBalance = await simulationOperationResult(
    blnd_contract.balance(comet_address),
    (result: string) => scValToNative(xdr.ScVal.fromXDR(result, 'base64')) as bigint,
    txParams
  );

  let totalCometTokens = await simulationOperationResult(
    comet.getTotalSupply(),
    (result: string) => scValToNative(xdr.ScVal.fromXDR(result, 'base64')) as bigint,
    txParams
  );

  let usdcBalance = await simulationOperationResult(
    usdc_contract.balance(comet_address),
    (result: string) => scValToNative(xdr.ScVal.fromXDR(result, 'base64')) as bigint,
    txParams
  );

  if (!totalCometTokens || !blndBalance || !usdcBalance) {
    throw new Error('Failed to fetch pool data');
  }

  // Calculate current k value
  const currentK = BigInt(
    Math.floor(Math.pow(Number(blndBalance), 0.8) * Math.pow(Number(usdcBalance), 0.2))
  );

  const poolBackstopData = await BackstopPoolV2.load(
    {
      rpc: config.rpc.serverURL,
      passphrase: config.passphrase,
      opts: { allowHttp: true },
    },
    addressBook.getContractId('backstopV2'),
    pool
  );
  const poolBackstopTokens = poolBackstopData.poolBalance.tokens / BigInt(10 ** 7);
  // Calculate the required LP tokens to reach the threshold
  const requiredLPtokens = (totalCometTokens * K_THRESHOLD) / currentK;
  const additionalLPtokens = requiredLPtokens - poolBackstopTokens;
  const requiredBLND = (additionalLPtokens * blndBalance) / totalCometTokens;
  const requiredUSDC = (additionalLPtokens * usdcBalance) / totalCometTokens;
  //adjust tokens to correct decimal places
  totalCometTokens = totalCometTokens / BigInt(10 ** 7);
  blndBalance = blndBalance / BigInt(10 ** 7);
  usdcBalance = usdcBalance / BigInt(10 ** 7);
  console.log(totalCometTokens);
  console.log(usdcBalance);
  console.log(blndBalance);
  const requiredSoloUSDC =
    Number(usdcBalance) *
    ((1 + Number(additionalLPtokens) / Number(totalCometTokens)) ** (1 / 0.2) - 1) *
    1.003;

  const requiredSoloBLND =
    Number(blndBalance) *
    ((1 + Number(additionalLPtokens) / Number(totalCometTokens)) ** (1 / 0.8) - 1) *
    1.003;

  console.log(`Current Backstop Requirements`);
  console.log(`Total Required Comet LP Tokens: ${requiredLPtokens}`);
  console.log(`Required LP Tokens to reach threshold: ${additionalLPtokens}`);
  console.log(`========================================`);
  console.log(`For a Balanced Deposit:`);
  console.log(`Required BLND: ${requiredBLND}`);
  console.log(`Required USDC: ${requiredUSDC}`);
  console.log(`========================================`);
  console.log(`For a Solo BLND Deposit:`);
  console.log(`Required BLND: ${requiredSoloBLND}`);
  console.log(`========================================`);
  console.log(`For a Solo USDC Deposit:`);
  console.log(`Required USDC: ${requiredSoloUSDC}`);
}

const network = process.argv[2];
if (!network) {
  throw new Error('Network argument required');
}

await getRequiredLP();
