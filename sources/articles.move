module contracts::articles {
    use std::string::String;
    use contracts::vault::{Self, Access, StoredAsset, PublicationVault};
    use contracts::publication::{Self, Publication, PublicationOwnerCap};
    use contracts::inkray_events;

    // === Errors ===
    const E_NOT_AUTHORIZED: u64 = 0;
    const E_INVALID_PUBLICATION: u64 = 1;
    const E_INVALID_VAULT: u64 = 2;

    // === Article Struct ===
    public struct Article has key, store {
        id: UID,
        gating: Access,                    // Free or Gated
        body_id: u256,                     // ID of body asset in vault
        asset_ids: vector<u256>,           // IDs of assets in vault
        // minimal metadata
        title: String,
        slug: String,
        publication_id: address,
        author: address,
        created_at: u64,
    }

    // === Public Functions ===
    
    /// Post article by contributor
    public fun post(
        publication: &Publication,
        vault: &mut PublicationVault,
        title: String,
        slug: String,
        gating: Access,
        body_asset: StoredAsset,
        assets: vector<StoredAsset>,
        ctx: &mut TxContext
    ): Article {
        let author = tx_context::sender(ctx);
        
        // Verify authorization (contributor or owner)
        assert!(
            publication::is_owner(publication, author) || 
            publication::is_contributor(publication, author),
            E_NOT_AUTHORIZED
        );
        
        post_internal(publication, vault, title, slug, gating, body_asset, assets, author, ctx)
    }

    /// Post article by owner using owner cap
    public fun post_as_owner(
        owner_cap: &PublicationOwnerCap,
        publication: &Publication,
        vault: &mut PublicationVault,
        title: String,
        slug: String,
        gating: Access,
        body_asset: StoredAsset,
        assets: vector<StoredAsset>,
        ctx: &mut TxContext
    ): Article {
        // Verify owner cap
        assert!(publication::verify_owner_cap(owner_cap, publication), E_NOT_AUTHORIZED);
        
        let author = tx_context::sender(ctx);
        post_internal(publication, vault, title, slug, gating, body_asset, assets, author, ctx)
    }

    /// Internal posting logic
    fun post_internal(
        publication: &Publication,
        vault: &mut PublicationVault,
        title: String,
        slug: String,
        gating: Access,
        body_asset: StoredAsset,
        mut assets: vector<StoredAsset>,
        author: address,
        ctx: &mut TxContext
    ): Article {
        let publication_addr = publication::get_publication_address(publication);
        let vault_addr = vault::get_vault_address(vault);
        
        // Verify vault belongs to publication
        assert!(publication::get_vault_id(publication) == vault_addr, E_INVALID_VAULT);
        
        let article_id = object::new(ctx);
        let article_addr = object::uid_to_address(&article_id);
        let created_at = tx_context::epoch_timestamp_ms(ctx);
        
        // Store body asset in vault
        let body_id = get_asset_id(&body_asset);
        publication::store_asset_in_vault(publication, vault, body_id, body_asset, ctx);
        
        // Store additional assets in vault and collect their IDs
        let mut asset_ids = vector::empty<u256>();
        while (!vector::is_empty(&assets)) {
            let asset = vector::pop_back(&mut assets);
            let asset_id = get_asset_id(&asset);
            publication::store_asset_in_vault(publication, vault, asset_id, asset, ctx);
            vector::push_back(&mut asset_ids, asset_id);
        };
        // Destroy the empty assets vector
        vector::destroy_empty(assets);
        
        let article = Article {
            id: article_id,
            gating,
            body_id: body_id,
            asset_ids,
            title,
            slug,
            publication_id: publication_addr,
            author,
            created_at,
        };
        
        // Emit event
        inkray_events::emit_article_posted(
            publication_addr,
            article_addr,
            author,
            title,
            access_to_u8(&gating),
            vector::length(&asset_ids) + 1  // +1 for body
        );
        
        article
    }

    /// Update article metadata (not assets)
    public fun update_article(
        owner_cap: &PublicationOwnerCap,
        publication: &Publication,
        article: &mut Article,
        new_title: String,
        new_slug: String,
        _ctx: &TxContext
    ) {
        // Verify ownership
        assert!(publication::verify_owner_cap(owner_cap, publication), E_NOT_AUTHORIZED);
        assert!(article.publication_id == publication::get_publication_address(publication), E_INVALID_PUBLICATION);
        
        article.title = new_title;
        article.slug = new_slug;
    }

    // === Helper Functions ===
    
    /// Extract asset ID from StoredAsset (using seal_id hash)
    fun get_asset_id(asset: &StoredAsset): u256 {
        let (_, seal_id, _, _) = vault::get_stored_asset_info(asset);
        // Use hash of seal_id as asset ID for Table key
        let hash = sui::hash::keccak256(seal_id);
        sui::bcs::peel_u256(&mut sui::bcs::new(hash))
    }
    
    /// Convert Access enum to u8 for events
    fun access_to_u8(access: &Access): u8 {
        if (vault::is_free(access)) {
            0  // Free
        } else {
            1  // Gated
        }
    }

    // === View Functions ===
    
    /// Get article address from its ID
    public fun get_article_address(article: &Article): address {
        object::uid_to_address(&article.id)
    }
    
    public fun is_free_content(article: &Article): bool {
        vault::is_free(&article.gating)
    }
    
    public fun is_gated_content(article: &Article): bool {
        vault::is_gated(&article.gating)
    }
    
    public fun get_article_info(article: &Article): (
        String,    // title
        String,    // slug
        address,   // publication_id
        address,   // author
        u64,       // created_at
        u8,        // gating (0=Free, 1=Gated)
        u64        // asset_count
    ) {
        (
            article.title,
            article.slug,
            article.publication_id,
            article.author,
            article.created_at,
            access_to_u8(&article.gating),
            vector::length(&article.asset_ids) + 1  // +1 for body
        )
    }
    
    public fun get_gating(article: &Article): &Access {
        &article.gating
    }
    
    public fun get_body_id(article: &Article): u256 {
        article.body_id
    }
    
    public fun get_asset_ids(article: &Article): &vector<u256> {
        &article.asset_ids
    }
    
    public fun get_publication_id(article: &Article): address {
        article.publication_id
    }
    
    public fun get_author(article: &Article): address {
        article.author
    }
}