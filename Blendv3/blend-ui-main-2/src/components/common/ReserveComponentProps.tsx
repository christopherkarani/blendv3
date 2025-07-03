import { BoxProps } from '@mui/material';

export interface ReserveComponentProps extends BoxProps {
  poolId: string;
  assetId: string;
}
