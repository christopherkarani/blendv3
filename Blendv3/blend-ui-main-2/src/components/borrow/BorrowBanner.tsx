import { Circle } from '@mui/icons-material';
import { Box, Typography } from '@mui/material';
import theme from '../../theme';
import { toBalance } from '../../utils/formatter';
import { Banner } from '../common/Banner';
export interface BorrowBannerProps {
  totalBorrowed: number;
}

export function BorrowBanner({ totalBorrowed }: BorrowBannerProps) {
  return (
    <Banner sx={{ background: theme.palette.borrow.opaque }}>
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'space-between',
          width: '100%',
        }}
      >
        <Typography
          sx={{ display: 'flex', gap: '4px', alignItems: 'center' }}
          variant="body2"
          color={theme.palette.text.primary}
        >
          <Circle fontSize="inherit" sx={{ width: '8px', color: theme.palette.borrow.main }} />
          Your borrowed positions
        </Typography>
        <Typography sx={{ display: 'flex' }} variant="body2" color={theme.palette.borrow.main}>
          Total borrowed {`$${toBalance(totalBorrowed ?? 0)}`}
        </Typography>
      </Box>
    </Banner>
  );
}
