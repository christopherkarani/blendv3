import ArrowForwardIcon from '@mui/icons-material/ArrowForward';
import SevereColdIcon from '@mui/icons-material/SevereCold';
import { Box, Typography, useTheme } from '@mui/material';
import { OpaqueButton } from '../common/OpaqueButton';

export const PoolFrozenBanner = () => {
  const theme = useTheme();

  return (
    <OpaqueButton
      onClick={() =>
        window.open(`https://docs.blend.capital/pool-creators/pool-management#frozen`, '_blank')
      }
      palette={theme.palette.error}
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
        <SevereColdIcon sx={{ marginRight: '6px' }} />
        <Typography variant="body2">
          This pool is frozen. Supplying and borrowing are suspended. You CAN withdraw and repay.
        </Typography>
      </Box>
      <ArrowForwardIcon fontSize="inherit" />
    </OpaqueButton>
  );
};
