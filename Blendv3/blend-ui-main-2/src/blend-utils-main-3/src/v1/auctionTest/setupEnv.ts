import { ReserveConfig } from '@blend-capital/blend-sdk';
import { Asset, TransactionBuilder } from '@stellar/stellar-sdk';
import { randomBytes } from 'crypto';
import { deployBlend } from '../deploy/blend.js';
import { deployCometFactory } from '../deploy/comet-factory.js';
import { deployComet } from '../deploy/comet.js';
import { tryDeployStellarAsset } from '../deploy/stellar-asset.js';
import { setupPool } from '../pool/pool-setup.js';
import { setupReserve } from '../pool/reserve-setup.js';
import { setupPoolBackstop } from '../testing-scripts/backstop-pool-setup.js';
import { airdropAccount } from '../../utils/contract.js';
import { config } from '../../utils/env_config.js';
import { TxParams, invokeSorobanOperation, signWithKeypair } from '../../utils/tx.js';
import { setupAuctionOracle } from './oracle.js';

const txBuilderOptions: TransactionBuilder.TransactionBuilderOptions = {
  fee: '10000',
  timebounds: {
    minTime: 0,
    maxTime: 0,
  },
  networkPassphrase: config.passphrase,
};
await setupEnv();

// setup a new network with the Blend Protocol, an admin user, and the relevant tokens for auction testing
async function setupEnv() {
  console.log('Setting up environment\n');
  const whale = config.getUser('WHALE');
  console.log('whale: ', whale.publicKey());
  await airdropAccount(whale);
  console.log('admin: ', config.admin.publicKey());
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

  await tryDeployStellarAsset(Asset.native(), adminTxParams);
  const asset_BLND = new Asset('BLND', config.admin.publicKey());
  const BLND = await tryDeployStellarAsset(asset_BLND, adminTxParams);
  const asset_USDC = new Asset('USDC', config.admin.publicKey());
  const USDC = await tryDeployStellarAsset(asset_USDC, adminTxParams);
  const asset_VOL = new Asset('VOL', config.admin.publicKey());
  const VOL = await tryDeployStellarAsset(asset_VOL, adminTxParams);
  const asset_IR = new Asset('IR', config.admin.publicKey());
  const IR = await tryDeployStellarAsset(asset_IR, adminTxParams);
  const asset_NOCOL = new Asset('NOCOL', config.admin.publicKey());
  const NOCOL = await tryDeployStellarAsset(asset_NOCOL, adminTxParams);

  const cometFactory = await deployCometFactory(adminTxParams);
  const null_address = 'GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWHF';
  const cometContract = await deployComet(
    cometFactory,
    adminTxParams,
    [BLND.contractId(), USDC.contractId()],
    [BigInt(0.8e7), BigInt(0.2e7)],
    [BigInt(1000e7), BigInt(25e7)],
    BigInt(0.003e7),
    null_address
  );
  const auctionOracle = await setupAuctionOracle(adminTxParams);
  const [backstopContract, emitterContract] = await deployBlend(
    BLND.contractId(),
    cometContract.contractId(),
    USDC.contractId(),
    [],
    adminTxParams
  );

  // deploy pool

  const auctionPool = await setupPool(
    {
      admin: config.admin.publicKey(),
      name: 'Auction',
      salt: randomBytes(32),
      oracle: auctionOracle.contractId(),
      backstop_take_rate: 0.1e7,
      max_positions: 4,
    },
    adminTxParams
  );

  const usdcReserveMeta: ReserveConfig = {
    index: 0,
    decimals: 7,
    c_factor: 950_0000,
    l_factor: 950_0000,
    util: 800_0000,
    max_util: 990_0000,
    r_base: 10_0000,
    r_one: 40_0000,
    r_two: 200_0000,
    r_three: 500_0000,
    reactivity: 100,
  };
  await setupReserve(
    auctionPool.contractId(),
    {
      asset: USDC.contractId(),
      metadata: usdcReserveMeta,
    },
    adminTxParams
  );

  const volReserveMeta: ReserveConfig = {
    index: 1,
    decimals: 7,
    c_factor: 750_0000,
    l_factor: 750_0000,
    util: 600_0000,
    max_util: 900_0000,
    r_base: 5000,
    r_one: 50_0000,
    r_two: 500_0000,
    r_three: 1_500_0000,
    reactivity: 500,
  };

  await setupReserve(
    auctionPool.contractId(),
    { asset: VOL.contractId(), metadata: volReserveMeta },
    adminTxParams
  );

  const highIntReserveMeta: ReserveConfig = {
    index: 2,
    decimals: 7,
    c_factor: 900_0000,
    l_factor: 900_0000,
    util: 500_0000,
    max_util: 900_0000,
    r_base: 100_0000,
    r_one: 200_0000,
    r_two: 1_500_0000,
    r_three: 5_000_0000,
    reactivity: 0,
  };

  await setupReserve(
    auctionPool.contractId(),
    { asset: IR.contractId(), metadata: highIntReserveMeta },
    adminTxParams
  );

  const noColReserveMeta: ReserveConfig = {
    index: 3,
    decimals: 7,
    c_factor: 0,
    l_factor: 500_0000,
    util: 500_0000,
    max_util: 900_0000,
    r_base: 1_0000,
    r_one: 5_0000,
    r_two: 500_0000,
    r_three: 2_000_0000,
    reactivity: 500,
  };

  await setupReserve(
    auctionPool.contractId(),
    { asset: NOCOL.contractId(), metadata: noColReserveMeta },
    adminTxParams
  );

  await setupPoolBackstop(
    backstopContract.contractId(),
    auctionPool.contractId(),
    cometContract.contractId(),
    BLND.contractId(),
    USDC.contractId(),
    adminTxParams,
    whaleTxParams,
    adminTxParams
  );

  console.log('Transfer blnd admin to emitter\n');

  await invokeSorobanOperation(
    BLND.set_admin(emitterContract.contractId()),
    () => undefined,
    adminTxParams
  );

  console.log('Successfully setup pool auction pool: ', auctionPool.contractId());
}
