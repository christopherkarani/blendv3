import AcUnitIcon from '@mui/icons-material/AcUnit';
import CheckIcon from '@mui/icons-material/Check';
import SevereColdIcon from '@mui/icons-material/SevereCold';
import { Box, BoxProps, Typography, useTheme } from '@mui/material';
import React from 'react';

export interface PoolStatusBoxProps extends BoxProps {
  type?: 'normal' | 'large' | undefined;
  titleColor?: string | undefined;
  status?: number | undefined;
}

export const PoolStatusBox: React.FC<PoolStatusBoxProps> = ({
  type,
  titleColor,
  status,
  ...props
}) => {
  const theme = useTheme();
  const textType = type ? type : 'normal';
  const textVariant = textType == 'large' ? 'h2' : 'h4';
  const muiTitleColor = titleColor ? titleColor : 'text.secondary';

  let poolStatus = 'Active';
  let statusTextColor = 'backstop.main';
  let statusBackColor = 'backstop.opaque';
  let statusIcon = <CheckIcon />;
  if (status !== undefined && status > 3) {
    poolStatus = 'Frozen';
    statusTextColor = 'error.main';
    statusBackColor = 'error.opaque';
    statusIcon = <SevereColdIcon />;
  } else if (status !== undefined && status > 1) {
    poolStatus = 'On-Ice';
    statusTextColor = 'secondary.main';
    statusBackColor = 'secondary.opaque';
    statusIcon = <AcUnitIcon />;
  }
  return (
    <Box
      sx={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        gap: '6px',
        ...props.sx,
      }}
    >
      <Box
        sx={{
          backgroundColor: theme.palette.background.default,
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <Typography variant="body2" color={muiTitleColor}>
          Pool Status
        </Typography>
        <Typography variant={textVariant} color={theme.palette.text.primary}>
          {poolStatus}
        </Typography>
      </Box>
      <Box sx={{ display: 'flex', flexDirection: 'row' }}>
        <Box
          sx={{
            backgroundColor: statusBackColor,
            color: statusTextColor,
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            width: '30px',
            height: '30px',
            borderRadius: '100px',
            padding: '4px',
          }}
        >
          {statusIcon}
        </Box>
      </Box>
    </Box>
  );
};
