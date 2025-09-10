module contracts::vault;

use contracts::inkray_events;
use sui::table::{Self, Table};

// === Access Enum ===
public enum Access has copy, drop, store {
    Free,
    Gated,
}

// === PublicationVault (child object) ===
public struct PublicationVault has key, store {
    id: UID,
    blobs: Table<ID, walrus::blob::Blob>, // unlimited blob storage via Table, keyed by blob object ID
    publication_id: ID, // parent publication
}

// === RenewCap (platform-owned) ===
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
) {
    let blob_id = walrus::blob::object_id(&blob);
    assert!(!table::contains(&vault.blobs, blob_id), E_ASSET_EXISTS);
    table::add(&mut vault.blobs, blob_id, blob);
}

/// Remove blob from vault
/// Authorization and vault ownership must be verified by the caller before calling this function
public(package) fun remove_blob(
    vault: &mut PublicationVault,
    blob_id: ID,
): walrus::blob::Blob {
    assert!(table::contains(&vault.blobs, blob_id), E_ASSET_NOT_FOUND);
    table::remove(&mut vault.blobs, blob_id)
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

/// Renewal function (platform uses RenewCap)
public fun renew_all(vault: &mut PublicationVault, _cap: &RenewCap) {
    // TODO: Iterate through assets and call walrus renewal
    // For now, emit intent for relayer orchestration
    inkray_events::emit_renew_intent(
        vault.publication_id,
        get_vault_address(vault),
        0, // batch_start
        0, // batch_len - will be filled by actual implementation
    );
}

// === Blob Helper Functions ===

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

// === Utility Functions ===

/// Create an empty Blob vector for use in PTBs
/// This is cleaner than creating empty vectors on the client side
public fun empty_blob_vector(): vector<walrus::blob::Blob> {
    vector::empty<walrus::blob::Blob>()
}

// === View Functions ===

/// Get vault ID from vault object
public fun get_vault_id(vault: &PublicationVault): ID {
    vault.id.to_inner()
}

/// Get vault address from its ID (legacy support)
public fun get_vault_address(vault: &PublicationVault): address {
    object::uid_to_address(&vault.id)
}

/// Get blob ID from walrus blob (object ID)
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
