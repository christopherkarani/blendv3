import { Pool } from '@blend-capital/blend-sdk';
import { Box, BoxProps, Typography } from '@mui/material';
import { useSettings, ViewType } from '../../contexts';
import { usePoolOracle } from '../../hooks/api';
import { LotListItem } from './LotListItem';

export interface LotListProps extends BoxProps {
  pool: Pool;
  lot: Map<string, bigint>;
  lotValue: Map<string, number>;
  type: string;
}

export const LotList: React.FC<LotListProps> = ({ pool, lot, type, lotValue }) => {
  const { viewType } = useSettings();
  const { data: poolOracle } = usePoolOracle(pool);

  const headerNum = viewType == ViewType.REGULAR ? 3 : 3;
  const headerWidth = `${(100 / headerNum).toFixed(2)}%`;
  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'column',
        overflow: 'auto',
        scrollbarColor: 'black grey',
        padding: '6px',
        marginTop: '12px',
      }}
    >
      <Box
        sx={{
          width: '100%',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          padding: '6px',
          type: 'alt',
        }}
      >
        <Box
          sx={{
            width: headerWidth,
            display: 'flex',
            justifyContent: 'left',
          }}
        >
          <Typography variant="body2" color="text.secondary" align="left">
            Lot
          </Typography>
        </Box>

        <Box
          sx={{
            width: headerWidth,
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
          }}
        >
          <Typography variant="body2" color="text.secondary" align="center">
            Type
          </Typography>
        </Box>

        <Box
          sx={{
            width: headerWidth,
            display: 'flex',
            justifyContent: 'right',
          }}
        >
          <Typography variant="body2" color="text.secondary" align="right">
            Amount
          </Typography>
        </Box>
      </Box>
      {Array.from(lot.entries()).map(([asset, amount]) => (
        <LotListItem
          key={asset}
          reserve={pool.reserves.get(asset)}
          type={type}
          amount={amount}
          oracleValue={lotValue.get(asset)}
        />
      ))}
    </Box>
  );
};
