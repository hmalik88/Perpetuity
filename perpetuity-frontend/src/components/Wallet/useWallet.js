import React from 'react';
import WalletContext from './WalletContext';
import { networkByChainId } from '../utils';

function useWallet() {
  const { account, chainId, ethereumRef, providerRef } = React.useContext(WalletContext);

  const network = React.useMemo(() => networkByChainId[chainId], [chainId]);

  return {
    account,
    chainId,
    network,
    get ethereum() {
      return ethereumRef.current;
    },
    get provider() {
      return providerRef.current;
    },
  };
}

export default useWallet;
