module contracts::publication;

use contracts::inkray_events;
use contracts::vault;
use std::string::String;

// === Errors ===
const E_NOT_OWNER: u64 = 0;
const E_CONTRIBUTOR_NOT_FOUND: u64 = 1;
const E_CONTRIBUTOR_EXISTS: u64 = 2;

// === Structs ===
public struct Publication has key, store {
    id: UID,
    name: String,
    contributors: vector<address>, // bounded collection - use vector
    vault_id: ID, // child PublicationVault
}

public struct PublicationOwnerCap has key, store {
    id: UID,
    publication_id: ID, // publication object id as address
}

// === Public Functions ===

/// Create a publication with its associated vault (shared object)
public fun create(name: String, ctx: &mut TxContext): PublicationOwnerCap {
    let owner = tx_context::sender(ctx);
    let publication_uid = object::new(ctx);
    let publication_id = publication_uid.to_inner();

    // Create vault first
    let vault_id = vault::create_and_share_vault(publication_id, ctx);

    let publication = Publication {
        id: publication_uid,
        name,
        contributors: vector::empty(),
        vault_id,
    };

    let owner_cap = PublicationOwnerCap {
        id: object::new(ctx),
        publication_id,
    };

    // Share publication
    transfer::share_object(publication);

    // Emit event
    inkray_events::emit_publication_created(
        publication_id,
        owner,
        name,
        vault_id,
    );

    owner_cap
}

public fun add_contributor(
    owner_cap: &PublicationOwnerCap,
    publication: &mut Publication,
    contributor: address,
    ctx: &TxContext,
) {
    assert!(owner_cap.publication_id == publication.id.to_inner(), E_NOT_OWNER);
    assert!(!vector::contains(&publication.contributors, &contributor), E_CONTRIBUTOR_EXISTS);

    vector::push_back(&mut publication.contributors, contributor);

    inkray_events::emit_contributor_added(
        publication.id.to_inner(),
        contributor,
        tx_context::sender(ctx),
    );
}

public fun remove_contributor(
    owner_cap: &PublicationOwnerCap,
    publication: &mut Publication,
    contributor: address,
    ctx: &TxContext,
) {
    assert!(owner_cap.publication_id == publication.id.to_inner(), E_NOT_OWNER);

    let (found, index) = vector::index_of(&publication.contributors, &contributor);
    assert!(found, E_CONTRIBUTOR_NOT_FOUND);

    vector::remove(&mut publication.contributors, index);

    inkray_events::emit_contributor_removed(
        publication.id.to_inner(),
        contributor,
        tx_context::sender(ctx),
    );
}

// === View Functions ===

public fun is_contributor(publication: &Publication, user: address): bool {
    vector::contains(&publication.contributors, &user)
}

/// Check if address holds ownership capability for this publication
/// Note: This function now requires the OwnerCap to prove ownership
public fun is_owner_with_cap(owner_cap: &PublicationOwnerCap, publication: &Publication): bool {
    owner_cap.publication_id == publication.id.to_inner()
}

public fun get_vault_id(publication: &Publication): ID {
    publication.vault_id
}

public fun get_contributors(publication: &Publication): &vector<address> {
    &publication.contributors
}

public fun get_name(publication: &Publication): String {
    publication.name
}

public fun get_publication_id(owner_cap: &PublicationOwnerCap): ID {
    owner_cap.publication_id
}

/// Get publication ID from publication object
public fun get_publication_object_id(publication: &Publication): ID {
    publication.id.to_inner()
}

/// Get publication address from publication object (legacy support)
public fun get_publication_address(publication: &Publication): address {
    object::uid_to_address(&publication.id)
}

public fun verify_owner_cap(owner_cap: &PublicationOwnerCap, publication: &Publication): bool {
    owner_cap.publication_id == publication.id.to_inner()
}

// === Authorization Helpers ===

/// Verify caller is a contributor (owner access requires capability)
public fun verify_caller_is_contributor(publication: &Publication, caller: address): bool {
    vector::contains(&publication.contributors, &caller)
}

/// Assert that caller is a contributor
public fun assert_contributor_access(publication: &Publication, caller: address) {
    assert!(verify_caller_is_contributor(publication, caller), E_NOT_OWNER);
}

/// Assert that owner capability matches publication
public fun assert_owner_access(owner_cap: &PublicationOwnerCap, publication: &Publication) {
    assert!(verify_owner_cap(owner_cap, publication), E_NOT_OWNER);
}

// === Authorized Vault Operations ===

/// Store blob in publication vault (contributor only - owners use store_blob_in_vault_as_owner)
public fun store_blob_in_vault(
    publication: &Publication,
    vault: &mut vault::PublicationVault,
    blob: walrus::blob::Blob,
    ctx: &TxContext,
) {
    let caller = tx_context::sender(ctx);

    // Check contributor authorization
    assert_contributor_access(publication, caller);
    
    // Verify vault belongs to this publication
    assert!(vault::get_vault_publication_id(vault) == publication.id.to_inner(), E_NOT_OWNER);

    // Store blob in vault
    vault::store_blob(vault, blob);
}

/// Store blob in publication vault using owner capability
public fun store_blob_in_vault_as_owner(
    owner_cap: &PublicationOwnerCap,
    publication: &Publication,
    vault: &mut vault::PublicationVault,
    blob: walrus::blob::Blob,
) {
    // Check owner authorization
    assert_owner_access(owner_cap, publication);
    
    // Verify vault belongs to this publication
    assert!(vault::get_vault_publication_id(vault) == publication.id.to_inner(), E_NOT_OWNER);

    // Store blob in vault
    vault::store_blob(vault, blob);
}

/// Remove blob from publication vault (contributor only - owners use remove_blob_from_vault_as_owner)
public fun remove_blob_from_vault(
    publication: &Publication,
    vault: &mut vault::PublicationVault,
    blob_id: ID,
    ctx: &TxContext,
): walrus::blob::Blob {
    let caller = tx_context::sender(ctx);

    // Check contributor authorization
    assert_contributor_access(publication, caller);
    
    // Verify vault belongs to this publication
    assert!(vault::get_vault_publication_id(vault) == publication.id.to_inner(), E_NOT_OWNER);

    // Remove blob from vault
    vault::remove_blob(vault, blob_id)
}

/// Remove blob from publication vault using owner capability
public fun remove_blob_from_vault_as_owner(
    owner_cap: &PublicationOwnerCap,
    publication: &Publication,
    vault: &mut vault::PublicationVault,
    blob_id: ID,
): walrus::blob::Blob {
    // Check owner authorization
    assert_owner_access(owner_cap, publication);
    
    // Verify vault belongs to this publication
    assert!(vault::get_vault_publication_id(vault) == publication.id.to_inner(), E_NOT_OWNER);

    // Remove blob from vault
    vault::remove_blob(vault, blob_id)
}
