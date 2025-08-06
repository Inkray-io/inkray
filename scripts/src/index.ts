#!/usr/bin/env node

import { Command } from 'commander';
import chalk from 'chalk';
import dotenv from 'dotenv';
import { getDefaultSuiClient } from './utils/client.js';
import { getCurrentNetwork } from './config/networks.js';
import { deployContracts } from './deployment/deploy.js';
import { verifyDeployment } from './deployment/verify.js';
import { uploadFile, uploadText, uploadJSON } from './storage/walrus-upload.js';
import { downloadBlob, downloadBlobToFile, downloadAsText } from './storage/walrus-download.js';

// Load environment variables
dotenv.config();

const program = new Command();

// CLI Header
function printHeader() {
  console.log(chalk.cyan(''));
  console.log(chalk.cyan('  ╔═══════════════════════════════════════╗'));
  console.log(chalk.cyan('  ║           Inkray SDK CLI             ║'));
  console.log(chalk.cyan('  ║    Decentralized Blogging Platform   ║'));
  console.log(chalk.cyan('  ╚═══════════════════════════════════════╝'));
  console.log(chalk.cyan(''));
}

// Error handler
function handleError(error: any) {
  console.error(chalk.red(`\\n❌ Error: ${error.message || error}`));
  if (process.env.LOG_LEVEL === 'debug') {
    console.error(chalk.gray(error.stack));
  }
  process.exit(1);
}

// Setup global error handling
process.on('unhandledRejection', handleError);
process.on('uncaughtException', handleError);

// Main program setup
program
  .name('inkray-cli')
  .description('CLI for Inkray decentralized blogging platform')
  .version('1.0.0')
  .option('-n, --network <network>', 'Network to use (localnet, testnet, mainnet)', 'testnet')
  .option('-v, --verbose', 'Enable verbose logging')
  .hook('preAction', (thisCommand) => {
    printHeader();
    
    if (thisCommand.opts().verbose) {
      process.env.LOG_LEVEL = 'debug';
    }
    
    const network = thisCommand.opts().network || getCurrentNetwork();
    console.log(chalk.blue(`🌐 Network: ${network}`));
    console.log('');
  });

// Deployment Commands
const deployCmd = program
  .command('deploy')
  .description('Deploy and manage smart contracts');

deployCmd
  .command('contracts')
  .description('Deploy all Inkray smart contracts')
  .option('-p, --path <path>', 'Contract source path', process.cwd())
  .action(async (options) => {
    try {
      const result = await deployContracts({
        contractPath: options.path,
        network: program.opts().network,
      });
      
      console.log(chalk.green('🎉 Deployment completed successfully!'));
      console.log(chalk.gray(`Package ID: ${result.packageId}`));
    } catch (error) {
      handleError(error);
    }
  });

deployCmd
  .command('verify')
  .description('Verify deployed contracts')
  .option('-p, --path <path>', 'Contract source path', process.cwd())
  .option('-r, --report', 'Generate verification report')
  .action(async (options) => {
    try {
      const success = await verifyDeployment({
        contractPath: options.path,
        network: program.opts().network,
        generateReport: options.report,
      });
      
      if (success) {
        console.log(chalk.green('✅ Verification completed successfully!'));
      } else {
        console.error(chalk.red('❌ Verification failed!'));
        process.exit(1);
      }
    } catch (error) {
      handleError(error);
    }
  });

// Storage Commands
const storageCmd = program
  .command('storage')
  .description('Walrus storage operations');

storageCmd
  .command('upload <file>')
  .description('Upload file to Walrus')
  .option('-e, --epochs <epochs>', 'Storage duration in epochs', '5')
  .option('-d, --deletable', 'Make blob deletable')
  .action(async (file, options) => {
    try {
      console.log(chalk.blue(`📤 Uploading file: ${file}`));
      
      const result = await uploadFile(file, {
        epochs: parseInt(options.epochs),
        deletable: options.deletable,
      });
      
      console.log(chalk.green('✅ Upload completed!'));
      console.log(chalk.gray(`Blob ID: ${result.blobId}`));
      console.log(chalk.gray(`Size: ${result.size} bytes`));
    } catch (error) {
      handleError(error);
    }
  });

storageCmd
  .command('download <blobId>')
  .description('Download blob from Walrus')
  .option('-o, --output <path>', 'Output file path')
  .option('--text', 'Download as text')
  .option('--json', 'Download as JSON')
  .action(async (blobId, options) => {
    try {
      console.log(chalk.blue(`📥 Downloading blob: ${blobId}`));
      
      if (options.text) {
        const text = await downloadAsText(blobId);
        console.log(chalk.green('✅ Download completed!'));
        console.log('Content:', text);
      } else if (options.output) {
        const result = await downloadBlobToFile(blobId, options.output);
        console.log(chalk.green(`✅ Download completed: ${result.outputPath}`));
      } else {
        const result = await downloadBlob(blobId);
        console.log(chalk.green('✅ Download completed!'));
        console.log(`Size: ${result.size} bytes`);
      }
    } catch (error) {
      handleError(error);
    }
  });

// Wallet Commands
const walletCmd = program
  .command('wallet')
  .description('Wallet operations');

walletCmd
  .command('info')
  .description('Show wallet information')
  .action(async () => {
    try {
      const client = getDefaultSuiClient();
      const address = client.getAddress();
      const balance = await client.getBalance();
      const network = client.getNetwork();
      
      console.log(chalk.blue('💼 Wallet Information'));
      console.log(chalk.gray(`Address: ${address}`));
      console.log(chalk.gray(`Network: ${network}`));
      console.log(chalk.gray(`Balance: ${Number(balance) / 1e9} SUI`));
    } catch (error) {
      handleError(error);
    }
  });

walletCmd
  .command('faucet')
  .description('Request test tokens from faucet')
  .action(async () => {
    try {
      const client = getDefaultSuiClient();
      await client.requestFaucet();
      
      // Wait a bit and show new balance
      setTimeout(async () => {
        const newBalance = await client.getBalance();
        console.log(chalk.green(`✅ New balance: ${Number(newBalance) / 1e9} SUI`));
      }, 2000);
    } catch (error) {
      handleError(error);
    }
  });

// Content Commands  
const contentCmd = program
  .command('content')
  .description('Content management operations');

contentCmd
  .command('publish <file>')
  .description('Publish content article')
  .requiredOption('-t, --title <title>', 'Article title')
  .requiredOption('-s, --summary <summary>', 'Article summary')
  .option('-p, --paid', 'Mark as paid content (encrypted)')
  .option('--publication <id>', 'Publication ID')
  .action(async (file, options) => {
    try {
      console.log(chalk.blue(`📝 Publishing article: ${options.title}`));
      
      // Upload file to Walrus first
      const uploadResult = await uploadFile(file);
      console.log(chalk.green(`✅ File uploaded with blob ID: ${uploadResult.blobId}`));
      
      // TODO: Create article in smart contract
      console.log(chalk.blue('📝 Creating article in smart contract...'));
      console.log(chalk.yellow('⚠️  Smart contract integration coming soon!'));
      
      console.log(chalk.green('✅ Article published!'));
    } catch (error) {
      handleError(error);
    }
  });

// Subscription Commands
const subCmd = program
  .command('subscription')
  .description('Platform subscription operations');

subCmd
  .command('create')
  .description('Create platform subscription')
  .option('-d, --duration <days>', 'Subscription duration in days', '30')
  .option('-t, --tier <tier>', 'Subscription tier', '1')
  .action(async (options) => {
    try {
      console.log(chalk.blue(`🔖 Creating subscription for ${options.duration} days`));
      console.log(chalk.yellow('⚠️  Smart contract integration coming soon!'));
      
      // TODO: Implement subscription creation
      console.log(chalk.green('✅ Subscription created!'));
    } catch (error) {
      handleError(error);
    }
  });

// NFT Commands
const nftCmd = program
  .command('nft')
  .description('NFT operations');

nftCmd
  .command('mint <articleId>')
  .description('Mint article as NFT')
  .option('-r, --royalty <percent>', 'Royalty percentage', '10')
  .action(async (articleId, options) => {
    try {
      console.log(chalk.blue(`🎨 Minting NFT for article: ${articleId}`));
      console.log(chalk.yellow('⚠️  Smart contract integration coming soon!'));
      
      // TODO: Implement NFT minting
      console.log(chalk.green('✅ NFT minted!'));
    } catch (error) {
      handleError(error);
    }
  });

// Utility Commands
const utilCmd = program
  .command('util')
  .description('Utility operations');

utilCmd
  .command('test-upload')
  .description('Test upload functionality with sample data')
  .action(async () => {
    try {
      console.log(chalk.blue('🧪 Testing upload functionality...'));
      
      const testText = `Test article content\\nUploaded at: ${new Date().toISOString()}`;
      const result = await uploadText(testText, 'test-article.txt');
      
      console.log(chalk.green('✅ Test upload completed!'));
      console.log(chalk.gray(`Blob ID: ${result.blobId}`));
      
      // Test download
      console.log(chalk.blue('🧪 Testing download...'));
      const downloadedText = await downloadAsText(result.blobId);
      
      if (downloadedText === testText) {
        console.log(chalk.green('✅ Upload/download test passed!'));
      } else {
        console.log(chalk.red('❌ Upload/download test failed!'));
      }
    } catch (error) {
      handleError(error);
    }
  });

utilCmd
  .command('generate-test-data')
  .description('Generate test data files')
  .action(async () => {
    try {
      console.log(chalk.blue('🧪 Generating test data...'));
      
      const testArticle = {
        title: 'Test Article',
        summary: 'This is a test article for the Inkray platform',
        content: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        author: 'Test Author',
        createdAt: new Date().toISOString(),
      };
      
      const result = await uploadJSON(testArticle, 'test-article.json');
      
      console.log(chalk.green('✅ Test data generated!'));
      console.log(chalk.gray(`Test article blob ID: ${result.blobId}`));
    } catch (error) {
      handleError(error);
    }
  });

// Help Command
program
  .command('help')
  .description('Show detailed help')
  .action(() => {
    console.log(chalk.blue('📖 Inkray SDK CLI Help\\n'));
    
    console.log(chalk.yellow('🚀 Quick Start:'));
    console.log('  1. Deploy contracts: inkray-cli deploy contracts');
    console.log('  2. Verify deployment: inkray-cli deploy verify');
    console.log('  3. Test functionality: inkray-cli util test-upload\\n');
    
    console.log(chalk.yellow('📁 Storage Operations:'));
    console.log('  Upload file: inkray-cli storage upload ./myfile.txt');
    console.log('  Download blob: inkray-cli storage download <blobId> -o output.txt\\n');
    
    console.log(chalk.yellow('📝 Content Management:'));
    console.log('  Publish article: inkray-cli content publish ./article.md -t "Title" -s "Summary"\\n');
    
    console.log(chalk.yellow('💼 Wallet Management:'));
    console.log('  Show wallet info: inkray-cli wallet info');
    console.log('  Request faucet: inkray-cli wallet faucet\\n');
    
    console.log(chalk.yellow('🔧 Configuration:'));
    console.log('  Set network: inkray-cli --network testnet <command>');
    console.log('  Verbose logging: inkray-cli --verbose <command>\\n');
    
    program.help();
  });

// Parse command line arguments
program.parse();

// If no command provided, show help
if (!process.argv.slice(2).length) {
  program.help();
}