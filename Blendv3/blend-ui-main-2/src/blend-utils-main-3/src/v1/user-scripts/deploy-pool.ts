import {
  BackstopContractV1,
  PoolContractV1,
  ReserveConfig,
  ReserveEmissionMetadata,
  parseError,
} from '@blend-capital/blend-sdk';
import { Operation, rpc, Transaction, TransactionBuilder, xdr } from '@stellar/stellar-sdk';
import { randomBytes } from 'crypto';
import { CometContract } from '../../external/comet.js';
import { setupPool } from '../pool/pool-setup.js';
import { setupReserve } from '../pool/reserve-setup.js';
import { addressBook } from '../../utils/address-book.js';
import { airdropAccount } from '../../utils/contract.js';
import { config } from '../../utils/env_config.js';
import {
  TxParams,
  invokeClassicOp,
  invokeSorobanOperation,
  sendTransaction,
  signWithKeypair,
} from '../../utils/tx.js';

/**
 * Deploy a pool with the following parameters (Parmeters can be changed as needed)
 * example: node ./lib/user-scripts/deploy-pool.js testnet
 */

const txParams: TxParams = {
  account: await config.rpc.getAccount(config.admin.publicKey()),
  txBuilderOptions: {
    fee: '10000',
    timebounds: {
      minTime: 0,
      maxTime: 0,
    },
    networkPassphrase: config.passphrase,
  },
  signerFunction: async (txXDR: string) => {
    return signWithKeypair(txXDR, config.passphrase, config.admin);
  },
};

/// Deployment Constants
const deposit_asset = BigInt(2); // 0=BLND, 1=USDC, 2=Both
const blnd_max = BigInt(9_000_000e7);
const usdc_max = BigInt(100_000e7);
const mint_amount = BigInt(60_000e7);
const pool_name = 'PairTrade';
const backstop_take_rate = 0.5e7;
const max_positions = 2;
const reserves = ['XLM', 'wBTC'];
const reserve_configs: ReserveConfig[] = [
  {
    index: 0, // Does not matter
    decimals: 7,
    c_factor: 980_0000, // (0_9800000)
    l_factor: 980_0000, // (0_9800000)
    util: 900_0000, // (0_9000000) must be under 950_0000
    max_util: 980_0000, // (0_9800000) must be greater than util
    r_base: 50000, // (0_0050000)
    r_one: 500000, // (0_0500000)
    r_two: 1000000, // (0_1000000)
    r_three: 1_0000000,
    reactivity: 1000, // must be 1000 or under
  },
  {
    index: 0,
    decimals: 7,
    c_factor: 980_0000, // (0_9800000)
    l_factor: 980_0000, // (0_9800000)
    util: 900_0000, // (0_9000000)
    max_util: 980_0000, // (0_9800000)
    r_base: 50000, // (0_0050000)
    r_one: 500000, // (0_0500000)
    r_two: 1000000, // (0_1000000)
    r_three: 1_0000000,
    reactivity: 1000,
  },
];
const poolEmissionMetadata: ReserveEmissionMetadata[] = [
  {
    res_index: 0, // first reserve
    res_type: 1, // 0 for borrow emissions : 1 for supply emissions
    share: BigInt(0.5e7), // Share of total emissions
  },
  {
    res_index: 1, // second reserve
    res_type: 1, // 0 for borrow emissions : 1 for supply emissions
    share: BigInt(0.5e7), // Share of total emissions
  },
];
const startingStatus = 0; // 0 for active, 2 for admin on ice, 3 for on ice, 4 for admin frozen
const addToRewardZone = true;
const poolToRemove = 'Stellar';
const revokeAdmin = true;

async function deploy() {
  // Initialize Contracts
  const backstop = new BackstopContractV1(addressBook.getContractId('backstop'));
  const comet = new CometContract(addressBook.getContractId('comet'));

  // mint lp with blnd
  if (mint_amount > 0) {
    if (deposit_asset == BigInt(0)) {
      await invokeSorobanOperation(
        comet.deposit_single_max_in(
          addressBook.getContractId('BLND'),
          blnd_max,
          mint_amount,
          config.admin.publicKey()
        ),
        () => undefined,
        txParams
      );
      // mint lp with usdc
    } else if (deposit_asset == BigInt(1)) {
      invokeSorobanOperation(
        comet.deposit_single_max_in(
          addressBook.getContractId('USDC'),
          usdc_max,
          mint_amount,
          config.admin.publicKey()
        ),
        () => undefined,
        txParams
      );
    } else {
      await invokeSorobanOperation(
        comet.joinPool(mint_amount, [blnd_max, usdc_max], config.admin.publicKey()),
        () => undefined,
        txParams
      );
    }
  }

  // Update token value
  await invokeSorobanOperation(
    backstop.updateTokenValue(),
    BackstopContractV1.parsers.updateTknVal,
    txParams
  );

  //********** Stellar Pool (XLM, USDC) **********//

  console.log('Deploy Pool\n');
  const poolSalt = randomBytes(32);

  const newPool = await setupPool(
    {
      admin: config.admin.publicKey(),
      name: pool_name,
      salt: poolSalt,
      oracle: addressBook.getContractId('oracle'),
      backstop_take_rate: backstop_take_rate,
      max_positions: max_positions,
    },
    txParams
  );

  console.log('Setup pool reserves and emissions\n');

  for (let i = 0; i < reserves.length; i++) {
    const reserve_name = reserves[i];
    const reserve_config = reserve_configs[i];
    await setupReserve(
      newPool.contractId(),
      {
        asset: addressBook.getContractId(reserve_name),
        metadata: reserve_config,
      },
      txParams
    );
  }

  await invokeSorobanOperation(
    newPool.setEmissionsConfig(poolEmissionMetadata),
    PoolContractV1.parsers.setEmissionsConfig,
    txParams
  );
  if (mint_amount > 0) {
    console.log('Setup backstop for Stellar pool\n');
    await invokeSorobanOperation(
      backstop.deposit({
        from: config.admin.publicKey(),
        pool_address: newPool.contractId(),
        amount: mint_amount,
      }),
      BackstopContractV1.parsers.deposit,
      txParams
    );
  }

  console.log('Setting Starting Status\n');
  await invokeSorobanOperation(
    newPool.setStatus(startingStatus),
    PoolContractV1.parsers.setStatus,
    txParams
  );

  if (addToRewardZone) {
    await invokeSorobanOperation(
      backstop.addReward(newPool.contractId(), addressBook.getContractId(poolToRemove)),
      BackstopContractV1.parsers.addReward,
      txParams
    );
  }

  if (revokeAdmin) {
    console.log('Revoking Admin\n');
    const newAdmin = config.getUser('PROPOSER');
    if (network != 'mainnet') {
      await airdropAccount(newAdmin);
    }
    //switch ownership to new admin
    const newAdminOp = newPool.setAdmin(newAdmin.publicKey());

    const txBuilder = new TransactionBuilder(txParams.account, txParams.txBuilderOptions)
      .setTimeout(0)
      .addOperation(xdr.Operation.fromXDR(newAdminOp, 'base64'));
    const transaction = txBuilder.build();
    const newAdminSignedTx = new Transaction(
      await signWithKeypair(transaction.toXDR(), config.passphrase, newAdmin),
      config.passphrase
    );
    const simResponse = await config.rpc.simulateTransaction(newAdminSignedTx);
    if (rpc.Api.isSimulationError(simResponse)) {
      const error = parseError(simResponse);
      throw error;
    }
    const assembledTx = rpc.assembleTransaction(newAdminSignedTx, simResponse).build();
    const signedTx = new Transaction(
      await txParams.signerFunction(assembledTx.toXDR()),
      config.passphrase
    );
    await sendTransaction(signedTx, () => undefined);

    // revoke new admin signing power
    const revokeOp = Operation.setOptions({
      masterWeight: 0,
    });
    txParams.account = await config.rpc.getAccount(newAdmin.publicKey());
    txParams.signerFunction = async (txXDR: string) => {
      return signWithKeypair(txXDR, config.passphrase, newAdmin);
    };
    await invokeClassicOp(revokeOp.toXDR('base64'), txParams);
  }
}

const network = process.argv[2];
await deploy();
