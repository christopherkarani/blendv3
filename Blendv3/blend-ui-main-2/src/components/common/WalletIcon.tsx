import { IconProps as MuiIconProps } from '@mui/material';
import React from 'react';
import { Icon } from './Icon';

export interface WalletIconProps extends MuiIconProps {
  name: string;
}

export const WalletIcon: React.FC<WalletIconProps> = ({ name, ...props }) => {
  return <Icon src={`/icons/wallets/${name.toLowerCase()}.svg`} alt={`${name}`} {...props} />;
};
