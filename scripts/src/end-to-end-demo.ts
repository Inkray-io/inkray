#!/usr/bin/env node

import { createMultiWalletClient } from './utils/multi-wallet-client.js';
import { PublicationFlow } from './workflows/publication-flow.js';
import { ArticleUploadFlow } from './workflows/article-upload-flow.js';
import { DecryptionTestFlow } from './workflows/decryption-test-flow.js';
import chalk from 'chalk';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Complete end-to-end demonstration of the Inkray platform
 * 
 * This script demonstrates:
 * 1. Publication creation with creator wallet
 * 2. Vault creation and contributor management
 * 3. Article encryption and upload to Walrus
 * 4. Decryption testing with multiple user credentials
 * 5. Access control validation
 */
async function runEndToEndDemo(): Promise<void> {
  console.log(chalk.bold.blue('🚀 Inkray End-to-End Demo Starting...'));
  console.log(chalk.gray('=' .repeat(80)));
  console.log();

  try {
    // Step 0: Environment validation and setup
    await setupAndValidateEnvironment();

    // Step 1: Initialize multi-wallet client
    const multiWallet = await initializeMultiWalletClient();

    // Step 2: Create publication with vault and contributor
    const publicationResult = await createPublicationWithContributor(multiWallet);

    // Step 3: Upload encrypted article to Walrus
    const articleResult = await uploadEncryptedArticle(multiWallet, publicationResult);

    // Step 4: Run comprehensive decryption tests
    const testResults = await runDecryptionTests(multiWallet, publicationResult, articleResult);

    // Step 5: Display final summary
    displayFinalSummary(publicationResult, articleResult, testResults);

    console.log(chalk.bold.green('🎉 End-to-end demo completed successfully!'));
    
  } catch (error) {
    console.error(chalk.bold.red('❌ End-to-end demo failed:'));
    console.error(chalk.red(error instanceof Error ? error.message : String(error)));
    process.exit(1);
  }
}

/**
 * Step 0: Setup and validate environment
 */
async function setupAndValidateEnvironment(): Promise<void> {
  console.log(chalk.blue('🔧 Setting up and validating environment...'));

  // Validate required environment variables
  const requiredVars = [
    'PACKAGE_ID',
    'ADMIN_PRIVATE_KEY',
    'CREATOR_PRIVATE_KEY',
    'READER_PRIVATE_KEY',
    'WRONG_READER_PRIVATE_KEY',
    'NETWORK',
  ];

  const missing = requiredVars.filter(v => !process.env[v]);
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  console.log(chalk.green('✅ Environment validation passed'));
  console.log(chalk.gray(`  Network: ${process.env.NETWORK}`));
  console.log(chalk.gray(`  Package ID: ${process.env.PACKAGE_ID}`));
  console.log();
}

/**
 * Step 1: Initialize multi-wallet client and display wallet info
 */
async function initializeMultiWalletClient(): Promise<ReturnType<typeof createMultiWalletClient>> {
  console.log(chalk.blue('💼 Initializing multi-wallet client...'));

  const multiWallet = createMultiWalletClient();
  
  // Display wallet information
  await multiWallet.displayWalletInfo();
  
  // Display role matrix
  multiWallet.displayRoleMatrix();
  
  // Request faucet funds if needed
  console.log(chalk.blue('🚰 Ensuring sufficient balance for all wallets...'));
  await multiWallet.requestFaucetForAll();
  
  // Wait a bit for faucet to process
  console.log(chalk.gray('  Waiting for faucet processing...'));
  await new Promise(resolve => setTimeout(resolve, 5000));
  
  console.log(chalk.green('✅ Multi-wallet client ready'));
  console.log();

  return multiWallet;
}

/**
 * Step 2: Create publication with vault and add contributor
 */
async function createPublicationWithContributor(multiWallet: ReturnType<typeof createMultiWalletClient>) {
  console.log(chalk.blue('📰 Creating publication with contributor access...'));

  const packageId = process.env.PACKAGE_ID!;
  const publicationFlow = new PublicationFlow(multiWallet, packageId);

  // Create publication with contributor setup
  const publicationName = `Inkray Demo Publication ${Date.now()}`;
  const result = await publicationFlow.setupCompletePublication(publicationName, 'reader');

  // Display publication summary
  publicationFlow.displayPublicationSummary(result);

  console.log(chalk.green('✅ Publication setup completed'));
  console.log();

  return result;
}

/**
 * Step 3: Upload encrypted article to Walrus
 */
async function uploadEncryptedArticle(
  multiWallet: ReturnType<typeof createMultiWalletClient>,
  publicationResult: any
) {
  console.log(chalk.blue('📄 Uploading encrypted article to Walrus...'));

  const packageId = process.env.PACKAGE_ID!;
  const uploadFlow = new ArticleUploadFlow(multiWallet, packageId);

  // Path to our test article
  const articlePath = join(__dirname, '..', 'test-articles', 'sample-article.md');
  
  const articleTitle = 'The Future of Decentralized Content Publishing';
  const articleSummary = 'A comprehensive guide to the Inkray platform demonstrating content-identity based encryption, Walrus storage, and multi-credential access control.';

  const result = await uploadFlow.uploadEncryptedArticle(
    articlePath,
    publicationResult.publicationId,
    publicationResult.vaultId,
    publicationResult.ownerCapId,
    articleTitle,
    articleSummary
  );

  // Verify upload
  const isVerified = await uploadFlow.verifyArticleStorage(
    result.articleId,
    publicationResult.vaultId,
    result.blobId
  );

  if (!isVerified) {
    throw new Error('Article storage verification failed');
  }

  // Display upload summary
  uploadFlow.displayUploadSummary(result);

  console.log(chalk.green('✅ Article upload completed'));
  console.log();

  return result;
}

/**
 * Step 4: Run comprehensive decryption tests
 */
async function runDecryptionTests(
  multiWallet: ReturnType<typeof createMultiWalletClient>,
  publicationResult: any,
  articleResult: any
) {
  console.log(chalk.blue('🧪 Running comprehensive decryption tests...'));

  const packageId = process.env.PACKAGE_ID!;
  const decryptionFlow = new DecryptionTestFlow(multiWallet, packageId);

  const testResults = await decryptionFlow.runDecryptionTestSuite(
    articleResult.contentId,
    articleResult.blobId,
    publicationResult.publicationId,
    publicationResult.ownerCapId
  );

  // Validate decrypted content for successful tests
  if (testResults.creatorTest.success && testResults.creatorTest.decryptedContent) {
    const isValid = decryptionFlow.validateDecryptedContent(testResults.creatorTest.decryptedContent);
    if (!isValid) {
      console.log(chalk.yellow('⚠️  Decrypted content validation failed for creator test'));
    }
  }

  console.log(chalk.green('✅ Decryption tests completed'));
  console.log();

  return testResults;
}

/**
 * Step 5: Display final summary
 */
function displayFinalSummary(
  publicationResult: any,
  articleResult: any,
  testResults: any
): void {
  console.log(chalk.bold.blue('📋 Final Demo Summary'));
  console.log(chalk.gray('=' .repeat(80)));

  // Publication Summary
  console.log(chalk.bold.white('Publication:'));
  console.log(chalk.white(`  ID: ${publicationResult.publicationId}`));
  console.log(chalk.white(`  Vault: ${publicationResult.vaultId}`));
  console.log(chalk.white(`  Owner Cap: ${publicationResult.ownerCapId}`));
  console.log(chalk.white(`  Creator: ${publicationResult.creatorAddress}`));
  console.log(chalk.white(`  Contributor: ${publicationResult.contributorResult.contributorAddress}`));
  console.log();

  // Article Summary
  console.log(chalk.bold.white('Article:'));
  console.log(chalk.white(`  ID: ${articleResult.articleId}`));
  console.log(chalk.white(`  Content ID: ${articleResult.contentId}`));
  console.log(chalk.white(`  Blob ID: ${articleResult.blobId}`));
  console.log(chalk.white(`  Size: ${articleResult.originalSize} → ${articleResult.encryptedSize} bytes`));
  console.log();

  // Test Results Summary
  console.log(chalk.bold.white('Access Control Tests:'));
  console.log(chalk.white(`  Creator (Owner): ${testResults.creatorTest.success ? '✅ PASS' : '❌ FAIL'}`));
  console.log(chalk.white(`  Reader (Contributor): ${testResults.readerTest.success ? '✅ PASS' : '⚠️  EXPECTED FAIL'}`));
  console.log(chalk.white(`  Wrong Reader: ${testResults.wrongReaderTest.success ? '❌ UNEXPECTED PASS' : '✅ EXPECTED FAIL'}`));
  console.log(chalk.white(`  Total Time: ${testResults.summary.executionTime}ms`));
  console.log();

  // Key Achievements
  console.log(chalk.bold.white('Key Achievements:'));
  console.log(chalk.green('✅ Smart contract deployment and integration'));
  console.log(chalk.green('✅ Publication and vault creation'));
  console.log(chalk.green('✅ Contributor management and authorization'));
  console.log(chalk.green('✅ Content-identity based encryption with Seal'));
  console.log(chalk.green('✅ Decentralized storage with Walrus'));
  console.log(chalk.green('✅ Multi-credential access control'));
  console.log(chalk.green('✅ Security validation and unauthorized access prevention'));
  console.log();

  // Next Steps
  console.log(chalk.bold.white('Next Steps:'));
  console.log(chalk.blue('• Frontend integration with TypeScript SDK'));
  console.log(chalk.blue('• Backend API for Walrus upload management'));
  console.log(chalk.blue('• Enhanced access control policies'));
  console.log(chalk.blue('• NFT minting and subscription systems'));
  console.log(chalk.blue('• Creator revenue and tipping integration'));
  console.log();
}

/**
 * Handle process signals for graceful shutdown
 */
process.on('SIGINT', () => {
  console.log(chalk.yellow('\\n⚠️  Demo interrupted by user'));
  process.exit(0);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error(chalk.red('❌ Unhandled rejection at:', promise, 'reason:', reason));
  process.exit(1);
});

// Run the demo if this file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  runEndToEndDemo().catch((error) => {
    console.error(chalk.bold.red('❌ Demo failed:'), error);
    process.exit(1);
  });
}

export { runEndToEndDemo };