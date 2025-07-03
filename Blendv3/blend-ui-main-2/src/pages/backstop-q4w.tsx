import { BackstopPoolEst, BackstopPoolUserEst } from '@blend-capital/blend-sdk';
import { Box, Typography, useTheme } from '@mui/material';
import type { NextPage } from 'next';
import { useRouter } from 'next/router';
import { BackstopAPR } from '../components/backstop/BackstopAPR';
import { BackstopDropdown } from '../components/backstop/BackstopDropdown';
import { BackstopQueueAnvil } from '../components/backstop/BackstopQueueAnvil';
import { BackstopQueueMod } from '../components/backstop/BackstopQueueMod';
import { GoBackHeader } from '../components/common/GoBackHeader';
import { Row } from '../components/common/Row';
import { Section, SectionSize } from '../components/common/Section';
import { StackedText } from '../components/common/StackedText';
import { NotPoolBar } from '../components/pool/NotPoolBar';
import { useBackstop, useBackstopPool, useBackstopPoolUser, usePoolMeta } from '../hooks/api';
import { NOT_BLEND_POOL_ERROR_MESSAGE } from '../hooks/types';
import { toBalance, toPercentage } from '../utils/formatter';

const BackstopQ4W: NextPage = () => {
  const theme = useTheme();
  const router = useRouter();

  const { poolId } = router.query;
  const safePoolId = typeof poolId == 'string' && /^[0-9A-Z]{56}$/.test(poolId) ? poolId : '';

  const { data: poolMeta, error: poolError } = usePoolMeta(safePoolId);
  const { data: backstop } = useBackstop(poolMeta?.version);
  const { data: backstopPoolData } = useBackstopPool(poolMeta);
  const { data: userBackstopPoolData } = useBackstopPoolUser(poolMeta);

  const backstopPoolEst =
    backstop !== undefined && backstopPoolData !== undefined
      ? BackstopPoolEst.build(backstop.backstopToken, backstopPoolData.poolBalance)
      : undefined;

  const backstopUserEst =
    userBackstopPoolData !== undefined && backstop !== undefined && backstopPoolData !== undefined
      ? BackstopPoolUserEst.build(backstop, backstopPoolData, userBackstopPoolData)
      : undefined;

  if (poolError?.message === NOT_BLEND_POOL_ERROR_MESSAGE) {
    return <NotPoolBar poolId={safePoolId} />;
  }

  return (
    <>
      <Row>
        <GoBackHeader poolId={safePoolId} />
      </Row>
      <Row>
        <Section width={SectionSize.FULL} sx={{ marginTop: '12px', marginBottom: '12px' }}>
          <BackstopDropdown type="q4w" poolId={safePoolId} />
        </Section>
      </Row>
      <Row>
        <Section width={SectionSize.FULL} sx={{ padding: '12px' }}>
          <Box
            sx={{
              width: '100%',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              padding: '6px',
            }}
          >
            <Box sx={{ display: 'flex', flexDirection: 'row' }}>
              <Typography variant="h5" sx={{ marginRight: '6px' }}>
                Available to queue
              </Typography>
              <Typography variant="h4" sx={{ color: theme.palette.backstop.main }}>
                {toBalance(backstopUserEst?.tokens)}
              </Typography>
            </Box>
            <Box>
              <Typography variant="h5" sx={{ color: theme.palette.text.secondary }}>
                BLND-USDC LP
              </Typography>
            </Box>
          </Box>
        </Section>
      </Row>
      <Row>
        <Section width={SectionSize.THIRD} sx={{ alignItems: 'center' }}>
          <BackstopAPR poolId={safePoolId} />
        </Section>
        <Section width={SectionSize.THIRD}>
          <StackedText
            title="Q4W"
            text={toPercentage(backstopPoolEst?.q4wPercentage)}
            sx={{ width: '100%', padding: '6px' }}
            tooltip="Percent of capital insuring this pool queued for withdrawal (Q4W). A higher percent indicates potential risks."
          ></StackedText>
        </Section>
        <Section width={SectionSize.THIRD}>
          <StackedText
            title="Total Deposited"
            text={`$${toBalance(backstopPoolEst?.totalSpotValue)}`}
            sx={{ width: '100%', padding: '6px' }}
          ></StackedText>
        </Section>
      </Row>
      <BackstopQueueAnvil poolId={safePoolId} />
      <BackstopQueueMod poolId={safePoolId} />
    </>
  );
};

export default BackstopQ4W;
