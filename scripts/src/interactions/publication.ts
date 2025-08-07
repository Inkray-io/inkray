import { createTransaction, executeTransaction } from '../utils/transactions.js';
import { getDefaultSuiClient } from '../utils/client.js';
import { CONTRACT_ADDRESSES, MODULES, FUNCTIONS } from '../config/constants.js';
import type { Publication, PublicationOwnerCap, TransactionResult } from '../utils/types.js';
import chalk from 'chalk';

export interface CreatePublicationParams {
  name: string;
  description: string;
  vaultId?: string;
}

export interface PublicationResult {
  publication: Publication;
  ownerCap: PublicationOwnerCap;
  transactionResult: TransactionResult;
}

export class PublicationManager {
  private client = getDefaultSuiClient();

  async createPublication(params: CreatePublicationParams): Promise<PublicationResult> {
    try {
      console.log(chalk.blue(`📖 Creating publication: ${params.name}`));
      
      const packageId = CONTRACT_ADDRESSES.PACKAGE_ID;
      if (!packageId) {
        throw new Error('Package ID not found. Please deploy contracts first.');
      }

      const result = await executeTransaction(async (tx) => {
        let publication, ownerCap;
        
        if (params.vaultId) {
          // Use existing vault ID
          [publication, ownerCap] = tx.moveCall({
            package: packageId,
            module: MODULES.PUBLICATION,
            function: FUNCTIONS.CREATE_PUBLICATION,
            arguments: [
              tx.pureString(params.name),
              tx.pureString(params.description),
              tx.pure(params.vaultId, 'address'),
            ],
          });
        } else {
          // Create publication with vault - using real Walrus Blob type on testnet
          [publication, ownerCap] = tx.moveCall({
            package: packageId,
            module: MODULES.PUBLICATION,
            function: 'create_publication_with_vault',
            typeArguments: [`0xd84704c17fc870b8764832c535aa6b11f21a95cd6f5bb38a9b07d2cf42220c66::blob::Blob`],
            arguments: [
              tx.pureString(params.name),
              tx.pureString(params.description),
            ],
          });
        }

        // Transfer publication and owner cap to sender
        tx.transferObjects([publication, ownerCap], tx.client.getAddress());
      });

      // Extract created objects from transaction result
      const createdObjects = result.objectChanges?.filter(change => change.type === 'created') || [];
      
      const publicationChange = createdObjects.find(obj => 
        (obj as any).objectType?.includes('Publication') && !(obj as any).objectType?.includes('Cap')
      );
      const ownerCapChange = createdObjects.find(obj => 
        (obj as any).objectType?.includes('PublicationOwnerCap')
      );
      const vaultChange = createdObjects.find(obj => 
        (obj as any).objectType?.includes('PublicationVault')
      );

      if (!publicationChange || !ownerCapChange) {
        throw new Error('Failed to create publication objects');
      }

      const publication: Publication = {
        id: (publicationChange as any).objectId,
        name: params.name,
        description: params.description,
        owner: this.client.getAddress(),
        vault_id: vaultChange ? (vaultChange as any).objectId : (params.vaultId || 'no_vault_created'),
        contributors: [],
      };

      const ownerCap: PublicationOwnerCap = {
        id: (ownerCapChange as any).objectId,
        publication_id: publication.id,
      };

      console.log(chalk.green(`✅ Publication created successfully!`));
      console.log(chalk.gray(`Publication ID: ${publication.id}`));
      console.log(chalk.gray(`Owner Cap ID: ${ownerCap.id}`));

      return {
        publication,
        ownerCap,
        transactionResult: result,
      };
    } catch (error) {
      console.error(chalk.red(`❌ Failed to create publication: ${error}`));
      throw error;
    }
  }

  async addContributor(
    publicationId: string, 
    ownerCapId: string, 
    contributorAddress: string
  ): Promise<TransactionResult> {
    try {
      console.log(chalk.blue(`👥 Adding contributor: ${contributorAddress}`));
      
      const packageId = CONTRACT_ADDRESSES.PACKAGE_ID;
      if (!packageId) {
        throw new Error('Package ID not found. Please deploy contracts first.');
      }

      const result = await executeTransaction(async (tx) => {
        tx.moveCall({
          package: packageId,
          module: MODULES.PUBLICATION,
          function: FUNCTIONS.ADD_CONTRIBUTOR,
          arguments: [
            tx.objectArg(ownerCapId),
            tx.objectArg(publicationId),
            tx.pureAddress(contributorAddress),
          ],
        });
      });

      console.log(chalk.green(`✅ Contributor added successfully!`));
      console.log(chalk.gray(`Contributor: ${contributorAddress}`));

      return result;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to add contributor: ${error}`));
      throw error;
    }
  }

  async removeContributor(
    publicationId: string, 
    ownerCapId: string, 
    contributorAddress: string
  ): Promise<TransactionResult> {
    try {
      console.log(chalk.blue(`👥 Removing contributor: ${contributorAddress}`));
      
      const packageId = CONTRACT_ADDRESSES.PACKAGE_ID;
      if (!packageId) {
        throw new Error('Package ID not found. Please deploy contracts first.');
      }

      const result = await executeTransaction(async (tx) => {
        tx.moveCall({
          package: packageId,
          module: MODULES.PUBLICATION,
          function: FUNCTIONS.REMOVE_CONTRIBUTOR,
          arguments: [
            tx.objectArg(ownerCapId),
            tx.objectArg(publicationId),
            tx.pureAddress(contributorAddress),
          ],
        });
      });

      console.log(chalk.green(`✅ Contributor removed successfully!`));
      console.log(chalk.gray(`Contributor: ${contributorAddress}`));

      return result;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to remove contributor: ${error}`));
      throw error;
    }
  }

  async getPublication(publicationId: string): Promise<Publication | null> {
    try {
      console.log(chalk.blue(`📖 Fetching publication: ${publicationId}`));

      const objectData = await this.client.getObject(publicationId);
      
      if (!objectData.data) {
        console.log(chalk.yellow(`⚠️  Publication not found: ${publicationId}`));
        return null;
      }

      const content = (objectData.data as any).content;
      if (!content || !content.fields) {
        throw new Error('Invalid publication object structure');
      }

      const fields = content.fields;
      const publication: Publication = {
        id: publicationId,
        name: fields.name || '',
        description: fields.description || '',
        owner: fields.owner || '',
        vault_id: fields.vault_id || '',
        contributors: fields.contributors?.fields?.contents || [],
      };

      console.log(chalk.green(`✅ Publication retrieved successfully!`));
      console.log(chalk.gray(`Name: ${publication.name}`));
      console.log(chalk.gray(`Owner: ${publication.owner}`));
      console.log(chalk.gray(`Contributors: ${publication.contributors.length}`));

      return publication;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to fetch publication: ${error}`));
      return null;
    }
  }

  async getOwnedPublications(ownerAddress?: string): Promise<Publication[]> {
    try {
      const address = ownerAddress || this.client.getAddress();
      console.log(chalk.blue(`📚 Fetching publications for: ${address}`));

      // Get all owned objects that are publications
      const ownedObjects = await this.client.getOwnedObjects(
        `${CONTRACT_ADDRESSES.PACKAGE_ID}::${MODULES.PUBLICATION}::Publication`
      );

      const publications: Publication[] = [];
      
      for (const objRef of ownedObjects.data) {
        if (objRef.data && objRef.data.objectId) {
          const publication = await this.getPublication(objRef.data.objectId);
          if (publication) {
            publications.push(publication);
          }
        }
      }

      console.log(chalk.green(`✅ Found ${publications.length} publications`));
      
      return publications;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to fetch owned publications: ${error}`));
      return [];
    }
  }

  async getPublicationsByContributor(contributorAddress?: string): Promise<Publication[]> {
    try {
      const address = contributorAddress || this.client.getAddress();
      console.log(chalk.blue(`📚 Fetching publications where ${address} is a contributor`));

      // This would require indexing or querying events in a full implementation
      // For now, we'll return empty array with a warning
      console.log(chalk.yellow(`⚠️  Contributor publication search requires event indexing`));
      console.log(chalk.gray('Consider implementing with event monitoring or GraphQL'));

      return [];
    } catch (error) {
      console.error(chalk.red(`❌ Failed to fetch contributor publications: ${error}`));
      return [];
    }
  }

  async updateVaultId(
    publicationId: string, 
    ownerCapId: string, 
    newVaultId: string
  ): Promise<TransactionResult> {
    try {
      console.log(chalk.blue(`🔧 Updating vault ID for publication: ${publicationId}`));
      
      const packageId = CONTRACT_ADDRESSES.PACKAGE_ID;
      if (!packageId) {
        throw new Error('Package ID not found. Please deploy contracts first.');
      }

      const result = await executeTransaction(async (tx) => {
        tx.moveCall({
          package: packageId,
          module: MODULES.PUBLICATION,
          function: 'set_vault_id',
          arguments: [
            tx.objectArg(ownerCapId),
            tx.objectArg(publicationId),
            tx.pure(newVaultId, 'address'),
          ],
        });
      });

      console.log(chalk.green(`✅ Vault ID updated successfully!`));
      console.log(chalk.gray(`New Vault ID: ${newVaultId}`));

      return result;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to update vault ID: ${error}`));
      throw error;
    }
  }

  // Utility methods
  async isContributor(publicationId: string, address?: string): Promise<boolean> {
    try {
      const checkAddress = address || this.client.getAddress();
      const publication = await this.getPublication(publicationId);
      
      if (!publication) {
        return false;
      }

      return publication.contributors.includes(checkAddress);
    } catch (error) {
      console.error(chalk.red(`❌ Failed to check contributor status: ${error}`));
      return false;
    }
  }

  async isOwner(publicationId: string, address?: string): Promise<boolean> {
    try {
      const checkAddress = address || this.client.getAddress();
      const publication = await this.getPublication(publicationId);
      
      if (!publication) {
        return false;
      }

      return publication.owner === checkAddress;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to check owner status: ${error}`));
      return false;
    }
  }

  async getPublicationStats(publicationId: string): Promise<{
    contributorCount: number;
    articlesCount: number;
    totalTips: string;
  } | null> {
    try {
      const publication = await this.getPublication(publicationId);
      
      if (!publication) {
        return null;
      }

      // In a full implementation, these would be queried from events or indexed data
      return {
        contributorCount: publication.contributors.length,
        articlesCount: 0, // Would need to query articles
        totalTips: '0', // Would need to query tip events
      };
    } catch (error) {
      console.error(chalk.red(`❌ Failed to get publication stats: ${error}`));
      return null;
    }
  }
}

// Singleton instance
let defaultManager: PublicationManager | null = null;

export function createPublicationManager(): PublicationManager {
  return new PublicationManager();
}

export function getDefaultPublicationManager(): PublicationManager {
  if (!defaultManager) {
    defaultManager = new PublicationManager();
  }
  return defaultManager;
}

// Convenience functions
export async function createPublication(params: CreatePublicationParams): Promise<PublicationResult> {
  return await getDefaultPublicationManager().createPublication(params);
}

export async function addContributor(
  publicationId: string, 
  ownerCapId: string, 
  contributorAddress: string
): Promise<TransactionResult> {
  return await getDefaultPublicationManager().addContributor(publicationId, ownerCapId, contributorAddress);
}

export async function removeContributor(
  publicationId: string, 
  ownerCapId: string, 
  contributorAddress: string
): Promise<TransactionResult> {
  return await getDefaultPublicationManager().removeContributor(publicationId, ownerCapId, contributorAddress);
}

export async function getPublication(publicationId: string): Promise<Publication | null> {
  return await getDefaultPublicationManager().getPublication(publicationId);
}

export async function getOwnedPublications(ownerAddress?: string): Promise<Publication[]> {
  return await getDefaultPublicationManager().getOwnedPublications(ownerAddress);
}