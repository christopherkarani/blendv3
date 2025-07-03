import WarningIcon from '@mui/icons-material/Warning';
import { Box, Typography, useTheme } from '@mui/material';
import { toCompactAddress } from '../../utils/formatter';
import { PoolComponentProps } from '../common/PoolComponentProps';
import { Section, SectionSize } from '../common/Section';

export const NotPoolBar: React.FC<PoolComponentProps> = ({ poolId }) => {
  const theme = useTheme();

  return (
    <Section
      width={SectionSize.FULL}
      sx={{
        background: theme.palette.warning.opaque,
        color: theme.palette.warning.main,
        display: 'flex',
        justifyContent: 'flex-start',
        alignItems: 'center',
        padding: '12px',
      }}
    >
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'flex-start',
          alignItems: 'center',
          gap: '6px',
        }}
      >
        <WarningIcon />
        <Typography variant="body2">
          {`${toCompactAddress(poolId)} is not a valid Blend Pool.`}
        </Typography>
      </Box>
    </Section>
  );
};
