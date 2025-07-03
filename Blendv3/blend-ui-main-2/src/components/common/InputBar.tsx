import { Box, BoxProps, Input, PaletteColor, Typography, useTheme } from '@mui/material';
import { ChangeEvent } from 'react';

export interface InputBarProps extends BoxProps {
  symbol: string;
  value: string | undefined;
  onValueChange: (new_value: string) => void;
  palette: PaletteColor;
}

export const InputBar: React.FC<InputBarProps> = ({
  symbol,
  value,
  onValueChange,
  palette,
  sx,
  children,
  ...props
}) => {
  const theme = useTheme();
  /**
   * sanitize input if type is number
   */
  function handleChange(event: ChangeEvent<HTMLInputElement>) {
    const newValue = event.target.value;

    if (newValue !== '') {
      const sanitizedValue = newValue.replace(/[^0-9.\.]/g, '');
      onValueChange(sanitizedValue);
    } else {
      onValueChange(newValue);
    }
  }
  /**
   * sanitize on key down if type is number
   */
  function handleKeyDown(event: React.KeyboardEvent<HTMLInputElement>) {
    const inputHasDecimalPoint = value?.includes('.');
    if (inputHasDecimalPoint && event.key === '.') {
      event.preventDefault();
    }
  }

  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: '3px',
        borderRadius: '5px',
        backgroundColor: theme.palette.accent.main,
        ...sx,
      }}
      {...props}
    >
      <Input
        value={value || ''}
        onChange={handleChange}
        onKeyDown={handleKeyDown}
        placeholder="0"
        disableUnderline={true}
        sx={{ marginLeft: '12px', width: '50%' }}
      />
      <Box
        sx={{
          marginLeft: '12px',
          display: 'flex',
          justifyContent: 'end',
          alignItems: 'center',
          width: '40%',
          gap: '4px',
        }}
      >
        <Typography
          variant="h5"
          sx={{ minWidth: '113px', color: theme.palette.text.secondary, textAlign: 'right' }}
        >
          {symbol}
        </Typography>
        {children}
      </Box>
    </Box>
  );
};
