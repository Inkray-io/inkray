/// Shared vault system for decentralized blob storage with contributor access.
///
/// This module provides a shared object model where multiple contributors can
/// concurrently access and store blobs in publication-specific vaults.
module contracts::vault;

use contracts::inkray_events;
use sui::table::{Self, Table};
use sui::coin::Coin;

// === Access Control Enum ===
/// Defines content access levels for articles and blobs
public enum Access has copy, drop, store {
    Free, // Publicly accessible content
    Gated, // Premium/paid content requiring authorization
}

// === Core Data Structures ===

/// Shared vault for storing blobs associated with a publication.
/// Multiple contributors can concurrently access this shared object.
public struct PublicationVault has key, store {
    id: UID,
    blobs: Table<ID, walrus::blob::Blob>, // unlimited blob storage, keyed by blob object ID
    publication_id: ID, // reference to parent publication
}

/// Platform capability for managing vault renewals.
/// This allows the platform to renew blob storage without blocking contributor access.
public struct RenewCap has key, store {
    id: UID,
}

// === Errors ===
const E_ASSET_NOT_FOUND: u64 = 0;
const E_ASSET_EXISTS: u64 = 1;

// === Admin Functions ===
fun init(ctx: &mut TxContext) {
    let renew_cap = RenewCap {
        id: object::new(ctx),
    };
    transfer::transfer(renew_cap, tx_context::sender(ctx));
}

// === Public Functions ===

/// Create a new vault as child object
/// Should only be called by authorized modules (e.g., publication.move)
fun create_vault(publication_id: ID, ctx: &mut TxContext): PublicationVault {
    PublicationVault {
        id: object::new(ctx),
        blobs: table::new(ctx),
        publication_id,
    }
}

/// Create vault and share it, returning the ID
/// Should only be called by authorized modules (e.g., publication.move)
public(package) fun create_and_share_vault(publication_id: ID, ctx: &mut TxContext): ID {
    let vault = create_vault(publication_id, ctx);
    let vault_id = vault.id.to_inner();
    transfer::share_object(vault);
    vault_id
}

/// Store blob in vault
/// Authorization and vault ownership must be verified by the caller before calling this function
public(package) fun store_blob(
    vault: &mut PublicationVault,
    blob: walrus::blob::Blob,
    stored_by: address,
) {
    let blob_id = walrus::blob::object_id(&blob);
    let blob_content_id = walrus::blob::blob_id(&blob);
    assert!(!table::contains(&vault.blobs, blob_id), E_ASSET_EXISTS);
    table::add(&mut vault.blobs, blob_id, blob);

    // Emit blob stored event with both object ID and content ID
    inkray_events::emit_blob_stored(
        vault.id.to_inner(),
        vault.publication_id,
        blob_id,
        blob_content_id,
        stored_by,
    );
}

/// Remove blob from vault
/// Authorization and vault ownership must be verified by the caller before calling this function
public(package) fun remove_blob(
    vault: &mut PublicationVault,
    blob_id: ID,
    removed_by: address,
): walrus::blob::Blob {
    assert!(table::contains(&vault.blobs, blob_id), E_ASSET_NOT_FOUND);
    let blob = table::remove(&mut vault.blobs, blob_id);

    // Emit blob removed event with both object ID and content ID
    let blob_content_id = walrus::blob::blob_id(&blob);
    inkray_events::emit_blob_removed(
        vault.id.to_inner(),
        vault.publication_id,
        blob_id,
        blob_content_id,
        removed_by,
    );

    blob
}

/// Check if blob exists
public fun has_blob(vault: &PublicationVault, blob_id: ID): bool {
    table::contains(&vault.blobs, blob_id)
}

/// Get blob from vault by blob object ID
public fun get_blob(vault: &PublicationVault, blob_id: ID): &walrus::blob::Blob {
    assert!(table::contains(&vault.blobs, blob_id), E_ASSET_NOT_FOUND);
    table::borrow(&vault.blobs, blob_id)
}

/// Renew multiple blobs in the vault by their IDs
/// Platform uses RenewCap to authorize renewal operations
/// Directly calls Walrus system::extend_blob for each blob
///
/// Note: Since Sui Table doesn't support iteration, blob IDs must be provided explicitly
public fun renew_blobs<WAL>(
    system: &mut walrus::system::System,
    vault: &mut PublicationVault,
    blob_ids: vector<ID>,
    extended_epochs: u32,
    payment: &mut Coin<WAL>,
    _cap: &RenewCap,
) {
    let mut i = 0;
    let len = vector::length(&blob_ids);

    while (i < len) {
        let blob_id = *vector::borrow(&blob_ids, i);
        assert!(table::contains(&vault.blobs, blob_id), E_ASSET_NOT_FOUND);

        // Get mutable reference to blob and extend its storage period
        let blob = table::borrow_mut(&mut vault.blobs, blob_id);
        walrus::system::extend_blob(system, blob, extended_epochs, payment);

        i = i + 1;
    };

    // Emit event for tracking
    inkray_events::emit_renew_intent(
        vault.publication_id,
        get_vault_id(vault),
        0,
        len,
    );
}

/// Renew a specific blob by its object ID
/// Platform uses RenewCap to authorize renewal operations
/// Directly calls Walrus system::extend_blob to extend the blob's storage period
public fun renew_blob<WAL>(
    system: &mut walrus::system::System,
    vault: &mut PublicationVault,
    blob_id: ID,
    extended_epochs: u32,
    payment: &mut Coin<WAL>,
    _cap: &RenewCap,
) {
    // Verify blob exists in vault
    assert!(table::contains(&vault.blobs, blob_id), E_ASSET_NOT_FOUND);

    // Get mutable reference to blob
    let blob = table::borrow_mut(&mut vault.blobs, blob_id);
    let blob_content_id = walrus::blob::blob_id(blob);

    // Call Walrus system to extend blob storage period
    walrus::system::extend_blob(system, blob, extended_epochs, payment);

    // Emit event for tracking
    inkray_events::emit_blob_renew_intent(
        get_vault_id(vault),
        vault.publication_id,
        blob_id,
        blob_content_id,
    );
}

// === Access Enum Functions ===
public fun access_free(): Access { Access::Free }

public fun access_gated(): Access { Access::Gated }

public fun is_free(access: &Access): bool {
    match (access) {
        Access::Free => true,
        Access::Gated => false,
    }
}

public fun is_gated(access: &Access): bool {
    match (access) {
        Access::Free => false,
        Access::Gated => true,
    }
}

// === View Functions ===

/// Create an empty Blob vector for use in Programmable Transaction Blocks
/// This is cleaner than creating empty vectors on the client side
public fun empty_blob_vector(): vector<walrus::blob::Blob> {
    vector::empty<walrus::blob::Blob>()
}

/// Get vault ID from vault object
public fun get_vault_id(vault: &PublicationVault): ID {
    vault.id.to_inner()
}

/// Get vault address from its ID (legacy support)
public fun get_vault_address(vault: &PublicationVault): address {
    object::uid_to_address(&vault.id)
}

/// Get blob object ID from walrus blob
public fun get_blob_object_id(blob: &walrus::blob::Blob): ID {
    walrus::blob::object_id(blob)
}

/// Get blob content hash from walrus blob
public fun get_blob_content_id(blob: &walrus::blob::Blob): u256 {
    walrus::blob::blob_id(blob)
}

public fun get_vault_info(vault: &PublicationVault): (ID, u64) {
    (vault.publication_id, table::length(&vault.blobs))
}

/// Get publication ID from vault
public fun get_vault_publication_id(vault: &PublicationVault): ID {
    vault.publication_id
}
