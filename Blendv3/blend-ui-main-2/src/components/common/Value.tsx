import { Box, SxProps, Typography, useTheme } from '@mui/material';

export interface ValueProps {
  title: any; //  ReactNode | string;
  value: string;
  sx?: SxProps;
}

export const Value: React.FC<ValueProps> = ({ title, value, sx, ...props }) => {
  const theme = useTheme();

  return (
    <Box
      sx={{
        marginLeft: '24px',
        marginBottom: '12px',
        display: 'flex',
        flexDirection: 'row',
        alignItems: 'end',
        gap: '6px',
        ...sx,
      }}
      {...props}
    >
      <Typography variant="h5" sx={{ color: theme.palette.text.secondary }}>
        {title}
      </Typography>
      <Typography variant="h5" sx={{ color: theme.palette.text.primary }}>
        {value}
      </Typography>
    </Box>
  );
};
