import { CometFactoryContract } from '../../external/comet.js';
import { addressBook } from '../../utils/address-book.js';
import {
  bumpContractCode,
  bumpContractInstance,
  deployContract,
  installContract,
} from '../../utils/contract.js';
import { TxParams, invokeSorobanOperation } from '../../utils/tx.js';

export async function deployCometFactory(txParams: TxParams): Promise<CometFactoryContract> {
  await installContract('comet', txParams);
  await bumpContractCode('comet', txParams);
  await installContract('cometFactory', txParams);
  await bumpContractCode('cometFactory', txParams);

  const comet_wasm = Buffer.from(addressBook.getWasmHash('comet'), 'hex');

  const cometFactoryAddress = await deployContract('cometFactory', 'cometFactory', txParams);
  await bumpContractInstance('cometFactory', txParams);
  const cometFactory = new CometFactoryContract(cometFactoryAddress);
  await invokeSorobanOperation(cometFactory.init(comet_wasm), () => undefined, txParams);

  if (!cometFactoryAddress) {
    throw new Error('Failed to deploy Comet contract.');
  }
  addressBook.setContractId('cometFactory', cometFactoryAddress.toString());
  addressBook.writeToFile();
  console.log('Successfully deployed Comet contract.\n');
  return cometFactory;
}
