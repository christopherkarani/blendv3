import { Auction, AuctionType, Pool } from '@blend-capital/blend-sdk';
import ArrowDropDownIcon from '@mui/icons-material/ArrowDropDown';
import { Box, Collapse, Typography, useTheme } from '@mui/material';
import { useState } from 'react';
import { toCompactAddress } from '../../utils/formatter';
import { PoolComponentProps } from '../common/PoolComponentProps';
import { Row } from '../common/Row';
import { Section, SectionSize } from '../common/Section';
import { StackedTextBox } from '../common/StackedTextBox';
import { OngoingAuctionCardCollapse } from './OngoingAuctionCardCollapse';

export interface OngoingAuctionCardProps extends PoolComponentProps {
  pool: Pool;
  auction: Auction;
  currLedger: number;
  index: number;
}

export const OngoingAuctionCard: React.FC<OngoingAuctionCardProps> = ({
  pool,
  auction,
  sx,
  currLedger,
  index,
}) => {
  const theme = useTheme();
  const [expand, setExpand] = useState(true);
  const [rotateArrow, setRotateArrow] = useState(true);
  const rotate = rotateArrow ? 'rotate(180deg)' : 'rotate(0)';

  return (
    <Section width={SectionSize.FULL} sx={{ flexDirection: 'column', marginBottom: '12px', ...sx }}>
      <Box
        sx={{
          width: '100%',
        }}
      >
        <Row>
          <Box
            sx={{
              margin: '6px',
              padding: '6px',
              display: 'flex',
              flexDirection: 'row',
              alignItems: 'center',
            }}
          >
            <Typography variant="h3" sx={{ marginRight: '12px' }}>
              Auction {toCompactAddress(auction.user)}
            </Typography>
            <Box
              sx={{
                padding: '4px',
                color: theme.palette.positive.main,
                background: theme.palette.positive.opaque,
                borderRadius: '5px',
                lineHeight: '100%',
              }}
            >
              *{AuctionType[auction.type]}*
            </Box>
          </Box>
          <Box
            onClick={() => {
              setExpand(!expand);
              setRotateArrow(!rotateArrow);
            }}
            sx={{
              color: theme.palette.text.secondary,
              margin: '6px',
              padding: '6px',
              display: 'flex',
              flexDirection: 'row',
              alignItems: 'center',
              '&:hover': {
                cursor: 'pointer',
                filter: 'brightness(110%)',
              },
            }}
          >
            {expand ? 'Hide' : 'Show'}
            <ArrowDropDownIcon
              sx={{
                color: theme.palette.text.secondary,
                transform: rotate,
                transition: 'all 0.2s linear',
              }}
            />
          </Box>
        </Row>
        <Row>
          <StackedTextBox name="Start Block" text={`${auction.data.block}`} sx={{ width: '50%' }} />
          <StackedTextBox name="Current Block" text={`${currLedger}`} sx={{ width: '50%' }} />
        </Row>
      </Box>
      <Collapse in={expand} sx={{ width: '100%' }}>
        <OngoingAuctionCardCollapse
          pool={pool}
          auction={auction}
          currLedger={currLedger}
          index={index}
          poolId={pool.id}
          expanded={expand}
        ></OngoingAuctionCardCollapse>
      </Collapse>
    </Section>
  );
};
