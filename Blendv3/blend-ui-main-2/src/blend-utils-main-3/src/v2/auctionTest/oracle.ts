import { Address } from '@stellar/stellar-sdk';
import { OracleContract } from '../../external/oracle.js';
import { addressBook } from '../../utils/address-book.js';
import {
  bumpContractCode,
  bumpContractInstance,
  deployContract,
  installContract,
} from '../../utils/contract.js';
import { config } from '../../utils/env_config.js';
import { TxParams, invokeSorobanOperation } from '../../utils/tx.js';

const AUCTION_ORACLE_KEY = 'auctionOracle';

export async function setupAuctionOracle(txParams: TxParams): Promise<OracleContract> {
  await installContract('oraclemock', txParams);
  await bumpContractCode('oraclemock', txParams);
  await deployContract(AUCTION_ORACLE_KEY, 'oraclemock', txParams);
  await bumpContractInstance(AUCTION_ORACLE_KEY, txParams);

  const oracleAddress = addressBook.getContractId(AUCTION_ORACLE_KEY);
  const oracle = new OracleContract(oracleAddress);
  await invokeSorobanOperation(
    oracle.setData(
      Address.fromString(config.admin.publicKey()),
      {
        tag: 'Other',
        values: ['USD'],
      },
      [
        {
          tag: 'Stellar',
          values: [Address.fromString(addressBook.getContractId('USDC'))],
        },
        {
          tag: 'Stellar',
          values: [Address.fromString(addressBook.getContractId('XLM'))],
        },
        {
          tag: 'Stellar',
          values: [Address.fromString(addressBook.getContractId('VOL'))],
        },
        {
          tag: 'Stellar',
          values: [Address.fromString(addressBook.getContractId('IR'))],
        },
        {
          tag: 'Stellar',
          values: [Address.fromString(addressBook.getContractId('NOCOL'))],
        },
      ],
      7,
      300
    ),
    () => undefined,
    txParams
  );
  await invokeSorobanOperation(
    oracle.setPriceStable([
      BigInt(1e7),
      BigInt(0.1e7),
      BigInt(100e7),
      BigInt(10000e7),
      BigInt(0.01e7),
    ]),
    () => undefined,
    txParams
  );
  console.log('Successfully deployed and setup the Auction Oracle contract.\n');
  return new OracleContract(oracleAddress);
}

export async function setPrice(
  txParams: TxParams,
  vol_price: number,
  high_int_price: number,
  no_col_price: number
) {
  const oracleAddress = addressBook.getContractId(AUCTION_ORACLE_KEY);
  const oracle = new OracleContract(oracleAddress);
  await invokeSorobanOperation(
    oracle.setPriceStable([
      BigInt(1e7),
      BigInt(0.1e7),
      BigInt(Math.floor(vol_price * 1e7)),
      BigInt(Math.floor(high_int_price * 1e7)),
      BigInt(Math.floor(no_col_price * 1e7)),
    ]),
    () => undefined,
    txParams
  );
  console.log('Successfully set prices for the Auction Oracle contract.\n');
}
