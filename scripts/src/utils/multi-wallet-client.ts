import { InkraySuiClient, createSuiClient } from './client.js';
import { InkraySealClient, createSealClient } from './seal-client.js';
import { getCurrentNetwork } from '../config/networks.js';
import chalk from 'chalk';

/**
 * User roles for the end-to-end demo
 */
export type UserRole = 'admin' | 'creator' | 'reader' | 'wrongReader';

/**
 * Multi-wallet client that manages different user roles
 * Each role uses a different private key from the .env file
 */
export class MultiWalletClient {
  private clients: Map<UserRole, InkraySuiClient> = new Map();
  private sealClients: Map<UserRole, InkraySealClient> = new Map();
  
  constructor() {
    this.initializeClients();
  }

  private initializeClients(): void {
    const network = getCurrentNetwork();
    
    // Initialize Sui clients for each role
    const roles: { role: UserRole; envKey: string }[] = [
      { role: 'admin', envKey: 'ADMIN_PRIVATE_KEY' },
      { role: 'creator', envKey: 'CREATOR_PRIVATE_KEY' },
      { role: 'reader', envKey: 'READER_PRIVATE_KEY' },
      { role: 'wrongReader', envKey: 'WRONG_READER_PRIVATE_KEY' },
    ];

    for (const { role, envKey } of roles) {
      const privateKey = process.env[envKey];
      
      if (!privateKey) {
        throw new Error(`Missing private key for ${role}: ${envKey} not found in environment`);
      }

      // Create Sui client
      const suiClient = createSuiClient({
        network,
        privateKey,
      });
      this.clients.set(role, suiClient);

      // Create Seal client with the Sui client
      const sealClient = createSealClient({
        network: network,
        suiClient,
      });
      this.sealClients.set(role, sealClient);
    }

    console.log(chalk.green('✅ Multi-wallet clients initialized for all roles'));
  }

  /**
   * Get Sui client for a specific role
   */
  getSuiClient(role: UserRole): InkraySuiClient {
    const client = this.clients.get(role);
    if (!client) {
      throw new Error(`No client found for role: ${role}`);
    }
    return client;
  }

  /**
   * Get Seal client for a specific role
   */
  getSealClient(role: UserRole): InkraySealClient {
    const client = this.sealClients.get(role);
    if (!client) {
      throw new Error(`No Seal client found for role: ${role}`);
    }
    return client;
  }

  /**
   * Get address for a specific role
   */
  getAddress(role: UserRole): string {
    return this.getSuiClient(role).getAddress();
  }

  /**
   * Display wallet information for all roles
   */
  async displayWalletInfo(): Promise<void> {
    console.log(chalk.blue('📋 Wallet Information'));
    console.log(chalk.gray('=' .repeat(60)));

    const roles: UserRole[] = ['admin', 'creator', 'reader', 'wrongReader'];

    for (const role of roles) {
      try {
        const client = this.getSuiClient(role);
        const address = client.getAddress();
        const balance = await client.getBalance();
        const balanceSui = parseInt(balance) / 1_000_000_000; // Convert MIST to SUI

        const roleEmoji = this.getRoleEmoji(role);
        const roleLabel = this.getRoleLabel(role);
        
        console.log(chalk.white(`${roleEmoji} ${roleLabel}`));
        console.log(chalk.gray(`  Address: ${address}`));
        console.log(chalk.gray(`  Balance: ${balanceSui.toFixed(4)} SUI`));
        console.log();
      } catch (error) {
        console.log(chalk.red(`❌ Error getting info for ${role}: ${error}`));
      }
    }
  }

  /**
   * Request faucet funds for all wallets
   */
  async requestFaucetForAll(): Promise<void> {
    console.log(chalk.blue('🚰 Requesting faucet funds for all wallets...'));
    
    const roles: UserRole[] = ['admin', 'creator', 'reader', 'wrongReader'];

    for (const role of roles) {
      try {
        const client = this.getSuiClient(role);
        const roleLabel = this.getRoleLabel(role);
        
        console.log(chalk.yellow(`  Requesting faucet for ${roleLabel}...`));
        await client.requestFaucet();
        
        // Wait a bit between requests to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 1000));
      } catch (error) {
        console.log(chalk.gray(`    Note: ${error}`));
      }
    }

    console.log(chalk.green('✅ Faucet requests completed'));
  }

  /**
   * Check balances and request faucet if needed
   */
  async ensureSufficientBalance(role: UserRole, minBalance: number = 1.0): Promise<void> {
    const client = this.getSuiClient(role);
    const balance = await client.getBalance();
    const balanceSui = parseInt(balance) / 1_000_000_000;

    if (balanceSui < minBalance) {
      const roleLabel = this.getRoleLabel(role);
      console.log(chalk.yellow(`⚠️  ${roleLabel} balance (${balanceSui.toFixed(4)} SUI) below minimum (${minBalance} SUI)`));
      console.log(chalk.blue(`  Requesting faucet for ${roleLabel}...`));
      
      try {
        await client.requestFaucet();
        console.log(chalk.green(`✅ Faucet requested for ${roleLabel}`));
      } catch (error) {
        console.log(chalk.gray(`    Note: ${error}`));
      }
    }
  }

  /**
   * Wait for transaction confirmation for a specific role
   */
  async waitForTransaction(role: UserRole, digest: string) {
    const client = this.getSuiClient(role);
    return await client.waitForTransaction(digest);
  }

  /**
   * Get owned objects for a specific role
   */
  async getOwnedObjects(role: UserRole, type?: string) {
    const client = this.getSuiClient(role);
    return await client.getOwnedObjects(type);
  }

  /**
   * Get object details for a specific role
   */
  async getObject(role: UserRole, objectId: string) {
    const client = this.getSuiClient(role);
    return await client.getObject(objectId);
  }

  /**
   * Validate that all required environment variables are present
   */
  static validateEnvironment(): void {
    const requiredKeys = [
      'ADMIN_PRIVATE_KEY',
      'CREATOR_PRIVATE_KEY', 
      'READER_PRIVATE_KEY',
      'WRONG_READER_PRIVATE_KEY',
      'PACKAGE_ID',
      'NETWORK'
    ];

    const missing = requiredKeys.filter(key => !process.env[key]);
    
    if (missing.length > 0) {
      throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }

    console.log(chalk.green('✅ All required environment variables present'));
  }

  private getRoleEmoji(role: UserRole): string {
    switch (role) {
      case 'admin': return '👨‍💼';
      case 'creator': return '✍️';
      case 'reader': return '👤';
      case 'wrongReader': return '🚫';
      default: return '❓';
    }
  }

  private getRoleLabel(role: UserRole): string {
    switch (role) {
      case 'admin': return 'Admin (Platform Manager)';
      case 'creator': return 'Creator (Content Publisher)';
      case 'reader': return 'Reader (Authorized User)';
      case 'wrongReader': return 'Wrong Reader (Unauthorized)';
      default: return 'Unknown Role';
    }
  }

  /**
   * Get role description for logging
   */
  getRoleDescription(role: UserRole): string {
    switch (role) {
      case 'admin':
        return 'Platform administrator who deploys contracts and manages configuration';
      case 'creator':
        return 'Content creator who publishes articles and manages publications';
      case 'reader':
        return 'Authorized reader who should be able to decrypt premium content';
      case 'wrongReader':
        return 'Unauthorized user who should NOT be able to decrypt content';
      default:
        return 'Unknown role';
    }
  }

  /**
   * Display role relationships and expected permissions
   */
  displayRoleMatrix(): void {
    console.log(chalk.blue('🔐 Access Control Matrix'));
    console.log(chalk.gray('=' .repeat(60)));
    
    const matrix: Array<{
      role: UserRole;
      publication: string;
      vault: string;
      decrypt: string;
      description: string;
    }> = [
      { role: 'admin', publication: '❌', vault: '❌', decrypt: '❌', description: 'Platform management only' },
      { role: 'creator', publication: '✅', vault: '✅', decrypt: '✅', description: 'Full access as owner' },
      { role: 'reader', vault: '✅*', decrypt: '✅*', publication: '❌', description: 'Access as contributor' },
      { role: 'wrongReader', publication: '❌', vault: '❌', decrypt: '❌', description: 'No access' },
    ];

    console.log(chalk.white('Role              Publication  Vault   Decrypt  Description'));
    console.log(chalk.gray('-'.repeat(60)));
    
    for (const { role, publication, vault, decrypt, description } of matrix) {
      const roleLabel = this.getRoleLabel(role).padEnd(16);
      console.log(`${roleLabel} ${publication}          ${vault}     ${decrypt}      ${description}`);
    }
    
    console.log();
    console.log(chalk.gray('* After being added as contributor'));
    console.log();
  }
}

/**
 * Create and validate multi-wallet client
 */
export function createMultiWalletClient(): MultiWalletClient {
  MultiWalletClient.validateEnvironment();
  return new MultiWalletClient();
}

/**
 * Singleton instance for the multi-wallet client
 */
let defaultMultiWalletClient: MultiWalletClient | null = null;

export function getDefaultMultiWalletClient(): MultiWalletClient {
  if (!defaultMultiWalletClient) {
    defaultMultiWalletClient = createMultiWalletClient();
  }
  return defaultMultiWalletClient;
}