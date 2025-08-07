import { Transaction } from '@mysten/sui/transactions';
import { getDefaultSuiClient } from './client.js';
import { GAS_CONFIG } from '../config/constants.js';
import type { TransactionResult } from './types.js';
import chalk from 'chalk';

export class TransactionBuilder {
  private tx: Transaction;
  public client = getDefaultSuiClient();

  constructor() {
    this.tx = new Transaction();
    this.tx.setGasPrice(GAS_CONFIG.GAS_PRICE);
    this.tx.setGasBudget(GAS_CONFIG.MAX_GAS_BUDGET);
  }

  getTransaction(): Transaction {
    return this.tx;
  }

  // Move call methods
  moveCall(params: {
    package: string;
    module: string;
    function: string;
    typeArguments?: string[];
    arguments?: any[];
  }) {
    return this.tx.moveCall({
      target: `${params.package}::${params.module}::${params.function}`,
      typeArguments: params.typeArguments || [],
      arguments: params.arguments || [],
    });
  }

  // Object handling
  objectArg(objectId: string) {
    return this.tx.object(objectId);
  }

  sharedObjectRef(objectId: string, initialSharedVersion?: string, mutable: boolean = true) {
    return this.tx.sharedObjectRef({
      objectId,
      initialSharedVersion: initialSharedVersion || '1',
      mutable,
    });
  }

  // Pure arguments
  pure(value: any, type?: string) {
    if (type) {
      return this.tx.pure.string(value);
    }
    return this.tx.pure(value);
  }

  pureString(value: string) {
    return this.tx.pure.string(value);
  }

  pureU64(value: number | string | bigint) {
    return this.tx.pure.u64(value);
  }

  pureU256(value: number | string | bigint) {
    return this.tx.pure.u256(value);
  }

  pureBool(value: boolean) {
    return this.tx.pure.bool(value);
  }

  pureAddress(address: string) {
    return this.tx.pure.address(address);
  }

  // Note: Vector types should be handled using specific methods or manual construction

  // SUI coin handling
  splitCoins(coin: any, amounts: (number | string | bigint)[]) {
    return this.tx.splitCoins(coin, amounts.map(amount => this.tx.pure.u64(amount)));
  }

  mergeCoins(destination: any, sources: any[]) {
    return this.tx.mergeCoins(destination, sources);
  }

  // Transfer operations
  transferObjects(objects: any[], recipient: string) {
    return this.tx.transferObjects(objects, this.tx.pure.address(recipient));
  }

  // Gas coin management
  getGasCoin() {
    return this.tx.gas;
  }

  // Transaction execution
  async execute(options?: {
    showEffects?: boolean;
    showEvents?: boolean;
    showObjectChanges?: boolean;
    showBalanceChanges?: boolean;
  }): Promise<TransactionResult> {
    try {
      const keypair = this.client.getKeypair();
      
      console.log(chalk.blue(`📤 Executing transaction...`));
      
      const result = await this.client.getClient().signAndExecuteTransaction({
        transaction: this.tx,
        signer: keypair,
        options: {
          showEffects: options?.showEffects ?? true,
          showEvents: options?.showEvents ?? true,
          showObjectChanges: options?.showObjectChanges ?? true,
          showBalanceChanges: options?.showBalanceChanges ?? true,
        },
      });

      if (result.effects?.status?.status !== 'success') {
        const error = result.effects?.status?.error || 'Unknown error';
        throw new Error(`Transaction failed: ${error}`);
      }

      console.log(chalk.green(`✓ Transaction executed successfully`));
      console.log(chalk.gray(`  Digest: ${result.digest}`));
      
      if (result.effects?.gasUsed) {
        const gasUsed = result.effects.gasUsed;
        console.log(chalk.gray(`  Gas used: ${gasUsed.computationCost} computation, ${gasUsed.storageCost} storage`));
      }

      return {
        digest: result.digest,
        effects: result.effects,
        events: result.events || [],
        objectChanges: result.objectChanges || [],
        balanceChanges: result.balanceChanges || [],
      };
    } catch (error) {
      console.error(chalk.red(`❌ Transaction execution failed: ${error}`));
      throw error;
    }
  }

  // Dry run for testing
  async dryRun(): Promise<any> {
    try {
      console.log(chalk.blue(`🧪 Dry running transaction...`));
      
      const result = await this.client.getClient().dryRunTransactionBlock({
        transactionBlock: await this.tx.build({
          client: this.client.getClient(),
          onlyTransactionKind: false,
        }),
      });

      console.log(chalk.green(`✓ Dry run completed`));
      return result;
    } catch (error) {
      console.error(chalk.red(`❌ Dry run failed: ${error}`));
      throw error;
    }
  }

  // Clone this builder
  clone(): TransactionBuilder {
    const newBuilder = new TransactionBuilder();
    // Note: Deep cloning a Transaction object is complex
    // For now, we'll create a fresh transaction
    return newBuilder;
  }
}

// Helper functions for common transaction patterns
export function createTransaction(): TransactionBuilder {
  return new TransactionBuilder();
}

export async function executeTransaction(
  buildFn: (tx: TransactionBuilder) => void | Promise<void>
): Promise<TransactionResult> {
  const tx = new TransactionBuilder();
  await buildFn(tx);
  return await tx.execute();
}

// Common transaction builders
export class CommonTransactions {
  static async transferSui(
    recipient: string, 
    amount: number | string | bigint
  ): Promise<TransactionResult> {
    return executeTransaction(async (tx) => {
      const coin = tx.splitCoins(tx.getGasCoin(), [amount]);
      tx.transferObjects([coin], recipient);
    });
  }

  static async mintNFT(params: {
    packageId: string;
    module: string;
    function: string;
    arguments: any[];
    typeArguments?: string[];
  }): Promise<TransactionResult> {
    return executeTransaction(async (tx) => {
      const nft = tx.moveCall({
        package: params.packageId,
        module: params.module,
        function: params.function,
        typeArguments: params.typeArguments,
        arguments: params.arguments,
      });
      
      const clientAddress = getDefaultSuiClient().getAddress();
      tx.transferObjects([nft], clientAddress);
    });
  }

  static async createSharedObject(params: {
    packageId: string;
    module: string;
    function: string;
    arguments: any[];
    typeArguments?: string[];
  }): Promise<TransactionResult> {
    return executeTransaction(async (tx) => {
      tx.moveCall({
        package: params.packageId,
        module: params.module,
        function: params.function,
        typeArguments: params.typeArguments,
        arguments: params.arguments,
      });
    });
  }
}

// Transaction event parsing utilities
export function parseEvents(events: any[], eventType: string): any[] {
  return events.filter(event => 
    event.type && event.type.includes(eventType)
  ).map(event => event.parsedJson);
}

export function findObjectChanges(objectChanges: any[], type: 'created' | 'mutated' | 'deleted'): any[] {
  return objectChanges.filter(change => change.type === type);
}

export function extractCreatedObjectIds(objectChanges: any[]): string[] {
  return findObjectChanges(objectChanges, 'created').map(change => change.objectId);
}

export function extractCreatedObjectsByType(objectChanges: any[], objectType: string): any[] {
  return findObjectChanges(objectChanges, 'created').filter(change => 
    change.objectType && change.objectType.includes(objectType)
  );
}