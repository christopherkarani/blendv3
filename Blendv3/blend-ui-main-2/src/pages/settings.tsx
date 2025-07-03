import RemoveCircleOutlineIcon from '@mui/icons-material/RemoveCircleOutline';
import { Box, Input, Typography } from '@mui/material';
import { Horizon, rpc } from '@stellar/stellar-sdk';
import { useEffect, useState } from 'react';
import packageJSON from '../../package.json';
import { Divider } from '../components/common/Divider';
import { OpaqueButton } from '../components/common/OpaqueButton';
import { Row } from '../components/common/Row';
import { TrackedPool } from '../components/pool/TrackedPool';
import { useSettings } from '../contexts';
import { useWallet } from '../contexts/wallet';
import { usePoolMeta } from '../hooks/api';
import theme from '../theme';

export default function SettingsPage() {
  const { getNetworkDetails, walletId } = useWallet();
  const { network, setNetwork, setDefaultNetwork, trackPool, untrackPool, trackedPools } =
    useSettings();

  const [newNetworkRPCUrl, setNewNetworkRPCUrl] = useState<string>('');
  const [newHorizonUrl, setNewHorizonUrl] = useState<string>('');
  const [safeRpcUrl, setSafeRpcUrl] = useState<string>('');
  const [safeHorizonUrl, setSafeHorizonUrl] = useState<string>('');
  const [canUpdateNetwork, setCanUpdateNetwork] = useState(false);
  const [updateNetworkMessage, setUpdateNetworkMessage] = useState<string>('');
  const [loadingNewNetwork, setLoadingNewNetwork] = useState(false);
  const [newOpts, setNewOpts] = useState<rpc.Server.Options | undefined>(undefined);
  const [poolToAdd, setPoolToAdd] = useState<string>('');
  const [poolIdError, setPoolIdError] = useState('');
  const { data: poolMeta } = usePoolMeta(poolToAdd, poolToAdd.length > 0);

  function fetchFromWallet() {
    getNetworkDetails().then((networkDetails) => {
      if (networkDetails.rpc) {
        handleChangeRpcUrl(networkDetails.rpc);
        setNewHorizonUrl(networkDetails.horizonUrl);
      }
    });
  }

  function handleUpdateNetworkClick() {
    if (safeRpcUrl && safeHorizonUrl) {
      setNetwork(safeRpcUrl, safeHorizonUrl, newOpts);
      setNewHorizonUrl('');
      setNewNetworkRPCUrl('');
      setLoadingNewNetwork(false);
      setCanUpdateNetwork(false);
      setNewOpts(undefined);
    }
  }

  function handleChangeRpcUrl(rpcUrl: string) {
    setNewNetworkRPCUrl(rpcUrl);
  }

  function handleAddTrackedPool(poolId: string) {
    if (poolMeta && poolMeta.id === poolId) {
      trackPool(poolMeta);
      setPoolToAdd('');
    } else {
      setPoolIdError('Pool not found.');
    }
  }

  function handleChangePoolToAdd(poolId: string) {
    setPoolToAdd(poolId);
  }

  const validatePoolId = (poolId: string) => {
    const safePoolId =
      typeof poolId == 'string' && /^[0-9A-Z]{56}$/.test(poolId) ? poolId : undefined;
    if (poolId.length === 0) {
      setPoolIdError('');
      return;
    }

    if (!safePoolId) {
      setPoolIdError(
        'Invalid contract address. Contract addresses begin with "C" and are 56 characters long.'
      );
    } else if (trackedPools.find((pool) => pool.id === safePoolId)) {
      setPoolIdError('Pool is already tracked.');
      return;
    } else {
      setPoolIdError('');
    }
  };

  const validateURLInputs = async (rpcUrl: string, horizonUrl: string) => {
    setLoadingNewNetwork(true);
    if (rpcUrl === '' || horizonUrl === '') {
      setCanUpdateNetwork(false);
      setUpdateNetworkMessage('');
      setLoadingNewNetwork(false);
      return;
    }
    let opts = undefined;
    if (rpcUrl.startsWith('http://')) {
      opts = { allowHttp: true };
    }

    // validate RPC URL
    let sanitizedRpcUrl = rpcUrl;
    try {
      const url = new URL(rpcUrl);
      sanitizedRpcUrl = url.toString();
      const rpcServer = new rpc.Server(sanitizedRpcUrl, opts);
      const defaultInfo = await rpcServer.getNetwork();
      if (defaultInfo.passphrase !== network.passphrase) {
        setCanUpdateNetwork(false);
        setUpdateNetworkMessage('The RPC server does not use the same network.');
        setLoadingNewNetwork(false);
        return;
      }
    } catch (e) {
      setCanUpdateNetwork(false);
      setUpdateNetworkMessage('Failed to validate RPC URL.');
      setLoadingNewNetwork(false);
      return;
    }

    // validate Horizon URL
    let sanitizedHorizonUrl = horizonUrl;
    try {
      const url = new URL(horizonUrl);
      sanitizedHorizonUrl = url.toString();
      const horizonServer = new Horizon.Server(sanitizedHorizonUrl, opts);
      const defaultInfo = await horizonServer.root();
      if (defaultInfo.network_passphrase !== network.passphrase) {
        setCanUpdateNetwork(false);
        setUpdateNetworkMessage('The Horizon server does not use the same network.');
        setLoadingNewNetwork(false);
        return;
      }
    } catch (e) {
      setCanUpdateNetwork(false);
      setUpdateNetworkMessage('Failed to validate Horizon URL.');
      setLoadingNewNetwork(false);
      return;
    }

    // both URLs valid
    setNewOpts(opts);
    setSafeRpcUrl(sanitizedRpcUrl);
    setSafeHorizonUrl(sanitizedHorizonUrl);
    setCanUpdateNetwork(true);
    setUpdateNetworkMessage('');
    setLoadingNewNetwork(false);
  };

  useEffect(() => {
    const handler = setTimeout(() => {
      validatePoolId(poolToAdd);
    }, 500);

    return () => {
      clearTimeout(handler);
    };
  }, [poolToAdd, trackedPools]);

  useEffect(() => {
    const handler = setTimeout(async () => {
      await validateURLInputs(newNetworkRPCUrl, newHorizonUrl);
    }, 500);

    return () => {
      clearTimeout(handler);
    };
  }, [newNetworkRPCUrl, newHorizonUrl]);

  return (
    <>
      <>
        <Row sx={{ margin: '12px', padding: '12px' }}>
          <Typography variant="h1">UI Release</Typography>
        </Row>
        <Divider />
        <Row sx={{ margin: '12px', padding: '12px', flexDirection: 'column', gap: '1rem' }}>
          <Typography variant="h2">Version</Typography>
          <Typography variant="h3" sx={{ color: theme.palette.text.secondary }}>
            {packageJSON.version}
          </Typography>
        </Row>
        <Row sx={{ margin: '12px', padding: '12px' }}>
          <Typography variant="h1">Network Configuration</Typography>
        </Row>
        <Divider />
        {!!network.rpc && (
          <Row sx={{ gap: '1rem', flexDirection: 'column', margin: '12px', padding: '12px' }}>
            <Typography variant="h2">Current Network Details</Typography>
            <Typography variant="h3">RPC Url</Typography>
            <Typography variant="h4" sx={{ color: theme.palette.text.secondary }}>
              {network.rpc}
            </Typography>
            <Typography variant="h3">Horizon Url</Typography>
            <Typography variant="h4" sx={{ color: theme.palette.text.secondary }}>
              {network.horizonUrl}
            </Typography>
            {(network.rpc !== process.env.NEXT_PUBLIC_RPC_URL ||
              network.horizonUrl !== process.env.NEXT_PUBLIC_HORIZON_URL) && (
              <OpaqueButton
                sx={{ width: '20rem', margin: 'auto' }}
                palette={theme.palette.warning}
                onClick={setDefaultNetwork}
              >
                Use Default Network
              </OpaqueButton>
            )}
          </Row>
        )}
        <Divider />
        <Row
          sx={{
            flexDirection: 'column',
            gap: '1rem',
            alignItems: 'start',
            margin: '12px',
            padding: '12px',
          }}
        >
          <Typography variant="h2">Update Network Details</Typography>

          <Row sx={{ flexDirection: 'column', display: 'flex', gap: '1rem' }}>
            <Input
              placeholder="Input RPC Url"
              type="text"
              value={newNetworkRPCUrl}
              onChange={(e) => handleChangeRpcUrl(e.target.value)}
            />
            <Input
              placeholder="Input Horizon Url"
              type="text"
              value={newHorizonUrl}
              onChange={(e) => setNewHorizonUrl(e.target.value)}
            />
            {walletId === 'freighter' && (
              <OpaqueButton
                sx={{ width: '20rem', margin: 'auto' }}
                palette={{
                  main: theme.palette.text.primary,
                  opaque: theme.palette.menu.light,
                  contrastText: theme.palette.text.primary,
                  light: theme.palette.text.secondary,
                  dark: theme.palette.text.secondary,
                }}
                onClick={fetchFromWallet}
              >
                Fetch from Wallet
              </OpaqueButton>
            )}
            {!canUpdateNetwork && updateNetworkMessage !== '' && (
              <Typography variant="body2" color="error">
                {updateNetworkMessage}
              </Typography>
            )}
            <OpaqueButton
              sx={{ width: '20rem', margin: 'auto' }}
              palette={theme.palette.primary}
              onClick={handleUpdateNetworkClick}
              disabled={!canUpdateNetwork || loadingNewNetwork}
            >
              {loadingNewNetwork ? 'Loading...' : 'Update Network'}
            </OpaqueButton>
          </Row>
        </Row>
        <Row sx={{ margin: '12px', padding: '12px' }}>
          <Typography variant="h1">Tracked Pools</Typography>
        </Row>
        <Divider />
        {trackedPools.length > 0 &&
          trackedPools.map((pool) => (
            <Box
              key={pool.id}
              sx={{
                width: '100%',
                display: 'flex',
                marginBottom: '6px',
                paddingBottom: '6px',
                justifyContent: 'space-between',
                alignItems: 'center',
                borderRadius: '5px',
              }}
            >
              <TrackedPool
                key={pool.id}
                name={pool.name}
                id={pool.id}
                version={pool.version}
                sx={{ flex: 1 }}
              />
              <OpaqueButton
                onClick={() => untrackPool(pool.id)}
                palette={theme.palette.error}
                sx={{ display: 'flex', alignSelf: 'center' }}
              >
                <RemoveCircleOutlineIcon />
              </OpaqueButton>
            </Box>
          ))}
        <Row
          sx={{
            flexDirection: 'column',
            gap: '1rem',
            alignItems: 'start',
            margin: '12px',
            padding: '12px',
          }}
        >
          <Typography variant="h2">Add Tracked Pool</Typography>

          <Row sx={{ flexDirection: 'column', display: 'flex', gap: '1rem' }}>
            <Input
              placeholder="Pool Address (C....)"
              type="text"
              value={poolToAdd}
              onChange={(e) => handleChangePoolToAdd(e.target.value)}
              error={!!poolIdError}
            />
            {poolIdError && (
              <Typography variant="body2" color="error">
                {poolIdError}
              </Typography>
            )}
            <OpaqueButton
              sx={{ width: '20rem', margin: 'auto' }}
              palette={theme.palette.primary}
              onClick={() => handleAddTrackedPool(poolToAdd)}
              disabled={!!poolIdError}
            >
              Add
            </OpaqueButton>
          </Row>
        </Row>
      </>
    </>
  );
}
