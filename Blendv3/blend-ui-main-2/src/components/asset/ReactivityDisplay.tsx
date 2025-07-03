import { Box, BoxProps, useTheme } from '@mui/material';
import React from 'react';
import { StackedText } from '../common/StackedText';

export interface ReactivityDisplayProps extends BoxProps {
  reactivity: number;
}

export const ReactivityDisplay: React.FC<ReactivityDisplayProps> = ({ reactivity, sx }) => {
  const theme = useTheme();

  let reactivityLevel = 'None';
  let reactivityColor = theme.palette.text.disabled;
  if (reactivity > 200) {
    reactivityLevel = 'High';
    reactivityColor = theme.palette.error.main;
  } else if (reactivity > 100) {
    reactivityLevel = 'Medium';
    reactivityColor = theme.palette.warning.main;
  } else if (reactivity > 0) {
    reactivityLevel = 'Low';
    reactivityColor = theme.palette.primary.main;
  }

  return (
    <Box
      sx={{
        width: '100px',
        display: 'flex',
        flexDirection: 'row',
        justifyContent: 'flex-start',
        ...sx,
      }}
    >
      <StackedText
        title="Reactivity"
        text={reactivityLevel}
        textColor={reactivityColor}
        type="large"
        tooltip={`The reactivity value (${reactivity}) dictates how quickly the rate modifier changes. The rate modifier increases when utilization is above target, and decreases when utilization is below target.`}
      />
    </Box>
  );
};
