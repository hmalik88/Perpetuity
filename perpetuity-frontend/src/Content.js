import React from 'react';
import Grid from '@material-ui/core/Grid';
import styled from 'styled-components';
import { ethers } from 'ethers';
import useWallet from './components/Wallet/useWallet';

const FancyAmount = styled.span`
  font-size: 16px;
  font-weight: 700;
`;

function Content() {
  const { provider, account } = useWallet();
  const [ethAmount, setEthAmount] = React.useState(null);

  React.useEffect(() => {
    (async () => {
      const balance = await provider.getBalance(account);
      setEthAmount(ethers.utils.formatEther(balance));
    })();
  }, [account]);

  return (
    <Grid container justify='center' alignItems='center'>
      <Grid item>
        <p>Here lies some awesome content!</p>
        <p>
          You have <FancyAmount>{ethAmount == null ? 'loading...' : ethAmount}</FancyAmount>
        </p>
      </Grid>
    </Grid>
  );
}

export default React.memo(Content);
