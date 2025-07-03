import { HelpOutline } from '@mui/icons-material';
import PriorityHighIcon from '@mui/icons-material/PriorityHigh';
import { Box, BoxProps, CircularProgress, Tooltip, useTheme } from '@mui/material';
import React from 'react';

export interface BorrowCapRingProps extends BoxProps {
  borrowLimit: number | undefined;
}

export const BorrowCapRing: React.FC<BorrowCapRingProps> = ({ borrowLimit }) => {
  const theme = useTheme();

  const capacityPercentage = Math.round(Number(((borrowLimit ?? 0) * 100).toFixed(2)));

  function getIconByCapacity(capacity: number) {
    if (capacity > 80) {
      return (
        <>
          <PriorityHighIcon
            sx={{
              position: 'absolute',
              left: 'calc(20% - 5.5px)',
            }}
            fontSize="small"
            color="error"
          />
          <PriorityHighIcon
            sx={{
              position: 'absolute',
              left: 'calc(20% + 1px)',
            }}
            fontSize="small"
            color="error"
          />
        </>
      );
    } else if (capacity > 50) {
      return (
        <PriorityHighIcon
          fontSize="small"
          color="warning"
          sx={{
            position: 'absolute',
          }}
        />
      );
    } else {
      return <></>;
    }
  }

  function getBackgroundByCapacity(capacity: number) {
    if (capacity > 80) {
      return theme.palette.error.opaque;
    } else if (capacity > 50) {
      return theme.palette.warning.opaque;
    } else {
      return theme.palette.primary.opaque;
    }
  }

  function getColorByCapacity(capacity: number) {
    if (capacity > 80) {
      return theme.palette.error.main;
    } else if (capacity > 50) {
      return theme.palette.warning.main;
    } else {
      return theme.palette.primary.main;
    }
  }
  return (
    <Tooltip
      title="The percentage of your borrow capacity being used."
      placement="top"
      enterTouchDelay={0}
      enterDelay={500}
      leaveTouchDelay={3000}
    >
      <Box
        sx={{
          display: 'flex',
          flexDirection: 'row',
          justifyContent: 'flex-start',
        }}
      >
        <Box
          sx={{
            position: 'relative',
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            width: '40px',
          }}
        >
          <CircularProgress
            sx={{
              color: getColorByCapacity(capacityPercentage),
              position: 'absolute',
            }}
            size="30px"
            thickness={4.5}
            variant="determinate"
            value={capacityPercentage}
          />
          <CircularProgress
            sx={{
              color: getBackgroundByCapacity(capacityPercentage),
              position: 'absolute',
            }}
            size="30px"
            thickness={4.5}
            variant="determinate"
            value={100}
          />
          <Box
            style={{
              position: 'relative',
              width: '24px',
              height: '24px',
              padding: 'none !important',
              background: 'transparent',
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            {getIconByCapacity(capacityPercentage)}
          </Box>
        </Box>
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'flex-start',
          }}
        >
          <HelpOutline
            sx={{ color: theme.palette.text.secondary, width: '15px', marginTop: '-4px' }}
          />
          <Box
            sx={{
              color: getColorByCapacity(capacityPercentage),
              background: getBackgroundByCapacity(capacityPercentage),
              fontSize: '16px',
              width: 'max-content',
              lineHeight: '16px',
              padding: '2px',
              borderRadius: '4px',
              boxSizing: 'border-box',
            }}
          >
            {capacityPercentage}
          </Box>
        </Box>
      </Box>
    </Tooltip>
  );
};
