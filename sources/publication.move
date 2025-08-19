module contracts::publication {
    use std::string::String;
    use contracts::vault;
    use contracts::inkray_events;

    // === Errors ===
    const E_NOT_OWNER: u64 = 0;
    const E_CONTRIBUTOR_NOT_FOUND: u64 = 1;
    const E_CONTRIBUTOR_EXISTS: u64 = 2;

    // === Structs ===
    public struct Publication has key, store {
        id: UID,
        name: String,
        owner: address,
        contributors: vector<address>,  // bounded collection - use vector
        vault_id: address,              // child PublicationVault
    }

    public struct PublicationOwnerCap has key, store {
        id: UID,
        publication_id: address,        // publication object id as address
    }


    // === Public Functions ===
    
    /// Create a publication with its associated vault (shared object)
    public fun create(
        name: String,
        ctx: &mut TxContext
    ): (PublicationOwnerCap, address) {
        let owner = tx_context::sender(ctx);
        let pub_id = object::new(ctx);
        let publication_addr = object::uid_to_address(&pub_id);
        
        // Create vault first
        let vault_addr = vault::create_and_share_vault(publication_addr, ctx);
        
        let publication = Publication {
            id: pub_id,
            name,
            owner,
            contributors: vector::empty(),
            vault_id: vault_addr,
        };
        
        let owner_cap = PublicationOwnerCap {
            id: object::new(ctx),
            publication_id: publication_addr,
        };
        
        // Share publication 
        transfer::share_object(publication);
        
        // Emit event
        inkray_events::emit_publication_created(
            publication_addr,
            owner,
            name,
            vault_addr
        );
        
        (owner_cap, publication_addr)
    }

    public fun add_contributor(
        owner_cap: &PublicationOwnerCap,
        publication: &mut Publication,
        contributor: address,
        ctx: &TxContext
    ) {
        assert!(owner_cap.publication_id == object::uid_to_address(&publication.id), E_NOT_OWNER);
        assert!(!vector::contains(&publication.contributors, &contributor), E_CONTRIBUTOR_EXISTS);
        
        vector::push_back(&mut publication.contributors, contributor);
        
        inkray_events::emit_contributor_added(
            object::uid_to_address(&publication.id),
            contributor,
            tx_context::sender(ctx)
        );
    }

    public fun remove_contributor(
        owner_cap: &PublicationOwnerCap,
        publication: &mut Publication,
        contributor: address,
        ctx: &TxContext
    ) {
        assert!(owner_cap.publication_id == object::uid_to_address(&publication.id), E_NOT_OWNER);
        
        let (found, index) = vector::index_of(&publication.contributors, &contributor);
        assert!(found, E_CONTRIBUTOR_NOT_FOUND);
        
        vector::remove(&mut publication.contributors, index);
        
        inkray_events::emit_contributor_removed(
            object::uid_to_address(&publication.id),
            contributor,
            tx_context::sender(ctx)
        );
    }

    // === View Functions ===
    
    /// Get publication address from its ID
    public fun get_publication_address(publication: &Publication): address {
        object::uid_to_address(&publication.id)
    }
    
    public fun is_contributor(
        publication: &Publication,
        user: address
    ): bool {
        vector::contains(&publication.contributors, &user)
    }

    public fun is_owner(publication: &Publication, addr: address): bool {
        publication.owner == addr
    }

    public fun get_owner(publication: &Publication): address {
        publication.owner
    }

    public fun get_vault_id(publication: &Publication): address {
        publication.vault_id
    }

    public fun get_contributors(publication: &Publication): &vector<address> {
        &publication.contributors
    }

    public fun get_name(publication: &Publication): String {
        publication.name
    }

    public fun get_publication_id(owner_cap: &PublicationOwnerCap): address {
        owner_cap.publication_id
    }

    public fun verify_owner_cap(
        owner_cap: &PublicationOwnerCap,
        publication: &Publication
    ): bool {
        owner_cap.publication_id == get_publication_address(publication)
    }

    // === Authorized Vault Operations ===
    
    /// Store asset in publication vault (owner or contributor only)
    public fun store_asset_in_vault(
        publication: &Publication,
        vault: &mut vault::PublicationVault,
        asset_id: u256,
        asset: vault::StoredAsset,
        ctx: &TxContext
    ) {
        let caller = tx_context::sender(ctx);
        vault::store_asset_authorized(
            vault,
            asset_id,
            asset,
            get_publication_address(publication),
            publication.owner,
            &publication.contributors,
            caller
        );
    }
    
    /// Remove asset from publication vault (owner or contributor only)
    public fun remove_asset_from_vault(
        publication: &Publication,
        vault: &mut vault::PublicationVault,
        asset_id: u256,
        ctx: &TxContext
    ): vault::StoredAsset {
        let caller = tx_context::sender(ctx);
        vault::remove_asset_authorized(
            vault,
            asset_id,
            get_publication_address(publication),
            publication.owner,
            &publication.contributors,
            caller
        )
    }

    // === Entry Functions ===
    
    /// Entry function wrapper for creating a publication
    /// This can be called directly from transactions
    public entry fun create_publication(
        name: String,
        ctx: &mut TxContext
    ) {
        let (owner_cap, _publication_addr) = create(name, ctx);
        
        // Transfer the owner cap to the sender
        transfer::transfer(owner_cap, tx_context::sender(ctx));
    }
    
    /// Entry function wrapper for adding a contributor
    public entry fun add_contributor_entry(
        owner_cap: &PublicationOwnerCap,
        publication: &mut Publication,
        contributor: address,
        ctx: &mut TxContext
    ) {
        add_contributor(owner_cap, publication, contributor, ctx);
    }
    
    /// Entry function wrapper for removing a contributor
    public entry fun remove_contributor_entry(
        owner_cap: &PublicationOwnerCap,
        publication: &mut Publication,
        contributor: address,
        ctx: &mut TxContext
    ) {
        remove_contributor(owner_cap, publication, contributor, ctx);
    }
}