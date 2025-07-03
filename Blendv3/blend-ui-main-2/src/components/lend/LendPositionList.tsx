import { PositionsEstimate } from '@blend-capital/blend-sdk';
import { Box, Typography } from '@mui/material';
import { ViewType, useSettings } from '../../contexts';
import { usePool, usePoolMeta, usePoolOracle, usePoolUser } from '../../hooks/api';
import { PoolComponentProps } from '../common/PoolComponentProps';
import { Row } from '../common/Row';
import { Section, SectionSize } from '../common/Section';
import { TooltipText } from '../common/TooltipText';
import { LendBanner } from './LendBanner';
import { LendPositionCard } from './LendPositionCard';

export const LendPositionList: React.FC<PoolComponentProps> = ({ poolId }) => {
  const { viewType } = useSettings();

  const { data: poolMeta } = usePoolMeta(poolId);
  const { data: pool } = usePool(poolMeta);
  const { data: poolOracle } = usePoolOracle(pool);
  const { data: poolUserData } = usePoolUser(pool);

  if (
    pool === undefined ||
    poolUserData === undefined ||
    (poolUserData.positions.collateral.size === 0 && poolUserData.positions.supply.size === 0)
  ) {
    return <></>;
  }

  const poolUserEst =
    poolOracle !== undefined
      ? PositionsEstimate.build(pool, poolOracle, poolUserData.positions)
      : undefined;

  const headerNum = viewType === ViewType.REGULAR ? 5 : 3;
  const headerWidth = `${(100 / headerNum).toFixed(2)}%`;
  return (
    <Row>
      <Section
        type="alt"
        width={SectionSize.FULL}
        sx={{ flexDirection: 'column', paddingTop: '12px', padding: '0px', gap: '4px' }}
      >
        <Row>
          <LendBanner totalSupplied={poolUserEst?.totalSupplied ?? 0} />
        </Row>
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            overflow: 'auto',
            scrollbarColor: 'black grey',
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
              Balance
            </Typography>

            <TooltipText
              tooltip="The estimated compounding interest rate earned on a supplied position. This rate will fluctuate based on the market conditions, and accrues to the supplied position automatically."
              width={headerWidth}
            >
              APY
            </TooltipText>

            <Box
              sx={{ flexGrow: '2', width: viewType === ViewType.MOBILE ? '24px' : headerWidth }}
            />
          </Box>
          <Box sx={{ width: '100%', gap: '.5rem', display: 'flex', flexDirection: 'column' }}>
            {Array.from(pool.reserves.values())
              .filter((reserve) => {
                const bTokens =
                  poolUserData.getSupplyBTokens(reserve) +
                  poolUserData.getCollateralBTokens(reserve);
                return bTokens > BigInt(0);
              })
              .map((reserve) => {
                const bTokens =
                  poolUserData.getSupplyBTokens(reserve) +
                  poolUserData.getCollateralBTokens(reserve);
                return (
                  <LendPositionCard
                    key={reserve.assetId}
                    poolId={poolId}
                    reserve={reserve}
                    bTokens={bTokens}
                  />
                );
              })}
          </Box>
        </Box>
      </Section>
    </Row>
  );
};
