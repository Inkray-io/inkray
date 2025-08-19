# Inkray End-to-End Demo

This document describes how to run the complete end-to-end demonstration of the Inkray decentralized blogging platform.

## Overview

The end-to-end demo demonstrates the complete workflow from publication creation to encrypted content access control:

1. **Publication Creation** - Creator creates a publication with associated vault
2. **Contributor Management** - Reader is added as a contributor to the publication  
3. **Article Encryption** - Article content is encrypted using Seal IBE
4. **Walrus Upload** - Encrypted content is uploaded to decentralized storage
5. **Access Control Testing** - Multiple users attempt decryption to validate security

## Prerequisites

### 1. Environment Setup

Ensure your `.env` file contains all required configuration:

```bash
# Network Configuration
NETWORK=testnet
PACKAGE_ID=0xa462e6057d02479109cab6e926b12a61f3dd9a459a2f79206ea42f52dde4ac2a

# Private Keys for Different Roles
ADMIN_PRIVATE_KEY=suiprivkey1qrl7xym6xa7scu9ylq8gh70d53rqsqcsy2vrpuvhhjnhsshknjmpsknjq3u
CREATOR_PRIVATE_KEY=suiprivkey1qrfv9ax4cuh4e4zaype8mpxeqjug7qz6gtqylyghphm5e0l8hdhazjgf0pw
READER_PRIVATE_KEY=suiprivkey1qzefe5704tlntyvy703c7laln8yfzsqm3ezts4920jjvsrjhvtsegckdyq0
WRONG_READER_PRIVATE_KEY=suiprivkey1qpr5fh5yyac938r8rmackng54m7zyhvcvff77afzqtszjw4shzn32437fu4

# Shared Objects
PLATFORM_SERVICE_ID=0xd6f8890bf47587fb7f1089b6861998bafd2b128b91a32f39d002f759f2d69c71
```

### 2. Dependencies

Install all required dependencies:

```bash
npm install
```

### 3. Smart Contract Deployment

Ensure the smart contracts are deployed on testnet with the `PACKAGE_ID` specified in your `.env` file.

## Running the Demo

### Quick Start

```bash
npm run demo:end-to-end
```

This will execute the complete workflow automatically with colored console output and progress tracking.

### Expected Output

The demo will display:

1. **🔧 Environment Setup** - Validation of configuration and network connectivity
2. **💼 Multi-Wallet Initialization** - Setup of 4 different user roles with balance checking
3. **📰 Publication Creation** - Creator creates publication and adds reader as contributor
4. **📄 Article Upload** - Encryption with Seal, upload to Walrus, metadata storage
5. **🧪 Decryption Tests** - Testing access control with different user credentials
6. **📋 Final Summary** - Complete overview of achievements and next steps

### User Roles Tested

| Role | Description | Expected Access |
|------|-------------|----------------|
| 👨‍💼 **Admin** | Platform administrator | Platform management only |
| ✍️ **Creator** | Publication owner | ✅ Full access (should succeed) |
| 👤 **Reader** | Authorized contributor | ⚠️ Limited access (needs policy setup) |
| 🚫 **Wrong Reader** | Unauthorized user | ❌ No access (should fail) |

## Key Features Demonstrated

### 🔐 Content-Identity Based Encryption
- Single encryption per article with unique hex-encoded content ID
- Multiple access methods can decrypt the same encrypted content
- Seal IBE integration with Mysten Labs key servers

### 🌊 Walrus Integration
- Decentralized blob storage for encrypted content
- Binary data handling for encrypted articles
- Persistent storage across multiple epochs

### 🛡️ Access Control Validation
- Publication owner access using `PublicationOwnerCap`
- Contributor access verification (demo mode)
- Unauthorized access prevention and error handling

### 🏗️ Smart Contract Integration
- Real Sui testnet transactions
- Publication and vault creation
- Event emission for off-chain indexing

## Demo Limitations

### Current Simplifications
- **Article Storage**: Uses simulation mode instead of actual smart contract calls
- **Contributor Policies**: Content policies not fully implemented
- **Real Walrus Blobs**: Uses mock blob creation for demonstration

### Production Requirements
For a production deployment, the following would be needed:

1. **Complete Smart Contract Integration**
   - Actual Walrus blob object creation from blob IDs
   - Full StoredAsset creation and vault storage
   - Real article posting through smart contracts

2. **Content Policy Setup**
   - Contributor access policies for Seal decryption
   - Allowlist management for specific user access
   - Subscription and NFT-based access policies

3. **Backend Integration**
   - API endpoints for Walrus upload management
   - Content ID generation and management
   - User authentication and authorization

## Troubleshooting

### Common Issues

1. **Missing Environment Variables**
   ```
   Error: Missing required environment variables: PACKAGE_ID
   ```
   - Solution: Ensure all required variables are set in `.env`

2. **Network Connectivity Issues**
   ```
   Error: Failed to connect to Sui RPC
   ```
   - Solution: Check `NETWORK` setting and RPC URL configuration

3. **Insufficient Balance**
   ```
   Warning: Balance below minimum
   ```
   - Solution: Demo automatically requests faucet funds

4. **Import Errors**
   ```
   SyntaxError: The requested module does not provide an export
   ```
   - Solution: Run `npm run build` to compile TypeScript

### Gas Configuration

Default gas limits:
- Publication creation: ~0.1 SUI
- Contributor management: ~0.05 SUI  
- Article operations: ~0.2 SUI (simulated)

## Expected Results

### Successful Demo Output
```
🎉 End-to-end demo completed successfully!

📋 Final Demo Summary
===============================================================================
Publication:
  ID: 0x40bc98a79c551d226e647cc611a3cde16145ce2b42f24d9be0d956d164c904c7
  Vault: 0x40bc98a79c551d226e647cc611a3cde16145ce2b42f24d9be0d956d164c904c7
  Creator: 0x123...

Article:
  Content ID: 0x61727469636c655f7072656d69756d5f...
  Blob ID: abc123...
  Size: 15234 → 15456 bytes

Access Control Tests:
  Creator (Owner): ✅ PASS
  Reader (Contributor): ⚠️ EXPECTED FAIL
  Wrong Reader: ✅ EXPECTED FAIL
```

### Security Validation
The demo proves that:
- ✅ Publication owners can decrypt their content
- ❌ Unauthorized users cannot decrypt content
- ⚠️ Contributor access needs proper policy setup

## Next Steps

After running the demo, consider:

1. **Frontend Integration** - Build web interface using the demonstrated workflows
2. **Backend API** - Implement server-side Walrus upload management
3. **Policy Enhancement** - Complete contributor and subscription access policies
4. **Mobile Apps** - Extend workflows to mobile applications
5. **Production Deployment** - Deploy to mainnet with real economic incentives

## Architecture Notes

This demo showcases the Inkray platform's core technical innovation:

- **Single Encrypt, Multi-Decrypt**: Content encrypted once, accessible through multiple credential types
- **Decentralized Storage**: Walrus provides censorship-resistant content distribution
- **Smart Contract Security**: Sui blockchain ensures tamper-proof access control
- **Identity-Based Encryption**: Seal enables sophisticated access policies without key distribution

The combination creates a platform where creators maintain full control over their content while readers enjoy seamless access through multiple authentication methods.