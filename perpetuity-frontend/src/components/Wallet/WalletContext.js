import React from 'react';

const WalletContext = React.createContext({
  account: undefined,
  chainId: undefined
});
WalletContext.displayName = 'Wallet';
export default WalletContext;
