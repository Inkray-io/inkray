import { SuiClient } from '@mysten/sui/client';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { fromBase64, fromHEX } from '@mysten/sui/utils';
import { getNetworkConfig, getCurrentNetwork, type Network } from '../config/networks.js';
import type { ClientConfig } from './types.js';
import chalk from 'chalk';

export class InkraySuiClient {
  private client: SuiClient;
  private keypair: Ed25519Keypair | null = null;
  private network: Network;

  constructor(config?: ClientConfig) {
    this.network = config?.network || getCurrentNetwork();
    const networkConfig = getNetworkConfig(this.network);
    
    this.client = new SuiClient({
      url: config?.rpcUrl || networkConfig.sui.rpcUrl,
    });

    if (config?.privateKey) {
      this.keypair = this.createKeypairFromPrivateKey(config.privateKey);
    } else if (config?.mnemonic) {
      this.keypair = this.createKeypairFromMnemonic(config.mnemonic);
    }
  }

  // Client getters
  getClient(): SuiClient {
    return this.client;
  }

  getKeypair(): Ed25519Keypair {
    if (!this.keypair) {
      throw new Error('No keypair configured. Please provide a private key or mnemonic.');
    }
    return this.keypair;
  }

  getAddress(): string {
    if (!this.keypair) {
      throw new Error('No keypair configured. Please provide a private key or mnemonic.');
    }
    return this.keypair.getPublicKey().toSuiAddress();
  }

  getNetwork(): Network {
    return this.network;
  }

  // Keypair creation methods
  private createKeypairFromPrivateKey(privateKey: string): Ed25519Keypair {
    try {
      // Handle different private key formats
      if (privateKey.startsWith('suiprivkey1')) {
        // Sui bech32 format
        return Ed25519Keypair.fromSecretKey(privateKey);
      } else if (privateKey.startsWith('0x')) {
        // Hex format
        const cleanKey = privateKey.replace(/^0x/, '');
        const keyBytes = fromHEX(cleanKey);
        return Ed25519Keypair.fromSecretKey(keyBytes);
      } else {
        // Base64 format
        const keyBytes = fromBase64(privateKey);
        return Ed25519Keypair.fromSecretKey(keyBytes);
      }
    } catch (error) {
      throw new Error(`Invalid private key format: ${error}`);
    }
  }

  private createKeypairFromMnemonic(mnemonic: string): Ed25519Keypair {
    try {
      return Ed25519Keypair.deriveKeypair(mnemonic);
    } catch (error) {
      throw new Error(`Invalid mnemonic: ${error}`);
    }
  }

  // Utility methods
  async getBalance(): Promise<string> {
    if (!this.keypair) {
      throw new Error('No keypair configured');
    }

    const balance = await this.client.getBalance({
      owner: this.getAddress(),
    });

    return balance.totalBalance;
  }

  async requestFaucet(): Promise<void> {
    if (this.network === 'mainnet') {
      throw new Error('Faucet not available on mainnet');
    }

    const networkConfig = getNetworkConfig(this.network);
    if (!networkConfig.sui.faucetUrl) {
      throw new Error(`Faucet URL not configured for ${this.network}`);
    }

    const address = this.getAddress();
    console.log(chalk.yellow(`Requesting faucet for address: ${address}`));

    try {
      const response = await fetch(networkConfig.sui.faucetUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          FixedAmountRequest: {
            recipient: address,
          },
        }),
      });

      if (!response.ok) {
        throw new Error(`Faucet request failed: ${response.statusText}`);
      }

      console.log(chalk.green('✓ Faucet request successful'));
    } catch (error) {
      console.error(chalk.red(`Faucet request failed: ${error}`));
      throw error;
    }
  }

  // Object inspection methods
  async getObject(objectId: string) {
    return await this.client.getObject({
      id: objectId,
      options: {
        showBcs: false,
        showContent: true,
        showDisplay: false,
        showOwner: true,
        showPreviousTransaction: false,
        showStorageRebate: false,
        showType: true,
      },
    });
  }

  async getOwnedObjects(type?: string) {
    const address = this.getAddress();
    
    return await this.client.getOwnedObjects({
      owner: address,
      filter: type ? { StructType: type } : undefined,
      options: {
        showContent: true,
        showType: true,
        showOwner: true,
      },
    });
  }

  // Transaction methods
  async waitForTransaction(digest: string) {
    return await this.client.waitForTransaction({
      digest,
      options: {
        showEffects: true,
        showEvents: true,
        showObjectChanges: true,
        showBalanceChanges: true,
      },
    });
  }

  async getTransactionBlock(digest: string) {
    return await this.client.getTransactionBlock({
      digest,
      options: {
        showEffects: true,
        showEvents: true,
        showInput: true,
        showObjectChanges: true,
        showBalanceChanges: true,
      },
    });
  }
}

// Singleton instance management
let defaultClient: InkraySuiClient | null = null;

export function createSuiClient(config?: ClientConfig): InkraySuiClient {
  return new InkraySuiClient(config);
}

export function getDefaultSuiClient(config?: ClientConfig): InkraySuiClient {
  if (!defaultClient) {
    // Auto-configure from environment variables if no config provided
    const autoConfig = config || {
      network: getCurrentNetwork(),
      mnemonic: process.env.ADMIN_MNEMONIC,
      privateKey: process.env.ADMIN_PRIVATE_KEY,
    };
    defaultClient = new InkraySuiClient(autoConfig);
  }
  return defaultClient;
}

export function setDefaultSuiClient(client: InkraySuiClient): void {
  defaultClient = client;
}