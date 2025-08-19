import dotenv from 'dotenv';
import process from 'process';

dotenv.config();

// Contract Package IDs (set after deployment)
export const CONTRACT_ADDRESSES = {
  PACKAGE_ID: process.env.PACKAGE_ID || '',
  PUBLICATION_PACKAGE_ID: process.env.PUBLICATION_PACKAGE_ID || '',
  VAULT_PACKAGE_ID: process.env.VAULT_PACKAGE_ID || '',
  CONTENT_REGISTRY_PACKAGE_ID: process.env.CONTENT_REGISTRY_PACKAGE_ID || '',
  PLATFORM_ACCESS_PACKAGE_ID: process.env.PLATFORM_ACCESS_PACKAGE_ID || '',
  ARTICLE_NFT_PACKAGE_ID: process.env.ARTICLE_NFT_PACKAGE_ID || '',
  PLATFORM_ECONOMICS_PACKAGE_ID: process.env.PLATFORM_ECONOMICS_PACKAGE_ID || '',
};

// Shared Object IDs (set after deployment)
export const SHARED_OBJECTS = {
  PLATFORM_SERVICE_ID: process.env.PLATFORM_SERVICE_ID || '',
  MINT_CONFIG_ID: process.env.MINT_CONFIG_ID || '',
  PLATFORM_TREASURY_ID: process.env.PLATFORM_TREASURY_ID || '',
};

// Seal Configuration
export const SEAL_CONFIG = {
  POLICY_PACKAGE_ID: process.env.SEAL_POLICY_PACKAGE_ID || '',
  KEY_SERVER_URL: process.env.SEAL_KEY_SERVER_URL || 'https://seal-testnet.mystenlabs.com',
};

// Move Module Names
export const MODULES = {
  PUBLICATION: 'publication',
  PUBLICATION_VAULT: 'publication_vault',
  CONTENT_REGISTRY: 'content_registry',
  PLATFORM_ACCESS: 'platform_access',
  ARTICLE_NFT: 'article_nft',
  PLATFORM_ECONOMICS: 'platform_economics',
} as const;

// Function Names
export const FUNCTIONS = {
  // Publication
  CREATE_PUBLICATION: 'create_publication',
  ADD_CONTRIBUTOR: 'add_contributor',
  REMOVE_CONTRIBUTOR: 'remove_contributor',

  // Publication Vault
  CREATE_VAULT: 'create_vault',
  STORE_BLOB: 'store_blob',
  GET_BLOB: 'get_blob',
  REMOVE_BLOB: 'remove_blob',
  UPDATE_RENEWAL_EPOCH: 'update_renewal_epoch',

  // Content Registry
  PUBLISH_ARTICLE: 'publish_article',
  PUBLISH_ARTICLE_AS_OWNER: 'publish_article_as_owner',
  UPDATE_ARTICLE: 'update_article',

  // Platform Access
  SUBSCRIBE_TO_PLATFORM: 'subscribe_to_platform',
  EXTEND_SUBSCRIPTION: 'extend_subscription',
  RENEW_SUBSCRIPTION: 'renew_subscription',
  SEAL_APPROVE_PLATFORM_SUBSCRIPTION: 'seal_approve_platform_subscription',

  // Article NFT
  MINT_ARTICLE_NFT: 'mint_article_nft',
  SEAL_APPROVE_ARTICLE_NFT: 'seal_approve_article_nft',

  // Platform Economics
  CREATE_CREATOR_TREASURY: 'create_creator_treasury',
  TIP_ARTICLE: 'tip_article',
  WITHDRAW_FUNDS: 'withdraw_funds',
} as const;

// Gas Configuration
export const GAS_CONFIG = {
  MAX_GAS_BUDGET: parseInt(process.env.MAX_GAS_BUDGET || '10000000'),
  GAS_PRICE: parseInt(process.env.GAS_PRICE || '1000'),
};

// Default Values
export const DEFAULTS = {
  STORAGE_EPOCHS: parseInt(process.env.DEFAULT_STORAGE_EPOCHS || '1'),
  SUBSCRIPTION_DURATION_DAYS: parseInt(process.env.DEFAULT_SUBSCRIPTION_DURATION_DAYS || '30'),
  SUBSCRIPTION_PRICE_SUI: parseInt(process.env.DEFAULT_SUBSCRIPTION_PRICE_SUI || '10'),
  NFT_ROYALTY_PERCENT: 10,
  PLATFORM_FEE_PERCENT: 5,
};

// SUI Denominations
export const SUI_UNITS = {
  MIST: 1,
  SUI: 1_000_000_000, // 1 SUI = 1B MIST
};

// Helper function to convert SUI to MIST
export function suiToMist(sui: number): bigint {
  return BigInt(Math.floor(sui * SUI_UNITS.SUI));
}

// Helper function to convert MIST to SUI
export function mistToSui(mist: bigint): number {
  return Number(mist) / SUI_UNITS.SUI;
}