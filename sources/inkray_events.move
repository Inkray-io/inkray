module contracts::inkray_events;

use std::string::String;

// === Publication Events ===
public struct PublicationCreated has copy, drop {
    publication: ID,
    owner: address,
    name: String,
    vault_id: ID,
}

public struct ContributorAdded has copy, drop {
    publication: ID,
    addr: address,
    added_by: address,
}

public struct ContributorRemoved has copy, drop {
    publication: ID,
    addr: address,
    removed_by: address,
}

// === Article Events ===
public struct ArticlePosted has copy, drop {
    publication: address,
    article: address,
    author: address,
    title: String,
    gating: u8, // 0 = Free, 1 = Gated
    asset_count: u64,
}

// === Vault Events ===
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
