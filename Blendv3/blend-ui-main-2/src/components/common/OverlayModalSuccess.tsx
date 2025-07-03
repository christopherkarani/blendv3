import ArrowForwardIcon from '@mui/icons-material/ArrowForward';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import { Box, Link, Typography, useTheme } from '@mui/material';
import { useWallet } from '../../contexts/wallet';
import { OpaqueButton } from './OpaqueButton';
import { CloseableOverlayProps } from './OverlayModal';

export const OverlayModalSuccess: React.FC<CloseableOverlayProps> = ({ handleCloseOverlay }) => {
  const theme = useTheme();
  const { lastTxHash } = useWallet();

  return (
    <Box
      sx={{
        width: '100%',
        height: '100%',
        top: '0',
        left: '0',
        display: 'flex',
        position: 'fixed',
        justifyContent: 'top',
        alignItems: 'center',
        zIndex: '10',
        flexWrap: 'wrap',
        flexDirection: 'column',
      }}
    >
      <Box
        sx={{
          display: 'flex',
          flexWrap: 'wrap',
          flexDirection: 'column',
          marginTop: '18vh',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <CheckCircleOutlineIcon sx={{ fontSize: '80px', color: theme.palette.primary.main }} />
        <Typography variant="h2" sx={{ margin: '12px' }}>
          Transaction submitted successfully!
        </Typography>
        <Link
          target="_blank"
          href={`${process.env.NEXT_PUBLIC_STELLAR_EXPERT_URL}/tx/${lastTxHash}`}
          underline="hover"
          variant="h5"
          rel="noopener"
        >
          View the transaction details.
        </Link>
        <OpaqueButton
          onClick={handleCloseOverlay}
          palette={theme.palette.primary}
          sx={{
            margin: '6px',
            padding: '6px',
            justifyContent: 'space-between',
            alignItems: 'center',
          }}
        >
          <Box sx={{ padding: '6px', display: 'flex', flexDirection: 'row', height: '30px' }}>
            <Box sx={{ paddingRight: '12px', lineHeight: '100%' }}>Return</Box>
            <Box>
              <ArrowForwardIcon fontSize="inherit" />
            </Box>
          </Box>
        </OpaqueButton>
      </Box>
    </Box>
  );
};
