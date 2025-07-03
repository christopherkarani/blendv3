import { I128MAX, ReserveConfigV2 } from '@blend-capital/blend-sdk';
import { Box, Typography, useTheme } from '@mui/material';
import { useSettings, ViewType } from '../../contexts';
import { usePool, usePoolMeta, usePoolOracle } from '../../hooks/api';
import { toBalance } from '../../utils/formatter';
import { ReserveComponentProps } from '../common/ReserveComponentProps';
import { Row } from '../common/Row';
import { Section, SectionSize } from '../common/Section';
import { Skeleton } from '../common/Skeleton';
import { StackedText } from '../common/StackedText';
import { ReactivityDisplay } from './ReactivityDisplay';

export const AssetConfig: React.FC<ReserveComponentProps> = ({ poolId, assetId }) => {
  const theme = useTheme();
  const { viewType } = useSettings();
  const { data: poolMeta } = usePoolMeta(poolId);
  const { data: pool } = usePool(poolMeta);
  const { data: poolOracle } = usePoolOracle(pool);

  const oraclePrice = poolOracle?.getPriceFloat(assetId);
  const reserve = pool?.reserves.get(assetId);
  if (!pool || !reserve || !oraclePrice) {
    return <Skeleton />;
  }

  let collateralCap = 'None';
  if (reserve.config instanceof ReserveConfigV2) {
    collateralCap =
      reserve.config.supply_cap === I128MAX
        ? 'None'
        : toBalance(reserve.config.supply_cap, reserve.config.decimals);
  }

  const flexView = viewType !== ViewType.REGULAR ? '0 1 43%' : undefined;

  return (
    <Section width={SectionSize.FULL} sx={{ display: 'flex', flexDirection: 'column' }}>
      <Row sx={{ margin: '6px' }}>
        <Typography
          variant="h3"
          sx={{
            display: 'flex',
            alignItems: 'center',
          }}
          color={theme.palette.text.primary}
        >
          Reserve Configuration
        </Typography>
      </Row>
      <Row
        sx={{
          display: 'flex',
          flexDirection: 'row',
          padding: '6px',
          flexWrap: 'wrap',
          rowGap: '12px',
        }}
      >
        <ReactivityDisplay
          reactivity={reserve.config.reactivity}
          sx={{
            display: 'flex',
            flex: flexView,
          }}
        />
        <StackedText
          title={'Reserve Index'}
          text={reserve.config.index.toString()}
          sx={{
            display: 'flex',
            flex: flexView,
          }}
        />
        <StackedText
          title={'Emission Indexes'}
          text={
            <Box
              sx={{
                display: 'flex',
                flexDirection: 'row',
              }}
            >
              <Typography>Supply</Typography>
              <Typography
                color={theme.palette.lend.main}
                sx={{
                  backgroundColor: theme.palette.lend.opaque,
                  borderRadius: '5px',
                  padding: '2px 6px',
                  margin: '0px 6px',
                }}
              >
                {reserve.getBTokenEmissionIndex().toString()}
              </Typography>

              <Typography>Borrow</Typography>
              <Typography
                color={theme.palette.borrow.main}
                sx={{
                  backgroundColor: theme.palette.borrow.opaque,
                  borderRadius: '5px',
                  padding: '2px 6px',
                  margin: '0px 6px',
                }}
              >
                {reserve.getDTokenEmissionIndex().toString()}
              </Typography>
            </Box>
          }
          tooltip="Emission Indexes are used for claiming pool emissions"
          sx={{
            display: 'flex',
            flex: flexView,
          }}
        />
        <StackedText
          title={'Collateral Cap'}
          text={collateralCap}
          sx={{
            display: 'flex',
            flex: flexView,
          }}
        />
      </Row>
    </Section>
  );
};
