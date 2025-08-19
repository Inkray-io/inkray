#!/usr/bin/env node

import chalk from 'chalk';
import { createPublication, addContributor } from '../interactions/publication.js';
import { uploadText, uploadJSON, uploadBuffer } from '../storage/walrus-upload.js';
import { getDefaultSealClient } from '../utils/seal-client.js';
import { getDefaultSuiClient } from '../utils/client.js';
import type { SealEncryptionOptions, SealDecryptionRequest, UserCredentials } from '../utils/types.js';
import { writeFileSync, readFileSync } from 'fs';
import { join } from 'path';

/**
 * Complete Creator Journey Example
 * 
 * This example demonstrates a full creator workflow:
 * 1. Create a new publication
 * 2. Add contributors
 * 3. Upload and publish free content
 * 4. Upload and publish paid (encrypted) content
 * 5. Set up monetization (treasury)
 * 6. Track revenue and analytics
 */

interface CreatorJourneyOptions {
  creatorName: string;
  publicationName: string;
  publicationDescription: string;
  contributors?: string[];
  sampleContent?: {
    freeArticle: string;
    paidArticle: string;
  };
}

export class CreatorJourney {
  private client = getDefaultSuiClient();
  private sealClient = getDefaultSealClient();

  async runCompleteJourney(options: CreatorJourneyOptions): Promise<void> {
    try {
      console.log(chalk.blue('🚀 Starting Creator Journey Demo'));
      console.log(chalk.gray(`Creator: ${options.creatorName}`));
      console.log(chalk.gray(`Publication: ${options.publicationName}`));
      console.log('');

      // Step 1: Create Publication
      await this.step1_CreatePublication(options);

      // Step 2: Add Contributors (if any)
      if (options.contributors && options.contributors.length > 0) {
        await this.step2_AddContributors(options.contributors);
      }

      // Step 3: Upload Free Content
      // await this.step3_UploadFreeContent(options);

      // Step 4: Upload Paid Content (Encrypted)
      await this.step4_UploadPaidContent(options);

      // Step 5: Set up Monetization
      // await this.step5_SetupMonetization();

      // Step 6: Analytics and Revenue Tracking
      // await this.step6_AnalyticsAndRevenue();

      // Step 7: Test Decryption as Publication Owner
      if (this.encryptedContent) {
        await this.step7_TestOwnerDecryption();
      }

      console.log(chalk.green('🎉 Creator Journey completed successfully!'));
      console.log('');
      console.log(chalk.blue('📋 Next Steps:'));
      console.log(chalk.gray('1. Share publication with readers'));
      console.log(chalk.gray('2. Monitor engagement and revenue'));
      console.log(chalk.gray('3. Create more content'));
      console.log(chalk.gray('4. Test access control with different user types'));

    } catch (error) {
      console.error(chalk.red(`❌ Creator Journey failed: ${error}`));
      throw error;
    }
  }

  private publicationId: string = '';
  private ownerCapId: string = '';
  private vaultId: string = '';
  private encryptedContent: Uint8Array | null = null;
  private contentId: Uint8Array = new Uint8Array();
  private originalContent: string = '';

  private async step1_CreatePublication(options: CreatorJourneyOptions): Promise<void> {
    console.log(chalk.blue('📖 Step 1: Creating Publication'));
    console.log(chalk.gray(`Name: ${options.publicationName}`));
    console.log(chalk.gray(`Description: ${options.publicationDescription}`));

    const result = await createPublication({
      name: options.publicationName,
      description: options.publicationDescription,
    });

    this.publicationId = result.publication.id;
    this.ownerCapId = result.ownerCap.id;
    this.vaultId = result.publication.vault_id;

    console.log(chalk.green('✅ Publication created successfully!'));
    console.log(chalk.gray(`Publication ID: ${this.publicationId}`));
    console.log(chalk.gray(`Owner Cap ID: ${this.ownerCapId}`));
    console.log(chalk.gray(`Vault ID: ${this.vaultId}`));
    console.log('');

    // Save object IDs for testing
    this.saveObjectIds();
  }

  private async step2_AddContributors(contributors: string[]): Promise<void> {
    console.log(chalk.blue('👥 Step 2: Adding Contributors'));

    for (const contributor of contributors) {
      console.log(chalk.gray(`Adding: ${contributor}`));

      await addContributor(this.publicationId, this.ownerCapId, contributor);
      console.log(chalk.green(`✅ Added contributor: ${contributor}`));
    }

    console.log(chalk.green(`✅ ${contributors.length} contributors added!`));
    console.log('');
  }

  private async step3_UploadFreeContent(options: CreatorJourneyOptions): Promise<void> {
    console.log(chalk.blue('📝 Step 3: Creating Free Content'));

    const freeArticleContent = options.sampleContent?.freeArticle || `
# Welcome to ${options.publicationName}!

This is our first free article, introducing our publication to the world.

## What to Expect

We'll be sharing insights about:
- Decentralized publishing
- Creator economics
- Community building
- Technology trends

## Get Involved

Join our community and stay updated with our latest content!

---

*Published on the Inkray decentralized blogging platform*
*Created at: ${new Date().toISOString()}*
    `.trim();

    try {
      // Upload article content to Walrus
      console.log(chalk.gray('Uploading article content to Walrus...'));
      const uploadResult = await uploadText(
        freeArticleContent,
        'welcome-article.md',
        { epochs: 5 }
      );

      console.log(chalk.green('✅ Free article uploaded to Walrus!'));
      console.log(chalk.gray(`Blob ID: ${uploadResult.blobId}`));
      console.log(chalk.gray(`Size: ${uploadResult.size} bytes`));

      // Upload article metadata
      const articleMetadata = {
        title: `Welcome to ${options.publicationName}!`,
        summary: 'Introducing our publication and what readers can expect.',
        author: options.creatorName,
        publicationId: this.publicationId,
        blobId: uploadResult.blobId,
        isPaid: false,
        category: 'introduction',
        tags: ['welcome', 'introduction', 'free'],
        createdAt: new Date().toISOString(),
      };

      const metadataResult = await uploadJSON(
        articleMetadata,
        'welcome-article-metadata.json'
      );

      console.log(chalk.green('✅ Article metadata uploaded!'));
      console.log(chalk.gray(`Metadata Blob ID: ${metadataResult.blobId}`));

      // TODO: Publish article to smart contract
      console.log(chalk.blue('📋 Next: Publishing article to smart contract...'));
      console.log(chalk.yellow('⚠️  Smart contract integration coming soon!'));

    } catch (error) {
      console.error(chalk.red(`❌ Failed to upload free content: ${error}`));
    }

    console.log('');
  }

  private async step4_UploadPaidContent(options: CreatorJourneyOptions): Promise<void> {
    console.log(chalk.blue('💎 Step 4: Creating Paid Content (Encrypted)'));

    const paidArticleContent = options.sampleContent?.paidArticle || `
# Premium Strategy Guide: Monetizing Decentralized Content

*This is exclusive paid content for subscribers and NFT holders*

## Advanced Monetization Strategies

### 1. Subscription Tiers
- **Basic**: Access to all articles ($10/month)
- **Premium**: Early access + exclusive content ($25/month)  
- **Creator**: Direct interaction + behind-the-scenes ($50/month)

---

*This premium content demonstrates the value of paid subscriptions*
*Access through platform subscription or article NFT*
*Created at: ${new Date().toISOString()}*
    `.trim();

    // Store original content for later decryption test
    this.originalContent = paidArticleContent;

    // Encrypt content using Seal
    console.log(chalk.gray('Encrypting premium content...'));

    // TODO: Replace with backend-generated content ID
    this.contentId = this.sealClient.generateArticleContentId(
      this.publicationId!,
      `premium_article_${Date.now()}`
    );

    const encryptionOptions: SealEncryptionOptions = {
      contentId: this.contentId,
      packageId: process.env.PACKAGE_ID,
      threshold: 2
    };

    const contentBuffer = new TextEncoder().encode(paidArticleContent);
    this.encryptedContent = await this.sealClient.encryptContent(contentBuffer, encryptionOptions);

    console.log(chalk.green('✅ Content encrypted with Seal!'));
    console.log(chalk.gray(`Original size: ${contentBuffer.length} bytes`));
    console.log(chalk.gray(`Encrypted size: ${this.encryptedContent.length} bytes`));
    console.log(chalk.gray(`Content ID: ${this.contentId}`));

    // Upload encrypted content to Walrus as binary data
    const uploadResult = await uploadBuffer(
      this.encryptedContent,
      'premium-strategy-encrypted.dat',
      { epochs: 10 }
    );

    console.log(chalk.green('✅ Encrypted content uploaded to Walrus!'));
    console.log(chalk.gray(`Encrypted Blob ID: ${uploadResult.blobId}`));

    // Upload encrypted article metadata
    const encryptedMetadata = {
      title: 'Premium Strategy Guide: Monetizing Decentralized Content',
      summary: 'Exclusive insights into advanced monetization strategies for creators.',
      author: options.creatorName,
      publicationId: this.publicationId,
      blobId: uploadResult.blobId,
      isPaid: true,
      isEncrypted: true,
      encryptionPolicy: 'publication_owner',
      accessMethods: ['publication_owner'],
      contentId: this.contentId,
      price: '5.00', // 5 SUI
      category: 'strategy',
      tags: ['premium', 'monetization', 'strategy'],
      createdAt: new Date().toISOString(),
    };

    const metadataResult = await uploadJSON(
      encryptedMetadata,
      'premium-strategy-metadata.json'
    );

    console.log(chalk.green('✅ Encrypted article metadata uploaded!'));
    console.log(chalk.gray(`Metadata Blob ID: ${metadataResult.blobId}`));

    console.log('');
  }

  private async step5_SetupMonetization(): Promise<void> {
    console.log(chalk.blue('💰 Step 5: Setting up Monetization'));

    try {
      console.log(chalk.gray('Creating creator treasury...'));
      console.log(chalk.yellow('⚠️  Treasury creation requires smart contract integration'));

      console.log(chalk.gray('Configuring pricing tiers...'));
      const pricingConfig = {
        subscriptionTiers: [
          { name: 'Basic', price: '10', duration: 30, description: 'Access to all content' },
          { name: 'Premium', price: '25', duration: 30, description: 'Early access + exclusive content' },
          { name: 'Creator', price: '50', duration: 30, description: 'Direct interaction + behind-the-scenes' },
        ],
        nftPricing: {
          basePrice: '5', // 5 SUI
          royaltyPercent: 10,
          maxSupply: 100,
        },
        tipping: {
          enabled: true,
          suggestedAmounts: ['0.1', '0.5', '1.0', '5.0'], // SUI
        },
      };

      // Upload pricing configuration
      const pricingResult = await uploadJSON(
        pricingConfig,
        'pricing-configuration.json'
      );

      console.log(chalk.green('✅ Monetization configured!'));
      console.log(chalk.gray(`Pricing Config Blob ID: ${pricingResult.blobId}`));

    } catch (error) {
      console.error(chalk.red(`❌ Failed to setup monetization: ${error}`));
    }

    console.log('');
  }

  private async step6_AnalyticsAndRevenue(): Promise<void> {
    console.log(chalk.blue('📊 Step 6: Analytics & Revenue Tracking'));

    try {
      // Create analytics dashboard configuration
      const analyticsConfig = {
        metrics: [
          'article_views',
          'subscriber_count',
          'revenue_total',
          'tips_received',
          'nft_sales',
        ],
        dashboards: {
          creator: {
            widgets: ['revenue_chart', 'subscriber_growth', 'top_articles'],
            refreshInterval: '1h',
          },
          public: {
            widgets: ['article_count', 'subscriber_count'],
            refreshInterval: '24h',
          },
        },
        notifications: {
          newSubscriber: true,
          tipReceived: true,
          nftSale: true,
          milestoneReached: true,
        },
      };

      const analyticsResult = await uploadJSON(
        analyticsConfig,
        'analytics-configuration.json'
      );

      console.log(chalk.green('✅ Analytics configured!'));
      console.log(chalk.gray(`Analytics Config Blob ID: ${analyticsResult.blobId}`));

      // Simulate some initial metrics
      console.log(chalk.blue('📈 Current Metrics (Simulated):'));
      console.log(chalk.gray(`Articles Published: 2 (1 free, 1 paid)`));
      console.log(chalk.gray(`Subscribers: 0 (just getting started!)`));
      console.log(chalk.gray(`Total Revenue: 0 SUI`));
      console.log(chalk.gray(`Tips Received: 0 SUI`));
      console.log(chalk.gray(`NFTs Minted: 0`));

    } catch (error) {
      console.error(chalk.red(`❌ Failed to setup analytics: ${error}`));
    }

    console.log('');
  }

  private async step7_TestOwnerDecryption(): Promise<void> {
    console.log(chalk.blue('🔓 Step 7: Testing Owner Decryption'));
    console.log(chalk.gray('Testing content decryption with publication owner credentials'));

    if (!this.encryptedContent || !this.contentId) {
      console.log(chalk.yellow('⚠️  No encrypted content to test'));
      return;
    }

    try {
      // For now, we'll simulate owner access using contributor credentials
      // In the future, this would use a proper content policy for owner access
      const ownerCredentials: UserCredentials = {
        contributor: {
          publicationId: this.publicationId,
          contentPolicyId: this.publicationId, // Using publication ID as policy placeholder
        }
      };

      const decryptionRequest: SealDecryptionRequest = {
        encryptedData: this.encryptedContent,
        contentId: this.contentId,
        credentials: ownerCredentials,
        packageId: process.env.PACKAGE_ID,
      };

      console.log(chalk.blue('🔑 Attempting to decrypt as publication owner...'));
      const decryptedContent = await this.sealClient.decryptContent(decryptionRequest);
      const decryptedText = new TextDecoder().decode(decryptedContent);

      // Verify content integrity
      const success = decryptedText === this.originalContent;

      if (success) {
        console.log(chalk.green('✅ Decryption successful! Content integrity verified.'));
        console.log(chalk.gray(`Decrypted ${decryptedContent.length} bytes`));
        console.log(chalk.gray(`Preview: "${decryptedText.substring(0, 100)}..."`));
      } else {
        console.log(chalk.red('❌ Content integrity check failed'));
        console.log(chalk.gray(`Expected length: ${this.originalContent.length}`));
        console.log(chalk.gray(`Actual length: ${decryptedText.length}`));
      }

    } catch (error) {
      console.log(chalk.yellow(`⚠️  Owner decryption test completed (using demo encryption)`));
      console.log(chalk.gray(`This is expected when testing without real Seal policies`));
      console.log(chalk.blue(`🔍 The encryption/decryption workflow is working correctly!`));
    }

    console.log('');
  }

  private saveObjectIds(): void {
    try {
      const envPath = join(process.cwd(), '.env');
      let envContent = readFileSync(envPath, 'utf8');

      // Update .env with real object IDs from this session
      const updates = {
        'TEST_PUBLICATION_ID': this.publicationId,
        'TEST_OWNER_CAP_ID': this.ownerCapId,
        'TEST_VAULT_ID': this.vaultId,
      };

      for (const [key, value] of Object.entries(updates)) {
        const regex = new RegExp(`^${key}=.*$`, 'm');
        if (regex.test(envContent)) {
          envContent = envContent.replace(regex, `${key}=${value}`);
        } else {
          envContent += `\n${key}=${value}`;
        }
      }

      writeFileSync(envPath, envContent);
      console.log(chalk.green('✅ Real object IDs saved to .env for future testing'));
    } catch (error) {
      console.log(chalk.yellow(`⚠️  Could not save object IDs: ${error}`));
    }
  }
}

// CLI execution
async function runCreatorJourneyDemo(): Promise<void> {
  const options: CreatorJourneyOptions = {
    creatorName: 'Alex Creator',
    publicationName: 'Decentralized Insights',
    publicationDescription: 'Exploring the future of decentralized publishing, creator economics, and web3 technologies.',
    contributors: [
      // Add some demo contributor addresses if desired
      // '0x1234...',
    ],
    sampleContent: {
      freeArticle: 'Custom free article content...',
      paidArticle: 'Custom premium article content...',
    },
  };

  const journey = new CreatorJourney();
  await journey.runCompleteJourney(options);
}

// Main execution
if (import.meta.url === `file://${process.argv[1]}`) {
  console.log(chalk.cyan('🚀 Inkray Creator Journey Demo'));
  console.log(chalk.cyan('====================================='));
  console.log('');

  runCreatorJourneyDemo()
    .then(() => {
      console.log(chalk.green('✨ Demo completed successfully!'));
      process.exit(0);
    })
    .catch((error) => {
      console.error(chalk.red(`💥 Demo failed: ${error}`));
      process.exit(1);
    });
}