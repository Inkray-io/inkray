module contracts::articles {
    use std::string::{Self, String};
    use contracts::vault::{Self, Access, PublicationVault};
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
        body_blob_id: ID,                  // Object ID of body blob in vault
        asset_blob_ids: vector<ID>,        // Object IDs of asset blobs in vault
        // minimal metadata
        title: String,
        slug: String,
        publication_id: ID,                // Use ID instead of address
        author: address,
        created_at: u64,
    }

    // === Public Functions ===
    
    /// Post article by contributor with auto-generated slug from title
    public fun post(
        publication: &Publication,
        vault: &mut PublicationVault,
        title: String,
        gating: Access,
        body_blob: walrus::blob::Blob,
        asset_blobs: vector<walrus::blob::Blob>,
        ctx: &mut TxContext
    ): Article {
        let author = tx_context::sender(ctx);
        
        // Verify contributor authorization
        assert!(publication::is_contributor(publication, author), E_NOT_AUTHORIZED);
        
        post_internal(publication, vault, title, gating, body_blob, asset_blobs, author, ctx)
    }

    /// Post article by owner using owner cap with auto-generated slug from title
    public fun post_as_owner(
        owner_cap: &PublicationOwnerCap,
        publication: &Publication,
        vault: &mut PublicationVault,
        title: String,
        gating: Access,
        body_blob: walrus::blob::Blob,
        asset_blobs: vector<walrus::blob::Blob>,
        ctx: &mut TxContext
    ): Article {
        // Verify owner cap
        assert!(publication::verify_owner_cap(owner_cap, publication), E_NOT_AUTHORIZED);
        
        let author = tx_context::sender(ctx);
        post_internal(publication, vault, title, gating, body_blob, asset_blobs, author, ctx)
    }

    /// Internal posting logic
    fun post_internal(
        publication: &Publication,
        vault: &mut PublicationVault,
        title: String,
        gating: Access,
        body_blob: walrus::blob::Blob,
        mut asset_blobs: vector<walrus::blob::Blob>,
        author: address,
        ctx: &mut TxContext
    ): Article {
        let publication_id = publication::get_publication_object_id(publication);
        let vault_id = vault::get_vault_id(vault);
        
        // Verify vault belongs to publication
        assert!(publication::get_vault_id(publication) == vault_id, E_INVALID_VAULT);
        
        let article_id = object::new(ctx);
        let article_addr = object::uid_to_address(&article_id);
        let created_at = tx_context::epoch_timestamp_ms(ctx);
        
        // Generate slug from title using article's own ID
        let slug = generate_slug_from_title(title, &article_id);
        
        // Store body blob in vault
        let body_blob_id = vault::get_blob_object_id(&body_blob);
        publication::store_blob_in_vault(publication, vault, body_blob, ctx);
        
        // Store additional asset blobs in vault and collect their IDs
        let mut asset_blob_ids = vector::empty<ID>();
        while (!vector::is_empty(&asset_blobs)) {
            let blob = vector::pop_back(&mut asset_blobs);
            let blob_id = vault::get_blob_object_id(&blob);
            publication::store_blob_in_vault(publication, vault, blob, ctx);
            vector::push_back(&mut asset_blob_ids, blob_id);
        };
        // Destroy the empty asset blobs vector
        vector::destroy_empty(asset_blobs);
        
        let article = Article {
            id: article_id,
            gating,
            body_blob_id,
            asset_blob_ids,
            title,
            slug,
            publication_id,
            author,
            created_at,
        };
        
        // Emit event
        inkray_events::emit_article_posted(
            publication::get_publication_address(publication), // Use address for event compatibility
            article_addr,
            author,
            title,
            access_to_u8(&gating),
            vector::length(&asset_blob_ids) + 1  // +1 for body
        );
        
        article
    }

    /// Update article metadata (not blobs) - regenerates slug from new title
    public fun update_article(
        owner_cap: &PublicationOwnerCap,
        publication: &Publication,
        article: &mut Article,
        new_title: String,
        _ctx: &TxContext
    ) {
        // Verify ownership
        assert!(publication::verify_owner_cap(owner_cap, publication), E_NOT_AUTHORIZED);
        assert!(article.publication_id == publication::get_publication_object_id(publication), E_INVALID_PUBLICATION);
        
        // Update title and regenerate slug from new title using article's ID
        article.title = new_title;
        article.slug = generate_slug_from_title(new_title, &article.id);
    }

    // === Helper Functions ===
    
    /// Generate a URL-friendly slug from article title with unique identifier
    /// Returns lowercase slug with hyphens, no special chars, and unique suffix from article ID
    public fun generate_slug_from_title(title: String, article_uid: &UID): String {
        // Clean the title string
        let cleaned_title = clean_title_string(title);
        
        // Generate unique identifier from article UID
        let unique_suffix = uid_to_short_hex(article_uid);
        
        // Combine cleaned title with unique suffix
        let mut slug = cleaned_title;
        if (string::length(&slug) > 0) {
            string::append(&mut slug, string::utf8(b"-"));
        };
        string::append(&mut slug, unique_suffix);
        
        slug
    }
    
    /// Clean title string for slug generation
    /// Converts to lowercase, replaces spaces with hyphens, removes special chars
    fun clean_title_string(title: String): String {
        let title_bytes = string::as_bytes(&title);
        let mut result_bytes = vector::empty<u8>();
        let mut i = 0;
        let len = vector::length(title_bytes);
        let mut last_was_hyphen = false;
        
        while (i < len) {
            let byte = *vector::borrow(title_bytes, i);
            
            // Convert uppercase to lowercase (A-Z -> a-z)
            let processed_byte = if (byte >= 65 && byte <= 90) {
                byte + 32  // Convert A-Z to a-z
            } else if (byte == 32) {  // Space
                45  // Convert space to hyphen (-)
            } else if (is_valid_slug_char(byte)) {
                byte  // Keep valid characters
            } else {
                0  // Mark invalid characters for removal
            };
            
            // Add byte if valid and not creating consecutive hyphens
            if (processed_byte != 0) {
                let is_hyphen = (processed_byte == 45);
                if (!is_hyphen || !last_was_hyphen) {
                    vector::push_back(&mut result_bytes, processed_byte);
                };
                last_was_hyphen = is_hyphen;
            };
            
            i = i + 1;
        };
        
        // Remove trailing hyphen if exists
        if (!vector::is_empty(&result_bytes)) {
            let last_idx = vector::length(&result_bytes) - 1;
            if (*vector::borrow(&result_bytes, last_idx) == 45) {
                vector::pop_back(&mut result_bytes);
            };
        };
        
        // Remove leading hyphen if exists
        if (!vector::is_empty(&result_bytes)) {
            if (*vector::borrow(&result_bytes, 0) == 45) {
                vector::remove(&mut result_bytes, 0);
            };
        };
        
        string::utf8(result_bytes)
    }
    
    /// Check if character is valid for slug (a-z, 0-9, hyphen)
    fun is_valid_slug_char(byte: u8): bool {
        (byte >= 97 && byte <= 122) ||  // a-z
        (byte >= 48 && byte <= 57) ||   // 0-9  
        (byte == 45)                    // hyphen
    }
    
    /// Convert UID to short hex string (first 8 characters)
    fun uid_to_short_hex(uid: &UID): String {
        let uid_bytes = object::uid_to_bytes(uid);
        let mut hex_bytes = vector::empty<u8>();
        let mut i = 0;
        
        // Take first 4 bytes and convert to hex (8 hex characters)
        while (i < 4 && i < vector::length(&uid_bytes)) {
            let byte = *vector::borrow(&uid_bytes, i);
            let high_nibble = byte / 16;
            let low_nibble = byte % 16;
            
            vector::push_back(&mut hex_bytes, nibble_to_hex_char(high_nibble));
            vector::push_back(&mut hex_bytes, nibble_to_hex_char(low_nibble));
            
            i = i + 1;
        };
        
        string::utf8(hex_bytes)
    }
    
    /// Convert nibble (0-15) to hex character
    fun nibble_to_hex_char(nibble: u8): u8 {
        if (nibble < 10) {
            48 + nibble  // '0' to '9'
        } else {
            97 + nibble - 10  // 'a' to 'f'
        }
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
    
    /// Get article object ID
    public fun get_article_id(article: &Article): ID {
        article.id.to_inner()
    }
    
    /// Get article address from its ID (legacy support)
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
        ID,        // publication_id
        address,   // author
        u64,       // created_at
        u8,        // gating (0=Free, 1=Gated)
        u64        // blob_count
    ) {
        (
            article.title,
            article.slug,
            article.publication_id,
            article.author,
            article.created_at,
            access_to_u8(&article.gating),
            vector::length(&article.asset_blob_ids) + 1  // +1 for body
        )
    }
    
    public fun get_gating(article: &Article): &Access {
        &article.gating
    }
    
    public fun get_body_blob_id(article: &Article): ID {
        article.body_blob_id
    }
    
    public fun get_asset_blob_ids(article: &Article): &vector<ID> {
        &article.asset_blob_ids
    }
    
    public fun get_publication_id(article: &Article): ID {
        article.publication_id
    }
    
    public fun get_author(article: &Article): address {
        article.author
    }
    
    public fun get_title(article: &Article): String {
        article.title
    }
    
    public fun get_slug(article: &Article): String {
        article.slug
    }
    
    /// Preview what slug would be generated for a title (for testing/UI purposes)
    /// Creates a temporary UID to simulate the slug generation process
    public fun preview_slug_from_title(title: String, ctx: &mut TxContext): String {
        let temp_uid = object::new(ctx);
        let slug = generate_slug_from_title(title, &temp_uid);
        object::delete(temp_uid);
        slug
    }
}