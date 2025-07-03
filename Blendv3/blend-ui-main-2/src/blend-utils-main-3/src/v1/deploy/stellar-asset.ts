import { Account, Asset, Operation, StrKey, hash, xdr } from '@stellar/stellar-sdk';
import { addressBook } from '../../utils/address-book.js';
import { config } from '../../utils/env_config.js';
import { TxParams, invokeSorobanOperation } from '../../utils/tx.js';

import { TokenContract } from '../../external/token.js';
import { bumpContractInstance } from '../../utils/contract.js';

export async function deployStellarAsset(asset: Asset, txParams: TxParams): Promise<TokenContract> {
  const xdrAsset = asset.toXDRObject();
  const networkId = hash(Buffer.from(config.passphrase));
  const preimage = xdr.HashIdPreimage.envelopeTypeContractId(
    new xdr.HashIdPreimageContractId({
      networkId: networkId,
      contractIdPreimage: xdr.ContractIdPreimage.contractIdPreimageFromAsset(xdrAsset),
    })
  );
  const contractId = StrKey.encodeContract(hash(preimage.toXDR()));
  addressBook.setContractId(asset.code, contractId);
  addressBook.writeToFile();

  const deployFunction = xdr.HostFunction.hostFunctionTypeCreateContract(
    new xdr.CreateContractArgs({
      contractIdPreimage: xdr.ContractIdPreimage.contractIdPreimageFromAsset(xdrAsset),
      executable: xdr.ContractExecutable.contractExecutableStellarAsset(),
    })
  );
  const deployOp = Operation.invokeHostFunction({
    func: deployFunction,
    auth: [],
  });
  await invokeSorobanOperation(deployOp.toXDR('base64'), () => undefined, txParams);
  await bumpContractInstance(asset.code, txParams);
  console.log(`Successfully deployed Stellar asset contract: ${asset}\n`);
  return new TokenContract(contractId, asset);
}

export async function tryDeployStellarAsset(
  asset: Asset,
  txParams: TxParams
): Promise<TokenContract> {
  try {
    return await deployStellarAsset(asset, txParams);
  } catch (e) {
    console.log('Asset already deployed', e);
    txParams.account = new Account(
      txParams.account.accountId(),
      (parseInt(txParams.account.sequenceNumber()) - 1).toString()
    );
    return new TokenContract(addressBook.getContractId(asset.code), asset);
  }
}
