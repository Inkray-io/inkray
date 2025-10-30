/// Shared vault system for decentralized blob storage with contributor access.
///
/// This module provides a shared object model where multiple contributors can
/// concurrently access and store blobs in publication-specific vaults.
module contracts::vault;

use contracts::inkray_events;
use sui::coin::Coin;
use sui::table::{Self, Table};
use wal::wal::WAL;
use walrus::blob;
use walrus::system::System;

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

// === Errors ===
const E_ASSET_NOT_FOUND: u64 = 0;
const E_ASSET_EXISTS: u64 = 1;
const E_INVALID_EPOCH_EXTENSION: u64 = 2;

// === Admin Functions ===
fun init(_ctx: &mut TxContext) {}

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
    let blob_size = blob::storage(&blob).size();
    let end_epoch = (blob::end_epoch(&blob) as u64);
    assert!(!table::contains(&vault.blobs, blob_id), E_ASSET_EXISTS);
    table::add(&mut vault.blobs, blob_id, blob);

    // Emit blob stored event with size, object ID and content ID
    inkray_events::emit_blob_stored(
        vault.id.to_inner(),
        vault.publication_id,
        blob_id,
        blob_content_id,
        blob_size,
        end_epoch,
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

/// Renew a specific blob by extending its storage duration
/// Anyone can call this function by providing sufficient payment
public fun renew_blob(
    vault: &mut PublicationVault,
    blob_object_id: ID,
    extended_epochs: u32,
    payment: &mut Coin<WAL>,
    system: &mut System,
    ctx: &mut TxContext,
) {
    // Basic validation
    assert!(extended_epochs > 0, E_INVALID_EPOCH_EXTENSION);
    assert!(table::contains(&vault.blobs, blob_object_id), E_ASSET_NOT_FOUND);

    // Get mutable reference to the blob
    let blob = table::borrow_mut(&mut vault.blobs, blob_object_id);

    // Call Walrus extend_blob - this will handle payment validation
    walrus::system::extend_blob(system, blob, extended_epochs, payment);

    // Get updated expiration epoch from the blob
    let new_expiration_epoch = (blob::end_epoch(blob) as u64);
    let blob_content_id = blob::blob_id(blob);

    // Emit renewal event
    inkray_events::emit_blob_renewed(
        vault.publication_id,
        vault.id.to_inner(),
        blob_object_id,
        blob_content_id,
        extended_epochs,
        new_expiration_epoch,
        tx_context::sender(ctx),
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
