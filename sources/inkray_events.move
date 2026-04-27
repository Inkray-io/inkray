module contracts::inkray_events;

use std::string::String;

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

public struct ArticlePosted has copy, drop {
    publication: ID,
    vault: ID,
    article: ID,
    author: address,
    title: String,
    slug: String,
    gating: u8,
    quilt_id: u256,
    quilt_object_id: ID,
}

public struct ArticleDeleted has copy, drop {
    publication: ID,
    vault: ID,
    article: ID,
    deleted_by: address,
    title: String,
    slug: String,
    body_blob_id: ID,
}

public struct BlobStored has copy, drop {
    vault_id: ID,
    publication_id: ID,
    blob_object_id: ID,
    blob_content_id: u256,
    size: u64,
    end_epoch: u64,
    stored_by: address,
}

public struct BlobRemoved has copy, drop {
    vault_id: ID,
    publication_id: ID,
    blob_object_id: ID,
    blob_content_id: u256,
    removed_by: address,
}

public struct BlobRenewed has copy, drop {
    publication: ID,
    vault: ID,
    blob_id: ID,
    blob_content_id: u256,
    extended_epochs: u32,
    new_expiration_epoch: u64,
    renewed_by: address,
}

public struct PublicationSubscriptionCreated has copy, drop {
    subscription_id: ID,
    publication_id: ID,
    subscriber: address,
    amount_paid: u64,
    expires_at: u64,
}

public struct PublicationSubscriptionExtended has copy, drop {
    subscription_id: ID,
    publication_id: ID,
    subscriber: address,
    amount_paid: u64,
    new_expires_at: u64,
}

public struct PublicationSubscriptionPriceUpdated has copy, drop {
    publication_id: ID,
    old_price: u64,
    new_price: u64,
    updated_by: address,
}

public struct PublicationNameUpdated has copy, drop {
    publication_id: ID,
    old_name: String,
    new_name: String,
    updated_by: address,
}

public struct SubscriptionBalanceWithdrawn has copy, drop {
    publication_id: ID,
    amount: u64,
    withdrawn_by: address,
}

public struct ArticleNftMinted has copy, drop {
    article_id: ID,
    nft_id: address,
    to: address,
    price_paid: u64,
}

public struct PublicationTipped has copy, drop {
    publication_id: ID,
    tipper: address,
    amount: u64,
}

// === Emit Functions ===

public fun emit_publication_created(publication: ID, owner: address, name: String, vault_id: ID) {
    sui::event::emit(PublicationCreated { publication, owner, name, vault_id });
}

public fun emit_contributor_added(publication: ID, addr: address, added_by: address) {
    sui::event::emit(ContributorAdded { publication, addr, added_by });
}

public fun emit_contributor_removed(publication: ID, addr: address, removed_by: address) {
    sui::event::emit(ContributorRemoved { publication, addr, removed_by });
}

public fun emit_article_posted(
    publication: ID, vault: ID, article: ID, author: address,
    title: String, slug: String, gating: u8, quilt_id: u256, quilt_object_id: ID,
) {
    sui::event::emit(ArticlePosted {
        publication, vault, article, author, title, slug, gating, quilt_id, quilt_object_id,
    });
}

public fun emit_article_deleted(
    publication: ID, vault: ID, article: ID, deleted_by: address,
    title: String, slug: String, body_blob_id: ID,
) {
    sui::event::emit(ArticleDeleted {
        publication, vault, article, deleted_by, title, slug, body_blob_id,
    });
}

public fun emit_blob_stored(
    vault_id: ID, publication_id: ID, blob_object_id: ID,
    blob_content_id: u256, size: u64, end_epoch: u64, stored_by: address,
) {
    sui::event::emit(BlobStored {
        vault_id, publication_id, blob_object_id, blob_content_id, size, end_epoch, stored_by,
    });
}

public fun emit_blob_removed(
    vault_id: ID, publication_id: ID, blob_object_id: ID,
    blob_content_id: u256, removed_by: address,
) {
    sui::event::emit(BlobRemoved {
        vault_id, publication_id, blob_object_id, blob_content_id, removed_by,
    });
}

public fun emit_blob_renewed(
    publication: ID, vault: ID, blob_id: ID, blob_content_id: u256,
    extended_epochs: u32, new_expiration_epoch: u64, renewed_by: address,
) {
    sui::event::emit(BlobRenewed {
        publication, vault, blob_id, blob_content_id,
        extended_epochs, new_expiration_epoch, renewed_by,
    });
}

public fun emit_article_nft_minted(article_id: ID, nft_id: address, to: address, price_paid: u64) {
    sui::event::emit(ArticleNftMinted { article_id, nft_id, to, price_paid });
}

public fun emit_publication_tipped(publication_id: ID, tipper: address, amount: u64) {
    sui::event::emit(PublicationTipped { publication_id, tipper, amount });
}

public fun emit_publication_subscription_created(
    subscription_id: ID, publication_id: ID, subscriber: address,
    amount_paid: u64, expires_at: u64,
) {
    sui::event::emit(PublicationSubscriptionCreated {
        subscription_id, publication_id, subscriber, amount_paid, expires_at,
    });
}

public fun emit_publication_subscription_extended(
    subscription_id: ID, publication_id: ID, subscriber: address,
    amount_paid: u64, new_expires_at: u64,
) {
    sui::event::emit(PublicationSubscriptionExtended {
        subscription_id, publication_id, subscriber, amount_paid, new_expires_at,
    });
}

public fun emit_publication_subscription_price_updated(
    publication_id: ID, old_price: u64, new_price: u64, updated_by: address,
) {
    sui::event::emit(PublicationSubscriptionPriceUpdated {
        publication_id, old_price, new_price, updated_by,
    });
}

public fun emit_publication_name_updated(
    publication_id: ID, old_name: String, new_name: String, updated_by: address,
) {
    sui::event::emit(PublicationNameUpdated {
        publication_id, old_name, new_name, updated_by,
    });
}

public fun emit_subscription_balance_withdrawn(
    publication_id: ID, amount: u64, withdrawn_by: address,
) {
    sui::event::emit(SubscriptionBalanceWithdrawn { publication_id, amount, withdrawn_by });
}
