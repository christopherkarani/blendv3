import { ButtonProps, useTheme } from '@mui/material';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { UrlObject } from 'url';
import { ToggleButton } from '../common/ToggleButton';

export interface INavItemProps extends ButtonProps {
  to: UrlObject;
  title: string;
}

export const NavItem = ({ to, title, sx, ...props }: INavItemProps) => {
  const theme = useTheme();
  const router = useRouter();
  const active = to.pathname == router.route;

  return (
    <Link href={to} passHref legacyBehavior>
      <ToggleButton
        active={active}
        palette={theme.palette.primary}
        sx={{ margin: '0px 6px 0px', ...sx }}
        {...props}
      >
        {title}
      </ToggleButton>
    </Link>
  );
};
