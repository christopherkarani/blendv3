import ArrowDropDownIcon from '@mui/icons-material/ArrowDropDown';
import { Menu, MenuItem, useTheme } from '@mui/material';
import { useRouter } from 'next/router';
import React from 'react';
import { CustomButton } from '../common/CustomButton';
import { PoolComponentProps } from '../common/PoolComponentProps';
import { BackstopHeader } from './BackstopHeader';

export interface BackstopComponentProps extends PoolComponentProps {
  type: 'deposit' | 'q4w';
}

export const BackstopDropdown: React.FC<BackstopComponentProps> = ({ type, poolId }) => {
  const theme = useTheme();
  const router = useRouter();

  const [anchorEl, setAnchorEl] = React.useState<null | HTMLElement>(null);
  const open = Boolean(anchorEl);

  const handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {
    setAnchorEl(event.currentTarget);
  };

  const handleClose = () => {
    setAnchorEl(null);
  };

  const handleSelectItem = (type: 'deposit' | 'q4w') => {
    handleClose();
    if (type == 'deposit') {
      router.push({ pathname: `/backstop-deposit`, query: { poolId: poolId } });
    } else if (type == 'q4w') {
      router.push({ pathname: `/backstop-q4w`, query: { poolId: poolId } });
    }
  };

  return (
    <>
      <CustomButton
        id="backstop-dropdown-button"
        onClick={handleClick}
        sx={{ width: '100%', '&:hover': { backgroundColor: theme.palette.background.default } }}
      >
        <BackstopHeader type={type} />
        <ArrowDropDownIcon sx={{ color: theme.palette.text.secondary }} />
      </CustomButton>
      <Menu
        id="backstop-menu"
        anchorEl={anchorEl}
        open={open}
        onClose={handleClose}
        MenuListProps={{
          'aria-labelledby': 'backstop-dropdown-button',
          sx: { width: '100%' },
        }}
      >
        <MenuItem onClick={() => handleSelectItem('deposit')}>
          <BackstopHeader type="deposit" />
        </MenuItem>
        <MenuItem onClick={() => handleSelectItem('q4w')}>
          <BackstopHeader type="q4w" />
        </MenuItem>
      </Menu>
    </>
  );
};
