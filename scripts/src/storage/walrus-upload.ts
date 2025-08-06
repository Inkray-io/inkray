import { getDefaultWalrusClient } from '../utils/walrus-client.js';
import { getDefaultSuiClient } from '../utils/client.js';
import { DEFAULTS } from '../config/constants.js';
import type { WalrusUploadResponse } from '../utils/types.js';
import chalk from 'chalk';
import fs from 'fs/promises';
import path from 'path';

export interface UploadOptions {
  epochs?: number;
  deletable?: boolean;
  metadata?: Record<string, any>;
}

export interface UploadResult {
  blobId: string;
  blobObjectId: string;
  size: number;
  storageEndEpoch: number;
  uploadUrl?: string;
}

export class WalrusUploadManager {
  private walrusClient = getDefaultWalrusClient();
  private suiClient = getDefaultSuiClient();

  async uploadFile(
    filePath: string, 
    options: UploadOptions = {}
  ): Promise<UploadResult> {
    try {
      console.log(chalk.blue(`📤 Starting file upload: ${filePath}`));
      
      // Validate file exists
      await this.validateFile(filePath);
      
      // Get file info
      const fileStats = await fs.stat(filePath);
      const fileName = path.basename(filePath);
      
      console.log(chalk.gray(`File size: ${fileStats.size} bytes`));
      console.log(chalk.gray(`File name: ${fileName}`));
      
      // Upload to Walrus
      const uploadResponse = await this.walrusClient.uploadFile(filePath, {
        epochs: options.epochs || DEFAULTS.STORAGE_EPOCHS,
        deletable: options.deletable || false,
      });
      
      // Process upload response
      const result = this.processUploadResponse(uploadResponse, fileName, options.metadata);
      
      console.log(chalk.green(`✅ File uploaded successfully!`));
      console.log(chalk.gray(`Blob ID: ${result.blobId}`));
      console.log(chalk.gray(`Storage end epoch: ${result.storageEndEpoch}`));
      
      return result;
    } catch (error) {
      console.error(chalk.red(`❌ File upload failed: ${error}`));
      throw error;
    }
  }

  async uploadBuffer(
    buffer: Uint8Array,
    fileName: string,
    options: UploadOptions = {}
  ): Promise<UploadResult> {
    try {
      console.log(chalk.blue(`📤 Starting buffer upload: ${fileName}`));
      console.log(chalk.gray(`Buffer size: ${buffer.length} bytes`));
      
      // Upload to Walrus
      const uploadResponse = await this.walrusClient.uploadBuffer(buffer, fileName, {
        epochs: options.epochs || DEFAULTS.STORAGE_EPOCHS,
        deletable: options.deletable || false,
      });
      
      // Process upload response
      const result = this.processUploadResponse(uploadResponse, fileName, options.metadata);
      
      console.log(chalk.green(`✅ Buffer uploaded successfully!`));
      console.log(chalk.gray(`Blob ID: ${result.blobId}`));
      
      return result;
    } catch (error) {
      console.error(chalk.red(`❌ Buffer upload failed: ${error}`));
      throw error;
    }
  }

  async uploadMultipleFiles(
    filePaths: string[],
    options: UploadOptions = {}
  ): Promise<UploadResult[]> {
    try {
      console.log(chalk.blue(`📤 Starting batch upload: ${filePaths.length} files`));
      
      // Validate all files exist
      for (const filePath of filePaths) {
        await this.validateFile(filePath);
      }
      
      // Upload all files
      const uploadResponses = await this.walrusClient.uploadMultipleFiles(filePaths, {
        epochs: options.epochs || DEFAULTS.STORAGE_EPOCHS,
        deletable: options.deletable || false,
      });
      
      // Process all responses
      const results: UploadResult[] = [];
      for (let i = 0; i < uploadResponses.length; i++) {
        const fileName = path.basename(filePaths[i]);
        const result = this.processUploadResponse(uploadResponses[i], fileName, options.metadata);
        results.push(result);
      }
      
      console.log(chalk.green(`✅ Batch upload completed: ${results.length} files`));
      return results;
    } catch (error) {
      console.error(chalk.red(`❌ Batch upload failed: ${error}`));
      throw error;
    }
  }

  async uploadDirectory(
    directoryPath: string,
    options: UploadOptions & { 
      recursive?: boolean;
      fileFilter?: (fileName: string) => boolean;
    } = {}
  ): Promise<UploadResult[]> {
    try {
      console.log(chalk.blue(`📤 Starting directory upload: ${directoryPath}`));
      
      // Get all files in directory
      const files = await this.getDirectoryFiles(directoryPath, options.recursive, options.fileFilter);
      
      if (files.length === 0) {
        throw new Error('No files found in directory');
      }
      
      console.log(chalk.gray(`Found ${files.length} files to upload`));
      
      // Upload all files
      return await this.uploadMultipleFiles(files, options);
    } catch (error) {
      console.error(chalk.red(`❌ Directory upload failed: ${error}`));
      throw error;
    }
  }

  private async validateFile(filePath: string): Promise<void> {
    try {
      const stats = await fs.stat(filePath);
      
      if (!stats.isFile()) {
        throw new Error(`Path is not a file: ${filePath}`);
      }
      
      if (stats.size === 0) {
        throw new Error(`File is empty: ${filePath}`);
      }
      
      // Check file size limits (Walrus has size limits)
      const maxSize = 100 * 1024 * 1024; // 100MB
      if (stats.size > maxSize) {
        throw new Error(`File too large: ${stats.size} bytes (max: ${maxSize} bytes)`);
      }
    } catch (error) {
      if ((error as any).code === 'ENOENT') {
        throw new Error(`File not found: ${filePath}`);
      }
      throw error;
    }
  }

  private async getDirectoryFiles(
    directoryPath: string,
    recursive: boolean = false,
    fileFilter?: (fileName: string) => boolean
  ): Promise<string[]> {
    const files: string[] = [];
    
    const entries = await fs.readdir(directoryPath, { withFileTypes: true });
    
    for (const entry of entries) {
      const fullPath = path.join(directoryPath, entry.name);
      
      if (entry.isFile()) {
        if (!fileFilter || fileFilter(entry.name)) {
          files.push(fullPath);
        }
      } else if (entry.isDirectory() && recursive) {
        const subFiles = await this.getDirectoryFiles(fullPath, recursive, fileFilter);
        files.push(...subFiles);
      }
    }
    
    return files;
  }

  private processUploadResponse(
    uploadResponse: WalrusUploadResponse,
    fileName: string,
    metadata?: Record<string, any>
  ): UploadResult {
    const blobObject = uploadResponse.blobObject;
    
    return {
      blobId: blobObject.blobId,
      blobObjectId: blobObject.id,
      size: blobObject.size,
      storageEndEpoch: blobObject.storageEndEpoch,
      uploadUrl: `walrus://${blobObject.blobId}`,
    };
  }

  // Utility methods for upload management
  async getUploadCost(sizeBytes: number, epochs: number = DEFAULTS.STORAGE_EPOCHS): Promise<bigint> {
    try {
      // This would calculate the cost based on Walrus pricing
      // For now, return a rough estimate
      const costPerBytePerEpoch = 100n; // MIST per byte per epoch (rough estimate)
      return BigInt(sizeBytes) * BigInt(epochs) * costPerBytePerEpoch;
    } catch (error) {
      console.warn(chalk.yellow(`Warning: Could not calculate upload cost: ${error}`));
      return 0n;
    }
  }

  async estimateUploadTime(sizeBytes: number): Promise<number> {
    // Rough estimate based on file size
    // This would ideally use network conditions and Walrus performance metrics
    const baseSizeKB = 1024;
    const baseTimeSeconds = 5;
    const scaleFactor = 1.2;
    
    const sizeKB = sizeBytes / 1024;
    const estimatedSeconds = baseTimeSeconds + (sizeKB / baseSizeKB) * scaleFactor;
    
    return Math.max(estimatedSeconds, 1);
  }

  async checkStorageQuota(): Promise<{ used: number; total: number; remaining: number }> {
    try {
      // This would check the user's storage quota on Walrus
      // For now, return dummy values
      return {
        used: 0,
        total: 1000000000, // 1GB
        remaining: 1000000000,
      };
    } catch (error) {
      console.warn(chalk.yellow(`Warning: Could not check storage quota: ${error}`));
      return {
        used: 0,
        total: 0,
        remaining: 0,
      };
    }
  }

  // Helper methods for common file types
  async uploadImage(
    imagePath: string,
    options: UploadOptions & { 
      resize?: { width: number; height: number };
      format?: 'jpeg' | 'png' | 'webp';
    } = {}
  ): Promise<UploadResult> {
    // Validate image file
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg'];
    const ext = path.extname(imagePath).toLowerCase();
    
    if (!allowedExtensions.includes(ext)) {
      throw new Error(`Unsupported image format: ${ext}`);
    }
    
    // For now, just upload as-is
    // In a full implementation, we could add image processing here
    return await this.uploadFile(imagePath, options);
  }

  async uploadText(
    text: string,
    fileName: string,
    options: UploadOptions = {}
  ): Promise<UploadResult> {
    const buffer = new TextEncoder().encode(text);
    return await this.uploadBuffer(buffer, fileName, options);
  }

  async uploadJSON(
    data: any,
    fileName: string,
    options: UploadOptions = {}
  ): Promise<UploadResult> {
    const jsonString = JSON.stringify(data, null, 2);
    const buffer = new TextEncoder().encode(jsonString);
    return await this.uploadBuffer(buffer, fileName, options);
  }
}

// Singleton instance
let defaultUploadManager: WalrusUploadManager | null = null;

export function createUploadManager(): WalrusUploadManager {
  return new WalrusUploadManager();
}

export function getDefaultUploadManager(): WalrusUploadManager {
  if (!defaultUploadManager) {
    defaultUploadManager = new WalrusUploadManager();
  }
  return defaultUploadManager;
}

// Convenience functions
export async function uploadFile(filePath: string, options?: UploadOptions): Promise<UploadResult> {
  return await getDefaultUploadManager().uploadFile(filePath, options);
}

export async function uploadText(text: string, fileName: string, options?: UploadOptions): Promise<UploadResult> {
  return await getDefaultUploadManager().uploadText(text, fileName, options);
}

export async function uploadJSON(data: any, fileName: string, options?: UploadOptions): Promise<UploadResult> {
  return await getDefaultUploadManager().uploadJSON(data, fileName, options);
}