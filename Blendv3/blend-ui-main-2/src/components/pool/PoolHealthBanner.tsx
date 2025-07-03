import { Box } from '@mui/material';
import { usePool, usePoolMeta, usePoolOracle } from '../../hooks/api';
import { PoolComponentProps } from '../common/PoolComponentProps';
import { Row } from '../common/Row';
import { PoolOracleError } from './PoolOracleErrorBanner';
import { PoolStatusBanner } from './PoolStatusBanner';

export const PoolHealthBanner: React.FC<PoolComponentProps> = ({ poolId, ...props }) => {
  const { data: poolMeta } = usePoolMeta(poolId);
  const { data: pool } = usePool(poolMeta);
  const { isError: isOracleError } = usePoolOracle(pool);

  return (
    <Box sx={{ width: '100%', display: 'flex', flexDirection: 'column' }}>
      <PoolStatusBanner status={pool?.metadata?.status} />
      {isOracleError && (
        <Row>
          <PoolOracleError />
        </Row>
      )}
    </Box>
  );
};
