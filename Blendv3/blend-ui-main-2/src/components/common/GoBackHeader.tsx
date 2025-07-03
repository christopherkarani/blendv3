import { Version } from '@blend-capital/blend-sdk';
import { BoxProps } from '@mui/material';
import { useSettings } from '../../contexts';
import { PoolHeader } from '../pool/PoolHeader';
import { GoBackButton } from './GoBackButton';
import { Section, SectionSize } from './Section';

export interface GoBackHeaderProps extends BoxProps {
  poolId: string;
}

export const GoBackHeader: React.FC<GoBackHeaderProps> = ({ poolId }) => {
  const { trackedPools } = useSettings();
  const trackedPool = trackedPools.find((pool) => pool.id === poolId);
  const name = trackedPool?.name ?? 'Unkown';
  const version = trackedPool?.version ?? Version.V1;
  return (
    <Section width={SectionSize.FULL} sx={{ padding: '12px' }}>
      <GoBackButton />
      <PoolHeader name={name} version={version} />
    </Section>
  );
};
