import { Box, BoxProps, PaletteColor, useTheme } from '@mui/material';
import { StackedText } from '../common/StackedText';

export interface StackedTextHLBoxProps extends BoxProps {
  name: string;
  text: string;
  palette: PaletteColor;
}

export const StackedTextHLBox: React.FC<StackedTextHLBoxProps> = ({
  name,
  text,
  palette,
  sx,
  ...props
}) => {
  const theme = useTheme();

  return (
    <Box
      sx={{
        padding: '6px',
        margin: '6px',
        borderRadius: '5px',
        display: 'flex',
        flexDirection: 'row',
        background: theme.palette.background.default,
        ...sx,
      }}
      {...props}
    >
      <StackedText
        title={name}
        text={text}
        sx={{ width: '100%', padding: '6px', color: palette.main }}
      ></StackedText>
      <Box
        sx={{
          position: 'relative',
          right: '-4px',
          width: '8px',
          borderRadius: '0 5px 5px 0',
          background: palette.opaque,
          margin: '-6px',
        }}
      ></Box>
    </Box>
  );
};
