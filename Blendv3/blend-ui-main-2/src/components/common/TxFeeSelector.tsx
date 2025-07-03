import ArrowDropDownIcon from '@mui/icons-material/ArrowDropDown';
import ArrowDropUpIcon from '@mui/icons-material/ArrowDropUp';
import { Box, BoxProps, Menu, MenuItem, Skeleton, Tooltip, Typography } from '@mui/material';
import React from 'react';
import { useWallet } from '../../contexts/wallet';
import { useFeeStats } from '../../hooks/api';
import theme from '../../theme';
import { CustomButton } from './CustomButton';

export interface TxFeeSelectorProps extends BoxProps {}

export const TxFeeSelector: React.FC<TxFeeSelectorProps> = () => {
  const { txInclusionFee, setTxInclusionFee } = useWallet();
  const { data: feeStats } = useFeeStats();

  const [anchorEl, setAnchorEl] = React.useState<null | HTMLElement>(null);
  const open = Boolean(anchorEl);
  const handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {
    setAnchorEl(event.currentTarget);
  };

  const handleClose = () => {
    setAnchorEl(null);
  };

  if (feeStats === undefined) {
    return <Skeleton />;
  }

  const lowFeeXLM = Number(feeStats.low) / 1e7;
  const mediumFeeXLM = Number(feeStats.medium) / 1e7;
  const highFeeXLM = Number(feeStats.high) / 1e7;

  return (
    <>
      <Tooltip
        title={
          'The priority fee is the maximum amount you are willing to pay to be included in the next ledger, in XLM.'
        }
        placement="top"
        enterTouchDelay={0}
        enterDelay={500}
        leaveTouchDelay={3000}
      >
        <Box sx={{ display: 'flex', flexDirection: 'row', alignItems: 'center' }}>
          <Box
            sx={{
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
              flexDirection: 'row',
            }}
          >
            <Typography variant={'body1'} color={'text.secondary'} align="center">
              Priority Fee
            </Typography>
          </Box>
          <CustomButton
            id="fee-dropdown-button"
            onClick={handleClick}
            sx={{ padding: '4px', '&:hover': { color: 'white' } }}
          >
            <Box
              sx={{
                display: 'flex',
                flexDirection: 'row',
                justifyContent: 'flex-start',
                alignItems: 'center',
                color: theme.palette.text.secondary,
                '&:hover': { color: 'white' },
              }}
            >
              <Typography variant="body1">{`${txInclusionFee.type}`}</Typography>
              {open ? <ArrowDropUpIcon /> : <ArrowDropDownIcon />}
            </Box>
          </CustomButton>
        </Box>
      </Tooltip>
      <Menu
        id="fee-menu"
        anchorEl={anchorEl}
        open={open}
        onClose={handleClose}
        MenuListProps={{
          'aria-labelledby': 'fee-dropdown-button',
        }}
      >
        <MenuItem
          onClick={() => {
            setTxInclusionFee({ type: 'Low', fee: feeStats.low });
            handleClose();
          }}
          sx={{
            display: 'flex',
            flexDirection: 'row',
            justifyContent: 'flex-start',
            alignItems: 'center',
            borderRadius: '5px',
          }}
        >
          <Typography variant="body1">{`Low (${lowFeeXLM} XLM)`}</Typography>
        </MenuItem>
        <MenuItem
          onClick={() => {
            setTxInclusionFee({ type: 'Medium', fee: feeStats.medium });
            handleClose();
          }}
          sx={{
            display: 'flex',
            flexDirection: 'row',
            justifyContent: 'flex-start',
            alignItems: 'center',
            borderRadius: '5px',
          }}
        >
          <Typography variant="body1">{`Medium (${mediumFeeXLM} XLM)`}</Typography>
        </MenuItem>
        <MenuItem
          onClick={() => {
            setTxInclusionFee({ type: 'High', fee: feeStats.high });
            handleClose();
          }}
          sx={{
            display: 'flex',
            flexDirection: 'row',
            justifyContent: 'flex-start',
            alignItems: 'center',
            borderRadius: '5px',
          }}
        >
          <Typography variant="body1">{`High (${highFeeXLM} XLM)`}</Typography>
        </MenuItem>
      </Menu>
    </>
  );
};
