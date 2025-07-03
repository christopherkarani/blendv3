import { Box, Typography, useTheme } from '@mui/material';

export interface LabeledTextProps {
  label: string;
  data: string;
  dataColor: string;
}

export const LabeledText: React.FC<LabeledTextProps> = ({ label, data, dataColor, ...props }) => {
  const theme = useTheme();

  const labelColor =
    dataColor == theme.palette.text.primary
      ? theme.palette.text.secondary
      : theme.palette.text.primary;
  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'row',
        justifyContent: 'flex-start',
        alignItems: 'center',
      }}
    >
      <Typography variant="subtitle1" color={labelColor} sx={{ marginRight: '6px' }}>
        {label}
      </Typography>
      <Typography variant="subtitle2" color={dataColor}>
        {data}
      </Typography>
    </Box>
  );
};
