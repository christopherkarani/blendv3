import { Box, BoxProps, Typography } from '@mui/material';
import theme from '../../theme';

export interface StackedApyProps extends BoxProps {
  apyLend: string;
  apyBorrow: string;
}

export const StackedApy: React.FC<StackedApyProps> = ({ apyLend, apyBorrow, sx, ...props }) => {
  return (
    <Box
      sx={{
        width: '100%',
        display: 'flex',
        flexDirection: 'column',
        ...sx,
      }}
      {...props}
    >
      <Box
        sx={{
          padding: '4px',
          display: 'flex',
          flexDirection: 'row',
          justifyContent: 'space-between',
          color: theme.palette.lend.main,
          background: theme.palette.lend.opaque,
          borderRadius: '5px',
        }}
      >
        <Typography variant="body2">{`${apyLend}`}</Typography>
        <Typography variant="body2">S</Typography>
      </Box>
      <Box
        sx={{
          marginTop: '6px',
          padding: '4px',
          display: 'flex',
          flexDirection: 'row',
          justifyContent: 'space-between',
          color: theme.palette.borrow.main,
          background: theme.palette.borrow.opaque,
          borderRadius: '5px',
        }}
      >
        <Typography variant="body2">{`${apyBorrow}`}</Typography>
        <Typography variant="body2">B</Typography>
      </Box>
    </Box>
  );
};
