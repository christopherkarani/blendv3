import { Box, Tooltip, Typography, useTheme } from '@mui/material';
import * as formatter from '../../utils/formatter';
import { Icon } from './Icon';

interface RateDisplayParams {
  assetSymbol: string;
  assetRate: number;
  emissionSymbol: string;
  emissionApr: number | undefined;
  rateType: 'earned' | 'charged';
  direction: 'vertical' | 'horizontal';
}

export const RateDisplay = ({
  assetSymbol,
  assetRate,
  emissionSymbol,
  emissionApr,
  rateType,
  direction,
}: RateDisplayParams) => {
  const theme = useTheme();

  const net =
    rateType === 'earned' ? (emissionApr ?? 0) + assetRate : assetRate - (emissionApr ?? 0);
  return (
    <Tooltip
      title={
        <Box sx={{ display: 'flex', flexDirection: 'column' }}>
          <Typography variant="body2">
            {`${assetSymbol} interest ${rateType} ${`${formatter.toPercentage(assetRate)}`}`}
          </Typography>
          {emissionApr && (
            <Typography variant="body2">{`${emissionSymbol} emissions earned ${formatter.toPercentage(
              emissionApr
            )}`}</Typography>
          )}
          <Typography variant="body2">
            {`Net interest ${rateType} ${formatter.toPercentage(net)}`}
          </Typography>
        </Box>
      }
      placement="top"
      enterTouchDelay={0}
      enterDelay={500}
      leaveTouchDelay={3000}
    >
      <Box
        sx={{
          display: 'flex',
          flexDirection: direction === 'vertical' ? 'column' : 'row',
          justifyContent: direction === 'vertical' ? 'center' : 'flex-start',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: direction === 'vertical' ? '0px' : '4px',
        }}
      >
        <Typography variant="body1">{formatter.toPercentage(assetRate)}</Typography>

        {emissionApr !== undefined && emissionApr > 0 && (
          <Box
            sx={{
              display: 'flex',
              flexDirection: 'row',
              borderRadius: '5px',
              paddingLeft: '4px',
              paddingRight: '4px',
              gap: '4px',
              background: theme.palette.primary.opaque,
              alignItems: 'center',
            }}
          >
            <Typography variant="body1" color={theme.palette.primary.main}>
              {formatter.toPercentage(emissionApr)}
            </Typography>
            <Icon
              src="/icons/dashboard/pool_emissions_icon.svg.svg"
              height={`${18}px`}
              width={`${18}px`}
              alt="emzission"
            />
          </Box>
        )}
      </Box>
    </Tooltip>
  );
};
