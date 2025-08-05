# Inkray Decentralized Blogging Platform - Smart Contracts

## Project Overview
- Building a decentralized blogging platform called Inkray on Sui blockchain
- Will use Walrus for media and article hosting
- Key features include:
  - Creator tipping mechanism
  - Minting articles as NFTs
  - Subscription model
  - Creator-specific blob storage wrapper on Walrus
  - Encrypted paid content gating using Seal from Mysten Labs

## Architecture Overview

### Content Access Model
- **Free Content**: Unencrypted, stored directly on Walrus
- **Paid Content**: Encrypted with Seal, stored on Walrus
- **Access Methods**: 
  1. Mint article as NFT (permanent access)
  2. Platform subscription (access to all paid content)

### Publication Management
- **Owner**: Uses `OwnerCap` pattern for administrative control
- **Contributors**: Dynamic list of addresses with publishing rights
- **Content**: Mixed free/paid articles with Walrus blob management

## Smart Contract Architecture

### 1. Publication Management (`publication.move`)
**Purpose**: Core publication ownership and contributor management

**Key Features**:
- OwnerCap-based ownership model
- Dynamic contributor management (add/remove contributors)
- Authorization helpers for content publishing
- Event emission for off-chain indexing

**Core Functions**:
- `create_publication()` - Creates new publication with owner capability
- `add_contributor()` / `remove_contributor()` - Manage publishing permissions
- `is_contributor()` / `is_authorized_with_cap()` - Authorization checks

### 2. Publication Vault (`publication_vault.move`)
**Purpose**: Centralized Walrus blob management with bulk renewal

**Key Features**:
- Walrus storage metadata tracking
- Efficient renewal system with RenewCap
- Blob reference management for off-chain indexing
- Configurable batch sizes for gas optimization

**Core Functions**:
- `create_vault()` - Initialize vault for publication
- `set_storage_info()` - Record Walrus storage allocation
- `add_blob()` - Track blob additions (emits events)
- `renew_storage()` - Platform renewal using RenewCap
- `needs_renewal()` - Check if renewal is required

**RenewCap System**:
- Platform-only capability for efficient bulk renewals
- Backend service calls daily to renew expiring storage
- Optimized for cost efficiency and gas limits

### 3. Content Registry (`content_registry.move`)
**Purpose**: Article metadata and publishing management

**Key Features**:
- Article creation and metadata management
- Author authorization (contributors + owners)
- Free vs paid content classification
- Integration with vault for blob tracking

**Core Functions**:
- `publish_article()` - Contributors can publish articles
- `publish_article_as_owner()` - Publication owners can publish
- `update_article()` - Update article metadata
- Content classification and author tracking

### 4. Platform Access Control (`platform_access.move`)
**Purpose**: Seal integration for encrypted premium content

**Key Features**:
- Platform-wide subscription management
- Time-based access control using Sui Clock
- Seal approval functions for content decryption
- Subscription pricing and duration management

**Core Functions**:
- `subscribe_to_platform()` - Create platform subscription
- `seal_approve_platform_subscription()` - Validate subscription for Seal
- `is_subscription_active()` - Check subscription status
- Service configuration and fee management

**Seal Integration**:
- Uses Identity-Based Encryption (IBE) with BLS12-381 curve
- Threshold encryption (t-out-of-n key servers)
- Access policies defined in Move smart contracts
- Session keys for reduced wallet confirmations

### 5. Article NFT (`article_nft.move`)
**Purpose**: Mintable NFTs for permanent article access

**Key Features**:
- NFT minting for paid articles only
- Automatic premium content access for holders
- Royalty system and marketplace integration
- Display metadata for wallets/marketplaces

**Core Functions**:
- `mint_article_nft()` - Mint NFT for permanent access
- `seal_approve_article_nft()` - Validate NFT ownership for Seal
- Display configuration with metadata templates
- Price and royalty management

**NFT Access Pattern**:
- Only paid articles can be minted as NFTs
- NFT ownership grants permanent access to encrypted content
- Royalties distributed on secondary sales
- Platform fee collection on minting

### 6. Platform Economics (`platform_economics.move`)
**Purpose**: Creator monetization and revenue management

**Key Features**:
- Creator treasury management per publication
- Direct article tipping functionality
- Revenue tracking and withdrawal system
- Platform fee collection and distribution

**Core Functions**:
- `create_creator_treasury()` - Initialize creator revenue account
- `tip_article()` - Direct tipping to article authors
- `withdraw_funds()` - Creator revenue withdrawal
- Platform fee management and collection

## Technical Implementation Details

### Sui Optimization Strategies
- **Object Size Limits**: 250KB max per object
- **Collection Strategy**: 
  - Small collections (≤1000): Use `VecSet<address>` for contributors
  - Large collections: Use `Table<K,V>` for unlimited scalability
- **Dynamic Fields**: Unlimited storage through Table-based collections

### Dependencies Configuration
```toml
[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "testnet-v1.53.1" }
Walrus = { git = "https://github.com/MystenLabs/walrus.git", rev = "main", subdir = "contracts/walrus" }
```

### Event-Driven Architecture
All contracts emit comprehensive events for off-chain indexing:
- Publication management events
- Article publishing events  
- Subscription and NFT minting events
- Revenue and tipping events
- Storage renewal events

### Gas Efficiency Patterns
- Batch operations where possible
- Cursor-based processing for large datasets
- Event-based off-chain indexing vs on-chain storage
- Table-based collections for unlimited scale

## Key Integrations

### Walrus Storage Integration
- Simplified metadata tracking (no direct Storage object handling)
- Event-driven blob reference management
- Efficient renewal system with platform-level RenewCap
- Cost optimization through bulk operations

### Seal Encryption Integration
- Multiple access patterns: subscriptions, NFTs, allowlists
- IBE-based encryption with Move access policies
- `seal_approve*` functions for content gating
- Session key support for UX optimization

## Security Considerations
- Capability-based access control (OwnerCap pattern)
- Field access restrictions through module boundaries
- Event-based audit trails for all operations
- Proper authorization checks for all state changes

## Deployment Status
✅ All contracts implemented and compile successfully
✅ Walrus and Seal integrations complete
✅ Event architecture for off-chain indexing
✅ Gas-optimized collection management
✅ Comprehensive authorization system

## Build Commands
```bash
sui move build    # Build all contracts
sui move test     # Run tests (currently minimal)
```

## Contract Addresses (Post-Deployment)
- Publication Management: TBD
- Publication Vault: TBD  
- Content Registry: TBD
- Platform Access Control: TBD
- Article NFT: TBD
- Platform Economics: TBD