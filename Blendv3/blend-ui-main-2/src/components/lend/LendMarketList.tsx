import { Box, Typography } from '@mui/material';
import { ViewType, useSettings } from '../../contexts';
import { usePool, usePoolMeta } from '../../hooks/api';
import { PoolComponentProps } from '../common/PoolComponentProps';
import { Skeleton } from '../common/Skeleton';
import { TooltipText } from '../common/TooltipText';
import { LendMarketCard } from './LendMarketCard';

export const LendMarketList: React.FC<PoolComponentProps> = ({ poolId }) => {
  const { viewType } = useSettings();

  const { data: poolMeta } = usePoolMeta(poolId);
  const { data: pool } = usePool(poolMeta);

  if (pool === undefined) {
    return <Skeleton />;
  }

  const headerNum = viewType === ViewType.REGULAR ? 5 : 3;
  const headerWidth = `${(100 / headerNum).toFixed(2)}%`;
  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'column',
        overflow: 'auto',
        scrollbarColor: 'black grey',
        padding: '6px',
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
        <Typography variant="body2" color="text.secondary" sx={{ width: headerWidth }}>
          Asset
        </Typography>
        <Typography
          variant="body2"
          color="text.secondary"
          align="center"
          sx={{ width: headerWidth }}
        >
          Wallet Balance
        </Typography>

        <TooltipText
          tooltip="The estimated compounding interest rate earned on a supplied position. This rate will fluctuate based on the market conditions, and accrues to the supplied position automatically."
          width={headerWidth}
        >
          APY
        </TooltipText>

        {viewType !== ViewType.MOBILE && (
          <TooltipText
            tooltip="The percent of this asset's value added to your borrow capacity."
            width={headerWidth}
          >
            Collateral Factor
          </TooltipText>
        )}
        <Box sx={{ width: viewType === ViewType.MOBILE ? 'auto' : headerWidth }} />
      </Box>
      {Array.from(pool.reserves.values()).map((reserve) => (
        <LendMarketCard key={reserve.assetId} poolId={poolId} reserve={reserve} />
      ))}
    </Box>
  );
};
