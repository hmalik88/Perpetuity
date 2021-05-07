import { abi as ERC20ABI } from '../contracts/IERC20.json';

const networkByKey = {
  mainNet: {
    key: 'mainNet',
    networkId: 1,
    name: 'MainNet',
    chainId: 1,
  },
  ropsten: {
    key: 'ropsten',
    networkId: 3,
    name: 'Ropsten',
    chainId: 3,
  },
  rinkeby: {
    key: 'rinkeby',
    networkId: 4,
    name: 'Rinkeby',
    chainId: 4,
  },
  goerli: {
    key: 'goerli',
    networkId: 5,
    name: 'Goerli',
    chainId: 5,
  },
  kovan: {
    key: 'kovan',
    networkId: 42,
    name: 'Kovan',
    chainId: 42,
  },
  maticMainnet: {
    key: 'maticMainnet',
    networkId: 137,
    name: 'Matic Mainnet',
    chainId: 137,
  },
  maticMumbaiTestnet: {
    key: 'maticMumbaiTestnet',
    networkId: 80001,
    name: 'Matic Mumbai Testnet',
    chainId: 80001,
  },
  ganache: {
    key: 'ganache',
    networkId: 5777,
    name: 'Ganache',
    chainId: 1337,
  },
  avalancheCChainMainnet: {
    key: 'avalancheCChainMainnet',
    networkId: 1,
    name: 'Avalanche C-Chain Mainnet',
    chainId: 43114,
  },
  avalancheFujiCChain: {
    key: 'avalancheFujiCChain',
    networkId: 1,
    name: 'Avalanche FUJI C-Chain',
    chainId: 43113,
  },
};

const networkByChainId = Object.keys(networkByKey).reduce((acc, key) => {
  acc[networkByKey[key].chainId] = networkByKey[key];
  return acc;
}, {});

const tokensByChainId = {
  [networkByKey.avalancheFujiCChain.chainId]: [
    // {
    //   address: '0x85CFE8b56f6E76F6c694279e3eFd0Efd4Da84863',
    //   name: 'Burst NFT',
    //   symbol: 'BURST',
    //   decimals: 18,
    //   abi: BurstNFT.abi,
    //   networkId: networkByKey.avalancheFujiCChain.networkId,
    //   chainId: networkByKey.avalancheFujiCChain.chainId,
    // },
  ],
  [networkByKey.ganache.chainId]: [
    // {
    //   address: BurstNFT.networks[Object.keys(BurstNFT.networks)[0]].address,
    //   name: 'Burst NFT',
    //   symbol: 'BURST',
    //   decimals: 18,
    //   abi: BurstNFT.abi,
    //   networkId: networkByKey.ganache.networkId,
    //   chainId: networkByKey.ganache.chainId,
    // },
  ],
  [networkByKey.maticMumbaiTestnet.chainId]: [
    // {
    //   address: '0xF6cad50Aea13C607C53a063EE059B5f6f5d6F86D',
    //   name: 'Burst NFT',
    //   symbol: 'BURST',
    //   decimals: 18,
    //   abi: BurstNFT.abi,
    //   networkId: networkByKey.maticMumbaiTestnet.networkId,
    //   chainId: networkByKey.maticMumbaiTestnet.chainId,
    // },
  ],
  [networkByKey.mainNet.chainId]: [
    {
      address: '0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2',
      name: 'Maker',
      symbol: 'MKR',
      decimals: 18,
      abi: ERC20ABI,
      networkId: networkByKey.mainNet.networkId,
      chainId: networkByKey.mainNet.chainId,
    },
    {
      address: '0x6B175474E89094C44Da98b954EedeAC495271d0F',
      name: 'Dai Stablecoin',
      symbol: 'DAI',
      decimals: 18,
      abi: ERC20ABI,
      networkId: networkByKey.mainNet.networkId,
      chainId: networkByKey.mainNet.chainId,
    },
  ],
  [networkByKey.rinkeby.chainId]: [
    {
      address: '0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa',
      symbol: 'DAI',
      name: 'Dai',
      decimals: 18,
      abi: ERC20ABI,
      networkId: networkByKey.rinkeby.networkId,
      chainId: networkByKey.rinkeby.chainId,
    },
    {
      address: '0xF9bA5210F91D0474bd1e1DcDAeC4C58E359AaD85',
      symbol: 'MKR',
      name: 'Maker',
      decimals: 18,
      abi: ERC20ABI,
      networkId: networkByKey.rinkeby.networkId,
      chainId: networkByKey.rinkeby.chainId,
    },
  ],
};

// TODO: Change to a single reduce function for better performance
// Builds an object to access the token by address
const tokenByAddress = Object.values(tokensByChainId)
  .flat()
  .reduce((acc, token) => {
    acc[token.address] = token;
    return acc;
  }, {});

/**
 * Find the first token matching the symbol
 */
const findTokenBySymbol = ({ chainId, symbol }) => {
  if (chainId && tokensByChainId[chainId]) {
    const token = tokensByChainId[chainId].find((_token) => _token.symbol === symbol);
    return token;
  }

  return undefined;
};

export { tokenByAddress, findTokenBySymbol, networkByKey, networkByChainId, tokensByChainId };
