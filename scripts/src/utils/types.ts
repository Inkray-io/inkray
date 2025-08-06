// Type definitions for Inkray SDK

export interface MockBlob {
  blob_id: string;
  size: number;
  encoding_type: number;
}

export interface Article {
  id: string;
  publication_id: string;
  author: string;
  title: string;
  summary: string;
  blob_id: string;
  is_paid: boolean;
  created_at: string;
}

export interface Publication {
  id: string;
  name: string;
  description: string;
  owner: string;
  vault_id: string;
  contributors: string[];
}

export interface PublicationOwnerCap {
  id: string;
  publication_id: string;
}

export interface PublicationVault {
  id: string;
  publication_id: string;
  blobs: Record<string, MockBlob>;
  blob_is_encrypted: Record<string, boolean>;
  next_renewal_epoch: number;
  renewal_batch_size: number;
}

export interface PlatformSubscription {
  id: string;
  subscriber: string;
  expires_at: string;
  tier: number;
}

export interface PlatformService {
  id: string;
  monthly_fee: string;
  time_to_live: string;
  owner: string;
}

export interface ArticleNFT {
  id: string;
  article_id: string;
  publication_id: string;
  title: string;
  author: string;
  blob_id: string;
  minted_at: string;
  royalty_percent: number;
}

export interface CreatorTreasury {
  id: string;
  publication_id: string;
  owner: string;
  total_tips_received: string;
  total_earnings: string;
}

// Walrus-related types
export interface WalrusBlob {
  blobId: string;
  size: number;
  storageEndEpoch: number;
  content?: Uint8Array;
}

export interface WalrusUploadResponse {
  blobObject: {
    id: string;
    blobId: string;
    size: number;
    encoding_type: string;
    storageEndEpoch: number;
  };
  resourceOperation: {
    RegisteredFromScratch?: {
      encoded_size: number;
      epochs_ahead: number;
    };
    RegisteredFromStorage?: {
      encoded_size: number;
      epochs_ahead: number;
    };
  };
}

// Seal-related types
export interface SealEncryptionOptions {
  policy: 'subscription' | 'nft' | 'allowlist';
  policyObjectId?: string;
  capId?: string;
  identity?: string;
}

export interface SealDecryptionRequest {
  encryptedData: Uint8Array;
  policy: string;
  identity: string;
  accessProof?: any;
}

// Transaction result types
export interface TransactionResult {
  digest: string;
  effects: any;
  events: any[];
  objectChanges: any[];
  balanceChanges: any[];
}

export interface DeploymentResult {
  packageId: string;
  sharedObjects: Record<string, string>;
  upgradeCapId?: string;
}

// Configuration types
export interface ClientConfig {
  network: 'localnet' | 'testnet' | 'mainnet';
  rpcUrl?: string;
  privateKey?: string;
  mnemonic?: string;
}

export interface WalrusClientConfig {
  network: string;
  publisherUrl: string;
  aggregatorUrl: string;
}

export interface SealClientConfig {
  network: string;
  keyServerUrl: string;
  policyPackageId?: string;
}

// CLI Command types
export interface CLICommand {
  name: string;
  description: string;
  action: (...args: any[]) => Promise<void>;
}

export interface PublishContentOptions {
  title: string;
  summary: string;
  filePath: string;
  isPaid: boolean;
  publicationId: string;
  encryptionPolicy?: SealEncryptionOptions;
}

export interface SubscriptionOptions {
  duration: number; // days
  tier: number;
}

export interface NFTMintOptions {
  articleId: string;
  royaltyPercent: number;
}

export interface TipOptions {
  articleId: string;
  amount: number; // SUI
  message?: string;
}