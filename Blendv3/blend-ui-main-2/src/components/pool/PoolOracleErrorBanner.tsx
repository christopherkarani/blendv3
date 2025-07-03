import WarningIcon from '@mui/icons-material/Warning';
import { Box, Typography, useTheme } from '@mui/material';

export const PoolOracleError = () => {
  const theme = useTheme();
  return (
    <Box
      sx={{
        width: '100%',
        display: 'flex',
        margin: '6px',
        padding: '12px',
        justifyContent: 'space-between',
        alignItems: 'center',
        paddingRight: '20px',
        borderRadius: '4px',
        color: theme.palette.warning.main,
        backgroundColor: theme.palette.warning.opaque,
      }}
    >
      <Box sx={{ display: 'flex', justifyContent: 'flex-start', alignItems: 'center' }}>
        <WarningIcon sx={{ marginRight: '6px' }} />
        <Typography variant="body2">
          {"This pool's oracle is currently experiencing issues. Please check back later."}
        </Typography>
      </Box>
    </Box>
  );
};
