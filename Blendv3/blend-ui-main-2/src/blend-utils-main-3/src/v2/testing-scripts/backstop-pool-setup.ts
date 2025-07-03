import { BackstopContractV2, PoolContractV2 } from '@blend-capital/blend-sdk';
import { Asset } from '@stellar/stellar-sdk';
import { CometContract } from '../../external/comet.js';
import { TokenContract } from '../../external/token.js';
import { TxParams, invokeClassicOp, invokeSorobanOperation } from '../../utils/tx.js';

export async function setupPoolBackstop(
  backstopAddress: string,
  poolAddress: string,
  cometAddress: string,
  blndAddress: string,
  usdcAddress: string,
  adminTxParams: TxParams,
  whaleTxParams: TxParams,
  issuerTxParams: TxParams
) {
  const pool = new PoolContractV2(poolAddress);
  const backstop = new BackstopContractV2(backstopAddress);
  const BLND = new TokenContract(
    blndAddress,
    new Asset('BLND', issuerTxParams.account.accountId())
  );
  const USDC = new TokenContract(usdcAddress, new Asset('USDC', adminTxParams.account.accountId()));
  const comet = new CometContract(cometAddress);
  await invokeClassicOp(BLND.classic_trustline(whaleTxParams.account.accountId()), whaleTxParams);
  await invokeClassicOp(
    BLND.classic_mint(whaleTxParams.account.accountId(), '500100'),
    issuerTxParams
  );
  await invokeClassicOp(USDC.classic_trustline(whaleTxParams.account.accountId()), whaleTxParams);
  await invokeClassicOp(
    USDC.classic_mint(whaleTxParams.account.accountId(), '12501'),
    adminTxParams
  );

  await invokeSorobanOperation(
    comet.joinPool(
      BigInt(50001e7),
      [BigInt(500100e7), BigInt(12501e7)],
      whaleTxParams.account.accountId()
    ),
    () => undefined,
    whaleTxParams
  );

  await invokeSorobanOperation(
    backstop.deposit({
      from: whaleTxParams.account.accountId(),
      pool_address: poolAddress,
      amount: BigInt(50_001e7),
    }),

    BackstopContractV2.parsers.deposit,
    whaleTxParams
  );

  await invokeSorobanOperation(pool.setStatus(0), PoolContractV2.parsers.setStatus, adminTxParams);
  await invokeSorobanOperation(
    backstop.addReward(pool.contractId(), pool.contractId()),
    BackstopContractV2.parsers.addReward,
    adminTxParams
  );
  console.log('Successfully setup pool backstop\n');
}
