import { BoxProps } from '@mui/material';
import { Row } from '../common/Row';
import { PoolFrozenBanner } from './PoolFrozenBanner';
import { PoolOnIceBanner } from './PoolOnIceBanner';

export interface PoolStatusBannerProps extends BoxProps {
  status: number | undefined;
}

export const PoolStatusBanner: React.FC<PoolStatusBannerProps> = ({ status, ...props }) => {
  // status of 1 or 0 indicated an active pool. if a status is currently loading or unable to be resolved,
  // do not display a banner
  const status_issue = status !== undefined && status > 1;

  if (!status_issue) {
    return <></>;
  }

  return <Row {...props}>{status <= 3 ? <PoolOnIceBanner /> : <PoolFrozenBanner />}</Row>;
};
