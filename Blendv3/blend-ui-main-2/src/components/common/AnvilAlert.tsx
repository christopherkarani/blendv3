import { Alert, AlertColor, Box, Typography } from '@mui/material';

export interface AnvilAlertProps {
  severity?: AlertColor;
  message?: string;
  extraContent?: React.ReactNode;
}
export function AnvilAlert({ severity, message, extraContent }: AnvilAlertProps) {
  return (
    <Box
      sx={{
        display: 'flex',
        gap: '1rem',
        flexDirection: 'column',
        '& .MuiAlert-message': {
          width: '100%',
        },
      }}
    >
      <Alert
        severity={severity}
        sx={{
          display: 'flex',
          justifyContent: 'flex-start',
          alignItems: !!extraContent ? 'start' : 'center',
          width: '100%',
        }}
      >
        <Typography variant="body2">{message || 'An error has ocurred'}</Typography>
        {!!extraContent && (
          <Box sx={{ display: 'flex', gap: '1rem', width: '100%', flexDirection: 'column' }}>
            {extraContent}
          </Box>
        )}
      </Alert>
    </Box>
  );
}
