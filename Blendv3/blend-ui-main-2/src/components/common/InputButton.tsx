import { ButtonBaseProps, PaletteColor } from '@mui/material';
import { CustomButton } from './CustomButton';

export interface InputButtonProps extends ButtonBaseProps {
  palette: PaletteColor;
  disabled: boolean;
  text: string;
  width?: string;
  marginRight?: string;
  marginLeft?: string;
}

export const InputButton: React.FC<InputButtonProps> = ({
  palette,
  onClick,
  disabled,
  text,
  children,
  width = '60px',
  marginRight = '2px',
  marginLeft = '6px',
  sx,
  ...props
}) => {
  return (
    <CustomButton
      onClick={onClick}
      disabled={disabled}
      sx={{
        color: palette.main,
        backgroundColor: palette.opaque,
        width: width,
        marginRight: marginRight,
        marginLeft: marginLeft,
        alignItems: 'center',
        justifyContent: 'center',
        ...sx,
      }}
      {...props}
    >
      {text}
    </CustomButton>
  );
};
