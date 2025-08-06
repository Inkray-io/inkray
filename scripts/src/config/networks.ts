import { getFullnodeUrl } from '@mysten/sui/client';

export type Network = 'localnet' | 'testnet' | 'mainnet';

export interface NetworkConfig {
  sui: {
    rpcUrl: string;
    faucetUrl?: string;
  };
  walrus: {
    network: string;
    publisherUrl: string;
    aggregatorUrl: string;
  };
  seal: {
    network: string;
    keyServerUrl: string;
  };
}

export const NETWORK_CONFIGS: Record<Network, NetworkConfig> = {
  localnet: {
    sui: {
      rpcUrl: 'http://127.0.0.1:9000',
      faucetUrl: 'http://127.0.0.1:9123/gas',
    },
    walrus: {
      network: 'localnet',
      publisherUrl: 'http://localhost:31415',
      aggregatorUrl: 'http://localhost:31416',
    },
    seal: {
      network: 'localnet',
      keyServerUrl: 'http://localhost:8080',
    },
  },
  testnet: {
    sui: {
      rpcUrl: getFullnodeUrl('testnet'),
      faucetUrl: 'https://faucet.testnet.sui.io/gas',
    },
    walrus: {
      network: 'testnet',
      publisherUrl: 'https://publisher.walrus-testnet.mystenlabs.com',
      aggregatorUrl: 'https://aggregator.walrus-testnet.mystenlabs.com',
    },
    seal: {
      network: 'testnet',
      keyServerUrl: 'https://seal-testnet.mystenlabs.com',
    },
  },
  mainnet: {
    sui: {
      rpcUrl: getFullnodeUrl('mainnet'),
    },
    walrus: {
      network: 'mainnet',
      publisherUrl: 'https://publisher.walrus.mystenlabs.com',
      aggregatorUrl: 'https://aggregator.walrus.mystenlabs.com',
    },
    seal: {
      network: 'mainnet',
      keyServerUrl: 'https://seal.mystenlabs.com',
    },
  },
};

export function getNetworkConfig(network: Network = 'testnet'): NetworkConfig {
  const config = NETWORK_CONFIGS[network];
  if (!config) {
    throw new Error(`Unsupported network: ${network}`);
  }
  return config;
}

export function getCurrentNetwork(): Network {
  return (process.env.NETWORK as Network) || 'testnet';
}