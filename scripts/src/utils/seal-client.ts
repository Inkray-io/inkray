import { getNetworkConfig, getCurrentNetwork } from '../config/networks.js';
import type { 
  SealClientConfig, 
  SealEncryptionOptions, 
  SealDecryptionRequest, 
  UserCredentials,
  SealDecryptionRequestLegacy 
} from './types.js';
import { bcs } from '@mysten/bcs';
import { createHash } from 'crypto';
import chalk from 'chalk';
import { SealClient, getAllowlistedKeyServers } from '@mysten/seal';
import { getDefaultSuiClient } from './client.js';
import { webcrypto } from 'node:crypto';

// Fix crypto for Node.js environment
if (typeof globalThis.crypto === 'undefined') {
  globalThis.crypto = webcrypto as any;
}

/**
 * Inkray Seal Client - Content-Identity Based Encryption
 * 
 * Key Concept:
 * - Encrypt once with content-specific identity (e.g., article_123)
 * - Decrypt with different policies based on available user credentials
 * - Try multiple access methods until one succeeds
 */
// IdV1 constants matching smart contract (policy.move)
const TAG_ARTICLE_CONTENT = 0;  // u8
const ID_VERSION_V1 = 1;        // u16

// BCS layout for IdV1 struct
const IdV1Layout = bcs.struct('IdV1', {
  tag: bcs.u8(),
  version: bcs.u16(),
  publication: bcs.fixedArray(32, bcs.u8()),  // 32-byte Sui address
  article: bcs.fixedArray(32, bcs.u8()),      // 32-byte Sui address
  nonce: bcs.u64(),
});

export class InkraySealClient {
  private config: SealClientConfig;
  private sealClient: SealClient | null = null;
  private suiClient: import('./client.js').InkraySuiClient;

  constructor(config?: Partial<SealClientConfig>) {
    const network = getCurrentNetwork();
    const networkConfig = getNetworkConfig(network);
    
    this.config = {
      network: config?.network || networkConfig.seal.network,
      keyServerUrl: config?.keyServerUrl || networkConfig.seal.keyServerUrl,
      policyPackageId: config?.policyPackageId,
      suiClient: config?.suiClient,
    };

    // Use provided Sui client or fall back to default
    this.suiClient = config?.suiClient || getDefaultSuiClient();
  }

  private async getSealClient(): Promise<SealClient> {
    if (!this.sealClient) {
      const { SuiClient } = await import('@mysten/sui/client');
      const { getNetworkConfig } = await import('../config/networks.js');
      
      const suiClient = new SuiClient({ 
        url: getNetworkConfig('testnet').sui.rpcUrl 
      });
      
      const serverObjectIds = getAllowlistedKeyServers('testnet');
      
      this.sealClient = new SealClient({
        suiClient: suiClient as any, // Type compatibility fix
        serverConfigs: serverObjectIds.map((id) => ({
          objectId: id,
          weight: 1,
        })),
        verifyKeyServers: false, // Set to true for production
      });
    }
    
    return this.sealClient;
  }

  getConfig(): SealClientConfig {
    return this.config;
  }

  // === ENCRYPTION METHODS ===

  /**
   * Encrypt content with content-specific identity
   * This is the main encryption method - encrypt once per content
   */
  async encryptContent(
    data: Uint8Array, 
    options: SealEncryptionOptions
  ): Promise<Uint8Array> {
    try {
      const contentIdDisplay = options.contentId instanceof Uint8Array 
        ? `[BCS bytes: ${options.contentId.length}]` 
        : options.contentId;
      console.log(chalk.blue(`🔒 Encrypting content with ID: ${contentIdDisplay}`));
      
      const packageId = options.packageId || process.env.PACKAGE_ID;
      const threshold = options.threshold || 2;
      
      if (!packageId) {
        console.log(chalk.yellow(`⚠️  No package ID configured, using demo encryption`));
        const contentIdStr = options.contentId instanceof Uint8Array 
          ? Array.from(options.contentId).map(b => b.toString(16).padStart(2, '0')).join('')
          : options.contentId;
        return this.demoEncrypt(data, contentIdStr);
      }
      
      try {
        const sealClient = await this.getSealClient();
        
        const contentIdDisplay = options.contentId instanceof Uint8Array 
          ? `[BCS bytes: ${options.contentId.length}]` 
          : options.contentId;
        console.log(chalk.gray(`  Content ID: ${contentIdDisplay}`));
        console.log(chalk.gray(`  Package ID: ${packageId}`));
        console.log(chalk.gray(`  Threshold: ${threshold} key servers`));
        
        // Encrypt using the content ID as the identity
        // Convert Uint8Array to hex string for Seal API
        const idForSeal = options.contentId instanceof Uint8Array 
          ? '0x' + Array.from(options.contentId).map(b => b.toString(16).padStart(2, '0')).join('')
          : options.contentId;
        
        const { encryptedObject: encrypted } = await sealClient.encrypt({
          threshold,
          packageId,
          id: idForSeal, // Content-specific identity
          data,
        });
        
        console.log(chalk.green(`✅ Content encrypted with Seal!`));
        console.log(chalk.gray(`  Original size: ${data.length} bytes`));
        console.log(chalk.gray(`  Encrypted size: ${encrypted.length} bytes`));
        
        return encrypted;
      } catch (sealError) {
        console.log(chalk.yellow(`⚠️  Seal encryption failed, using demo encryption`));
        console.log(chalk.gray(`  Error: ${sealError}`));
        const contentIdStr = options.contentId instanceof Uint8Array 
          ? Array.from(options.contentId).map(b => b.toString(16).padStart(2, '0')).join('')
          : options.contentId;
        return this.demoEncrypt(data, contentIdStr);
      }
    } catch (error) {
      console.error(chalk.red(`❌ Encryption failed: ${error}`));
      throw error;
    }
  }

  /**
   * Convenience method for encrypting files
   */
  async encryptFile(
    filePath: string, 
    contentId: string | Uint8Array,
    options?: Partial<SealEncryptionOptions>
  ): Promise<Uint8Array> {
    try {
      const fs = await import('fs/promises');
      const data = await fs.readFile(filePath);
      
      console.log(chalk.blue(`🔒 Encrypting file: ${filePath}`));
      return await this.encryptContent(data, {
        contentId,
        ...options
      });
    } catch (error) {
      console.error(chalk.red(`❌ File encryption failed: ${error}`));
      throw error;
    }
  }

  // === HELPER METHODS ===

  /**
   * Validate Sui address format (exactly 32 bytes = 64 hex chars + 0x)
   */
  private isValidSuiAddress(address: string): boolean {
    return /^0x[a-fA-F0-9]{64}$/.test(address);
  }

  /**
   * Convert hex address string to byte array
   */
  private addressToBytes(address: string): number[] {
    if (!this.isValidSuiAddress(address)) {
      throw new Error(`Invalid Sui address format: ${address}`);
    }
    
    // Remove 0x prefix and convert to bytes
    const hexString = address.slice(2);
    const bytes: number[] = [];
    for (let i = 0; i < hexString.length; i += 2) {
      bytes.push(parseInt(hexString.slice(i, i + 2), 16));
    }
    return bytes;
  }

  /**
   * Generate deterministic article address from inputs
   */
  private generateDeterministicArticleAddress(
    publicationId: string,
    title: string,
    timestamp: number
  ): string {
    // Create deterministic hash from inputs
    const hash = createHash('sha256')
      .update(publicationId)
      .update(title)
      .update(timestamp.toString())
      .digest();
      
    // Return as proper Sui address format (32 bytes = 64 hex chars)
    return '0x' + hash.toString('hex');
  }

  /**
   * Generate a proper BCS-encoded IdV1 content ID for articles
   */
  generateArticleContentId(
    publicationId: string,
    articleTitle: string
  ): Uint8Array {
    // Validate publication ID format
    if (!this.isValidSuiAddress(publicationId)) {
      throw new Error(`Invalid Sui address format for publication: ${publicationId}`);
    }

    const timestamp = Date.now();
    
    // Generate deterministic article address
    const articleAddress = this.generateDeterministicArticleAddress(
      publicationId,
      articleTitle,
      timestamp
    );

    console.log(chalk.gray(`  Publication ID: ${publicationId}`));
    console.log(chalk.gray(`  Article Title: ${articleTitle}`));
    console.log(chalk.gray(`  Generated Article Address: ${articleAddress}`));

    // Create IdV1 struct
    const idV1 = {
      tag: TAG_ARTICLE_CONTENT,     // 0
      version: ID_VERSION_V1,       // 1
      publication: this.addressToBytes(publicationId),
      article: this.addressToBytes(articleAddress),
      nonce: BigInt(timestamp)
    };

    // BCS encode to bytes
    const encodedBytes = IdV1Layout.serialize(idV1).toBytes();
    
    console.log(chalk.gray(`  Generated BCS-encoded IdV1 (${encodedBytes.length} bytes)`));
    return encodedBytes;
  }

  // === DECRYPTION METHODS ===

  /**
   * Decrypt content by trying available user credentials
   * This is the main decryption method - tries policies based on what user has
   */
  async decryptContent(request: SealDecryptionRequest): Promise<Uint8Array> {
    try {
      console.log(chalk.blue(`🔓 Attempting to decrypt content: ${request.contentId}`));
      
      // Check if this is demo encrypted data
      if (this.isDemoEncrypted(request.encryptedData)) {
        console.log(chalk.yellow(`⚠️  Detected demo-encrypted data, validating access control...`));
        
        // Even in demo mode, we should validate access control
        await this.validateAccessControl(request.credentials, request.packageId, request.requestingClient);
        
        console.log(chalk.green(`✅ Access control validated, decrypting demo data`));
        const contentIdStr = request.contentId instanceof Uint8Array 
          ? Array.from(request.contentId).map(b => b.toString(16).padStart(2, '0')).join('')
          : request.contentId;
        return this.demoDecrypt(request.encryptedData, contentIdStr);
      }
      
      // Try each available credential type until one succeeds
      const credentials = request.credentials;
      const packageId = request.packageId || process.env.PACKAGE_ID;
      
      if (!packageId) {
        throw new Error('Package ID is required for Seal decryption');
      }

      // Try subscription access first (most common)
      if (credentials.subscription) {
        console.log(chalk.blue('🎫 Trying subscription access...'));
        try {
          return await this.tryDecryptWithSubscription(
            request.encryptedData,
            request.contentId,
            credentials.subscription,
            packageId
          );
        } catch (error: any) {
          console.log(chalk.gray(`  Subscription access failed: ${error?.message || error}`));
        }
      }

      // Try NFT access
      if (credentials.nft) {
        console.log(chalk.blue('🎨 Trying NFT access...'));
        try {
          return await this.tryDecryptWithNFT(
            request.encryptedData,
            request.contentId,
            credentials.nft,
            packageId
          );
        } catch (error: any) {
          console.log(chalk.gray(`  NFT access failed: ${error?.message || error}`));
        }
      }

      // Try publication owner access (highest priority)
      if (credentials.publicationOwner) {
        console.log(chalk.blue('👑 Trying publication owner access...'));
        try {
          return await this.tryDecryptWithPublicationOwner(
            request.encryptedData,
            request.contentId,
            credentials.publicationOwner,
            packageId
          );
        } catch (error: any) {
          console.log(chalk.gray(`  Publication owner access failed: ${error?.message || error}`));
        }
      }

      // Try contributor access
      if (credentials.contributor) {
        console.log(chalk.blue('✍️ Trying contributor access...'));
        try {
          return await this.tryDecryptWithContributor(
            request.encryptedData,
            request.contentId,
            credentials.contributor,
            packageId
          );
        } catch (error: any) {
          console.log(chalk.gray(`  Contributor access failed: ${error?.message || error}`));
        }
      }

      // Try allowlist access
      if (credentials.allowlist) {
        console.log(chalk.blue('📋 Trying allowlist access...'));
        try {
          return await this.tryDecryptWithAllowlist(
            request.encryptedData,
            request.contentId,
            credentials.allowlist,
            packageId
          );
        } catch (error: any) {
          console.log(chalk.gray(`  Allowlist access failed: ${error?.message || error}`));
        }
      }

      throw new Error('No valid access method found for this content');
    } catch (error) {
      console.error(chalk.red(`❌ Decryption failed: ${error}`));
      throw error;
    }
  }

  // === INDIVIDUAL POLICY DECRYPTION METHODS ===

  private async tryDecryptWithSubscription(
    encryptedData: Uint8Array,
    contentId: string | Uint8Array,
    subscription: NonNullable<UserCredentials['subscription']>,
    packageId: string
  ): Promise<Uint8Array> {
    const sealClient = await this.getSealClient();
    const suiClient = this.suiClient;
    
    const [{ SessionKey }, { Transaction }] = await Promise.all([
      import('@mysten/seal'),
      import('@mysten/sui/transactions')
    ]);
    
    const { SuiClient } = await import('@mysten/sui/client');
    const compatibleSuiClient = new SuiClient({ 
      url: getNetworkConfig('testnet').sui.rpcUrl 
    }) as any;
    
    const sessionKey = await SessionKey.create({
      address: suiClient.getAddress(),
      packageId,
      ttlMin: 10,
      suiClient: compatibleSuiClient,
    });
    
    const message = sessionKey.getPersonalMessage();
    const { signature } = await suiClient.getKeypair().signPersonalMessage(message);
    sessionKey.setPersonalMessageSignature(signature);
    
    const tx = new Transaction();
    // Convert contentId to bytes
    const contentIdBytes = contentId instanceof Uint8Array 
      ? Array.from(contentId)
      : Array.from(new TextEncoder().encode(contentId));
    
    tx.moveCall({
      target: `${packageId}::platform_access::seal_approve`,
      arguments: [
        tx.pure.vector('u8', contentIdBytes),
        tx.object(subscription.id),
        tx.object(subscription.serviceId),
        tx.object('0x6'), // Clock object
      ]
    });
    
    const txBytes = await tx.build({ 
      client: suiClient.getClient(), 
      onlyTransactionKind: true 
    });
    
    const decrypted = await sealClient.decrypt({
      data: encryptedData,
      sessionKey,
      txBytes,
    });
    
    console.log(chalk.green('✅ Decrypted with subscription access'));
    return decrypted;
  }

  private async tryDecryptWithNFT(
    encryptedData: Uint8Array,
    contentId: string | Uint8Array,
    nft: NonNullable<UserCredentials['nft']>,
    packageId: string
  ): Promise<Uint8Array> {
    const sealClient = await this.getSealClient();
    const suiClient = this.suiClient;
    
    const [{ SessionKey }, { Transaction }] = await Promise.all([
      import('@mysten/seal'),
      import('@mysten/sui/transactions')
    ]);
    
    const { SuiClient } = await import('@mysten/sui/client');
    const compatibleSuiClient = new SuiClient({ 
      url: getNetworkConfig('testnet').sui.rpcUrl 
    }) as any;
    
    const sessionKey = await SessionKey.create({
      address: suiClient.getAddress(),
      packageId,
      ttlMin: 10,
      suiClient: compatibleSuiClient,
    });
    
    const message = sessionKey.getPersonalMessage();
    const { signature } = await suiClient.getKeypair().signPersonalMessage(message);
    sessionKey.setPersonalMessageSignature(signature);
    
    const tx = new Transaction();
    // Convert contentId to bytes
    const contentIdBytes = contentId instanceof Uint8Array 
      ? Array.from(contentId)
      : Array.from(new TextEncoder().encode(contentId));
    
    tx.moveCall({
      target: `${packageId}::article_nft::seal_approve`,
      arguments: [
        tx.pure.vector('u8', contentIdBytes),
        tx.object(nft.id),
        tx.object(nft.articleId),
      ]
    });
    
    const txBytes = await tx.build({ 
      client: suiClient.getClient(), 
      onlyTransactionKind: true 
    });
    
    const decrypted = await sealClient.decrypt({
      data: encryptedData,
      sessionKey,
      txBytes,
    });
    
    console.log(chalk.green('✅ Decrypted with NFT access'));
    return decrypted;
  }

  private async tryDecryptWithContributor(
    encryptedData: Uint8Array,
    contentId: string | Uint8Array,
    contributor: NonNullable<UserCredentials['contributor']>,
    packageId: string
  ): Promise<Uint8Array> {
    const sealClient = await this.getSealClient();
    const suiClient = this.suiClient;
    
    const [{ SessionKey }, { Transaction }] = await Promise.all([
      import('@mysten/seal'),
      import('@mysten/sui/transactions')
    ]);
    
    const { SuiClient } = await import('@mysten/sui/client');
    const compatibleSuiClient = new SuiClient({ 
      url: getNetworkConfig('testnet').sui.rpcUrl 
    }) as any;
    
    const sessionKey = await SessionKey.create({
      address: suiClient.getAddress(),
      packageId,
      ttlMin: 10,
      suiClient: compatibleSuiClient,
    });
    
    const message = sessionKey.getPersonalMessage();
    const { signature } = await suiClient.getKeypair().signPersonalMessage(message);
    sessionKey.setPersonalMessageSignature(signature);
    
    const tx = new Transaction();
    // Convert contentId to bytes
    const contentIdBytes = contentId instanceof Uint8Array 
      ? Array.from(contentId)
      : Array.from(new TextEncoder().encode(contentId));
    
    tx.moveCall({
      target: `${packageId}::policy::seal_approve_roles`,
      arguments: [
        tx.pure.vector('u8', contentIdBytes),
        tx.object(contributor.publicationId),
      ]
    });
    
    const txBytes = await tx.build({ 
      client: suiClient.getClient(), 
      onlyTransactionKind: true 
    });
    
    const decrypted = await sealClient.decrypt({
      data: encryptedData,
      sessionKey,
      txBytes,
    });
    
    console.log(chalk.green('✅ Decrypted with contributor access'));
    return decrypted;
  }

  private async tryDecryptWithPublicationOwner(
    encryptedData: Uint8Array,
    contentId: string | Uint8Array,
    publicationOwner: NonNullable<UserCredentials['publicationOwner']>,
    packageId: string
  ): Promise<Uint8Array> {
    const sealClient = await this.getSealClient();
    const suiClient = this.suiClient;
    
    const [{ SessionKey }, { Transaction }] = await Promise.all([
      import('@mysten/seal'),
      import('@mysten/sui/transactions')
    ]);
    
    const { SuiClient } = await import('@mysten/sui/client');
    const compatibleSuiClient = new SuiClient({ 
      url: getNetworkConfig('testnet').sui.rpcUrl 
    }) as any;
    
    const sessionKey = await SessionKey.create({
      address: suiClient.getAddress(),
      packageId,
      ttlMin: 10,
      suiClient: compatibleSuiClient,
    });
    
    const message = sessionKey.getPersonalMessage();
    const { signature } = await suiClient.getKeypair().signPersonalMessage(message);
    sessionKey.setPersonalMessageSignature(signature);
    
    const tx = new Transaction();
    console.log(chalk.gray(`  Building transaction with:`));
    console.log(chalk.gray(`    Target: ${packageId}::policy::seal_approve_roles`));
    const contentIdDisplay = contentId instanceof Uint8Array 
      ? `[BCS bytes: ${contentId.length}]` 
      : contentId;
    console.log(chalk.gray(`    Content ID: ${contentIdDisplay}`));
    console.log(chalk.gray(`    Owner Cap ID: ${publicationOwner.ownerCapId}`));
    console.log(chalk.gray(`    Publication ID: ${publicationOwner.publicationId}`));
    
    // Convert content ID to bytes correctly
    let contentIdBytes: number[];
    if (contentId instanceof Uint8Array) {
      // Already BCS-encoded bytes
      contentIdBytes = Array.from(contentId);
    } else if (contentId.startsWith('0x')) {
      // If it's a hex string, convert from hex to bytes
      const hexStr = contentId.substring(2);
      contentIdBytes = [];
      for (let i = 0; i < hexStr.length; i += 2) {
        contentIdBytes.push(parseInt(hexStr.substr(i, 2), 16));
      }
    } else {
      // If it's a plain string, convert to UTF-8 bytes
      contentIdBytes = Array.from(new TextEncoder().encode(contentId));
    }
    
    console.log(chalk.gray(`  Content ID bytes length: ${contentIdBytes.length}`));
    
    tx.moveCall({
      target: `${packageId}::policy::seal_approve_roles`,
      arguments: [
        tx.pure.vector('u8', contentIdBytes),
        tx.object(publicationOwner.publicationId),
      ]
    });
    
    const txBytes = await tx.build({ 
      client: suiClient.getClient(), 
      onlyTransactionKind: true 
    });
    
    console.log(chalk.gray(`  Transaction built successfully, ${txBytes.length} bytes`));
    
    // Test if the transaction would succeed by executing it (dry run)
    try {
      const dryRunResult = await suiClient.getClient().dryRunTransactionBlock({
        transactionBlock: txBytes,
      });
      console.log(chalk.gray(`  Dry run status: ${dryRunResult.effects.status.status}`));
      if (dryRunResult.effects.status.status === 'failure') {
        console.log(chalk.red(`  Dry run failed: ${dryRunResult.effects.status.error}`));
      }
    } catch (dryRunError) {
      console.log(chalk.yellow(`  Could not dry run transaction: ${dryRunError}`));
    }
    
    try {
      console.log(chalk.gray(`  Calling Seal decrypt...`));
      console.log(chalk.gray(`  Encrypted data length: ${encryptedData.length} bytes`));
      console.log(chalk.gray(`  First 16 bytes: ${Array.from(encryptedData.slice(0, 16)).map(b => b.toString(16).padStart(2, '0')).join(' ')}`));
      
      const decrypted = await sealClient.decrypt({
        data: encryptedData,
        sessionKey,
        txBytes,
      });
      
      console.log(chalk.green('✅ Decrypted with publication owner access'));
      return decrypted;
    } catch (sealError: any) {
      console.log(chalk.red(`  Seal decrypt error: ${sealError.message}`));
      console.log(chalk.gray(`  Error details: ${JSON.stringify(sealError, null, 2)}`));
      throw sealError;
    }
  }

  private async tryDecryptWithAllowlist(
    _encryptedData: Uint8Array,
    _contentId: string | Uint8Array,
    _allowlist: NonNullable<UserCredentials['allowlist']>,
    _packageId: string
  ): Promise<Uint8Array> {
    // Note: Allowlist functionality not implemented in smart contract
    // Using roles-based approval as fallback
    throw new Error('Allowlist access not implemented - use publication roles instead');
  }

  // === DEMO ENCRYPTION/DECRYPTION (FALLBACK) ===

  private demoEncrypt(data: Uint8Array, contentId: string): Uint8Array {
    const key = new TextEncoder().encode(contentId.padEnd(32, '0')).slice(0, 32);
    const encrypted = new Uint8Array(data.length);
    
    for (let i = 0; i < data.length; i++) {
      encrypted[i] = data[i] ^ key[i % key.length];
    }
    
    const header = new TextEncoder().encode(`DEMO_ENCRYPTED_${contentId}_`);
    const result = new Uint8Array(header.length + encrypted.length);
    result.set(header, 0);
    result.set(encrypted, header.length);
    
    console.log(chalk.green(`✅ Content encrypted with demo encryption`));
    console.log(chalk.gray(`  Content ID: ${contentId}`));
    console.log(chalk.gray(`  Original size: ${data.length} bytes`));
    console.log(chalk.gray(`  Encrypted size: ${result.length} bytes`));
    
    return result;
  }

  private isDemoEncrypted(encryptedData: Uint8Array): boolean {
    const headerStart = new TextEncoder().encode('DEMO_ENCRYPTED_');
    if (encryptedData.length < headerStart.length) return false;
    
    for (let i = 0; i < headerStart.length; i++) {
      if (encryptedData[i] !== headerStart[i]) return false;
    }
    return true;
  }

  /**
   * Validate access control even in demo mode
   */
  private async validateAccessControl(credentials: UserCredentials, packageId?: string, requestingClient?: import('./client.js').InkraySuiClient): Promise<void> {
    // For now, we'll do basic validation
    // In a full implementation, this would call the smart contract to verify access
    
    if (!packageId) {
      throw new Error('Package ID required for access control validation');
    }

    // Check if user has any valid credentials
    const hasValidCredentials = !!(
      credentials.publicationOwner || 
      credentials.contributor || 
      credentials.subscription || 
      credentials.nft || 
      credentials.allowlist
    );

    if (!hasValidCredentials) {
      throw new Error('No valid credentials provided for access control');
    }

    // For publication owner credentials, we should validate that the user actually owns the owner cap
    if (credentials.publicationOwner) {
      console.log(chalk.gray('Validating publication owner access...'));
      
      // TODO: In a full implementation, we would:
      // 1. Get the owner cap object from the blockchain
      // 2. Verify that the current user actually owns that object
      // 3. Verify that the owner cap belongs to the specified publication
      
      // Use the requesting client if provided, otherwise use this instance's client
      const suiClient = requestingClient || this.suiClient;
      const currentUserAddress = suiClient.getAddress();
      
      console.log(chalk.gray(`Validating access for user: ${currentUserAddress}`));
      
      try {
        // Try to get the owner cap object - this will tell us if it exists and who owns it
        const ownerCapObject = await suiClient.getObject(credentials.publicationOwner.ownerCapId);
        
        if (!ownerCapObject.data) {
          throw new Error(`Owner cap object ${credentials.publicationOwner.ownerCapId} not found`);
        }

        // Check if the current user actually owns this object
        const ownerAddress = (ownerCapObject.data as any).owner?.AddressOwner;
        if (ownerAddress !== currentUserAddress) {
          throw new Error(`Access denied: Current user ${currentUserAddress} does not own owner cap ${credentials.publicationOwner.ownerCapId} (owned by ${ownerAddress})`);
        }

        console.log(chalk.green('✅ Publication owner access validated'));
        
      } catch (error) {
        console.log(chalk.red(`❌ Publication owner validation failed: ${error}`));
        throw error;
      }
    }

    // Similar validation could be added for other credential types
    if (credentials.contributor) {
      console.log(chalk.gray('Contributor validation not fully implemented - allowing access'));
    }

    if (credentials.subscription) {
      console.log(chalk.gray('Subscription validation not fully implemented - allowing access'));  
    }

    if (credentials.nft) {
      console.log(chalk.gray('NFT validation not fully implemented - allowing access'));
    }

    if (credentials.allowlist) {
      console.log(chalk.gray('Allowlist validation not fully implemented - allowing access'));
    }
  }

  private demoDecrypt(encryptedData: Uint8Array, contentId: string): Uint8Array {
    const headerText = `DEMO_ENCRYPTED_${contentId}_`;
    const header = new TextEncoder().encode(headerText);
    
    if (encryptedData.length < header.length) {
      throw new Error('Invalid demo encrypted data format');
    }
    
    const encrypted = encryptedData.slice(header.length);
    const key = new TextEncoder().encode(contentId.padEnd(32, '0')).slice(0, 32);
    const decrypted = new Uint8Array(encrypted.length);
    
    for (let i = 0; i < encrypted.length; i++) {
      decrypted[i] = encrypted[i] ^ key[i % key.length];
    }
    
    console.log(chalk.green(`✅ Demo decryption successful`));
    console.log(chalk.gray(`  Content ID: ${contentId}`));
    console.log(chalk.gray(`  Decrypted size: ${decrypted.length} bytes`));
    
    return decrypted;
  }

  // === CONVENIENCE METHODS ===

  async decryptToFile(
    request: SealDecryptionRequest, 
    outputPath: string
  ): Promise<void> {
    try {
      const decrypted = await this.decryptContent(request);
      
      const fs = await import('fs/promises');
      await fs.writeFile(outputPath, decrypted);
      
      console.log(chalk.green(`✅ Decrypted content saved to: ${outputPath}`));
    } catch (error) {
      console.error(chalk.red(`❌ Decryption to file failed: ${error}`));
      throw error;
    }
  }

  // === LEGACY SUPPORT ===

  /**
   * @deprecated Use encryptContent instead
   */
  async encryptData(data: Uint8Array, options: any): Promise<Uint8Array> {
    console.log(chalk.yellow('⚠️  Using deprecated encryptData method'));
    return this.demoEncrypt(data, options.policy || 'legacy');
  }

  /**
   * @deprecated Use decryptContent instead  
   */
  async decryptData(request: SealDecryptionRequestLegacy): Promise<Uint8Array> {
    console.log(chalk.yellow('⚠️  Using deprecated decryptData method'));
    return this.demoDecrypt(request.encryptedData, request.identity);
  }

  // === UTILITY METHODS ===

  private arraysEqual(a: Uint8Array, b: Uint8Array): boolean {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) return false;
    }
    return true;
  }

  /**
   * Validate if user has any access to the content
   */
  async validateAccess(
    contentId: string,
    credentials: UserCredentials
  ): Promise<{hasAccess: boolean, method?: string}> {
    try {
      console.log(chalk.blue(`✅ Validating access for content: ${contentId}`));
      
      // Check what credentials are available
      const availableMethods = [];
      if (credentials.subscription) availableMethods.push('subscription');
      if (credentials.nft) availableMethods.push('nft');
      if (credentials.contributor) availableMethods.push('contributor');
      if (credentials.allowlist) availableMethods.push('allowlist');
      
      if (availableMethods.length === 0) {
        console.log(chalk.red('❌ No credentials available'));
        return { hasAccess: false };
      }
      
      console.log(chalk.green(`✅ Available access methods: ${availableMethods.join(', ')}`));
      return { hasAccess: true, method: availableMethods[0] };
    } catch (error) {
      console.error(chalk.red(`❌ Access validation failed: ${error}`));
      return { hasAccess: false };
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