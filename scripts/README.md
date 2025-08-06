# Inkray SDK - TypeScript Integration

Complete TypeScript SDK for the Inkray decentralized blogging platform, integrating Sui smart contracts, Walrus storage, and Seal encryption.

## 🚀 Quick Start

### Installation

```bash
cd scripts
npm install
```

### Environment Setup

```bash
cp .env.example .env
# Edit .env with your configuration
```

### Build and Run

```bash
# Build TypeScript
npm run build

# Run CLI directly with tsx
npm run dev -- --help

# Or use built version
npm start -- --help
```

## 📋 Prerequisites

1. **Sui CLI**: Install from [Sui docs](https://docs.sui.io/build/install)
2. **Node.js**: Version 18 or higher
3. **SUI Tokens**: For testnet operations
4. **Private Key/Mnemonic**: Set in environment variables

## 🔧 Configuration

### Environment Variables

```bash
# Network Configuration
NETWORK=testnet
SUI_RPC_URL=https://fullnode.testnet.sui.io:443

# Private Keys (choose one method)
ADMIN_MNEMONIC=your-admin-mnemonic-here
# OR
ADMIN_PRIVATE_KEY=your-private-key-here

# Contract Addresses (auto-populated after deployment)
PACKAGE_ID=
PLATFORM_SERVICE_ID=
MINT_CONFIG_ID=

# Walrus Configuration
WALRUS_PUBLISHER_URL=https://publisher.walrus-testnet.mystenlabs.com
WALRUS_AGGREGATOR_URL=https://aggregator.walrus-testnet.mystenlabs.com

# Seal Configuration  
SEAL_KEY_SERVER_URL=https://seal-testnet.mystenlabs.com
```

### Network Support

- **Localnet**: Local development
- **Testnet**: Testing and development (recommended)
- **Mainnet**: Production (when available)

## 🎯 CLI Usage

### Core Commands

```bash
# Show help
inkray-cli help

# Show wallet info
inkray-cli wallet info

# Request testnet faucet
inkray-cli wallet faucet
```

### Deployment

```bash
# Deploy all smart contracts
inkray-cli deploy contracts

# Verify deployment
inkray-cli deploy verify

# Generate verification report
inkray-cli deploy verify --report
```

### Storage Operations

```bash
# Upload file to Walrus
inkray-cli storage upload ./myfile.txt

# Upload with custom storage duration
inkray-cli storage upload ./myfile.txt --epochs 10

# Download blob by ID
inkray-cli storage download <blobId> --output ./downloaded.txt

# Download as text
inkray-cli storage download <blobId> --text
```

### Content Management

```bash
# Publish free article
inkray-cli content publish ./article.md \\
  --title "My Article" \\
  --summary "Article summary"

# Publish paid article (encrypted)
inkray-cli content publish ./premium.md \\
  --title "Premium Content" \\
  --summary "Exclusive content" \\
  --paid

# Publish to specific publication
inkray-cli content publish ./article.md \\
  --title "Team Article" \\
  --summary "Team content" \\
  --publication <publicationId>
```

### Subscriptions & NFTs

```bash
# Create platform subscription
inkray-cli subscription create --duration 30 --tier 1

# Mint article NFT
inkray-cli nft mint <articleId> --royalty 15
```

### Testing & Utilities

```bash
# Test upload/download functionality
inkray-cli util test-upload

# Generate test data
inkray-cli util generate-test-data

# Run with verbose logging
inkray-cli --verbose <command>

# Use different network
inkray-cli --network testnet <command>
```

## 📚 SDK Usage (Programmatic)

### Basic Setup

```typescript
import { 
  createSuiClient, 
  createWalrusClient, 
  createSealClient 
} from 'inkray-sdk';

// Initialize clients
const suiClient = createSuiClient({
  network: 'testnet',
  mnemonic: process.env.ADMIN_MNEMONIC
});

const walrusClient = createWalrusClient();
const sealClient = createSealClient();
```

### File Upload & Storage

```typescript
import { uploadFile, downloadBlob } from 'inkray-sdk/storage';

// Upload file to Walrus
const result = await uploadFile('./myfile.txt', {
  epochs: 5,
  deletable: false
});

console.log(`Uploaded: ${result.blobId}`);

// Download file
const downloaded = await downloadBlob(result.blobId, {
  outputPath: './downloaded.txt'
});
```

### Smart Contract Interactions

```typescript
import { deployContracts, verifyDeployment } from 'inkray-sdk/deployment';

// Deploy contracts
const deployment = await deployContracts({
  network: 'testnet',
  contractPath: '../'
});

// Verify deployment
const isValid = await verifyDeployment({
  network: 'testnet',
  contractPath: '../'
});
```

### Content Publishing Workflow

```typescript
import { 
  uploadFile, 
  createPublication, 
  publishArticle 
} from 'inkray-sdk';

// 1. Upload content to Walrus
const uploadResult = await uploadFile('./article.md');

// 2. Create publication (if needed)
const publication = await createPublication({
  name: 'My Blog',
  description: 'Personal blog'
});

// 3. Publish article
const article = await publishArticle({
  publicationId: publication.id,
  title: 'My Article',
  summary: 'Article summary',
  blobId: uploadResult.blobId,
  isPaid: false
});
```

### Encryption with Seal

```typescript
import { encryptContent, createSubscriptionPolicy } from 'inkray-sdk/encryption';

// Create access policy
const policy = await createSubscriptionPolicy({
  platformServiceId: '<serviceId>',
  subscriptionDuration: 30
});

// Encrypt content
const encrypted = await encryptContent('./premium-article.md', {
  policy: 'subscription',
  policyObjectId: policy
});

// Upload encrypted content
const result = await uploadBuffer(encrypted, 'encrypted-article.dat');
```

## 🏗️ Architecture

### SDK Structure

```
src/
├── config/           # Network and contract configurations
├── utils/            # Client utilities and types
├── deployment/       # Contract deployment scripts
├── storage/          # Walrus upload/download
├── encryption/       # Seal encryption utilities
├── interactions/     # Smart contract interactions
├── workflows/        # Complete user workflows
└── examples/         # Usage examples
```

### Key Components

1. **Sui Client**: Smart contract interactions and transaction building
2. **Walrus Client**: Decentralized storage operations
3. **Seal Client**: Access-controlled encryption
4. **Transaction Builder**: Programmable transaction blocks
5. **Deployment Manager**: Contract deployment and verification

### Integration Flow

```
Frontend App
     ↓
TypeScript SDK
     ↓
┌─────────────┬─────────────┬─────────────┐
│ Sui Network │   Walrus    │    Seal     │
│ (Contracts) │ (Storage)   │ (Encryption)│
└─────────────┴─────────────┴─────────────┘
```

## 🔐 Security Considerations

### Private Key Management

- Never commit private keys to version control
- Use mnemonics for development
- Consider hardware wallets for production
- Rotate keys regularly

### Access Control

- Verify contributor permissions before publishing
- Implement proper access policies for encrypted content
- Monitor subscription and NFT access patterns
- Use time-limited access where appropriate

### Content Encryption

- Client-side encryption for paid content
- Identity-based encryption with Seal
- Proper key derivation and storage
- Access policy validation

## 🧪 Testing

### Unit Tests

```bash
npm test
```

### Integration Tests

```bash
# Test full workflow
npm run demo:creator
npm run demo:reader
npm run demo:platform
```

### Manual Testing

```bash
# Test deployment
inkray-cli deploy contracts
inkray-cli deploy verify

# Test storage
inkray-cli util test-upload

# Test content flow
echo "Test content" > test.txt
inkray-cli content publish test.txt -t "Test" -s "Test article"
```

## 📖 API Reference

### Core Functions

- `createSuiClient(config)` - Initialize Sui client
- `createWalrusClient(config)` - Initialize Walrus client  
- `createSealClient(config)` - Initialize Seal client
- `deployContracts(options)` - Deploy smart contracts
- `verifyDeployment(options)` - Verify deployment

### Storage Functions

- `uploadFile(path, options)` - Upload file to Walrus
- `downloadBlob(blobId, options)` - Download from Walrus
- `uploadText(text, filename)` - Upload text content
- `uploadJSON(data, filename)` - Upload JSON data

### Contract Interactions

- `createPublication(params)` - Create new publication
- `addContributor(publicationId, contributor)` - Add contributor
- `publishArticle(params)` - Publish article with blob storage
- `mintArticleNFT(articleId, options)` - Mint article as NFT
- `createSubscription(duration, tier)` - Create platform subscription

## 🚨 Troubleshooting

### Common Issues

1. **"Insufficient gas"**
   - Check SUI balance: `inkray-cli wallet info`
   - Request faucet: `inkray-cli wallet faucet`

2. **"Package not found"**
   - Deploy contracts: `inkray-cli deploy contracts`
   - Update .env with package IDs

3. **"Network connection failed"**
   - Check network configuration in .env
   - Verify RPC endpoint availability

4. **"Private key invalid"**
   - Check private key/mnemonic format
   - Ensure proper environment variables

### Debug Mode

```bash
# Enable verbose logging
LOG_LEVEL=debug inkray-cli <command>

# Or use CLI flag
inkray-cli --verbose <command>
```

### Getting Help

- Check the CLI help: `inkray-cli help`
- Review error messages carefully
- Enable verbose logging for detailed info
- Check network status and RPC endpoints

## 🛣️ Roadmap

### Current Features ✅

- Complete SDK structure and CLI
- Sui smart contract integration
- Walrus storage operations
- Seal encryption framework
- Contract deployment and verification
- Comprehensive testing utilities

### Coming Soon 🔄

- Smart contract interaction implementations
- Complete Seal encryption integration
- Advanced workflow examples
- Frontend integration guides
- Production deployment tools

### Future Enhancements 🎯

- GraphQL API integration
- Real-time event monitoring
- Advanced access control policies
- Content recommendation engine
- Multi-chain support

## 📄 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`  
5. Open pull request

## 📞 Support

- GitHub Issues: Report bugs and request features
- Documentation: Check README and code comments
- Community: Join discussions in project channels