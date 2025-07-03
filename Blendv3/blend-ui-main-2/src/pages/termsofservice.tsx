import { Box, Typography } from '@mui/material';
import { NextPage } from 'next';
import { Divider } from '../components/common/Divider';
import { Row } from '../components/common/Row';
import { TOS } from '../components/common/TOS';

const TermsOfService: NextPage = () => {
  return (
    <>
      <>
        <Row sx={{ margin: '12px', padding: '12px' }}>
          <Typography variant="h1">Blend App Terms of Service</Typography>
        </Row>
        <Divider />
        <Box sx={{ margin: '12px', padding: '12px' }}>
          <TOS />
        </Box>
      </>
    </>
  );
};

export default TermsOfService;
