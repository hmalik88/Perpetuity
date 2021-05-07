import React from 'react';
import Button from '@material-ui/core/Button';
import useWallet from './useWallet';

function ConnectToWallet() {
  const { ethereum, account = '' } = useWallet();

  const displayAccount = account ? `${account.slice(0, 10)}...` : '';
  console.log('ConnectToWallet.account', account, displayAccount);
  const handleClick = () => {
    ethereum.enable();
  };
  return !!displayAccount ? (
    <Button variant='contained' disableElevation style={{ backgroundColor: 'white' }} disabled>
      {displayAccount}
    </Button>
  ) : (
    <Button onClick={handleClick} variant='contained' disableElevation style={{ backgroundColor: 'white' }}>
      Connect
    </Button>
  );
}

export default ConnectToWallet;
