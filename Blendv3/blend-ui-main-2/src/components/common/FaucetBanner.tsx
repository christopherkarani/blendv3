import ArrowForwardIcon from '@mui/icons-material/ArrowForward';
import WaterDropOutlinedIcon from '@mui/icons-material/WaterDropOutlined';
import { Alert, Box, Snackbar, Typography, useTheme } from '@mui/material';
import React from 'react';
import { useWallet } from '../../contexts/wallet';
import { useHorizonAccount, usePool, usePoolMeta, useTokenMetadataList } from '../../hooks/api';
import { requiresTrustline } from '../../utils/horizon';
import { OpaqueButton } from './OpaqueButton';

interface FaucetBannerParams {
  poolId: string;
}

export const FaucetBanner = ({ poolId }: FaucetBannerParams) => {
  const theme = useTheme();
  const { faucet, connected } = useWallet();
  const [openCon, setOpenCon] = React.useState(false);

  const { data: poolMeta } = usePoolMeta(poolId);
  const { data: pool } = usePool(poolMeta);
  const { data: horizonAccount } = useHorizonAccount();
  const reserveList = Array.from(pool?.reserves.keys() ?? []);
  const tokenMetadataList = useTokenMetadataList(reserveList);

  let needsFaucet = false;
  if (connected && pool && horizonAccount) {
    for (const { data: tokenMetadata } of tokenMetadataList) {
      if (tokenMetadata?.asset && !needsFaucet) {
        needsFaucet = requiresTrustline(horizonAccount, tokenMetadata.asset);
      }
    }
  }

  const handleSnackClose = () => {
    setOpenCon(false);
  };

  const handleFaucet = async () => {
    if (connected) {
      await faucet();
      setOpenCon(true);
    }
  };

  return (
    <>
      {needsFaucet ? (
        <OpaqueButton
          onClick={() => {
            handleFaucet();
          }}
          palette={theme.palette.positive}
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
            <WaterDropOutlinedIcon sx={{ marginRight: '6px' }} />
            <Typography variant="body2">
              Click here to receive assets for the Blend test network.
            </Typography>
          </Box>
          <ArrowForwardIcon fontSize="inherit" />
        </OpaqueButton>
      ) : (
        <></>
      )}

      <Snackbar
        open={openCon}
        autoHideDuration={4000}
        onClose={handleSnackClose}
        anchorOrigin={{
          vertical: 'bottom',
          horizontal: 'right',
        }}
      >
        <Alert
          onClose={handleSnackClose}
          severity="success"
          sx={{
            backgroundColor: theme.palette.primary.opaque,
            alignItems: 'center',
            width: '100%',
          }}
        >
          Test network assets added to wallet.
        </Alert>
      </Snackbar>
    </>
  );
};
