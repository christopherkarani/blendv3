import { Version } from '@blend-capital/blend-sdk';
import { Box, BoxProps, Typography } from '@mui/material';
import { VersionTag } from '../common/VersionTag';
import { PoolIcon } from './PoolIcon';

export interface PoolHeaderProps extends BoxProps {
  name: string;
  version: Version;
}

export const PoolHeader: React.FC<PoolHeaderProps> = ({ name, version, sx, ...props }) => {
  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'row',
        justifyContent: 'flex-start',
        alignItems: 'center',
        borderRadius: '5px',
        ...sx,
      }}
      {...props}
    >
      <PoolIcon name={name} sx={{ height: '30px', width: '30px', borderRadius: '50%' }} />
      <Typography variant="h3" sx={{ marginLeft: '6px' }}>
        {`${name} Pool`}
      </Typography>

      <VersionTag version={version} sx={{ marginLeft: '6px' }} />
    </Box>
  );
};
