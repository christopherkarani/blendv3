import { ContractErrorType, parseError } from '@blend-capital/blend-sdk';
import { AlertColor } from '@mui/material';
import { rpc } from '@stellar/stellar-sdk';
import { OpaqueButton } from '../components/common/OpaqueButton';
import { useWallet } from '../contexts/wallet';
import theme from '../theme';

export function RestoreButton({
  simResponse,
}: {
  simResponse: rpc.Api.SimulateTransactionResponse;
}) {
  const { restore } = useWallet();
  function handleRestore() {
    if (simResponse && rpc.Api.isSimulationRestore(simResponse)) {
      restore(simResponse);
    }
  }
  return (
    <OpaqueButton
      onClick={handleRestore}
      palette={theme.palette.warning}
      sx={{ padding: '6px 24px', margin: '12px auto' }}
    >
      Restore
    </OpaqueButton>
  );
}

export function getErrorFromSim(
  input: string | undefined,
  decimals: number,
  loading: boolean,
  simulationResult: rpc.Api.SimulateTransactionResponse | undefined,
  extraValidations?: () => Partial<SubmitError>
): SubmitError {
  let errorProps: SubmitError = {
    isError: false,
    isSubmitDisabled: false,
    isMaxDisabled: false,
    reason: undefined,
    disabledType: undefined,
    extraContent: undefined,
  };
  if (input == undefined || input === '') {
    errorProps.isSubmitDisabled = true;
    errorProps.isError = true;
    errorProps.isMaxDisabled = false;
    errorProps.reason = 'Please enter an amount.';
    errorProps.disabledType = 'info';
    return errorProps;
  }
  if (input.split('.')[1]?.length > decimals) {
    errorProps.isError = true;
    errorProps.isSubmitDisabled = true;
    errorProps.isMaxDisabled = false;
    errorProps.reason = `You cannot input more than ${decimals} decimal places.`;
    errorProps.disabledType = 'warning';
    return errorProps;
  }
  if (loading) {
    errorProps.isSubmitDisabled = true;
    errorProps.isError = true;
    errorProps.isMaxDisabled = false;
    errorProps.reason = 'Loading estimate...';
    errorProps.disabledType = 'info';
    return errorProps;
  }
  if (!!extraValidations) {
    errorProps = { ...errorProps, ...extraValidations() };
    if (errorProps.isError) {
      return errorProps;
    }
  }
  if (simulationResult && rpc.Api.isSimulationRestore(simulationResult)) {
    errorProps.isError = true;
    errorProps.extraContent = <RestoreButton simResponse={simulationResult} />;
    errorProps.isSubmitDisabled = true;
    errorProps.isMaxDisabled = false;
    errorProps.disabledType = 'warning';
    errorProps.reason =
      'This transaction ran into expired entries which need to be restored before proceeding.';
    return errorProps;
  }
  if (simulationResult && rpc.Api.isSimulationError(simulationResult)) {
    const error = parseError(simulationResult);
    errorProps.isError = true;
    errorProps.isSubmitDisabled = true;
    errorProps.isMaxDisabled = false;
    errorProps.reason = error.message || ContractErrorType[error.type];
    errorProps.disabledType = 'error';
    return errorProps;
  }
  return errorProps;
}

export interface SubmitError {
  isError: boolean;
  isSubmitDisabled: boolean;
  isMaxDisabled: boolean;
  reason: string | undefined;
  disabledType: AlertColor | undefined;
  extraContent?: React.ReactNode;
}
