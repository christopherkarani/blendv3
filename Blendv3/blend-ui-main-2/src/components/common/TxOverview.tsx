import { Box, BoxProps, Typography } from '@mui/material';
import theme from '../../theme';
export interface TxOverviewProps extends BoxProps {}

export const TxOverview: React.FC<TxOverviewProps> = ({ children }) => {
  return (
    <Box
      sx={{
        width: '100%',
        display: 'flex',
        flexDirection: 'column',
        backgroundColor: theme.palette.background.paper,
        zIndex: 12,
        borderRadius: '5px',
        '& .MuiAlert-message': {
          width: '100%',
        },
      }}
    >
      <Typography variant="h5" sx={{ marginLeft: '24px', marginBottom: '12px', marginTop: '12px' }}>
        Transaction Overview
      </Typography>
      {children}
    </Box>
  );
};
