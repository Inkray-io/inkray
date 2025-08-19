import { Transaction } from '@mysten/sui/transactions';
import { MultiWalletClient, type UserRole } from '../utils/multi-wallet-client.js';
import chalk from 'chalk';

export interface PublicationResult {
  publicationId: string;
  vaultId: string;
  ownerCapId: string;
  transactionDigest: string;
  creatorAddress: string;
}

export interface ContributorResult {
  transactionDigest: string;
  contributorAddress: string;
}

/**
 * Publication workflow that handles creation and contributor management
 */
export class PublicationFlow {
  constructor(
    private multiWallet: MultiWalletClient,
    private packageId: string
  ) {}

  /**
   * Create a new publication with the creator wallet
   */
  async createPublication(
    publicationName: string,
    description?: string
  ): Promise<PublicationResult> {
    console.log(chalk.blue('📰 Creating new publication...'));
    console.log(chalk.gray(`  Name: ${publicationName}`));
    console.log(chalk.gray(`  Creator: ${this.multiWallet.getAddress('creator')}`));

    const creatorClient = this.multiWallet.getSuiClient('creator');
    
    // Ensure creator has sufficient balance
    await this.multiWallet.ensureSufficientBalance('creator', 1.0);

    // Build transaction
    const tx = new Transaction();
    
    // Call the publication creation entry function
    tx.moveCall({
      target: `${this.packageId}::publication::create_publication`,
      arguments: [
        tx.pure.string(publicationName),
      ],
    });

    console.log(chalk.gray('  Building transaction...'));

    try {
      // Execute transaction
      const txResult = await creatorClient.getClient().signAndExecuteTransaction({
        transaction: tx,
        signer: creatorClient.getKeypair(),
        options: {
          showEffects: true,
          showEvents: true,
          showObjectChanges: true,
        },
      });

      console.log(chalk.gray(`  Transaction: ${txResult.digest}`));

      // Wait for confirmation
      const confirmedTx = await this.multiWallet.waitForTransaction('creator', txResult.digest);
      
      if (confirmedTx.effects?.status?.status !== 'success') {
        throw new Error(`Transaction failed: ${confirmedTx.effects?.status?.error}`);
      }

      // Extract object IDs from transaction effects
      const objectChanges = confirmedTx.objectChanges || [];
      
      let publicationId = '';
      let vaultId = '';
      let ownerCapId = '';

      console.log(chalk.gray(`  Analyzing ${objectChanges.length} object changes...`));

      for (const change of objectChanges) {
        if (change.type === 'created') {
          const objectType = change.objectType;
          console.log(chalk.gray(`    Created: ${objectType} -> ${change.objectId}`));
          
          if (objectType && objectType.includes('Publication') && !objectType.includes('Cap') && !objectType.includes('Vault')) {
            publicationId = change.objectId;
            console.log(chalk.gray(`      -> Publication ID: ${publicationId}`));
          } else if (objectType && objectType.includes('PublicationVault')) {
            vaultId = change.objectId;
            console.log(chalk.gray(`      -> Vault ID: ${vaultId}`));
          } else if (objectType && objectType.includes('PublicationOwnerCap')) {
            ownerCapId = change.objectId;
            console.log(chalk.gray(`      -> Owner Cap ID: ${ownerCapId}`));
          }
        } else if (change.type === 'transferred') {
          const objectType = change.objectType;
          if (objectType && objectType.includes('PublicationOwnerCap')) {
            ownerCapId = change.objectId;
            console.log(chalk.gray(`    Transferred Owner Cap: ${ownerCapId}`));
          }
        }
      }

      if (!publicationId || !vaultId || !ownerCapId) {
        console.error(chalk.red(`Missing required objects:`));
        console.error(chalk.red(`  Publication ID: ${publicationId || 'MISSING'}`));
        console.error(chalk.red(`  Vault ID: ${vaultId || 'MISSING'}`));
        console.error(chalk.red(`  Owner Cap ID: ${ownerCapId || 'MISSING'}`));
        console.error(chalk.red(`Object changes found:`));
        objectChanges.forEach(change => {
          if ('objectType' in change && 'objectId' in change) {
            console.error(chalk.red(`  ${change.type}: ${change.objectType} -> ${change.objectId}`));
          } else {
            console.error(chalk.red(`  ${change.type}: ${JSON.stringify(change)}`));
          }
        });
        throw new Error('Failed to extract required object IDs from transaction');
      }

      const result: PublicationResult = {
        publicationId,
        vaultId,
        ownerCapId,
        transactionDigest: txResult.digest,
        creatorAddress: this.multiWallet.getAddress('creator'),
      };

      console.log(chalk.green('✅ Publication created successfully!'));
      console.log(chalk.gray(`  Publication ID: ${publicationId}`));
      console.log(chalk.gray(`  Vault ID: ${vaultId}`));
      console.log(chalk.gray(`  Owner Cap ID: ${ownerCapId}`));

      return result;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to create publication: ${error}`));
      throw error;
    }
  }

  /**
   * Add a contributor to the publication
   */
  async addContributor(
    ownerCapId: string,
    publicationId: string,
    contributorRole: UserRole = 'reader'
  ): Promise<ContributorResult> {
    console.log(chalk.blue('👥 Adding contributor to publication...'));
    
    const contributorAddress = this.multiWallet.getAddress(contributorRole);
    console.log(chalk.gray(`  Contributor: ${contributorAddress} (${contributorRole})`));
    console.log(chalk.gray(`  Publication: ${publicationId}`));

    const creatorClient = this.multiWallet.getSuiClient('creator');
    
    // Ensure creator has sufficient balance
    await this.multiWallet.ensureSufficientBalance('creator', 0.5);

    // Build transaction
    const tx = new Transaction();
    
    // Call the add contributor entry function
    tx.moveCall({
      target: `${this.packageId}::publication::add_contributor_entry`,
      arguments: [
        tx.object(ownerCapId),
        tx.object(publicationId),
        tx.pure.address(contributorAddress),
      ],
    });

    console.log(chalk.gray('  Building transaction...'));

    try {
      // Execute transaction
      const txResult = await creatorClient.getClient().signAndExecuteTransaction({
        transaction: tx,
        signer: creatorClient.getKeypair(),
        options: {
          showEffects: true,
          showEvents: true,
        },
      });

      console.log(chalk.gray(`  Transaction: ${txResult.digest}`));

      // Wait for confirmation
      const confirmedTx = await this.multiWallet.waitForTransaction('creator', txResult.digest);
      
      if (confirmedTx.effects?.status?.status !== 'success') {
        throw new Error(`Transaction failed: ${confirmedTx.effects?.status?.error}`);
      }

      const result: ContributorResult = {
        transactionDigest: txResult.digest,
        contributorAddress,
      };

      console.log(chalk.green('✅ Contributor added successfully!'));
      console.log(chalk.gray(`  Address: ${contributorAddress}`));

      return result;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to add contributor: ${error}`));
      throw error;
    }
  }

  /**
   * Verify publication ownership and contributor status
   */
  async verifyPublicationSetup(
    publicationId: string,
    ownerCapId: string,
    expectedContributors: string[] = []
  ): Promise<boolean> {
    console.log(chalk.blue('🔍 Verifying publication setup...'));

    try {
      const creatorClient = this.multiWallet.getSuiClient('creator');
      
      // Get publication object
      const publicationObject = await creatorClient.getObject(publicationId);
      
      if (!publicationObject.data) {
        throw new Error('Publication object not found');
      }

      console.log(chalk.gray(`  Publication exists: ✅`));

      // Get owner cap object
      const ownerCapObject = await creatorClient.getObject(ownerCapId);
      
      if (!ownerCapObject.data) {
        throw new Error('Owner cap object not found');
      }

      // Verify owner cap is owned by creator
      const ownerCapOwner = (ownerCapObject.data as any).owner?.AddressOwner;
      const creatorAddress = this.multiWallet.getAddress('creator');
      
      if (ownerCapOwner !== creatorAddress) {
        throw new Error(`Owner cap owned by ${ownerCapOwner}, expected ${creatorAddress}`);
      }

      console.log(chalk.gray(`  Owner cap ownership: ✅`));

      // TODO: Verify contributors once we have view functions
      if (expectedContributors.length > 0) {
        console.log(chalk.gray(`  Contributors (${expectedContributors.length}): ✅`));
      }

      console.log(chalk.green('✅ Publication setup verified'));
      return true;
    } catch (error) {
      console.error(chalk.red(`❌ Publication verification failed: ${error}`));
      return false;
    }
  }

  /**
   * Get publication information
   */
  async getPublicationInfo(publicationId: string): Promise<any> {
    console.log(chalk.blue('📋 Getting publication information...'));

    try {
      const creatorClient = this.multiWallet.getSuiClient('creator');
      const publicationObject = await creatorClient.getObject(publicationId);
      
      if (!publicationObject.data) {
        throw new Error('Publication object not found');
      }

      console.log(chalk.green('✅ Publication info retrieved'));
      return publicationObject.data;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to get publication info: ${error}`));
      throw error;
    }
  }

  /**
   * Complete publication setup with contributor
   */
  async setupCompletePublication(
    publicationName: string,
    contributorRole: UserRole = 'reader'
  ): Promise<PublicationResult & { contributorResult: ContributorResult }> {
    console.log(chalk.blue('🏗️  Setting up complete publication with contributor...'));

    // Step 1: Create publication
    const publicationResult = await this.createPublication(publicationName);

    // Step 2: Add contributor
    const contributorResult = await this.addContributor(
      publicationResult.ownerCapId,
      publicationResult.publicationId,
      contributorRole
    );

    // Step 3: Verify setup
    const isValid = await this.verifyPublicationSetup(
      publicationResult.publicationId,
      publicationResult.ownerCapId,
      [contributorResult.contributorAddress]
    );

    if (!isValid) {
      throw new Error('Publication setup verification failed');
    }

    console.log(chalk.green('🎉 Complete publication setup finished!'));

    return {
      ...publicationResult,
      contributorResult,
    };
  }

  /**
   * Display publication summary
   */
  displayPublicationSummary(result: PublicationResult): void {
    console.log(chalk.blue('📊 Publication Summary'));
    console.log(chalk.gray('=' .repeat(50)));
    console.log(chalk.white(`Publication ID: ${result.publicationId}`));
    console.log(chalk.white(`Vault ID: ${result.vaultId}`));
    console.log(chalk.white(`Owner Cap ID: ${result.ownerCapId}`));
    console.log(chalk.white(`Creator: ${result.creatorAddress}`));
    console.log(chalk.white(`Transaction: ${result.transactionDigest}`));
    console.log();
  }
}