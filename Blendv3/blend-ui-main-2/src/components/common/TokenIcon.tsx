import React from 'react';

import { Reserve } from '@blend-capital/blend-sdk';
import { Theme } from '@emotion/react';
import { SxProps } from '@mui/material';
import { useTokenMetadata } from '../../hooks/api';
import { toCompactAddress } from '../../utils/formatter';
import { Icon } from './Icon';
import { LetterIcon } from './LetterIcon';

export interface TokenIconProps {
  reserve: Reserve;
  height?: string;
  width?: string;
  sx?: SxProps<Theme> | undefined;
}
export const TokenIcon: React.FC<TokenIconProps> = ({ reserve, ...props }) => {
  const { data: stellarTokenMetadata } = useTokenMetadata(reserve.assetId);
  const symbol = stellarTokenMetadata?.symbol || toCompactAddress(reserve.assetId);

  if (stellarTokenMetadata?.image) {
    return <Icon src={stellarTokenMetadata.image} alt={symbol} {...props} />;
  } else {
    // return circle with capitalized first letter of the symbol
    return <LetterIcon text={symbol.charAt(0).toUpperCase()} {...props} />;
  }
};
