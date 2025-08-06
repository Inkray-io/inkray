import { getNetworkConfig, getCurrentNetwork } from '../config/networks.js';
import type { SealClientConfig, SealEncryptionOptions, SealDecryptionRequest } from './types.js';
import chalk from 'chalk';

// Note: Seal SDK integration - this is a placeholder implementation
// The actual Seal SDK usage would depend on the final API
export class InkraySealClient {
  private config: SealClientConfig;

  constructor(config?: Partial<SealClientConfig>) {
    const network = getCurrentNetwork();
    const networkConfig = getNetworkConfig(network);
    
    this.config = {
      network: config?.network || networkConfig.seal.network,
      keyServerUrl: config?.keyServerUrl || networkConfig.seal.keyServerUrl,
      policyPackageId: config?.policyPackageId,
    };
  }

  getConfig(): SealClientConfig {
    return this.config;
  }

  // Identity-based encryption methods
  async generateIdentity(userAddress: string): Promise<string> {
    try {
      console.log(chalk.blue(`🔑 Generating Seal identity for: ${userAddress}`));
      
      // This would use the actual Seal SDK to generate an identity
      // For now, we'll use a deterministic approach based on the address
      const identity = `user:${userAddress}`;
      
      console.log(chalk.green(`✓ Identity generated: ${identity}`));
      return identity;
    } catch (error) {
      console.error(chalk.red(`❌ Identity generation failed: ${error}`));
      throw error;
    }
  }

  // Encryption methods
  async encryptData(
    data: Uint8Array, 
    options: SealEncryptionOptions
  ): Promise<Uint8Array> {
    try {
      console.log(chalk.blue(`🔒 Encrypting data with policy: ${options.policy}`));
      
      // This is a placeholder implementation
      // In reality, this would use the Seal SDK to encrypt data
      // with the specified access policy
      
      // For now, we'll simulate encryption by adding a header
      const header = new TextEncoder().encode(`SEAL_ENCRYPTED_${options.policy}_`);
      const encrypted = new Uint8Array(header.length + data.length);
      encrypted.set(header, 0);
      encrypted.set(data, header.length);
      
      console.log(chalk.green(`✓ Data encrypted successfully`));
      console.log(chalk.gray(`  Policy: ${options.policy}`));
      console.log(chalk.gray(`  Original size: ${data.length} bytes`));
      console.log(chalk.gray(`  Encrypted size: ${encrypted.length} bytes`));
      
      return encrypted;
    } catch (error) {
      console.error(chalk.red(`❌ Encryption failed: ${error}`));
      throw error;
    }
  }

  async encryptFile(
    filePath: string, 
    options: SealEncryptionOptions
  ): Promise<Uint8Array> {
    try {
      const fs = await import('fs/promises');
      const data = await fs.readFile(filePath);
      
      console.log(chalk.blue(`🔒 Encrypting file: ${filePath}`));
      return await this.encryptData(data, options);
    } catch (error) {
      console.error(chalk.red(`❌ File encryption failed: ${error}`));
      throw error;
    }
  }

  // Decryption methods
  async decryptData(request: SealDecryptionRequest): Promise<Uint8Array> {
    try {
      console.log(chalk.blue(`🔓 Decrypting data for identity: ${request.identity}`));
      
      // This is a placeholder implementation
      // In reality, this would:
      // 1. Validate access permissions via smart contract
      // 2. Request decryption keys from Seal key servers
      // 3. Decrypt the data using IBE
      
      // For now, we'll simulate decryption by removing our header
      const headerText = `SEAL_ENCRYPTED_${request.policy}_`;
      const header = new TextEncoder().encode(headerText);
      
      if (request.encryptedData.length < header.length) {
        throw new Error('Invalid encrypted data format');
      }
      
      // Check if data starts with our header
      const headerMatch = request.encryptedData.slice(0, header.length);
      if (!this.arraysEqual(headerMatch, header)) {
        throw new Error('Invalid encrypted data header');
      }
      
      const decrypted = request.encryptedData.slice(header.length);
      
      console.log(chalk.green(`✓ Data decrypted successfully`));
      console.log(chalk.gray(`  Identity: ${request.identity}`));
      console.log(chalk.gray(`  Policy: ${request.policy}`));
      console.log(chalk.gray(`  Decrypted size: ${decrypted.length} bytes`));
      
      return decrypted;
    } catch (error) {
      console.error(chalk.red(`❌ Decryption failed: ${error}`));
      throw error;
    }
  }

  async decryptToFile(
    request: SealDecryptionRequest, 
    outputPath: string
  ): Promise<void> {
    try {
      const decrypted = await this.decryptData(request);
      
      const fs = await import('fs/promises');
      await fs.writeFile(outputPath, decrypted);
      
      console.log(chalk.green(`✓ Decrypted data saved to: ${outputPath}`));
    } catch (error) {
      console.error(chalk.red(`❌ Decryption to file failed: ${error}`));
      throw error;
    }
  }

  // Access policy management
  async createSubscriptionPolicy(policyConfig: {
    platformServiceId: string;
    subscriptionDuration: number;
  }): Promise<string> {
    try {
      console.log(chalk.blue(`📋 Creating subscription access policy`));
      
      // This would create a Seal access policy for subscription-based access
      // The policy would verify subscription status via smart contract
      const policyId = `subscription_policy_${Date.now()}`;
      
      console.log(chalk.green(`✓ Subscription policy created: ${policyId}`));
      return policyId;
    } catch (error) {
      console.error(chalk.red(`❌ Policy creation failed: ${error}`));
      throw error;
    }
  }

  async createNFTPolicy(policyConfig: {
    articleId: string;
    nftType: string;
  }): Promise<string> {
    try {
      console.log(chalk.blue(`📋 Creating NFT access policy`));
      
      // This would create a Seal access policy for NFT-based access
      // The policy would verify NFT ownership via smart contract
      const policyId = `nft_policy_${Date.now()}`;
      
      console.log(chalk.green(`✓ NFT policy created: ${policyId}`));
      return policyId;
    } catch (error) {
      console.error(chalk.red(`❌ Policy creation failed: ${error}`));
      throw error;
    }
  }

  async createAllowlistPolicy(policyConfig: {
    allowedAddresses: string[];
    creatorAddress: string;
  }): Promise<string> {
    try {
      console.log(chalk.blue(`📋 Creating allowlist access policy`));
      
      // This would create a Seal access policy for allowlist-based access
      const policyId = `allowlist_policy_${Date.now()}`;
      
      console.log(chalk.green(`✓ Allowlist policy created: ${policyId}`));
      return policyId;
    } catch (error) {
      console.error(chalk.red(`❌ Policy creation failed: ${error}`));
      throw error;
    }
  }

  // Utility methods
  private arraysEqual(a: Uint8Array, b: Uint8Array): boolean {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) return false;
    }
    return true;
  }

  async validateAccess(
    identity: string,
    policy: string,
    accessProof?: any
  ): Promise<boolean> {
    try {
      console.log(chalk.blue(`✅ Validating access for identity: ${identity}`));
      
      // This would validate access permissions via Seal key servers
      // and smart contract verification
      
      // For now, we'll simulate validation
      const isValid = true; // In reality, this would check actual access rights
      
      if (isValid) {
        console.log(chalk.green(`✓ Access validated successfully`));
      } else {
        console.log(chalk.red(`❌ Access denied`));
      }
      
      return isValid;
    } catch (error) {
      console.error(chalk.red(`❌ Access validation failed: ${error}`));
      return false;
    }
  }
}

// Singleton instance management
let defaultSealClient: InkraySealClient | null = null;

export function createSealClient(config?: Partial<SealClientConfig>): InkraySealClient {
  return new InkraySealClient(config);
}

export function getDefaultSealClient(config?: Partial<SealClientConfig>): InkraySealClient {
  if (!defaultSealClient) {
    defaultSealClient = new InkraySealClient(config);
  }
  return defaultSealClient;
}

export function setDefaultSealClient(client: InkraySealClient): void {
  defaultSealClient = client;
}