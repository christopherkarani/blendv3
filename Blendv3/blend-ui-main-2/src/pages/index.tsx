import { Version } from '@blend-capital/blend-sdk';
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined';
import { Box, Typography, useTheme } from '@mui/material';
import type { NextPage } from 'next';
import { useEffect, useState } from 'react';
import { Divider } from '../components/common/Divider';
import { Row } from '../components/common/Row';
import { Section, SectionSize } from '../components/common/Section';
import { SectionBase } from '../components/common/SectionBase';
import { ToggleSlider } from '../components/common/ToggleSlider';
import { MarketCard } from '../components/markets/MarketCard';
import { useSettings } from '../contexts';
import { useBackstop } from '../hooks/api';

const Markets: NextPage = () => {
  const theme = useTheme();
  const { blockedPools, isV2Enabled, lastPool } = useSettings();

  const [currentIndex, setCurrentIndex] = useState(0);
  const [version, setVersion] = useState<Version | undefined>(undefined);

  const { data: backstop } = useBackstop(version);

  useEffect(() => {
    if (isV2Enabled && lastPool?.version) {
      setVersion(lastPool.version);
    } else {
      setVersion(Version.V2);
    }
  }, [isV2Enabled, lastPool]);

  const rewardZone = [...(backstop?.config?.rewardZone ?? [])].reverse();
  const safeRewardZone = rewardZone.filter((poolId) => !blockedPools.includes(poolId));

  function handlePoolLoaded(index: number) {
    if (index >= currentIndex) {
      setCurrentIndex(Math.min(currentIndex + 1, safeRewardZone.length));
    }
  }

  return (
    <>
      <Row sx={{ alignItems: 'center' }}>
        <SectionBase type="alt" sx={{ margin: '6px', padding: '6px' }}>
          Markets
        </SectionBase>
        {isV2Enabled && version !== undefined && (
          <ToggleSlider
            options={[
              { optionName: Version.V1, palette: theme.palette.primary },
              { optionName: Version.V2, palette: theme.palette.backstop },
            ]}
            selected={version}
            changeState={setVersion}
            sx={{ height: '24px', width: '80px' }}
          />
        )}
      </Row>
      <Divider />
      {safeRewardZone.length === 0 && (
        <Section
          width={SectionSize.FULL}
          sx={{
            background: theme.palette.info.opaque,
            color: theme.palette.text.primary,
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
            <InfoOutlinedIcon />
            <Typography variant="body2">No pools in the reward zone</Typography>
          </Box>
        </Section>
      )}
      {safeRewardZone.slice(0, currentIndex + 1).map((poolId, index) => {
        return (
          <MarketCard
            key={poolId}
            poolId={poolId}
            index={index}
            onLoaded={handlePoolLoaded}
          ></MarketCard>
        );
      })}
    </>
  );
};

export default Markets;
