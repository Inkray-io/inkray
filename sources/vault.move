module contracts::vault;

use contracts::inkray_events;
use sui::coin::Coin;
use sui::table::{Self, Table};
use wal::wal::WAL;
use walrus::blob;
use walrus::system::System;

public enum Access has copy, drop, store {
    Free,
    Gated,
}

public struct PublicationVault has key, store {
    id: UID,
    blobs: Table<ID, walrus::blob::Blob>,
    publication_id: ID,
}

const E_ASSET_NOT_FOUND: u64 = 301;
const E_ASSET_EXISTS: u64 = 302;
const E_INVALID_EPOCH_EXTENSION: u64 = 303;

fun init(_ctx: &mut TxContext) {}

fun create_vault(publication_id: ID, ctx: &mut TxContext): PublicationVault {
    PublicationVault {
        id: object::new(ctx),
        blobs: table::new(ctx),
        publication_id,
    }
}

public(package) fun create_and_share_vault(publication_id: ID, ctx: &mut TxContext): ID {
    let vault = create_vault(publication_id, ctx);
    let vault_id = vault.id.to_inner();
    transfer::share_object(vault);
    vault_id
}

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
    inkray_events::emit_blob_stored(
        vault.id.to_inner(), vault.publication_id,
        blob_id, blob_content_id, blob_size, end_epoch, stored_by,
    );
}

public(package) fun remove_blob(
    vault: &mut PublicationVault,
    blob_id: ID,
    removed_by: address,
): walrus::blob::Blob {
    assert!(table::contains(&vault.blobs, blob_id), E_ASSET_NOT_FOUND);
    let blob = table::remove(&mut vault.blobs, blob_id);
    let blob_content_id = walrus::blob::blob_id(&blob);
    inkray_events::emit_blob_removed(
        vault.id.to_inner(), vault.publication_id,
        blob_id, blob_content_id, removed_by,
    );
    blob
}

public fun renew_blob(
    vault: &mut PublicationVault,
    blob_object_id: ID,
    extended_epochs: u32,
    payment: &mut Coin<WAL>,
    system: &mut System,
    ctx: &mut TxContext,
) {
    assert!(extended_epochs > 0, E_INVALID_EPOCH_EXTENSION);
    assert!(table::contains(&vault.blobs, blob_object_id), E_ASSET_NOT_FOUND);
    let blob = table::borrow_mut(&mut vault.blobs, blob_object_id);
    walrus::system::extend_blob(system, blob, extended_epochs, payment);
    let new_expiration_epoch = (blob::end_epoch(blob) as u64);
    let blob_content_id = blob::blob_id(blob);
    inkray_events::emit_blob_renewed(
        vault.publication_id, vault.id.to_inner(),
        blob_object_id, blob_content_id,
        extended_epochs, new_expiration_epoch, tx_context::sender(ctx),
    );
}

// === Access Enum Functions ===

public fun access_free(): Access { Access::Free }
public fun access_gated(): Access { Access::Gated }

public fun is_free(access: &Access): bool {
    match (access) { Access::Free => true, Access::Gated => false }
}

// === View Functions ===

public fun get_vault_id(vault: &PublicationVault): ID {
    vault.id.to_inner()
}

public fun get_blob_object_id(blob: &walrus::blob::Blob): ID {
    walrus::blob::object_id(blob)
}

public fun get_blob_content_id(blob: &walrus::blob::Blob): u256 {
    walrus::blob::blob_id(blob)
}

public fun get_vault_publication_id(vault: &PublicationVault): ID {
    vault.publication_id
}
