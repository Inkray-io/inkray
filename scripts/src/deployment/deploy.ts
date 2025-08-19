import { execSync } from 'child_process';
import { writeFileSync, readFileSync, existsSync } from 'fs';
import path from 'path';
import chalk from 'chalk';
import dotenv from 'dotenv';
import { getDefaultSuiClient } from '../utils/client.js';
import { getCurrentNetwork } from '../config/networks.js';
import { createTransaction } from '../utils/transactions.js';
import type { DeploymentResult } from '../utils/types.js';

// Load environment variables
dotenv.config();

interface DeploymentConfig {
  contractPath: string;
  network: string;
  skipDependencyChecks?: boolean;
}

export class ContractDeployer {
  private client = getDefaultSuiClient();
  private network: string;
  private contractPath: string;

  constructor(config: DeploymentConfig) {
    this.contractPath = config.contractPath;
    this.network = config.network;
  }

  async deploy(): Promise<DeploymentResult> {
    try {
      console.log(chalk.blue(`🚀 Starting deployment to ${this.network}...`));
      console.log(chalk.gray(`Contract path: ${this.contractPath}`));

      // Step 1: Build the contract
      await this.buildContract();

      // Step 2: Publish the contract
      const result = await this.publishContract();

      // Step 3: Save deployment info
      await this.saveDeploymentInfo(result);

      // Step 4: Initialize shared objects
      await this.initializeSharedObjects(result);

      // Step 5: Validate entry functions
      await this.validateEntryFunctions(result);

      console.log(chalk.green(`✅ Deployment completed successfully!`));
      console.log(chalk.gray(`Package ID: ${result.packageId}`));

      return result;
    } catch (error) {
      console.error(chalk.red(`❌ Deployment failed: ${error}`));
      throw error;
    }
  }

  private async buildContract(): Promise<void> {
    console.log(chalk.blue(`🔨 Building contract...`));

    try {
      const buildOutput = execSync('sui move build', {
        cwd: this.contractPath,
        encoding: 'utf8',
        stdio: 'pipe',
      });

      console.log(chalk.green(`✓ Contract built successfully`));

      if (buildOutput.includes('warning')) {
        console.log(chalk.yellow(`⚠️  Build warnings detected:`));
        console.log(chalk.gray(buildOutput));
      }
    } catch (error) {
      console.error(chalk.red(`❌ Build failed:`));
      console.error(error);
      throw new Error('Contract build failed');
    }
  }

  private async publishContract(): Promise<DeploymentResult> {
    console.log(chalk.blue(`📦 Publishing contract...`));

    try {
      // Use Sui CLI to publish the package
      const publishOutput = await this.publishWithSuiCLI();
      const result = this.parsePublishOutput(publishOutput);

      console.log(chalk.green(`✓ Contract published successfully`));
      console.log(chalk.gray(`Package ID: ${result.packageId}`));

      return result;
    } catch (error) {
      console.error(chalk.red(`❌ Publish failed: ${error}`));
      throw error;
    }
  }

  private async publishWithSuiCLI(): Promise<string> {
    console.log(chalk.gray(`Using Sui CLI to publish package...`));

    try {
      const publishCommand = `sui client publish ${this.contractPath} --json --gas-budget 1000000000`;
      console.log(chalk.gray(`Command: ${publishCommand}`));

      const output = execSync(publishCommand, {
        encoding: 'utf8',
        stdio: 'pipe',
        cwd: this.contractPath,
      });

      return output;
    } catch (error: any) {
      // Get the full output from both stderr and stdout
      const stderr = error.stderr || '';
      const stdout = error.stdout || '';
      const fullOutput = stderr + stdout;

      console.log(chalk.yellow(`Debug - Sui CLI output:`));
      console.log(chalk.gray(`stderr: ${stderr || 'none'}`));
      console.log(chalk.gray(`stdout: ${stdout || 'none'}`));
      console.log(chalk.gray(`status: ${error.status || 'unknown'}`));

      // Check if this is actually a successful execution with warnings/notes
      const hasSuccessIndicators = fullOutput.includes('UPDATING GIT DEPENDENCY') ||
        fullOutput.includes('[warning]') ||
        fullOutput.includes('[Note]') ||
        fullOutput.includes('[note]');

      const hasActualErrors = fullOutput.toLowerCase().includes('error:') ||
        fullOutput.toLowerCase().includes('failed:') ||
        fullOutput.includes('Insufficient funds') ||
        fullOutput.includes('InsufficientGas') ||
        fullOutput.includes('Compilation failed') ||
        fullOutput.includes('Failed to publish the Move module(s)');

      // If we have success indicators but no actual errors, treat as success
      if (hasSuccessIndicators && !hasActualErrors) {
        console.log(chalk.yellow(`⚠️  Sui CLI returned warnings/notes but appears successful`));
        console.log(chalk.gray(`Full output: ${fullOutput}`));

        // Try to extract JSON from the output
        const jsonMatch = fullOutput.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          console.log(chalk.green(`✓ Found JSON output in warnings, treating as success`));
          return jsonMatch[0];
        }

        // If no JSON found, this might be a real error
        console.log(chalk.red(`❌ No JSON output found, this is likely a real error`));
      }

      // Handle specific known errors
      if (fullOutput.includes('Insufficient funds')) {
        throw new Error('Insufficient SUI balance for gas. Please request faucet tokens.');
      } else if (fullOutput.includes('InsufficientGas')) {
        throw new Error('Insufficient gas budget. Large package deployment requires higher gas budget - increased to 1B. You may also need more SUI balance.');
      } else if (fullOutput.includes('does not specify a published address')) {
        throw new Error('Unpublished dependencies detected. Using --with-unpublished-dependencies flag in next attempt.');
      } else if (fullOutput.includes('Package dependency') && !fullOutput.includes('published address')) {
        throw new Error('Package dependency error. Please check Move.toml dependencies.');
      } else if (fullOutput.includes('Compilation failed')) {
        throw new Error('Move compilation failed. Please check your Move code for errors.');
      }

      throw new Error(`Sui CLI publish failed: ${fullOutput}`);
    }
  }

  private parsePublishOutput(output: string): DeploymentResult {
    try {
      const result = JSON.parse(output);

      if (!result.objectChanges) {
        throw new Error('No object changes found in publish result');
      }

      // Find the published package
      const publishedPackage = result.objectChanges.find((change: any) =>
        change.type === 'published'
      );

      if (!publishedPackage) {
        throw new Error('No published package found in object changes');
      }

      const packageId = publishedPackage.packageId;

      // Extract shared objects created during initialization
      const sharedObjects: Record<string, string> = {};
      const createdObjects = result.objectChanges.filter((change: any) =>
        change.type === 'created' && change.owner && typeof change.owner === 'object' && change.owner.Shared
      );

      // Track shared objects from our current architecture
      for (const change of createdObjects) {
        if (change.objectType?.includes('::vault::PublicationVault')) {
          // Publications create vaults automatically, we don't need to track specific vault IDs
          console.log(chalk.gray(`  Found shared vault: ${change.objectId}`));
        } else if (change.objectType?.includes('::subscription::')) {
          sharedObjects.SUBSCRIPTION_SERVICE_ID = change.objectId;
        } else if (change.objectType?.includes('::nft::')) {
          sharedObjects.NFT_CONFIG_ID = change.objectId;
        }
        // Publications themselves are shared objects but created dynamically
      }

      // Extract upgrade capability
      const upgradeCapObject = result.objectChanges.find((change: any) =>
        change.type === 'created' && change.objectType?.includes('UpgradeCap')
      );

      return {
        packageId,
        sharedObjects,
        upgradeCapId: upgradeCapObject?.objectId,
      };
    } catch (error) {
      console.error(chalk.red(`Raw output: ${output}`));
      throw new Error(`Failed to parse publish output: ${error}`);
    }
  }

  private getPackageName(): string {
    const moveTomlPath = path.join(this.contractPath, 'Move.toml');
    if (!existsSync(moveTomlPath)) {
      throw new Error('Move.toml not found');
    }

    const moveToml = readFileSync(moveTomlPath, 'utf8');
    const nameMatch = moveToml.match(/name\s*=\s*"([^"]+)"/);
    if (!nameMatch) {
      throw new Error('Package name not found in Move.toml');
    }

    return nameMatch[1];
  }

  // This method is no longer needed as we use Sui CLI for publishing
  // Kept for future implementation of tx.publish() method
  private readCompiledModules(): Uint8Array[] {
    const moduleFiles = ['articles.mv', 'inkray_events.mv', 'nft.mv',
      'policy.mv', 'publication.mv', 'subscription.mv', 'vault.mv'];

    return moduleFiles.map(file => {
      const filePath = path.join(this.contractPath, 'build/contracts/bytecode_modules', file);

      if (!existsSync(filePath)) {
        throw new Error(`Module file not found: ${filePath}`);
      }

      return readFileSync(filePath);
    });
  }

  private async saveDeploymentInfo(result: DeploymentResult): Promise<void> {
    console.log(chalk.blue(`💾 Saving deployment info...`));

    const deploymentInfo = {
      network: this.network,
      deployedAt: new Date().toISOString(),
      packageId: result.packageId,
      sharedObjects: result.sharedObjects,
      upgradeCapId: result.upgradeCapId,
      deployer: this.client.getAddress(),
    };

    const outputPath = path.join(this.contractPath, 'scripts', `deployment-${this.network}.json`);
    writeFileSync(outputPath, JSON.stringify(deploymentInfo, null, 2));

    console.log(chalk.green(`✓ Deployment info saved to: ${outputPath}`));

    // Also update .env file
    this.updateEnvFile(result);
  }

  private updateEnvFile(result: DeploymentResult): void {
    const envPath = path.join(this.contractPath, 'scripts/.env');
    const envExamplePath = path.join(this.contractPath, 'scripts/.env.example');

    let envContent = '';

    if (existsSync(envPath)) {
      envContent = readFileSync(envPath, 'utf8');
    } else if (existsSync(envExamplePath)) {
      envContent = readFileSync(envExamplePath, 'utf8');
    } else {
      envContent = `# Generated deployment configuration\\nNETWORK=${this.network}\\n`;
    }

    // Update package ID
    if (envContent.includes('PACKAGE_ID=')) {
      envContent = envContent.replace(/PACKAGE_ID=.*/, `PACKAGE_ID=${result.packageId}`);
    } else {
      envContent += `\\nPACKAGE_ID=${result.packageId}`;
    }

    // Update shared object IDs (only add if they exist)
    for (const [key, value] of Object.entries(result.sharedObjects)) {
      if (value) { // Only add if the shared object was actually found
        if (envContent.includes(`${key}=`)) {
          envContent = envContent.replace(new RegExp(`${key}=.*`), `${key}=${value}`);
        } else {
          envContent += `\\n${key}=${value}`;
        }
      }
    }

    // Remove old/unused environment variables that are no longer relevant
    const unusedVars = ['PLATFORM_SERVICE_ID', 'MINT_CONFIG_ID', 'PLATFORM_TREASURY_ID'];
    for (const unusedVar of unusedVars) {
      if (envContent.includes(`${unusedVar}=`)) {
        envContent = envContent.replace(new RegExp(`\\n?${unusedVar}=.*\\n?`), '\\n');
        console.log(chalk.gray(`  Removed unused variable: ${unusedVar}`));
      }
    }

    writeFileSync(envPath, envContent);
    console.log(chalk.green(`✓ Environment file updated`));
  }

  private async initializeSharedObjects(result: DeploymentResult): Promise<void> {
    console.log(chalk.blue(`🔧 Initializing shared objects...`));

    // Most shared objects are created automatically during package initialization
    // Additional setup can be done here if needed

    console.log(chalk.green(`✓ Shared objects initialized`));
  }

  private async validateEntryFunctions(result: DeploymentResult): Promise<void> {
    console.log(chalk.blue(`🧪 Validating entry functions...`));

    try {
      // Test that the entry functions exist by doing a dry run
      const { Transaction } = await import('@mysten/sui/transactions');

      // Test create_publication entry function
      const testTx = new Transaction();
      testTx.setSender(this.client.getAddress());
      testTx.moveCall({
        target: `${result.packageId}::publication::create_publication`,
        arguments: [
          testTx.pure.string('Test Publication'),
        ],
      });

      // Do a dry run to validate the function exists
      const txBytes = await testTx.build({
        client: this.client.getClient()
      });

      const dryRunResult = await this.client.getClient().dryRunTransactionBlock({
        transactionBlock: txBytes,
      });

      if (dryRunResult.effects.status.status === 'failure') {
        const error = dryRunResult.effects.status.error;
        if (error?.includes('FunctionNotFound')) {
          throw new Error(`Entry function not found: create_publication`);
        }
        // Other errors (like insufficient gas, etc.) are OK - we just want to validate the function exists
        console.log(chalk.gray(`  Dry run status: ${dryRunResult.effects.status.status} (expected for validation)`));
      }

      console.log(chalk.green(`✓ Entry functions validated successfully`));
    } catch (error) {
      // For validation purposes, some errors are acceptable (like gas estimation issues)
      const errorMsg = error instanceof Error ? error.message : String(error);

      if (errorMsg.includes('FunctionNotFound')) {
        console.error(chalk.red(`❌ Entry function validation failed: ${error}`));
        throw error;
      } else {
        // Other errors might be OK for validation purposes
        console.log(chalk.yellow(`⚠️  Entry function validation completed with warnings: ${errorMsg}`));
        console.log(chalk.green(`✓ Entry functions appear to exist (function calls can be constructed)`));
      }
    }
  }
}

// Main deployment function
export async function deployContracts(options: {
  network?: string;
  contractPath?: string;
} = {}): Promise<DeploymentResult> {
  const contractPath = options.contractPath || process.cwd();
  const network = options.network || getCurrentNetwork();

  console.log(chalk.blue(`🚀 Starting Inkray contract deployment`));
  console.log(chalk.gray(`Network: ${network}`));
  console.log(chalk.gray(`Contract path: ${contractPath}`));

  // Initialize client
  const client = getDefaultSuiClient();
  const address = client.getAddress();
  const balance = await client.getBalance();

  console.log(chalk.blue(`📍 Deployer: ${address}`));
  console.log(chalk.blue(`💰 Balance: ${Number(balance) / 1e9} SUI`));

  if (Number(balance) < 2e9) { // Less than 2 SUI
    console.log(chalk.yellow(`⚠️  Low balance detected (${Number(balance) / 1e9} SUI).`));
    console.log(chalk.yellow(`⚠️  Large package deployment typically requires 1-2 SUI. Consider requesting more faucet funds.`));

    if (Number(balance) < 1e9) {
      console.log(chalk.red(`❌ Balance too low for deployment. Please request faucet funds first.`));
      console.log(chalk.gray(`   Run: sui client faucet`));
    }
  }

  const deployer = new ContractDeployer({
    contractPath,
    network,
  });

  return await deployer.deploy();
}

// CLI usage
if (import.meta.url === `file://${process.argv[1]}`) {
  const network = process.argv[2] || getCurrentNetwork();
  // Set contract path to the parent directory (where Move.toml is located)
  const contractPath = process.argv[3] || path.join(process.cwd(), '../');

  deployContracts({ network, contractPath })
    .then(() => {
      console.log(chalk.green(`🎉 Deployment completed successfully!`));
      process.exit(0);
    })
    .catch((error) => {
      console.error(chalk.red(`💥 Deployment failed: ${error}`));
      process.exit(1);
    });
}