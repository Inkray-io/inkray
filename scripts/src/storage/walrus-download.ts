import { getDefaultWalrusClient } from '../utils/walrus-client.js';
import type { WalrusBlob } from '../utils/types.js';
import chalk from 'chalk';
import fs from 'fs/promises';
import path from 'path';

export interface DownloadOptions {
  outputPath?: string;
  createDirectories?: boolean;
  overwrite?: boolean;
  verifyIntegrity?: boolean;
}

export interface DownloadResult {
  blobId: string;
  size: number;
  outputPath?: string;
  data?: Uint8Array;
  contentType?: string;
}

export class WalrusDownloadManager {
  private walrusClient = getDefaultWalrusClient();

  async downloadBlob(
    blobId: string, 
    options: DownloadOptions = {}
  ): Promise<DownloadResult> {
    try {
      console.log(chalk.blue(`📥 Starting blob download: ${blobId}`));
      
      // Download from Walrus
      const data = await this.walrusClient.downloadBlob(blobId);
      
      console.log(chalk.gray(`Downloaded ${data.length} bytes`));
      
      // Save to file if output path specified
      let outputPath: string | undefined;
      if (options.outputPath) {
        outputPath = await this.saveToFile(data, options.outputPath, options);
      }
      
      console.log(chalk.green(`✅ Blob downloaded successfully!`));
      if (outputPath) {
        console.log(chalk.gray(`Saved to: ${outputPath}`));
      }
      
      return {
        blobId,
        size: data.length,
        outputPath,
        data,
        contentType: this.detectContentType(data),
      };
    } catch (error) {
      console.error(chalk.red(`❌ Blob download failed: ${error}`));
      throw error;
    }
  }

  async downloadBlobToFile(
    blobId: string, 
    outputPath: string,
    options: DownloadOptions = {}
  ): Promise<DownloadResult> {
    try {
      console.log(chalk.blue(`📥 Downloading blob to file: ${blobId} -> ${outputPath}`));
      
      // Download blob data
      const data = await this.walrusClient.downloadBlob(blobId);
      
      // Save to file
      const finalPath = await this.saveToFile(data, outputPath, options);
      
      console.log(chalk.green(`✅ Blob downloaded and saved!`));
      console.log(chalk.gray(`File: ${finalPath}`));
      console.log(chalk.gray(`Size: ${data.length} bytes`));
      
      return {
        blobId,
        size: data.length,
        outputPath: finalPath,
        contentType: this.detectContentType(data),
      };
    } catch (error) {
      console.error(chalk.red(`❌ Download to file failed: ${error}`));
      throw error;
    }
  }

  async downloadMultipleBlobs(
    blobIds: string[],
    options: DownloadOptions & { 
      outputDirectory?: string;
      namePattern?: (blobId: string, index: number) => string;
    } = {}
  ): Promise<DownloadResult[]> {
    try {
      console.log(chalk.blue(`📥 Starting batch download: ${blobIds.length} blobs`));
      
      // Download all blobs
      const blobDataMap = await this.walrusClient.downloadMultipleBlobs(blobIds);
      
      const results: DownloadResult[] = [];
      let index = 0;
      
      for (const [blobId, data] of blobDataMap.entries()) {
        let outputPath: string | undefined;
        
        if (options.outputDirectory) {
          const fileName = options.namePattern 
            ? options.namePattern(blobId, index)
            : `blob_${blobId.substring(0, 8)}_${index}`;
          
          outputPath = path.join(options.outputDirectory, fileName);
          outputPath = await this.saveToFile(data, outputPath, options);
        }
        
        results.push({
          blobId,
          size: data.length,
          outputPath,
          data,
          contentType: this.detectContentType(data),
        });
        
        index++;
      }
      
      console.log(chalk.green(`✅ Batch download completed: ${results.length} blobs`));
      return results;
    } catch (error) {
      console.error(chalk.red(`❌ Batch download failed: ${error}`));
      throw error;
    }
  }

  async downloadBlobInfo(blobId: string): Promise<WalrusBlob | null> {
    try {
      console.log(chalk.blue(`ℹ️  Getting blob info: ${blobId}`));
      
      const info = await this.walrusClient.getBlobInfo(blobId);
      
      if (info) {
        console.log(chalk.green(`✅ Blob info retrieved`));
        console.log(chalk.gray(`Size: ${info.size} bytes`));
        console.log(chalk.gray(`Storage end epoch: ${info.storageEndEpoch}`));
      } else {
        console.log(chalk.yellow(`⚠️  Blob not found: ${blobId}`));
      }
      
      return info;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to get blob info: ${error}`));
      return null;
    }
  }

  async verifyBlobExists(blobId: string): Promise<boolean> {
    try {
      const exists = await this.walrusClient.blobExists(blobId);
      
      if (exists) {
        console.log(chalk.green(`✅ Blob exists: ${blobId}`));
      } else {
        console.log(chalk.yellow(`⚠️  Blob not found: ${blobId}`));
      }
      
      return exists;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to verify blob existence: ${error}`));
      return false;
    }
  }

  private async saveToFile(
    data: Uint8Array, 
    outputPath: string,
    options: DownloadOptions
  ): Promise<string> {
    // Create directories if needed
    if (options.createDirectories !== false) {
      const dir = path.dirname(outputPath);
      await fs.mkdir(dir, { recursive: true });
    }
    
    // Check if file exists and handle overwrite
    try {
      await fs.access(outputPath);
      if (!options.overwrite) {
        // File exists and overwrite is false, generate new name
        outputPath = await this.generateUniqueFileName(outputPath);
      }
    } catch (error) {
      // File doesn't exist, proceed normally
    }
    
    // Write file
    await fs.writeFile(outputPath, data);
    
    // Verify integrity if requested
    if (options.verifyIntegrity) {
      await this.verifyFileIntegrity(outputPath, data);
    }
    
    return outputPath;
  }

  private async generateUniqueFileName(basePath: string): Promise<string> {
    const dir = path.dirname(basePath);
    const ext = path.extname(basePath);
    const nameWithoutExt = path.basename(basePath, ext);
    
    let counter = 1;
    let newPath: string;
    
    do {
      newPath = path.join(dir, `${nameWithoutExt}_${counter}${ext}`);
      counter++;
      
      try {
        await fs.access(newPath);
      } catch (error) {
        // File doesn't exist, use this path
        break;
      }
    } while (counter < 1000); // Safety limit
    
    return newPath;
  }

  private async verifyFileIntegrity(filePath: string, originalData: Uint8Array): Promise<void> {
    try {
      const fileData = await fs.readFile(filePath);
      
      if (fileData.length !== originalData.length) {
        throw new Error('File size mismatch after save');
      }
      
      // Compare bytes (for small files)
      if (originalData.length < 1024 * 1024) { // 1MB
        for (let i = 0; i < originalData.length; i++) {
          if (fileData[i] !== originalData[i]) {
            throw new Error('File content mismatch after save');
          }
        }
      }
      
      console.log(chalk.green(`✓ File integrity verified`));
    } catch (error) {
      console.error(chalk.red(`❌ File integrity check failed: ${error}`));
      throw error;
    }
  }

  private detectContentType(data: Uint8Array): string {
    // Simple content type detection based on file headers
    if (data.length === 0) return 'application/octet-stream';
    
    // Check for common file signatures
    const header = Array.from(data.slice(0, 8)).map(b => b.toString(16).padStart(2, '0')).join('');
    
    if (header.startsWith('89504e47')) return 'image/png';
    if (header.startsWith('ffd8ff')) return 'image/jpeg';
    if (header.startsWith('47494638')) return 'image/gif';
    if (header.startsWith('52494646')) return 'image/webp';
    if (header.startsWith('25504446')) return 'application/pdf';
    if (header.startsWith('504b0304')) return 'application/zip';
    
    // Check for text content
    try {
      const text = new TextDecoder('utf-8', { fatal: true }).decode(data.slice(0, 1024));
      if (text.includes('{') && text.includes('}')) return 'application/json';
      if (text.includes('<') && text.includes('>')) return 'text/html';
      return 'text/plain';
    } catch (error) {
      // Not valid UTF-8 text
    }
    
    return 'application/octet-stream';
  }

  // Specialized download methods
  async downloadAsText(blobId: string, encoding: string = 'utf-8'): Promise<string> {
    const result = await this.downloadBlob(blobId);
    
    if (!result.data) {
      throw new Error('No data received');
    }
    
    try {
      return new TextDecoder(encoding).decode(result.data);
    } catch (error) {
      throw new Error(`Failed to decode text with encoding ${encoding}: ${error}`);
    }
  }

  async downloadAsJSON<T = any>(blobId: string): Promise<T> {
    const text = await this.downloadAsText(blobId);
    
    try {
      return JSON.parse(text);
    } catch (error) {
      throw new Error(`Failed to parse JSON: ${error}`);
    }
  }

  async downloadImage(
    blobId: string, 
    outputPath: string,
    options: DownloadOptions = {}
  ): Promise<DownloadResult> {
    const result = await this.downloadBlobToFile(blobId, outputPath, options);
    
    // Verify it's actually an image
    if (!result.contentType || !result.contentType.startsWith('image/')) {
      console.warn(chalk.yellow(`⚠️  Warning: Downloaded content may not be an image (${result.contentType})`));
    }
    
    return result;
  }

  // Stream download for large files (placeholder)
  async streamDownload(
    blobId: string,
    outputPath: string,
    options: DownloadOptions & {
      chunkSize?: number;
      onProgress?: (downloaded: number, total: number) => void;
    } = {}
  ): Promise<DownloadResult> {
    // For now, fall back to regular download
    // In a full implementation, this would stream the download
    console.log(chalk.blue(`📥 Stream downloading: ${blobId}`));
    
    return await this.downloadBlobToFile(blobId, outputPath, options);
  }
}

// Singleton instance
let defaultDownloadManager: WalrusDownloadManager | null = null;

export function createDownloadManager(): WalrusDownloadManager {
  return new WalrusDownloadManager();
}

export function getDefaultDownloadManager(): WalrusDownloadManager {
  if (!defaultDownloadManager) {
    defaultDownloadManager = new WalrusDownloadManager();
  }
  return defaultDownloadManager;
}

// Convenience functions
export async function downloadBlob(blobId: string, options?: DownloadOptions): Promise<DownloadResult> {
  return await getDefaultDownloadManager().downloadBlob(blobId, options);
}

export async function downloadBlobToFile(blobId: string, outputPath: string, options?: DownloadOptions): Promise<DownloadResult> {
  return await getDefaultDownloadManager().downloadBlobToFile(blobId, outputPath, options);
}

export async function downloadAsText(blobId: string, encoding?: string): Promise<string> {
  return await getDefaultDownloadManager().downloadAsText(blobId, encoding);
}

export async function downloadAsJSON<T = any>(blobId: string): Promise<T> {
  return await getDefaultDownloadManager().downloadAsJSON<T>(blobId);
}