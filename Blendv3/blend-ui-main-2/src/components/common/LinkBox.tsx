import { Box, BoxProps } from '@mui/material';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { UrlObject } from 'url';

export interface LinkBoxProps extends BoxProps {
  to: UrlObject;
}

export const LinkBox = ({ to, title, sx, ...props }: LinkBoxProps) => {
  const router = useRouter();

  return (
    <Link href={to} passHref legacyBehavior>
      <Box sx={{ padding: '0', ...sx }} {...props}></Box>
    </Link>
  );
};
