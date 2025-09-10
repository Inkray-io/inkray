/// Comprehensive event system for Inkray decentralized blogging platform.
///
/// This module defines all events emitted by the platform for off-chain indexing,
/// analytics, and user interface updates.
module contracts::inkray_events;

use std::string::String;

// === Publication Management Events ===

/// Emitted when a new publication is created
public struct PublicationCreated has copy, drop {
    publication: ID,    // Publication object ID
    owner: address,     // Owner address
    name: String,       // Publication name
    vault_id: ID,      // Associated vault ID
}

/// Emitted when a contributor is added to a publication
public struct ContributorAdded has copy, drop {
    publication: ID,    // Publication object ID
    addr: address,      // Contributor address
    added_by: address,  // Address that added the contributor (owner)
}

/// Emitted when a contributor is removed from a publication
public struct ContributorRemoved has copy, drop {
    publication: ID,    // Publication object ID
    addr: address,      // Contributor address removed
    removed_by: address, // Address that removed the contributor (owner)
}

// === Article Publishing Events ===

/// Emitted when a new article is published
public struct ArticlePosted has copy, drop {
    publication: address,  // Publication address (legacy format)
    article: address,     // Article address
    author: address,      // Article author
    title: String,        // Article title
    gating: u8,          // 0 = Free, 1 = Gated
    asset_count: u64,    // Total number of blobs (body + assets)
}

// === Vault Storage Events ===

/// Emitted when a blob is stored in a vault
public struct BlobStored has copy, drop {
    vault_id: ID,        // Vault object ID
    publication_id: ID,  // Publication object ID
    blob_id: ID,         // Blob object ID
    stored_by: address,  // Address that stored the blob
}

/// Emitted when a blob is removed from a vault
public struct BlobRemoved has copy, drop {
    vault_id: ID,        // Vault object ID
    publication_id: ID,  // Publication object ID
    blob_id: ID,         // Blob object ID
    removed_by: address, // Address that removed the blob
}

public struct RenewIntent has copy, drop {
    publication: ID,
    vault: address,
    batch_start: u64,
    batch_len: u64,
}

// === Subscription Events ===
public struct SubscriptionMinted has copy, drop {
    user: address,
    subscription_id: address,
    plan: u8,
    expires_ms: u64,
}

public struct SubscriptionExtended has copy, drop {
    user: address,
    subscription_id: address,
    old_expires_ms: u64,
    new_expires_ms: u64,
}

// === NFT Events ===
public struct ArticleNftMinted has copy, drop {
    article: address,
    nft_id: address,
    to: address,
    price_paid: u64,
}

// === Event Emission Functions ===
public fun emit_publication_created(publication: ID, owner: address, name: String, vault_id: ID) {
    sui::event::emit(PublicationCreated {
        publication,
        owner,
        name,
        vault_id,
    });
}

public fun emit_contributor_added(publication: ID, addr: address, added_by: address) {
    sui::event::emit(ContributorAdded {
        publication,
        addr,
        added_by,
    });
}

public fun emit_contributor_removed(publication: ID, addr: address, removed_by: address) {
    sui::event::emit(ContributorRemoved {
        publication,
        addr,
        removed_by,
    });
}

public fun emit_article_posted(
    publication: address,
    article: address,
    author: address,
    title: String,
    gating: u8,
    asset_count: u64,
) {
    sui::event::emit(ArticlePosted {
        publication,
        article,
        author,
        title,
        gating,
        asset_count,
    });
}

public fun emit_blob_stored(
    vault_id: ID,
    publication_id: ID,
    blob_id: ID,
    stored_by: address,
) {
    sui::event::emit(BlobStored {
        vault_id,
        publication_id,
        blob_id,
        stored_by,
    });
}

public fun emit_blob_removed(
    vault_id: ID,
    publication_id: ID,
    blob_id: ID,
    removed_by: address,
) {
    sui::event::emit(BlobRemoved {
        vault_id,
        publication_id,
        blob_id,
        removed_by,
    });
}

public fun emit_renew_intent(
    publication: ID,
    vault: address,
    batch_start: u64,
    batch_len: u64,
) {
    sui::event::emit(RenewIntent {
        publication,
        vault,
        batch_start,
        batch_len,
    });
}

public fun emit_subscription_minted(
    user: address,
    subscription_id: address,
    plan: u8,
    expires_ms: u64,
) {
    sui::event::emit(SubscriptionMinted {
        user,
        subscription_id,
        plan,
        expires_ms,
    });
}

public fun emit_subscription_extended(
    user: address,
    subscription_id: address,
    old_expires_ms: u64,
    new_expires_ms: u64,
) {
    sui::event::emit(SubscriptionExtended {
        user,
        subscription_id,
        old_expires_ms,
        new_expires_ms,
    });
}

public fun emit_article_nft_minted(
    article: address,
    nft_id: address,
    to: address,
    price_paid: u64,
) {
    sui::event::emit(ArticleNftMinted {
        article,
        nft_id,
        to,
        price_paid,
    });
}
