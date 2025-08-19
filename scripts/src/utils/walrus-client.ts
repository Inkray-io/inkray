import { WalrusClient, WalrusFile } from '@mysten/walrus';
import { getNetworkConfig, getCurrentNetwork } from '../config/networks.js';
import { getDefaultSuiClient } from './client.js';
import type { WalrusClientConfig, WalrusBlob, WalrusUploadResponse } from './types.js';
import chalk from 'chalk';
import type { RequestInfo, RequestInit } from 'undici';
import { Agent, fetch } from 'undici';
import fs from 'fs/promises';

export class InkrayWalrusClient {
  private client: WalrusClient;
  private config: WalrusClientConfig;
  private suiClient: import('./client.js').InkraySuiClient;

  constructor(config?: Partial<WalrusClientConfig> & { suiClient?: import('./client.js').InkraySuiClient }) {
    const network = getCurrentNetwork();
    const networkConfig = getNetworkConfig(network);

    this.config = {
      network: config?.network || networkConfig.walrus.network,
      publisherUrl: config?.publisherUrl || networkConfig.walrus.publisherUrl,
      aggregatorUrl: config?.aggregatorUrl || networkConfig.walrus.aggregatorUrl,
    };

    // Use provided Sui client or fall back to default
    this.suiClient = config?.suiClient || getDefaultSuiClient();

    this.client = new WalrusClient({
      network: this.config.network as 'testnet' | 'mainnet',
      suiClient: this.suiClient.getClient(),
      storageNodeClientOptions: {
        timeout: 60_000 * 2,
        fetch: (url, init) => {
          // Some casting may be required because undici types may not exactly match the @node/types types
          return fetch(url as RequestInfo, {
            ...(init as RequestInit),
            dispatcher: new Agent({
              connectTimeout: 60_000 * 2,
            }),
          }) as unknown as Promise<Response>;
        },
      },
    });
  }

  getClient(): WalrusClient {
    return this.client;
  }

  getConfig(): WalrusClientConfig {
    return this.config;
  }

  // File upload methods
  async uploadFile(filePath: string, options?: {
    epochs?: number;
    deletable?: boolean;
  }): Promise<WalrusUploadResponse> {
    try {
      console.log(chalk.blue(`📤 Uploading file to Walrus: ${filePath}`));

      // Read file
      const fileContent = await fs.readFile(filePath);

      // Get signer
      const signer = this.suiClient.getKeypair();

      // Upload to Walrus
      const result = await this.client.writeBlob({
        blob: fileContent,
        epochs: options?.epochs || 5,
        deletable: options?.deletable || false,
        signer,
      });

      if (!result) {
        throw new Error('Upload failed: No result returned');
      }

      console.log(chalk.green(`✓ File uploaded successfully`));
      console.log(chalk.gray(`  Blob ID: ${result.blobId}`));
      console.log(chalk.gray(`  Size: ${result.blobObject.size} bytes`));

      return result as WalrusUploadResponse;
    } catch (error) {
      console.error(chalk.red(`❌ Upload failed: ${error}`));
      throw error;
    }
  }

  async uploadBuffer(buffer: Uint8Array, filename: string, options?: {
    epochs?: number;
    deletable?: boolean;
  }): Promise<WalrusUploadResponse> {
    try {
      console.log(chalk.blue(`📤 Uploading buffer to Walrus: ${filename}`));

      // Try using writeBlob instead of writeFiles
      const signer = this.suiClient.getKeypair();

      const result = await this.client.writeBlob({
        blob: buffer,
        epochs: options?.epochs || 5,
        deletable: options?.deletable || false,
        signer,
      });

      if (!result) {
        throw new Error('Upload failed: No result returned');
      }

      console.log(chalk.green(`✓ Buffer uploaded successfully`));
      console.log(chalk.gray(`  Blob ID: ${result.blobId}`));
      console.log(chalk.gray(`  Size: ${result.blobObject.size} bytes`));

      return result as WalrusUploadResponse;
    } catch (error) {
      console.error(chalk.red(`❌ Upload failed: ${error}`));
      throw error;
    }
  }

  // File download methods
  async downloadBlob(blobId: string): Promise<Uint8Array> {
    try {
      console.log(chalk.blue(`📥 Downloading blob from Walrus: ${blobId}`));

      const files = await this.client.getFiles({
        ids: [blobId],
      });

      if (!files || files.length === 0) {
        throw new Error(`Blob not found: ${blobId}`);
      }

      const file = files[0];

      const content = file instanceof WalrusFile
        ? await file.bytes()
        : new Uint8Array(await (file as any).arrayBuffer());

      console.log(chalk.green(`✓ Blob downloaded successfully`));
      console.log(chalk.gray(`  Size: ${content.byteLength} bytes`));

      return content;
    } catch (error) {
      console.error(chalk.red(`❌ Download failed: ${error}`));
      throw error;
    }
  }

  async downloadBlobToFile(blobId: string, outputPath: string): Promise<void> {
    try {
      const content = await this.downloadBlob(blobId);
      await fs.writeFile(outputPath, content);

      console.log(chalk.green(`✓ Blob saved to: ${outputPath}`));
    } catch (error) {
      console.error(chalk.red(`❌ Save failed: ${error}`));
      throw error;
    }
  }

  // Utility methods
  async getBlobInfo(blobId: string): Promise<WalrusBlob | null> {
    try {
      const files = await this.client.getFiles({
        ids: [blobId],
      });

      if (!files || files.length === 0) {
        return null;
      }

      const file = files[0];

      return {
        blobId,
        size: (file as any).size || 0,
        storageEndEpoch: 0, // This would need to be retrieved from the blob object
      };
    } catch (error) {
      console.warn(chalk.yellow(`Warning: Could not get blob info for ${blobId}: ${error}`));
      return null;
    }
  }

  async blobExists(blobId: string): Promise<boolean> {
    try {
      const info = await this.getBlobInfo(blobId);
      return info !== null;
    } catch (error) {
      return false;
    }
  }

  // Batch operations
  async uploadMultipleFiles(filePaths: string[], options?: {
    epochs?: number;
    deletable?: boolean;
  }): Promise<WalrusUploadResponse[]> {
    try {
      console.log(chalk.blue(`📤 Uploading ${filePaths.length} files to Walrus`));

      const files = await Promise.all(
        filePaths.map(async (filePath) => {
          const content = await fs.readFile(filePath);
          const fileName = filePath.split('/').pop() || 'file';
          return (WalrusFile as any).from(content, fileName);
        })
      );

      const signer = this.suiClient.getKeypair();

      const results = await this.client.writeFiles({
        files,
        epochs: options?.epochs || 5,
        deletable: options?.deletable || false,
        signer,
      });

      console.log(chalk.green(`✓ ${results.length} files uploaded successfully`));
      return results as WalrusUploadResponse[];
    } catch (error) {
      console.error(chalk.red(`❌ Batch upload failed: ${error}`));
      throw error;
    }
  }

  async downloadMultipleBlobs(blobIds: string[]): Promise<Map<string, Uint8Array>> {
    try {
      console.log(chalk.blue(`📥 Downloading ${blobIds.length} blobs from Walrus`));

      const files = await this.client.getFiles({
        ids: blobIds,
      });

      const results = new Map<string, Uint8Array>();

      for (let i = 0; i < files.length; i++) {
        const file = files[i];
        const content = await (file as any).arrayBuffer();
        results.set(blobIds[i], new Uint8Array(content));
      }

      console.log(chalk.green(`✓ ${results.size} blobs downloaded successfully`));
      return results;
    } catch (error) {
      console.error(chalk.red(`❌ Batch download failed: ${error}`));
      throw error;
    }
  }
}

// Singleton instance management
let defaultWalrusClient: InkrayWalrusClient | null = null;

export function createWalrusClient(config?: Partial<WalrusClientConfig> & { suiClient?: import('./client.js').InkraySuiClient }): InkrayWalrusClient {
  return new InkrayWalrusClient(config);
}

export function getDefaultWalrusClient(config?: Partial<WalrusClientConfig> & { suiClient?: import('./client.js').InkraySuiClient }): InkrayWalrusClient {
  if (!defaultWalrusClient) {
    defaultWalrusClient = new InkrayWalrusClient(config);
  }
  return defaultWalrusClient;
}

export function setDefaultWalrusClient(client: InkrayWalrusClient): void {
  defaultWalrusClient = client;
}