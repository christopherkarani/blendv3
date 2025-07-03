import { Box, Tooltip, useTheme } from '@mui/material';
import { Icon } from './Icon';

export function FlameIcon({
  width = 32,
  height = 32,
  title,
}: {
  width?: number;
  height?: number;
  title?: string;
}) {
  const theme = useTheme();
  const size = Math.min(width, height);
  const iconHeight = Math.floor(size * 0.8);
  // flame icon width is 77% of the of the height
  const iconWidth = Math.floor(size * 0.77 * 0.8);
  return (
    <Tooltip
      disableHoverListener={!title}
      disableFocusListener={!title}
      disableTouchListener={!title}
      title={title || ''}
      placement="top"
      enterTouchDelay={0}
      enterDelay={500}
      leaveTouchDelay={3000}
    >
      <Box
        sx={{
          backgroundColor: theme.palette.primary.opaque,
          color: theme.palette.primary.main,
          borderRadius: '50%',
          margin: '6px',
          width,
          height,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon
          src="/icons/dashboard/flame.svg"
          height={`${iconHeight}px`}
          width={`${iconWidth}px`}
          alt="emmission"
        />
      </Box>
    </Tooltip>
  );
}
