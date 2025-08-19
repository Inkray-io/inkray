import { createTransaction, executeTransaction } from '../utils/transactions.js';
import { getDefaultSuiClient } from '../utils/client.js';
import chalk from 'chalk';
import type { TransactionResult } from '../utils/types.js';

export interface CreateArticleParams {
  publicationId: string;
  vaultId: string;
  ownerCapId: string;
  title: string;
  walrusBlobObjectId: string;
  sealContentId: string | Uint8Array;
  isGated: boolean;
}

export interface CreateArticleResult {
  articleId: string;
  transactionDigest: string;
  transactionResult: TransactionResult;
}

/**
 * Article management using Sui PTBs (Programmable Transaction Blocks)
 * Creates real Article objects on blockchain using smart contract integration
 */
export class ArticleManager {
  private client: import('../utils/client.js').InkraySuiClient;
  private packageId: string;

  constructor(
    client?: import('../utils/client.js').InkraySuiClient,
    packageId?: string
  ) {
    this.client = client || getDefaultSuiClient();
    this.packageId = packageId || process.env.PACKAGE_ID!;

    if (!this.packageId) {
      throw new Error('Package ID not found. Please deploy contracts first or set PACKAGE_ID env var.');
    }
  }

  /**
   * Create a new article using PTB with real smart contract integration
   * 
   * Flow:
   * 1. Create StoredAsset from Walrus blob + seal ID
   * 2. Create Access enum (gated/free)
   * 3. Create Article using post_as_owner
   * 4. Transfer Article to sender
   */
  async createArticle(params: CreateArticleParams): Promise<CreateArticleResult> {
    try {
      console.log(chalk.blue('📝 Creating article with real smart contract integration...'));
      console.log(chalk.gray(`  Title: ${params.title}`));
      console.log(chalk.gray(`  Gated: ${params.isGated}`));
      console.log(chalk.gray(`  Walrus Blob: ${params.walrusBlobObjectId}`));
      console.log(chalk.gray(`  Package ID: ${this.packageId}`));
      console.log(chalk.gray(`  Seal Content ID: ${params.sealContentId}`));

      const result = await executeTransaction(async (tx) => {
        // Step 1: Create StoredAsset from Walrus blob + seal ID
        console.log(chalk.blue('  📦 Creating StoredAsset...'));
        console.log(chalk.gray(`    Seal Content ID: ${params.sealContentId instanceof Uint8Array ? `[BCS bytes: ${params.sealContentId.length}]` : `"${params.sealContentId}"`}`));

        // Validate seal content ID
        if (!params.sealContentId) {
          throw new Error(`Invalid seal content ID: ${params.sealContentId}`);
        }

        // Convert to proper Uint8Array based on input type
        let sealIdBytes: Uint8Array;
        if (params.sealContentId instanceof Uint8Array) {
          // Already BCS-encoded bytes - use directly
          sealIdBytes = params.sealContentId;
        } else if (typeof params.sealContentId === 'string') {
          if (params.sealContentId.startsWith('0x')) {
            // Remove 0x prefix and convert hex pairs to bytes
            const hexString = params.sealContentId.slice(2);
            const bytes = [];
            for (let i = 0; i < hexString.length; i += 2) {
              bytes.push(parseInt(hexString.slice(i, i + 2), 16));
            }
            sealIdBytes = new Uint8Array(bytes);
          } else {
            // Fallback: treat as text and encode as UTF-8
            sealIdBytes = new TextEncoder().encode(params.sealContentId);
          }
        } else {
          throw new Error(`Invalid seal content ID type: ${typeof params.sealContentId}`);
        }

        console.log(chalk.gray(`    Seal ID bytes length: ${sealIdBytes.length}`));
        console.log(chalk.gray(`    First few bytes: ${Array.from(sealIdBytes.slice(0, 10)).join(',')}`));

        const storedAsset = tx.moveCall({
          package: this.packageId,
          module: 'vault',
          function: 'new_stored_asset_minimal',
          arguments: [
            tx.objectArg(params.walrusBlobObjectId), // walrus::blob::Blob object
            tx.getTransaction().pure.vector('u8', sealIdBytes), // BCS-encoded seal ID
          ],
        });

        // Step 2: Create Access enum (gated or free)
        console.log(chalk.blue(`  🔐 Creating Access enum (${params.isGated ? 'gated' : 'free'})...`));
        const gatingAccess = tx.moveCall({
          package: this.packageId,
          module: 'vault',
          function: params.isGated ? 'access_gated' : 'access_free',
          arguments: [],
        });

        // Step 3: Create empty vector for additional assets using smart contract function
        console.log(chalk.blue('  📦 Creating empty StoredAsset vector...'));
        const emptyAssetsVec = tx.moveCall({
          package: this.packageId,
          module: 'vault',
          function: 'empty_stored_asset_vector',
          arguments: [],
        });

        // Step 4: Create Article using post_as_owner
        console.log(chalk.blue('  📄 Creating Article object...'));
        const slug = params.title.toLowerCase().replace(/\s+/g, '_'); // Convert title to slug

        const article = tx.moveCall({
          package: this.packageId,
          module: 'articles',
          function: 'post_as_owner',
          arguments: [
            tx.objectArg(params.ownerCapId),     // &PublicationOwnerCap
            tx.objectArg(params.publicationId),  // &Publication
            tx.objectArg(params.vaultId),        // &mut PublicationVault
            tx.pureString(params.title),         // String title
            tx.pureString(slug),                 // String slug
            gatingAccess,                        // Access enum
            storedAsset,                         // StoredAsset (body asset)
            emptyAssetsVec,                      // vector<StoredAsset> (additional assets)
          ],
        });

        // Step 5: Transfer Article to sender
        console.log(chalk.blue('  📤 Transferring Article to sender...'));
        tx.transferObjects([article], this.client.getAddress());
      }, this.client);

      // Extract Article object ID from transaction result
      const articleId = this.extractArticleId(result);

      console.log(chalk.green('✅ Article created successfully!'));
      console.log(chalk.gray(`  Article ID: ${articleId}`));
      console.log(chalk.gray(`  Transaction: ${result.digest}`));

      return {
        articleId,
        transactionDigest: result.digest,
        transactionResult: result,
      };
    } catch (error) {
      console.error(chalk.red(`❌ Failed to create article: ${error}`));
      throw error;
    }
  }

  /**
   * Extract Article object ID from transaction result
   */
  private extractArticleId(result: TransactionResult): string {
    // Debug logging to see what objects were created
    const allCreatedObjects = result.objectChanges?.filter(change => change.type === 'created') || [];
    console.log(chalk.gray(`  Debug: Found ${allCreatedObjects.length} created objects:`));
    allCreatedObjects.forEach((change, index) => {
      console.log(chalk.gray(`    ${index + 1}. ${(change as any).objectType} (${(change as any).objectId})`));
    });

    const createdObjects = result.objectChanges?.filter(change =>
      change.type === 'created' &&
      ((change as any).objectType?.includes('::articles::Article') || (change as any).objectType?.endsWith('::Article')) &&
      !(change as any).objectType?.includes('Cap') // Exclude owner caps
    ) || [];

    if (createdObjects.length === 0) {
      console.log(chalk.red(`  Debug: No Article objects found. Looking for objects containing '::articles::Article' or ending with '::Article'`));
      throw new Error('No Article object found in transaction result');
    }

    const articleChange = createdObjects[0];
    const articleId = (articleChange as any).objectId;

    if (!articleId) {
      throw new Error('Failed to extract Article object ID from transaction');
    }

    return articleId;
  }

  /**
   * Get article information from blockchain
   */
  async getArticle(articleId: string): Promise<any> {
    try {
      console.log(chalk.blue(`📖 Fetching article: ${articleId}`));

      const objectData = await this.client.getObject(articleId);

      if (!objectData.data) {
        console.log(chalk.yellow(`⚠️  Article not found: ${articleId}`));
        return null;
      }

      const content = (objectData.data as any).content;
      if (!content || !content.fields) {
        throw new Error('Invalid article object structure');
      }

      const fields = content.fields;
      console.log(chalk.green(`✅ Article retrieved successfully!`));
      console.log(chalk.gray(`  Title: ${fields.title || 'Unknown'}`));
      console.log(chalk.gray(`  Author: ${fields.author || 'Unknown'}`));
      console.log(chalk.gray(`  Debug - Gating object:`, JSON.stringify(fields.gating, null, 2)));
      console.log(chalk.gray(`  Gated: ${fields.gating?.variant === 'Gated' ? 'Yes' : 'No'}`));

      return {
        id: articleId,
        title: fields.title,
        slug: fields.slug,
        author: fields.author,
        publication_id: fields.publication_id,
        body_id: fields.body_id,
        asset_ids: fields.asset_ids?.fields?.contents || [],
        gating: fields.gating,
        created_at: fields.created_at,
      };
    } catch (error) {
      console.error(chalk.red(`❌ Failed to fetch article: ${error}`));
      return null;
    }
  }

  /**
   * Check if article exists on blockchain
   */
  async articleExists(articleId: string): Promise<boolean> {
    try {
      const article = await this.getArticle(articleId);
      return article !== null;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to check article existence: ${error}`));
      return false;
    }
  }

  /**
   * Validate article data integrity
   */
  async validateArticle(articleId: string, expectedTitle: string): Promise<boolean> {
    try {
      const article = await this.getArticle(articleId);

      if (!article) {
        return false;
      }

      // Basic validation checks
      const isValid =
        article.title === expectedTitle &&
        article.id === articleId &&
        article.author === this.client.getAddress();

      if (isValid) {
        console.log(chalk.green('✅ Article validation passed'));
      } else {
        console.log(chalk.yellow('⚠️  Article validation failed'));
        console.log(chalk.gray(`  Expected title: ${expectedTitle}, got: ${article.title}`));
        console.log(chalk.gray(`  Expected author: ${this.client.getAddress()}, got: ${article.author}`));
      }

      return isValid;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to validate article: ${error}`));
      return false;
    }
  }
}

// Singleton instance management
let defaultManager: ArticleManager | null = null;

export function createArticleManager(
  client?: import('../utils/client.js').InkraySuiClient,
  packageId?: string
): ArticleManager {
  return new ArticleManager(client, packageId);
}

export function getDefaultArticleManager(
  client?: import('../utils/client.js').InkraySuiClient,
  packageId?: string
): ArticleManager {
  if (!defaultManager) {
    defaultManager = new ArticleManager(client, packageId);
  }
  return defaultManager;
}

// Convenience functions
export async function createArticle(
  params: CreateArticleParams,
  client?: import('../utils/client.js').InkraySuiClient,
  packageId?: string
): Promise<CreateArticleResult> {
  return await getDefaultArticleManager(client, packageId).createArticle(params);
}

export async function getArticle(
  articleId: string,
  client?: import('../utils/client.js').InkraySuiClient,
  packageId?: string
): Promise<any> {
  return await getDefaultArticleManager(client, packageId).getArticle(articleId);
}

export async function validateArticle(
  articleId: string,
  expectedTitle: string,
  client?: import('../utils/client.js').InkraySuiClient,
  packageId?: string
): Promise<boolean> {
  return await getDefaultArticleManager(client, packageId).validateArticle(articleId, expectedTitle);
}