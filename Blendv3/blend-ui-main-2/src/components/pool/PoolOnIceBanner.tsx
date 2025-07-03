import AcUnitIcon from '@mui/icons-material/AcUnit';
import ArrowForwardIcon from '@mui/icons-material/ArrowForward';
import { Box, Typography, useTheme } from '@mui/material';
import { OpaqueButton } from '../common/OpaqueButton';

export const PoolOnIceBanner = () => {
  const theme = useTheme();
  return (
    <OpaqueButton
      onClick={() =>
        window.open(`https://docs.blend.capital/pool-creators/pool-management#on-ice`, '_blank')
      }
      palette={theme.palette.warning}
      sx={{
        width: '100%',
        display: 'flex',
        margin: '6px',
        padding: '12px',
        justifyContent: 'space-between',
        alignItems: 'center',
        paddingRight: '20px',
      }}
    >
      <Box sx={{ display: 'flex', justifyContent: 'flex-start', alignItems: 'center' }}>
        <AcUnitIcon sx={{ marginRight: '6px' }} />
        <Typography variant="body2">
          This pool is on-ice. Borrowing is suspended. You CAN supply, withdraw, and repay.
        </Typography>
      </Box>
      <ArrowForwardIcon fontSize="inherit" />
    </OpaqueButton>
  );
};
