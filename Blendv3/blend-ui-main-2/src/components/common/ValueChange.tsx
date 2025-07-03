import ArrowForwardIcon from '@mui/icons-material/ArrowForward';
import { Box, BoxProps, Typography, useTheme } from '@mui/material';

export interface ValueChangeProps extends BoxProps {
  title: string;
  curValue: string;
  newValue: string;
}

export const ValueChange: React.FC<ValueChangeProps> = ({
  title,
  curValue,
  newValue,
  sx,
  ...props
}) => {
  const theme = useTheme();

  return (
    <Box
      sx={{
        marginLeft: '24px',
        marginBottom: '12px',
        display: 'flex',
        flexDirection: 'row',
        alignItems: 'center',
        ...sx,
      }}
      {...props}
    >
      <Typography variant="h5" sx={{ color: theme.palette.text.secondary, marginRight: '6px' }}>
        {title}
      </Typography>
      <Typography variant="h5" sx={{ color: theme.palette.text.primary, marginRight: '6px' }}>
        {curValue}
      </Typography>
      <ArrowForwardIcon
        fontSize="inherit"
        sx={{ color: theme.palette.text.primary, marginRight: '6px' }}
      />
      <Typography variant="h5" sx={{ color: theme.palette.text.primary }}>
        {newValue}
      </Typography>
    </Box>
  );
};
