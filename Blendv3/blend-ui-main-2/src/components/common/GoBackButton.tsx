import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import { Box, ButtonBase, ButtonBaseProps, Typography, useTheme } from '@mui/material';
import { useRouter } from 'next/router';

export const GoBackButton: React.FC<ButtonBaseProps> = ({ children, sx, ...props }) => {
  const router = useRouter();
  const theme = useTheme();
  return (
    <ButtonBase
      id="go-back-button"
      onClick={() => router.back()}
      sx={{
        marginRight: '12px',
        '&:hover': { backgroundColor: theme.palette.background.default },
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: '6px',
        borderRadius: '5px',
        transition: 'all 0.2s',
        ...sx,
      }}
      {...props}
    >
      <Box sx={{ display: 'flex', flexDirection: 'row', height: '100%' }}>
        <ArrowBackIcon fontSize="inherit" />
        <Typography
          variant="h5"
          sx={{ paddingLeft: '6px', paddingRight: '6px', lineHeight: '100%' }}
        >
          Go back
        </Typography>
      </Box>
    </ButtonBase>
  );
};
