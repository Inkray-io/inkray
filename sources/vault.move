module contracts::vault {
    use sui::table::{Self, Table};
    use contracts::inkray_events;

    // === Access Enum ===
    public enum Access has store, drop, copy {
        Free,
        Gated
    }

    // === StoredAsset Struct ===
    public struct StoredAsset has store {
        blob: walrus::blob::Blob,  // canonical Walrus object used for renewals
        seal_id: vector<u8>,       // BCS-encoded IdV1 bytes used at encryption time
        // optional metadata
        sha256: vector<u8>,        // integrity hint
        mime: vector<u8>,          // display hint
    }

    // === PublicationVault (child object) ===
    public struct PublicationVault has key, store {
        id: UID,
        assets: Table<u256, StoredAsset>, // unlimited storage via Table
        publication_id: address,          // parent publication
    }

    // === RenewCap (platform-owned) ===
    public struct RenewCap has key, store {
        id: UID,
    }

    // === Errors ===
    const E_ASSET_NOT_FOUND: u64 = 0;
    const E_ASSET_EXISTS: u64 = 1;
    const E_NOT_AUTHORIZED: u64 = 2;
    const E_WRONG_PUBLICATION: u64 = 3;
    
    // === Error Code Access (for tests) ===
    public fun error_not_authorized(): u64 { E_NOT_AUTHORIZED }
    public fun error_wrong_publication(): u64 { E_WRONG_PUBLICATION }
    public fun error_asset_not_found(): u64 { E_ASSET_NOT_FOUND }
    public fun error_asset_exists(): u64 { E_ASSET_EXISTS }

    // === Authorization Helpers ===
    
    /// Verify caller is authorized for publication vault operations
    /// This must be called by modules that have access to Publication objects
    public(package) fun verify_caller_authorization(
        publication_owner: address,
        contributors: &vector<address>,
        caller: address
    ): bool {
        caller == publication_owner || vector::contains(contributors, &caller)
    }

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
    public(package) fun create_vault(
        publication_id: address,
        ctx: &mut TxContext
    ): PublicationVault {
        PublicationVault {
            id: object::new(ctx),
            assets: table::new(ctx),
            publication_id,
        }
    }

    /// Create vault and share it, returning the address
    /// Should only be called by authorized modules (e.g., publication.move)
    public(package) fun create_and_share_vault(
        publication_id: address,
        ctx: &mut TxContext
    ): address {
        let vault = create_vault(publication_id, ctx);
        let vault_addr = object::uid_to_address(&vault.id);
        transfer::share_object(vault);
        vault_addr
    }

    /// Store asset in vault with authorization check
    /// The caller must verify authorization before calling this function
    public(package) fun store_asset_authorized(
        vault: &mut PublicationVault,
        asset_id: u256,
        asset: StoredAsset,
        vault_publication_id: address,
        publication_owner: address,
        contributors: &vector<address>,
        caller: address
    ) {
        // Verify vault belongs to the correct publication
        assert!(vault.publication_id == vault_publication_id, E_WRONG_PUBLICATION);
        
        // Verify caller is authorized (owner or contributor)
        assert!(
            verify_caller_authorization(publication_owner, contributors, caller), 
            E_NOT_AUTHORIZED
        );
        
        assert!(!table::contains(&vault.assets, asset_id), E_ASSET_EXISTS);
        table::add(&mut vault.assets, asset_id, asset);
    }

    /// Store asset in vault (convenience function for testing)
    /// NOTE: This should not be used in production - use store_asset_authorized instead
    public fun store_asset(
        vault: &mut PublicationVault,
        asset_id: u256,
        asset: StoredAsset,
        _ctx: &TxContext
    ) {
        assert!(!table::contains(&vault.assets, asset_id), E_ASSET_EXISTS);
        table::add(&mut vault.assets, asset_id, asset);
    }

    /// Get asset from vault
    public fun get_asset(
        vault: &PublicationVault,
        asset_id: u256
    ): &StoredAsset {
        assert!(table::contains(&vault.assets, asset_id), E_ASSET_NOT_FOUND);
        table::borrow(&vault.assets, asset_id)
    }

    /// Remove asset from vault with authorization check
    /// The caller must verify authorization before calling this function
    public(package) fun remove_asset_authorized(
        vault: &mut PublicationVault,
        asset_id: u256,
        vault_publication_id: address,
        publication_owner: address,
        contributors: &vector<address>,
        caller: address
    ): StoredAsset {
        // Verify vault belongs to the correct publication
        assert!(vault.publication_id == vault_publication_id, E_WRONG_PUBLICATION);
        
        // Verify caller is authorized (owner or contributor)
        assert!(
            verify_caller_authorization(publication_owner, contributors, caller), 
            E_NOT_AUTHORIZED
        );
        
        assert!(table::contains(&vault.assets, asset_id), E_ASSET_NOT_FOUND);
        table::remove(&mut vault.assets, asset_id)
    }

    /// Remove asset from vault (convenience function for testing)
    /// NOTE: This should not be used in production - use remove_asset_authorized instead
    public fun remove_asset(
        vault: &mut PublicationVault,
        asset_id: u256,
        _ctx: &TxContext
    ): StoredAsset {
        assert!(table::contains(&vault.assets, asset_id), E_ASSET_NOT_FOUND);
        table::remove(&mut vault.assets, asset_id)
    }

    /// Check if asset exists
    public fun has_asset(
        vault: &PublicationVault,
        asset_id: u256
    ): bool {
        table::contains(&vault.assets, asset_id)
    }

    /// Renewal function (platform uses RenewCap)
    public entry fun renew_all(
        vault: &mut PublicationVault,
        _cap: &RenewCap
    ) {
        // TODO: Iterate through assets and call walrus renewal
        // For now, emit intent for relayer orchestration
        inkray_events::emit_renew_intent(
            vault.publication_id,
            get_vault_address(vault),
            0, // batch_start
            0  // batch_len - will be filled by actual implementation
        );
    }

    // === StoredAsset Functions ===
    
    /// Create a new StoredAsset
    public fun new_stored_asset(
        blob: walrus::blob::Blob,
        seal_id: vector<u8>,
        sha256: vector<u8>,
        mime: vector<u8>
    ): StoredAsset {
        StoredAsset {
            blob,
            seal_id,
            sha256,
            mime,
        }
    }

    /// Create StoredAsset with minimal metadata
    public fun new_stored_asset_minimal(
        blob: walrus::blob::Blob,
        seal_id: vector<u8>
    ): StoredAsset {
        StoredAsset {
            blob,
            seal_id,
            sha256: vector::empty(),
            mime: vector::empty(),
        }
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

    // === Utility Functions ===
    
    /// Create an empty StoredAsset vector for use in PTBs
    /// This is cleaner than creating empty vectors on the client side
    public fun empty_stored_asset_vector(): vector<StoredAsset> {
        vector::empty<StoredAsset>()
    }

    // === View Functions ===
    
    /// Get vault address from its ID
    public fun get_vault_address(vault: &PublicationVault): address {
        object::uid_to_address(&vault.id)
    }
    
    public fun get_stored_asset_info(asset: &StoredAsset): (&walrus::blob::Blob, &vector<u8>, &vector<u8>, &vector<u8>) {
        (&asset.blob, &asset.seal_id, &asset.sha256, &asset.mime)
    }

    public fun get_seal_id(asset: &StoredAsset): &vector<u8> {
        &asset.seal_id
    }

    public fun get_vault_info(vault: &PublicationVault): (address, u64) {
        (vault.publication_id, table::length(&vault.assets))
    }
}