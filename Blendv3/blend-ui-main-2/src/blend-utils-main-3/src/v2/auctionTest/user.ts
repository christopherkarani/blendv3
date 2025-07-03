import { Asset, Keypair, scValToNative, xdr } from '@stellar/stellar-sdk';
import { airdropAccount } from '../../utils/contract.js';
import { TokenContract } from '../../external/token.js';
import { addressBook } from '../../utils/address-book.js';
import { config } from '../../utils/env_config.js';
import {
  invokeClassicOp,
  invokeSorobanOperation,
  signWithKeypair,
  TxParams,
} from '../../utils/tx.js';
import { PoolContractV2, Request, RequestType } from '@blend-capital/blend-sdk';

async function createUser(): Promise<Keypair> {
  const keypair = Keypair.random();
  await airdropAccount(keypair);
  const txParams = {
    account: await config.rpc.getAccount(keypair.publicKey()),
    txBuilderOptions: {
      fee: '10000',
      timebounds: {
        minTime: 0,
        maxTime: 0,
      },
      networkPassphrase: config.passphrase,
    },
    signerFunction: async (txXDR: string) => {
      return signWithKeypair(txXDR, config.passphrase, keypair);
    },
  };
  const adminTxParams = {
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
  const highVolToken = new TokenContract(
    addressBook.getContractId('VOL'),
    new Asset('VOL', config.admin.publicKey())
  );
  const USDC = new TokenContract(
    addressBook.getContractId('USDC'),
    new Asset('USDC', config.admin.publicKey())
  );
  const highIRToken = new TokenContract(
    addressBook.getContractId('IR'),
    new Asset('IR', config.admin.publicKey())
  );
  const noCollateralToken = new TokenContract(
    addressBook.getContractId('NOCOL'),
    new Asset('NOCOL', config.admin.publicKey())
  );
  await invokeClassicOp(highVolToken.classic_trustline(keypair.publicKey()), txParams);
  await invokeSorobanOperation(
    highVolToken.mint(keypair.publicKey(), BigInt(10000e7)),
    (xdrString) => {
      return scValToNative(xdr.ScVal.fromXDR(xdrString, 'base64'));
    },
    adminTxParams
  );

  await invokeClassicOp(USDC.classic_trustline(keypair.publicKey()), txParams);
  await invokeSorobanOperation(
    USDC.mint(keypair.publicKey(), BigInt(10000e7)),
    (xdrString) => {
      return scValToNative(xdr.ScVal.fromXDR(xdrString, 'base64'));
    },
    adminTxParams
  );

  await invokeClassicOp(highIRToken.classic_trustline(keypair.publicKey()), txParams);
  await invokeSorobanOperation(
    highIRToken.mint(keypair.publicKey(), BigInt(10000e7)),
    (xdrString) => {
      return scValToNative(xdr.ScVal.fromXDR(xdrString, 'base64'));
    },
    adminTxParams
  );

  await invokeClassicOp(noCollateralToken.classic_trustline(keypair.publicKey()), txParams);
  await invokeSorobanOperation(
    noCollateralToken.mint(keypair.publicKey(), BigInt(10000e7)),
    (xdrString) => {
      return scValToNative(xdr.ScVal.fromXDR(xdrString, 'base64'));
    },
    adminTxParams
  );
  return keypair;
}

async function submit(
  txParams: TxParams,
  poolId: string,
  asset: string,
  action: RequestType,
  amount: bigint
): Promise<void> {
  const pool = new PoolContractV2(poolId);
  const request: Request = {
    amount: amount,
    request_type: action,
    address: asset,
  };
  await invokeSorobanOperation(
    pool.submit({
      from: txParams.account.accountId(),
      to: txParams.account.accountId(),
      spender: txParams.account.accountId(),
      requests: [request],
    }),
    PoolContractV2.parsers.submit,
    txParams
  );
}

export { createUser, submit };
