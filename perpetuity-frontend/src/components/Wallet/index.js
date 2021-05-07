import React from 'react';
import { ethers } from 'ethers';
import WalletContext from './WalletContext';

function Wallet({ children }) {
  const providerRef = React.useRef(null);
  const ethereumRef = React.useRef(null);
  const [account, setAccount] = React.useState('');
  const [chainId, setChainId] = React.useState(undefined);

  // equivalent to component will mount
  if (providerRef.current == null && window.ethereum) {
    ethereumRef.current = window.ethereum;
    providerRef.current = new ethers.providers.Web3Provider(window.ethereum);
  }

  // callbacks
  const chainChangedCallback = React.useCallback(
    (chainId) => {
      console.log('chainChanged', chainId);
      // comes in as a hex string
      setChainId(parseInt(chainId));
    },
    [setChainId]
  );
  const accountsChangedCallback = React.useCallback(
    (accounts) => {
      console.log('accountsChanged', accounts);
      setAccount(accounts[0]);
    },
    [setAccount]
  );

  React.useEffect(() => {
    if (ethereumRef.current != null) {
      setAccount(ethereumRef.current.selectedAddress);
      setChainId(parseInt(ethereumRef.current.chainId));
      ethereumRef.current.on('accountsChanged', accountsChangedCallback);
      ethereumRef.current.on('chainChanged', chainChangedCallback);
    }

    // clean up
    return () => {
      if (ethereumRef?.current?.removeListener) {
        ethereumRef.current.removeListener('chainChanged', chainChangedCallback);
        ethereumRef.current.removeListener('accountsChanged', accountsChangedCallback);
      }
    };
  }, [accountsChangedCallback, chainChangedCallback]);

  return <WalletContext.Provider children={children} value={{ providerRef, ethereumRef, account, chainId }} />;
}

export default Wallet;
