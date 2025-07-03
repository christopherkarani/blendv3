import { Skeleton as MuiSkeleton, SkeletonProps } from '@mui/material';
import { SectionSize } from './Section';

export const Skeleton: React.FC<SkeletonProps> = ({ width, height, sx, ...props }) => {
  return (
    <MuiSkeleton
      width={width ?? SectionSize.FULL}
      height={height ?? '50px'}
      sx={{
        padding: '6px',
        margin: '6px',
        borderRadius: '5px',
        ...sx,
      }}
      animation="wave"
      {...props}
    />
  );
};
