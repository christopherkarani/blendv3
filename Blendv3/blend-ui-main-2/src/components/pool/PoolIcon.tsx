import { IconProps } from '@mui/material';
import React, { useState } from 'react';
import { Icon } from '../common/Icon';

export interface PoolIconProps extends IconProps {
  name: string;
}

export const PoolIcon: React.FC<PoolIconProps> = ({ name, ...props }) => {
  const [imgSrc, setImgSrc] = useState<string>(`/icons/pools/${name.toLowerCase()}.svg`);
  const onError = () => setImgSrc(`/icons/pools/blend.svg`);

  return <Icon src={imgSrc} alt={`${name}`} onError={onError} {...props} />;
};
