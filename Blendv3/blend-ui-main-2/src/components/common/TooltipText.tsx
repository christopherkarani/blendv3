import { Box, BoxProps, Tooltip, Typography } from '@mui/material';
import React from 'react';

import { HelpOutline } from '@mui/icons-material';

export interface TooltipTextProps extends BoxProps {
  tooltip: string;
  width: string;
  textColor?: string;
  textVariant?:
    | 'inherit'
    | 'button'
    | 'caption'
    | 'h1'
    | 'h2'
    | 'h3'
    | 'h4'
    | 'h5'
    | 'h6'
    | 'overline'
    | 'subtitle1'
    | 'subtitle2'
    | 'body1'
    | 'body2';
  helpIconColor?: string;
}

export const TooltipText: React.FC<TooltipTextProps> = ({
  tooltip,
  width,
  children,
  textColor = 'text.secondary',
  textVariant = 'body2',
  helpIconColor = 'text.secondary',
  sx,
}) => {
  return (
    <Box width={width}>
      <Tooltip
        title={tooltip}
        placement="top"
        enterTouchDelay={0}
        enterDelay={500}
        leaveTouchDelay={3000}
      >
        <Box
          sx={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            flexDirection: 'row',
            ...sx,
          }}
        >
          <Typography variant={textVariant} color={textColor} align="center">
            {children}
          </Typography>
          <HelpOutline
            sx={{
              color: helpIconColor,
              width: '16px',
              marginLeft: '4px',
              height: '16px',
              marginBottom: '2px', // account for text baseline
            }}
          />
        </Box>
      </Tooltip>
    </Box>
  );
};
