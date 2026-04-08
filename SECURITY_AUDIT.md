# Inkray Smart Contract Security Audit Report

**Date**: 2026-04-08  
**Scope**: All Sui Move smart contracts in `sources/`  
**Auditor**: Automated security review  

---

## Executive Summary

A comprehensive security audit of the Inkray decentralized blogging platform's Sui Move smart contracts identified **17 issues** across 8 contract modules. The most severe findings involve **Seal policy bypass vulnerabilities** that allow unauthorized decryption of premium content, **user fund loss** through subscription overpayment, and **author impersonation** via the platform posting capability.

| Severity | Count |
|----------|-------|
| Critical | 4     |
| High     | 4     |
| Medium   | 4     |
| Low      | 5     |

---

## Critical Findings

### C-01: Seal NFT Approval Does Not Verify NFT-Article Binding

**File**: `sources/policy.move:60-64`  
**Impact**: Any NFT holder can decrypt any gated article  

**Description**:  
`seal_approve_nft()` accepts any `ArticleAccessNft` without verifying its `article_id` matches the content being decrypted. The NFT parameter is prefixed with `_` (unused), and the existing helper `nft::nft_matches_article()` is never called.

```move
public fun seal_approve_nft(id: vector<u8>, _access_nft: &ArticleAccessNft) {
    let _p = parse_id_v1(&id);
    // No verification that NFT's article_id matches content ID
}
```

**Steps to Reproduce**:
1. Mint an NFT for any free/cheap article (Article A)
2. Call `seal_approve_nft(content_id_of_premium_article_B, nft_for_article_A)`
3. Seal key server releases decryption key for Article B's content
4. Attacker decrypts premium content they never paid for

**Fix**:
```move
public fun seal_approve_nft(id: vector<u8>, article: &Article, access_nft: &ArticleAccessNft) {
    let p = parse_id_v1(&id);
    // Verify NFT is bound to the correct article
    assert!(nft::nft_matches_article(access_nft, articles::get_article_id(article)), E_ACCESS_DENIED);
    // Verify article belongs to the publication in the content ID
    assert!(articles::get_publication_address(article) == p.publication, E_BAD_ID);
}
```

---

### C-02: Seal Composite Approval Allows Cross-Publication Article Confusion

**File**: `sources/policy.move:84-99`  
**Impact**: Bypass gating on any publication's premium content using a free article from a different publication  

**Description**:  
`seal_approve_any()` validates the content ID's publication field against the `publication` parameter, but never verifies the `article` parameter belongs to that publication. An attacker can pass a free article from Publication A to bypass gating on Publication B.

```move
public fun seal_approve_any(
    id: vector<u8>,
    publication: &Publication,
    article: &Article,
    ctx: &TxContext,
) {
    let p = parse_id_v1(&id);
    assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);

    // BUG: No check that article belongs to publication
    if (articles::is_free_content(article)) return; // Early return with unrelated free article
    // ...
}
```

**Steps to Reproduce**:
1. Find any free article from any publication on the platform
2. Construct a content ID targeting a premium article in Publication X
3. Call `seal_approve_any(content_id_for_pub_X, pub_X, free_article_from_pub_Y, ctx)`
4. Function returns early at line 95 because the free article passes `is_free_content()`
5. Seal key server releases decryption key for the premium article

**Fix**:
```move
// Add after the publication ID check:
assert!(
    articles::get_publication_id(article) == publication::get_publication_object_id(publication),
    E_BAD_ID,
);
```

---

### C-03: Subscription Payments Not Refunded on Overpayment

**File**: `sources/subscription.move:68-86, 111-117, 140-147`  
**Impact**: Direct loss of user funds  

**Description**:  
In `mint_platform()`, `extend()`, and `renew()`, the code asserts the payment is `>= required_fee` but transfers the **entire coin** to the admin. If a user sends 100 SUI when 5 SUI is required, the admin receives all 100 SUI with no refund.

```move
// Line 68: Only checks minimum
assert!(coin::value(&payment) >= required_fee, E_INSUFFICIENT_PAYMENT);
// ...
// Line 86: Transfers ENTIRE coin, not just the required amount
transfer::public_transfer(payment, service.admin);
```

**Steps to Reproduce**:
1. Call `mint_platform()` with a 50 SUI coin when basic plan costs 5 SUI
2. Admin receives 50 SUI instead of 5 SUI
3. User loses 45 SUI with no recovery mechanism

**Fix**:
```move
let required_fee = *vector::borrow(&service.monthly_fees, (plan as u64));
let paid = coin::value(&payment);
assert!(paid >= required_fee, E_INSUFFICIENT_PAYMENT);

// Split exact amount and refund excess
if (paid > required_fee) {
    let refund = coin::split(&mut payment, paid - required_fee, ctx);
    transfer::public_transfer(refund, tx_context::sender(ctx));
};
transfer::public_transfer(payment, service.admin);
```

Apply this pattern to all three functions: `mint_platform()`, `extend()`, `renew()`.

---

### C-04: PostArticleCap Allows Arbitrary Author Impersonation

**File**: `sources/articles.move:84-95`  
**Impact**: Platform operator can forge authorship of any article as any address  

**Description**:  
`post_with_cap()` bypasses all contributor/owner authorization and accepts an arbitrary `author` address parameter. The cap holder can post articles to any publication claiming authorship from any address.

```move
public fun post_with_cap(
    _cap: &PostArticleCap,
    publication: &Publication,
    vault: &mut PublicationVault,
    title: String,
    gating: Access,
    body_blob: walrus::blob::Blob,
    author: address,         // <-- Arbitrary, unvalidated address
    ctx: &mut TxContext,
): Article {
    post_internal(publication, vault, title, gating, body_blob, author, ctx)
}
```

**Steps to Reproduce**:
1. Acquire `PostArticleCap` (given to deployer in `init()`)
2. Call `post_with_cap(cap, any_publication, vault, title, gating, blob, victim_address, ctx)`
3. Article is created with `victim_address` as the author
4. On-chain record permanently attributes content to the wrong person

**Fix**: Either enforce that `author` is the tx sender, or validate `author` is a contributor:
```move
public fun post_with_cap(
    _cap: &PostArticleCap,
    publication: &Publication,
    vault: &mut PublicationVault,
    title: String,
    gating: Access,
    body_blob: walrus::blob::Blob,
    author: address,
    ctx: &mut TxContext,
): Article {
    // At minimum, verify author is a contributor or owner
    assert!(publication::is_contributor(publication, author), E_NOT_AUTHORIZED);
    post_internal(publication, vault, title, gating, body_blob, author, ctx)
}
```

---

## High Findings

### H-01: NFT Mint Pricing Completely Bypassed

**File**: `sources/nft.move:81-91`  
**Impact**: Revenue model broken; MintConfig is non-functional  

**Description**:  
The `mint()` function accepts `_config: &MintConfig` (unused — note underscore prefix) and immediately returns the full payment to the sender. The `MintConfig.base_price` and `MintConfig.platform_fee_percent` fields have no effect, even if updated via `update_mint_config()`.

```move
public fun mint(
    recipient: address,
    article: &Article,
    _config: &MintConfig,      // <-- Unused
    payment: Coin<SUI>,
    ctx: &mut TxContext,
): ArticleAccessNft {
    // NFT minting is now free - return payment to sender
    transfer::public_transfer(payment, tx_context::sender(ctx));
    // ...
}
```

**Impact**: The `update_mint_config()` admin function provides a false sense of control. Setting prices has zero effect on actual minting behavior.

**Fix**: Either enforce pricing from the config, or remove the payment parameter and config reference entirely to avoid confusion.

---

### H-02: Subscription Extend on Expired Subscription Results in Wasted Payment

**File**: `sources/subscription.move:99-126`  
**Impact**: User pays for extension but subscription remains expired  

**Description**:  
`extend()` adds `duration_ms` to the **old** `expires_ms` regardless of current time. The `_clock` parameter is unused (underscore prefix). If a subscription expired long ago, the new expiry may still be in the past.

```move
public fun extend(
    subscription: &mut Subscription,
    service: &PlatformService,
    payment: Coin<SUI>,
    _clock: &Clock,        // <-- UNUSED! Current time never checked
    ctx: &TxContext
) {
    // ...
    subscription.expires_ms = subscription.expires_ms + service.duration_ms;
    transfer::public_transfer(payment, service.admin);
}
```

**Steps to Reproduce**:
1. Subscription expires at timestamp 1000
2. Current time is 5000
3. `duration_ms` is 2592000000 (30 days)
4. After `extend()`: `expires_ms = 1000 + 2592000000 = 2592001000`
5. If current time > 2592001000, subscription is still expired
6. User paid full fee but got nothing

More realistically: subscription expired 60 days ago, user extends for 30 days, new expiry is 30 days in the past. User wasted their money.

**Fix**:
```move
public fun extend(
    subscription: &mut Subscription,
    service: &PlatformService,
    payment: Coin<SUI>,
    clock: &Clock,
    ctx: &TxContext
) {
    // ...
    let current_time = clock::timestamp_ms(clock);
    // Extend from current time if expired, else from expiry
    let base_time = if (current_time > subscription.expires_ms) {
        current_time
    } else {
        subscription.expires_ms
    };
    subscription.expires_ms = base_time + service.duration_ms;
    // ...
}
```

---

### H-03: Immutable Admin Keys With No Transfer/Recovery Mechanism

**Files**: `sources/nft.move:27-31,70` and `sources/subscription.move:30-35,47`  
**Impact**: Platform becomes permanently unmanageable if admin key is lost or compromised  

**Description**:  
Both `MintConfig` and `PlatformService` store an `admin` address set at deployment time with no function to rotate or transfer admin privileges.

```move
// nft.move
public struct MintConfig has key, store {
    id: UID,
    base_price: u64,
    platform_fee_percent: u8,
    admin: address, // Immutable after init()
}

// subscription.move
public struct PlatformService has key, store {
    id: UID,
    monthly_fees: vector<u64>,
    duration_ms: u64,
    admin: address, // Immutable after init()
}
```

**Fix**: Add admin transfer functions to both modules:
```move
public fun transfer_admin(config: &mut MintConfig, new_admin: address, ctx: &TxContext) {
    assert!(tx_context::sender(ctx) == config.admin, E_NOT_ADMIN);
    config.admin = new_admin;
}
```

---

### H-04: Public Event Emission Functions Allow Fake Event Injection

**File**: `sources/inkray_events.move:113-269`  
**Impact**: External contracts can emit spoofed Inkray events, poisoning off-chain indexers  

**Description**:  
All 11 event emission functions use `public` visibility instead of `public(package)`. Any external module can call these functions to emit fake `PublicationCreated`, `ArticlePosted`, `ArticleNftMinted`, etc. events.

```move
// All functions have this pattern:
public fun emit_publication_created(...) { sui::event::emit(...); }
public fun emit_contributor_added(...) { sui::event::emit(...); }
public fun emit_article_posted(...) { sui::event::emit(...); }
// ... 8 more public functions
```

**Impact**: Off-chain indexers and UIs that trust these events will display fabricated data. Attackers can fake publication creation, article posting, NFT minting, and tipping events.

**Fix**: Change all emission functions to `public(package)`:
```move
public(package) fun emit_publication_created(...) { ... }
public(package) fun emit_contributor_added(...) { ... }
// ... etc.
```

---

## Medium Findings

### M-01: seal_approve_roles Excludes Publication Owner

**File**: `sources/policy.move:67-74`  
**Impact**: Publication owner locked out of role-based Seal decryption unless also added as contributor  

**Description**:  
`seal_approve_roles()` only checks `is_contributor()`. If the publication owner didn't add themselves as a contributor, they cannot use the roles-based decryption path. The function has no access to `PublicationOwnerCap` for ownership verification.

```move
public fun seal_approve_roles(id: vector<u8>, publication: &Publication, ctx: &TxContext) {
    let p = parse_id_v1(&id);
    assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);
    let who = tx_context::sender(ctx);
    // Only checks contributor, NOT owner
    assert!(publication::is_contributor(publication, who), E_ACCESS_DENIED);
}
```

**Fix**: Add an overload that accepts `PublicationOwnerCap`, or document that owners must add themselves as contributors.

---

### M-02: RenewCap Is Globally Scoped

**File**: `sources/vault.move:29-31, 122-132`  
**Impact**: Single capability controls renewal of all vaults across all publications  

**Description**:  
`RenewCap` has no `publication_id` or `vault_id` field. Any holder can call `renew_all()` on any vault. In a multi-tenant platform, this prevents safe delegation of renewal authority.

```move
public struct RenewCap has key, store {
    id: UID,
    // No scoping field
}
```

**Fix**: Add `publication_id` or `vault_id` to scope the capability, and verify it in `renew_all()`.

---

### M-03: Unbounded Contributors Vector

**File**: `sources/publication.move:24`  
**Impact**: Linear-scan operations become increasingly expensive; potential gas exhaustion  

**Description**:  
`contributors: vector<address>` has no upper bound. Operations like `is_contributor()` perform linear scans. While Sui gas limits provide natural protection, a malicious owner could add hundreds of contributors to increase gas costs for authorization checks on that publication's content.

**Fix**: Add a maximum contributor limit (e.g., 100-200) enforced in `add_contributor()`:
```move
const MAX_CONTRIBUTORS: u64 = 200;
assert!(vector::length(&publication.contributors) < MAX_CONTRIBUTORS, E_TOO_MANY_CONTRIBUTORS);
```

---

### M-04: Zero-Balance Withdrawal Creates Junk Transactions

**File**: `sources/platform_economics.move:96-109`  
**Impact**: Spam vector; creates zero-value Coin objects  

**Description**:  
`withdraw_all_tips()` doesn't check if the balance is zero before splitting. When called on an empty treasury, it creates a zero-value `Coin<SUI>` object, wastes gas, and emits no event.

**Fix**: Add a zero-balance check:
```move
let total_balance = publication::get_tip_balance(publication);
assert!(total_balance > 0, E_INSUFFICIENT_BALANCE);
```

---

## Low Findings

### L-01: Wrong Error Code in update_service

**File**: `sources/subscription.move:167`  
**Impact**: Misleading error messages for debugging  

**Description**:  
`update_service()` uses `E_NOT_SUBSCRIBER` (3) for admin authorization failure instead of a dedicated `E_NOT_ADMIN` constant.

```move
assert!(tx_context::sender(ctx) == service.admin, E_NOT_SUBSCRIBER); // Should be E_NOT_ADMIN
```

**Fix**: Add `const E_NOT_ADMIN: u64 = 4;` and use it.

---

### L-02: Wrong Error Code in update_mint_config

**File**: `sources/nft.move:141`  
**Impact**: Misleading error messages  

**Description**:  
Fee percentage validation uses `E_INVALID_ARTICLE` instead of a dedicated error constant:

```move
assert!(new_platform_fee_percent <= 100, E_INVALID_ARTICLE); // Semantically wrong
```

**Fix**: Add `const E_INVALID_FEE_PERCENT: u64 = 3;` and use it.

---

### L-03: Theoretical Integer Overflow in Tip Counters

**File**: `sources/publication.move:227-228`  
**Impact**: Stats corruption in extreme scenario  

**Description**:  
`total_tips_received` and `total_amount_received` use unchecked `u64` addition. While overflow requires ~18.4 quintillion operations (practically impossible), the pattern lacks defensive programming.

```move
publication.total_tips_received = publication.total_tips_received + 1;
publication.total_amount_received = publication.total_amount_received + amount;
```

**Fix**: Use checked arithmetic or document the assumption that overflow is infeasible.

---

### L-04: seal_approve_free Doesn't Verify Publication Binding

**File**: `sources/policy.move:52-57`  
**Impact**: Low for free content (accessible by design), but demonstrates the pattern flaw  

**Description**:  
The parsed content ID's `publication` field is never compared against the article's actual publication. For free content this is not exploitable since free content is open, but it demonstrates the missing validation pattern.

---

### L-05: No Duration Validation in update_service

**File**: `sources/subscription.move:161-171`  
**Impact**: Admin can accidentally brick subscriptions  

**Description**:  
`update_service()` accepts `new_duration_ms: u64` with no minimum validation. Setting it to 0 makes all new subscriptions expire immediately. The `new_fees` vector is also not validated for length (could break plan indexing).

```move
public fun update_service(
    service: &mut PlatformService,
    new_fees: vector<u64>,
    new_duration_ms: u64,  // No minimum check
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == service.admin, E_NOT_SUBSCRIBER);
    service.monthly_fees = new_fees;      // No length validation
    service.duration_ms = new_duration_ms; // Could be 0
}
```

**Fix**: Add validation:
```move
assert!(new_duration_ms > 0, E_INVALID_DURATION);
assert!(vector::length(&new_fees) > 0, E_INVALID_FEES);
```

---

## Informational Notes

### I-01: Single Point of Failure for PublicationOwnerCap

The `PublicationOwnerCap` is a single object created once per publication. If transferred or lost, the owner loses all administrative control permanently with no recovery. Consider implementing a cap revocation or multi-sig pattern for production.

### I-02: RenewCap Init Sends to Deployer Only

`vault::init()` creates a single `RenewCap` and transfers it to the deployer. There's no way to create additional caps. If lost, vault renewal capability is permanently unavailable.

### I-03: PostArticleCap Init Sends to Deployer Only

Same pattern as RenewCap — single cap, no minting function, no recovery if lost.

### I-04: renew_all is a Stub

`vault::renew_all()` (line 123-132) contains only a TODO comment and event emission. No actual Walrus renewal logic is implemented.

---

## Summary of Recommended Priority Actions

1. **Immediate**: Fix Seal policy functions (C-01, C-02) — these allow unauthorized content decryption
2. **Immediate**: Implement overpayment refund in subscription functions (C-03)
3. **Urgent**: Restrict `post_with_cap` author parameter (C-04)
4. **Urgent**: Fix subscription extend behavior on expired subscriptions (H-02)
5. **Urgent**: Change event functions to `public(package)` (H-04)
6. **Short-term**: Implement admin transfer mechanisms (H-03)
7. **Short-term**: Either enforce NFT pricing or clean up the unused payment flow (H-01)
8. **Ongoing**: Address medium and low findings as part of regular development
