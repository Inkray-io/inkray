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
  blobId: string;
  blobObject: {
    id: { id: string };
    registered_epoch: number;
    blob_id: string;
    size: string;
    encoding_type: number;
    certified_epoch: number | null;
    storage: {
      id: { id: string };
      start_epoch: number;
      end_epoch: number;
      storage_size: string;
    } | null;
    deletable: boolean;
  };
  resourceOperation?: {
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
  contentId: string | Uint8Array; // BCS-encoded IdV1 or legacy string identifier
  packageId?: string;
  threshold?: number; // Number of key servers required for decryption (default: 2)
}

export interface UserCredentials {
  subscription?: {
    id: string;
    serviceId: string;
  };
  nft?: {
    id: string;
    articleId: string;
  };
  publicationOwner?: {
    ownerCapId: string;
    publicationId: string;
  };
  contributor?: {
    publicationId: string;
    contentPolicyId: string;
  };
  allowlist?: {
    contentPolicyId: string;
  };
}

export interface SealDecryptionRequest {
  encryptedData: Uint8Array;
  contentId: string | Uint8Array; // BCS-encoded IdV1 or legacy string identifier
  credentials: UserCredentials; // Available user credentials
  packageId?: string;
  requestingClient?: import('./client.js').InkraySuiClient; // The client making the request (for access validation)
}

// Legacy interface for backward compatibility
export interface SealDecryptionRequestLegacy {
  encryptedData: Uint8Array;
  policy: string;
  identity: string;
  policyPackageId?: string;
  policyObjectId?: string;
  subscriptionId?: string;
  nftId?: string;
  publicationId?: string;
  articleId?: string;
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
  suiClient?: import('./client.js').InkraySuiClient;
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