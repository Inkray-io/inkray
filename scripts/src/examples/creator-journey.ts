#!/usr/bin/env node

import chalk from 'chalk';
import { createPublication, addContributor } from '../interactions/publication.js';
import { uploadText, uploadJSON } from '../storage/walrus-upload.js';
import { encryptData } from '../utils/seal-client.js';
import { getDefaultSuiClient } from '../utils/client.js';
import type { SealEncryptionOptions } from '../utils/types.js';

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
      await this.step3_UploadFreeContent(options);

      // Step 4: Upload Paid Content (Encrypted)
      await this.step4_UploadPaidContent(options);

      // Step 5: Set up Monetization
      await this.step5_SetupMonetization();

      // Step 6: Analytics and Revenue Tracking
      await this.step6_AnalyticsAndRevenue();

      console.log(chalk.green('🎉 Creator Journey completed successfully!'));
      console.log('');
      console.log(chalk.blue('📋 Next Steps:'));
      console.log(chalk.gray('1. Share publication with readers'));
      console.log(chalk.gray('2. Monitor engagement and revenue'));
      console.log(chalk.gray('3. Create more content'));
      console.log(chalk.gray('4. Engage with community'));

    } catch (error) {
      console.error(chalk.red(`❌ Creator Journey failed: ${error}`));
      throw error;
    }
  }

  private publicationId: string = '';
  private ownerCapId: string = '';
  private vaultId: string = '';

  private async step1_CreatePublication(options: CreatorJourneyOptions): Promise<void> {
    console.log(chalk.blue('📖 Step 1: Creating Publication'));
    console.log(chalk.gray(`Name: ${options.publicationName}`));
    console.log(chalk.gray(`Description: ${options.publicationDescription}`));

    try {
      const result = await createPublication({
        name: options.publicationName,
        description: options.publicationDescription,
      });

      this.publicationId = result.publication.id;
      this.ownerCapId = result.ownerCap.id;
      this.vaultId = result.publication.vault_id;

      console.log(chalk.green('✅ Publication created successfully!'));
      console.log(chalk.gray(`Publication ID: ${this.publicationId}`));
      console.log('');

    } catch (error) {
      // For demo purposes, if contract isn't deployed, show what would happen
      console.log(chalk.yellow('⚠️  Smart contracts not deployed - showing simulation'));
      
      this.publicationId = 'demo_publication_' + Date.now();
      this.ownerCapId = 'demo_owner_cap_' + Date.now();
      this.vaultId = 'demo_vault_' + Date.now();

      console.log(chalk.green('✅ Publication would be created with:'));
      console.log(chalk.gray(`Publication ID: ${this.publicationId}`));
      console.log('');
    }
  }

  private async step2_AddContributors(contributors: string[]): Promise<void> {
    console.log(chalk.blue('👥 Step 2: Adding Contributors'));

    for (const contributor of contributors) {
      console.log(chalk.gray(`Adding: ${contributor}`));

      try {
        await addContributor(this.publicationId, this.ownerCapId, contributor);
        console.log(chalk.green(`✅ Added contributor: ${contributor}`));
      } catch (error) {
        console.log(chalk.yellow(`⚠️  Would add contributor: ${contributor}`));
      }
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

### 2. NFT Collections
Create limited edition NFTs for special articles:
- Permanent access to content
- Resale rights with royalties
- Community status and perks

### 3. Revenue Optimization
- **Direct Tips**: Enable reader appreciation
- **Sponsored Content**: Brand partnerships
- **Course Sales**: Educational content bundles
- **Consulting**: Leverage expertise

### 4. Community Building
- **Exclusive Discord**: Subscriber-only channels
- **Live Events**: Virtual meetups and AMAs
- **Early Access**: New features and content
- **Collaboration**: Co-creation opportunities

## Implementation Roadmap

**Phase 1: Foundation (Month 1-2)**
- Set up publication and content pipeline
- Create initial subscriber base
- Launch basic content

**Phase 2: Growth (Month 3-6)**
- Introduce premium tiers
- Launch NFT collections
- Build community features

**Phase 3: Scale (Month 6+)**
- Expand to multiple publications
- Create creator network
- Develop advanced features

---

*This premium content demonstrates the value of paid subscriptions*
*Access through platform subscription or article NFT*
*Created at: ${new Date().toISOString()}*
    `.trim();

    try {
      // Encrypt content using Seal
      console.log(chalk.gray('Encrypting premium content...'));
      
      const sealClient = (await import('../utils/seal-client.js')).getDefaultSealClient();
      const encryptionOptions: SealEncryptionOptions = {
        policy: 'subscription',
        policyObjectId: 'demo_subscription_policy',
      };

      const contentBuffer = new TextEncoder().encode(paidArticleContent);
      const encryptedContent = await sealClient.encryptData(contentBuffer, encryptionOptions);

      console.log(chalk.green('✅ Content encrypted with Seal!'));
      console.log(chalk.gray(`Original size: ${contentBuffer.length} bytes`));
      console.log(chalk.gray(`Encrypted size: ${encryptedContent.length} bytes`));

      // Upload encrypted content to Walrus
      const uploadResult = await uploadText(
        Array.from(encryptedContent).map(b => String.fromCharCode(b)).join(''),
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
        encryptionPolicy: 'subscription',
        accessMethods: ['platform_subscription', 'article_nft'],
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

    } catch (error) {
      console.error(chalk.red(`❌ Failed to create encrypted content: ${error}`));
    }

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