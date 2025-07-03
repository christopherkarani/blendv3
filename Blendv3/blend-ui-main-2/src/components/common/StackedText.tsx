import { Box, BoxProps, Typography } from '@mui/material';
import React, { ReactElement } from 'react';
import { TooltipText } from './TooltipText';

export interface StackedTextProps extends BoxProps {
  title: string;
  text: string | ReactElement;
  type?: 'normal' | 'large' | undefined;
  titleColor?: string | undefined;
  textColor?: string | undefined;
  tooltip?: string;
}

export const StackedText: React.FC<StackedTextProps> = ({
  title,
  text,
  type,
  titleColor,
  textColor,
  tooltip,
  ...props
}) => {
  const textType = type ? type : 'normal';
  const textVariant = textType == 'large' ? 'h2' : 'h4';
  const muiTitleColor = titleColor ? titleColor : 'text.secondary';
  const muiTextColor = textColor ? textColor : 'text.primary';
  const hasTooltip = tooltip !== undefined && tooltip !== '';
  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        alignItems: 'flex-start',
        ...props.sx,
      }}
    >
      {hasTooltip ? (
        <TooltipText tooltip={tooltip} width="auto" textVariant="body2" textColor={muiTitleColor}>
          {title}
        </TooltipText>
      ) : (
        <Typography variant="body2" color={muiTitleColor}>
          {title}
        </Typography>
      )}
      <Typography variant={textVariant} color={muiTextColor}>
        {text}
      </Typography>
    </Box>
  );
};
