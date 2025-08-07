# Seal Implementation Guide - PublicationOwnerCap Integration

## 🎉 Implementation Status: **FULLY WORKING**

This guide documents the complete implementation of Mysten Labs Seal Identity-Based Encryption (IBE) integration with Inkray's PublicationOwnerCap system. **The system is working end-to-end with real Seal encryption/decryption on testnet.**

## Quick Start - Working Example

### ✅ Successful Decryption Test Results
```
🔓 Simple Decryption Test

📥 Step 1: Loading encrypted blob
✅ Loaded 386 bytes
🔍 Step 2: Extracting content ID
  Found: article_premium_article_1754574323028
🔑 Step 3: Setting up owner credentials
  Publication: 0xd10c90aa...
  Package: 0xa462e605...
  Owner Cap: 0xaffa4db0...
🔓 Step 4: Attempting decryption
👑 Trying publication owner access...
✅ Decrypted with publication owner access
  ✅ Success with variant 1!

📊 Results:
✅ DECRYPTION SUCCESSFUL!
Used content ID: 0x61727469636c655f7072656d69756d5f61727469636c655f31373534353734333233303238
Decrypted size: 33 bytes

📄 Decrypted Content:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Custom premium article content...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Architecture Overview

### Core Concept: Content-Identity Based Encryption
- **Encrypt once** with a unique content-specific identity
- **Decrypt multiple ways** using different access policies
- **PublicationOwnerCap** provides the cleanest, most direct access method

### Access Methods (Priority Order)
1. 🏆 **PublicationOwnerCap** - Direct owner access (IMPLEMENTED ✅)
2. **Platform Subscription** - Time-based access to all content
3. **Article NFT** - Permanent access through ownership
4. **Publication Contributor** - Access for authorized contributors  
5. **Allowlist** - Explicit permission-based access

## Smart Contract Implementation

### 1. Seal Content Policy Module

**File**: `sources/seal_content_policy.move`

#### Key Function: `seal_approve_publication_owner`
```move
// Seal approval for publication owner using owner cap
entry fun seal_approve_publication_owner(
    _id: vector<u8>,
    owner_cap: &PublicationOwnerCap,
    publication: &Publication,
    _ctx: &TxContext
) {
    // Verify the owner cap matches the publication
    assert!(
        publication::get_publication_id(owner_cap) == object::id(publication),
        E_NO_ACCESS
    );
}
```

**Why This Works:**
- ✅ **Direct Validation**: No need for separate content policies
- ✅ **OwnerCap Pattern**: Leverages Sui's capability security model
- ✅ **Clean Architecture**: Simple assertion that owner cap matches publication
- ✅ **Seal Integration**: Seamlessly integrates with Mysten Labs Seal key servers

### 2. Contract Deployment

**Current Package**: `0xa462e6057d02479109cab6e926b12a61f3dd9a459a2f79206ea42f52dde4ac2a`

**Key Objects**:
- Publication: `0xd10c90aa4626553a948070c3710b7929c7ef6d8719d781ff47df87e73ecd16ee`
- Owner Cap: `0xaffa4db02488f54509f7ac2bb48c907c423d14268c79bd3558ce6be6191d835d`
- Vault: `0x40bc98a79c551d226e647cc611a3cde16145ce2b42f24d9be0d956d164c904c7`

## Client Implementation

### 1. UserCredentials Type Extension

**File**: `src/utils/types.ts`

```typescript
export interface UserCredentials {
  // 🎯 NEW: Publication owner credentials (highest priority)
  publicationOwner?: {
    ownerCapId: string;      // PublicationOwnerCap object ID
    publicationId: string;   // Publication object ID
  };
  
  // Fallback credentials
  subscription?: { id: string; serviceId: string; };
  nft?: { id: string; articleId: string; };
  contributor?: { publicationId: string; contentPolicyId: string; };
  allowlist?: { contentPolicyId: string; };
}
```

### 2. Seal Client Integration

**File**: `src/utils/seal-client.ts`

#### Key Method: `tryDecryptWithPublicationOwner`
```typescript
private async tryDecryptWithPublicationOwner(
  encryptedData: Uint8Array,
  contentId: string,
  publicationOwner: NonNullable<UserCredentials['publicationOwner']>,
  packageId: string
): Promise<Uint8Array> {
  // 1. Create Seal session key
  const sessionKey = await SessionKey.create({
    address: suiClient.getAddress(),
    packageId,
    ttlMin: 10,
    suiClient: compatibleSuiClient,
  });

  // 2. Build approval transaction
  const tx = new Transaction();
  
  // 🔑 CRITICAL: Proper content ID encoding
  let contentIdBytes: number[];
  if (contentId.startsWith('0x')) {
    // Hex string to bytes
    const hexStr = contentId.substring(2);
    contentIdBytes = [];
    for (let i = 0; i < hexStr.length; i += 2) {
      contentIdBytes.push(parseInt(hexStr.substring(i, i + 2), 16));
    }
  } else {
    // String to UTF-8 bytes
    contentIdBytes = Array.from(new TextEncoder().encode(contentId));
  }
  
  tx.moveCall({
    target: `${packageId}::seal_content_policy::seal_approve_publication_owner`,
    arguments: [
      tx.pure.vector('u8', contentIdBytes),
      tx.object(publicationOwner.ownerCapId),
      tx.object(publicationOwner.publicationId),
    ]
  });

  // 3. Build transaction bytes
  const txBytes = await tx.build({ 
    client: suiClient.getClient(), 
    onlyTransactionKind: true 
  });

  // 4. Decrypt with Seal
  const decrypted = await sealClient.decrypt({
    data: encryptedData,
    sessionKey,
    txBytes,
  });
  
  return decrypted;
}
```

## Binary Data Handling - CRITICAL

### ❌ The Problem That Was Fixed
**Initial Issue**: Encrypted content was being corrupted when uploaded as text:
```typescript
// ❌ WRONG - corrupts binary data
const uploadResult = await uploadText(
  Array.from(encryptedContent).map(b => String.fromCharCode(b)).join(''),
  'premium-strategy-encrypted.dat'
);
```

### ✅ The Solution
**Fixed Implementation**: Upload as proper binary data:
```typescript
// ✅ CORRECT - preserves binary integrity
const uploadResult = await uploadBuffer(
  encryptedContent,  // Uint8Array
  'premium-strategy-encrypted.dat',
  { epochs: 10 }
);
```

**Evidence of Fix**:
- **Before**: 556 bytes (corrupted UTF-8 encoding)
- **After**: 386 bytes (proper binary data)
- **Result**: Seal library can parse the blob structure correctly

## Working End-to-End Workflow

### 1. Content Encryption (Creator Journey)
```typescript
// Step 1: Generate hex-encoded content ID
const contentId = sealClient.generateArticleContentId(`premium_article_${Date.now()}`);
// Result: "0x61727469636c655f7072656d69756d5f61727469636c655f31373534..."

// Step 2: Encrypt content
const encryptedContent = await sealClient.encryptContent(contentBuffer, {
  contentId: contentId,
  packageId: process.env.PACKAGE_ID,
  threshold: 2
});

// Step 3: Upload as binary to Walrus
const uploadResult = await uploadBuffer(
  encryptedContent,
  'premium-strategy-encrypted.dat',
  { epochs: 10 }
);
```

### 2. Content Decryption (Publication Owner)
```typescript
// Step 1: Download encrypted blob from Walrus
const encryptedBlob = await downloadBinaryBlob(walrusBlobId);

// Step 2: Extract content ID from blob (embedded during encryption)
const blobText = new TextDecoder('utf-8', { fatal: false }).decode(encryptedBlob);
const contentIdMatch = blobText.match(/article_premium_article_(\d+)/);
const extractedContentId = contentIdMatch[0]; // "article_premium_article_1754574323028"

// Step 3: Convert to hex-encoded content ID
const hexContentId = sealClient.generateArticleContentId(extractedContentId.replace('article_', ''));

// Step 4: Set up publication owner credentials
const ownerCredentials: UserCredentials = {
  publicationOwner: {
    ownerCapId: process.env.TEST_OWNER_CAP_ID,
    publicationId: process.env.TEST_PUBLICATION_ID, // MUST match owner cap's publication_id!
  }
};

// Step 5: Decrypt content
const decrypted = await sealClient.decryptContent({
  encryptedData: encryptedBlob,
  contentId: hexContentId,
  credentials: ownerCredentials,
  packageId: process.env.PACKAGE_ID
});

// Step 6: Read decrypted content
const content = new TextDecoder().decode(decrypted);
console.log('Success!', content); // "Custom premium article content..."
```

## Common Issues & Solutions

### Issue 1: "Deserialization error: invalid length 66"
**Problem**: Content ID not properly encoded as bytes
**Solution**: Convert hex strings to byte arrays in the transaction

### Issue 2: "User does not have access to one or more of the requested keys"  
**Problem**: Publication ID mismatch between owner cap and function call
**Solution**: Use the correct publication ID from the owner cap's `publication_id` field

### Issue 3: "Offset is outside the bounds of the DataView"
**Problem**: Encrypted blob corrupted by text encoding
**Solution**: Upload/download encrypted content as binary data, not text

### Issue 4: Transaction building fails
**Problem**: Object IDs don't match or objects don't exist
**Solution**: Verify all object IDs are correct and exist on-chain

## Testing

### Simple Decryption Test
**File**: `src/simple-decrypt-test.ts`

```bash
# Run the working test
npx tsx src/simple-decrypt-test.ts

# Expected output: ✅ DECRYPTION SUCCESSFUL!
```

### Creator Journey Test
```bash
# Generate new encrypted content and test objects
npm run demo:creator

# This will:
# 1. Create publication and owner cap
# 2. Encrypt content with Seal
# 3. Upload as binary to Walrus
# 4. Test owner decryption
```

## Production Deployment Checklist

- [x] Smart contract deployed with `seal_approve_publication_owner` function
- [x] Binary blob handling implemented correctly  
- [x] Content ID hex encoding working
- [x] Publication owner credentials integrated
- [x] End-to-end encryption/decryption tested
- [x] Real Seal key server integration verified
- [ ] Frontend integration with credential management
- [ ] Multiple access method fallback chain implementation
- [ ] Production environment configuration

## Key Implementation Insights

### 1. The PublicationOwnerCap Advantage
- **No Content Policies Required**: Direct capability-based access
- **Cleaner Architecture**: One assertion instead of complex policy management
- **Better Security**: Leverages Sui's capability security model
- **Easier Testing**: Simpler object relationships

### 2. Binary Data is Critical
- **Seal expects binary**: Text encoding corrupts the encryption headers
- **Walrus supports binary**: Use `uploadBuffer()` not `uploadText()`
- **Size matters**: Binary encoding is more efficient (386 vs 556 bytes)

### 3. Content-Identity Encryption
- **Hex encoding required**: Seal IBE needs hex-encoded content identities
- **Embedded content IDs**: Content IDs are embedded in the encrypted blob
- **Consistent encoding**: Same encoding method for encryption and decryption

### 4. Object ID Relationships
- **Owner cap points to publication**: `owner_cap.publication_id` must match `object::id(publication)`
- **Vault is separate**: Don't confuse vault ID with publication ID
- **Verification matters**: Always check object relationships on-chain

## Conclusion

🎉 **The PublicationOwnerCap-based Seal integration is fully implemented and working!**

This implementation provides the cleanest and most direct method for publication owners to decrypt their encrypted content, leveraging Sui's capability security model and Mysten Labs' Seal Identity-Based Encryption system.

The system successfully demonstrates:
- ✅ Real IBE encryption/decryption with Seal key servers
- ✅ Binary encrypted content storage on Walrus
- ✅ Smart contract capability-based access control
- ✅ End-to-end content-identity based encryption workflow

Next steps involve implementing the remaining access methods (subscription, NFT, contributor, allowlist) and building the frontend credential management system.