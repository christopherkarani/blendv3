import { SectionBase, SectionBaseProps } from './SectionBase';

export enum SectionSize {
  SMALL = 'calc(35.6956% - 12px)',
  LARGE = 'calc(64.3045% - 12px)',
  FULL = 'calc(100% - 12px)',
  TILE = 'calc(50% - 12px)',
  THIRD = 'calc(33.33% - 12px)',
  TWO_THIRD = 'calc(66.67% - 12px)',
  EIGHTY = 'calc(80% - 12px)',
  TWENTY = 'calc(20% - 12px)',
}

export interface SectionProps extends SectionBaseProps {
  width: SectionSize;
  dir?: 'row' | 'column' | undefined;
}

export const Section: React.FC<SectionProps> = ({ children, width, dir, sx, ...props }) => {
  const flexDirection = dir ?? 'row';
  return (
    <SectionBase
      sx={{
        width: width,
        margin: '6px',
        display: 'flex',
        flexDirection: flexDirection,
        padding: '6px',
        ...sx,
      }}
      {...props}
    >
      {children}
    </SectionBase>
  );
};
