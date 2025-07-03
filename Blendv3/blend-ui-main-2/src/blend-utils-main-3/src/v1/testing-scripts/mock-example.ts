import {
  BackstopContractV1,
  PoolContractV1,
  Request,
  RequestType,
  ReserveConfig,
  ReserveEmissionMetadata,
} from '@blend-capital/blend-sdk';
import { Asset, TransactionBuilder } from '@stellar/stellar-sdk';
import { randomBytes } from 'crypto';
import { deployBlend } from '../deploy/blend.js';
import { deployCometFactory } from '../deploy/comet-factory.js';
import { deployComet } from '../deploy/comet.js';
import { tryDeployStellarAsset } from '../deploy/stellar-asset.js';
import { setupPool } from '../pool/pool-setup.js';
import { setupReserve } from '../pool/reserve-setup.js';
import { airdropAccount } from '../../utils/contract.js';
import { config } from '../../utils/env_config.js';
import {
  TxParams,
  invokeClassicOp,
  invokeSorobanOperation,
  signWithKeypair,
} from '../../utils/tx.js';
import { setupPoolBackstop } from './backstop-pool-setup.js';
import { setupMockOracle } from './oracle-setup.js';

const txBuilderOptions: TransactionBuilder.TransactionBuilderOptions = {
  fee: '10000',
  timebounds: {
    minTime: 0,
    maxTime: 0,
  },
  networkPassphrase: config.passphrase,
};
await mock();

async function mock() {
  const whale = config.getUser('WHALE');
  await airdropAccount(whale);
  await airdropAccount(config.admin);
  const adminTxParams: TxParams = {
    account: await config.rpc.getAccount(config.admin.publicKey()),
    txBuilderOptions,
    signerFunction: async (txXDR: string) => {
      return signWithKeypair(txXDR, config.passphrase, config.admin);
    },
  };
  const whaleTxParams: TxParams = {
    account: await config.rpc.getAccount(whale.publicKey()),
    txBuilderOptions,
    signerFunction: async (txXDR: string) => {
      return signWithKeypair(txXDR, config.passphrase, whale);
    },
  };

  const XLM = await tryDeployStellarAsset(Asset.native(), adminTxParams);
  const BLND = await tryDeployStellarAsset(
    new Asset('BLND', config.admin.publicKey()),
    adminTxParams
  );
  const USDC = await tryDeployStellarAsset(
    new Asset('USDC', config.admin.publicKey()),
    adminTxParams
  );
  const wETH = await tryDeployStellarAsset(
    new Asset('wETH', config.admin.publicKey()),
    adminTxParams
  );
  const wBTC = await tryDeployStellarAsset(
    new Asset('wBTC', config.admin.publicKey()),
    adminTxParams
  );
  const cometFactory = await deployCometFactory(adminTxParams);
  const null_address = 'GCVJMEUXNIN7BYI4ERWW66ZJNTXRU2AWM65ZDYOODH5ZEZUM7UZXDEAD';
  const cometContract = await deployComet(
    cometFactory,
    adminTxParams,
    [BLND.contractId(), USDC.contractId()],
    [BigInt(0.8e7), BigInt(0.2e7)],
    [BigInt(1000e7), BigInt(25e7)],
    BigInt(0.003e7),
    null_address
  );
  const mockOracle = await setupMockOracle(adminTxParams);
  const [backstopContract, emitterContract] = await deployBlend(
    BLND.contractId(),
    cometContract.contractId(),
    USDC.contractId(),
    [],
    adminTxParams
  );

  //********** Testnet Pool (XLM, USDC, wBTC, wETH) **********//

  const testnetPool = await setupPool(
    {
      admin: config.admin.publicKey(),
      name: 'Testnet',
      salt: randomBytes(32),
      oracle: mockOracle.contractId(),
      backstop_take_rate: 0.1e7,
      max_positions: 8,
    },
    adminTxParams
  );

  const testnetPoolXlmReserveMetaData: ReserveConfig = {
    index: 0,
    decimals: 7,
    c_factor: 900_0000,
    l_factor: 900_0000,
    util: 500_0000,
    max_util: 950_0000,
    r_base: 5000,
    r_one: 30_0000,
    r_two: 200_0000,
    r_three: 1_000_0000,
    reactivity: 100,
  };
  await setupReserve(
    testnetPool.contractId(),
    {
      asset: Asset.native().contractId(config.passphrase),
      metadata: testnetPoolXlmReserveMetaData,
    },
    adminTxParams
  );

  const wethReserveMetaData: ReserveConfig = {
    index: 1,
    decimals: 7,
    c_factor: 850_0000,
    l_factor: 800_0000,
    util: 650_0000,
    max_util: 950_0000,
    r_base: 7000,
    r_one: 50_0000,
    r_three: 1_500_0000,
    r_two: 500_0000,
    reactivity: 100,
  };
  await setupReserve(
    testnetPool.contractId(),
    {
      asset: wETH.contractId(),
      metadata: wethReserveMetaData,
    },
    adminTxParams
  );

  const wbtcReserveMetaData: ReserveConfig = {
    index: 2,
    decimals: 7,
    c_factor: 900_0000,
    l_factor: 900_0000,
    util: 750_0000,
    max_util: 950_0000,
    r_base: 7000,
    r_one: 50_0000,
    r_three: 1_500_0000,
    r_two: 500_0000,
    reactivity: 100,
  };
  await setupReserve(
    testnetPool.contractId(),
    {
      asset: wBTC.contractId(),
      metadata: wbtcReserveMetaData,
    },
    adminTxParams
  );

  const testnetPoolUsdcReserveMetaData: ReserveConfig = {
    index: 3,
    decimals: 7,
    c_factor: 950_0000,
    l_factor: 950_0000,
    util: 750_0000,
    max_util: 950_0000,
    r_base: 5000,
    r_one: 30_0000,
    r_two: 100_0000,
    r_three: 1_000_0000,
    reactivity: 100,
  };
  await setupReserve(
    testnetPool.contractId(),
    {
      asset: USDC.contractId(),
      metadata: testnetPoolUsdcReserveMetaData,
    },
    adminTxParams
  );

  const bridgeEmissionMetadata: ReserveEmissionMetadata[] = [
    {
      res_index: 1, // WETH
      res_type: 0, // d_token
      share: BigInt(0.4e7), // 40%
    },
    {
      res_index: 2, // WBTC
      res_type: 1, // b_token
      share: BigInt(0.2e7), // 20%
    },
    {
      res_index: 3, // USDC
      res_type: 0, // d_token
      share: BigInt(0.4e7), // 40%
    },
  ];
  await invokeSorobanOperation(
    testnetPool.setEmissionsConfig(bridgeEmissionMetadata),
    PoolContractV1.parsers.setEmissionsConfig,
    adminTxParams
  );

  await setupPoolBackstop(
    backstopContract.contractId(),
    testnetPool.contractId(),
    cometContract.contractId(),
    BLND.contractId(),
    USDC.contractId(),
    adminTxParams,
    whaleTxParams,
    adminTxParams
  );

  console.log('');
  console.log('Transfer blnd admin to emitter');

  await invokeSorobanOperation(
    BLND.set_admin(emitterContract.contractId()),
    () => undefined,
    adminTxParams
  );

  console.log('');
  console.log('Minting tokens to whale');
  await invokeClassicOp(wETH.classic_trustline(whale.publicKey()), whaleTxParams);
  await invokeClassicOp(wBTC.classic_trustline(whale.publicKey()), whaleTxParams);
  await invokeClassicOp(wETH.classic_mint(whale.publicKey(), '100'), adminTxParams);
  await invokeClassicOp(wBTC.classic_mint(whale.publicKey(), '10'), adminTxParams);
  await invokeClassicOp(USDC.classic_mint(whale.publicKey(), '200000'), adminTxParams);

  console.log('');
  console.log('Whale Supply tokens to Testnet pool');
  const bridgeSupplyRequests: Request[] = [
    {
      amount: BigInt(5000e7),
      request_type: RequestType.SupplyCollateral,
      address: XLM.contractId(),
    },
    {
      amount: BigInt(5e7),
      request_type: RequestType.SupplyCollateral,
      address: wETH.contractId(),
    },
    {
      amount: BigInt(0.5e7),
      request_type: RequestType.SupplyCollateral,
      address: wBTC.contractId(),
    },
    {
      amount: BigInt(10000e7),
      request_type: RequestType.SupplyCollateral,
      address: USDC.contractId(),
    },
  ];
  await invokeSorobanOperation(
    testnetPool.submit({
      from: whale.publicKey(),
      spender: whale.publicKey(),
      to: whale.publicKey(),
      requests: bridgeSupplyRequests,
    }),
    PoolContractV1.parsers.submit,
    whaleTxParams
  );

  console.log('');
  console.log('Whale Borrow tokens from Testnet pool');
  const bridgeBorrowRequests: Request[] = [
    {
      amount: BigInt(2500e7),
      request_type: RequestType.Borrow,
      address: XLM.contractId(),
    },
    {
      amount: BigInt(3e7),
      request_type: RequestType.Borrow,
      address: wETH.contractId(),
    },
    {
      amount: BigInt(0.2e7),
      request_type: RequestType.Borrow,
      address: wBTC.contractId(),
    },
    {
      amount: BigInt(5000e7),
      request_type: RequestType.Borrow,
      address: USDC.contractId(),
    },
  ];
  await invokeSorobanOperation(
    testnetPool.submit({
      from: whale.publicKey(),
      spender: whale.publicKey(),
      to: whale.publicKey(),
      requests: bridgeBorrowRequests,
    }),
    PoolContractV1.parsers.submit,
    whaleTxParams
  );

  await invokeSorobanOperation(
    backstopContract.queueWithdrawal({
      from: whale.publicKey(),
      pool_address: testnetPool.contractId(),
      amount: BigInt(1000e7),
    }),
    BackstopContractV1.parsers.queueWithdrawal,
    whaleTxParams
  );
}
