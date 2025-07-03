import { Box, BoxProps, Typography } from '@mui/material';
import { WalletIcon } from './WalletIcon';

/// @dev TODO: Consider consolidation of icons / headers

export interface WalletHeaderProps extends BoxProps {
  name: string;
}

export const WalletHeader: React.FC<WalletHeaderProps> = ({ name, sx, ...props }) => {
  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'row',
        justifyContent: 'flex-start',
        alignItems: 'center',
        borderRadius: '5px',
        ...sx,
      }}
      {...props}
    >
      <WalletIcon name={name} sx={{ height: '30px', width: '30px' }} />
      <Typography variant="h3" sx={{ marginLeft: '6px' }}>
        {`${name}`}
      </Typography>
    </Box>
  );
};
