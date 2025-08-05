module contracts::content_registry {
    use contracts::publication::{Self, Publication, PublicationOwnerCap};
    use contracts::publication_vault::{Self, PublicationVault};
    use sui::event;
    use std::string::String;

    // === Errors ===
    const ENotAuthorized: u64 = 0;
    const EInvalidPublication: u64 = 1;
    const EInvalidVault: u64 = 2;

    // === Structs ===
    public struct Article has key, store {
        id: UID,
        publication_id: ID,
        author: address,
        title: String,
        summary: String,
        blob_id: u256,
        is_paid: bool,
        created_at: u64,
    }

    // === Events ===
    public struct ArticlePublished has copy, drop {
        article_id: ID,
        publication_id: ID,
        author: address,
        title: String,
        blob_id: u256,
        is_paid: bool,
        created_at: u64,
    }

    public struct ArticleUpdated has copy, drop {
        article_id: ID,
        updated_by: address,
        updated_at: u64,
    }

    // === Public Functions ===
    fun publish_article_internal(
        publication: &Publication,
        vault: &mut PublicationVault,
        author: address,
        title: String,
        summary: String,
        blob_id: u256,
        blob_size: u64,
        is_paid: bool,
        ctx: &mut TxContext
    ): Article {
        let publication_id = object::id(publication);
        let vault_id = publication::get_vault_id(publication);

        // Verify the vault matches the publication
        assert!(object::id(vault) == vault_id, EInvalidVault);

        let id = object::new(ctx);
        let article_id = object::uid_to_inner(&id);
        let created_at = tx_context::epoch_timestamp_ms(ctx);

        let article = Article {
            id,
            publication_id,
            author,
            title,
            summary,
            blob_id,
            is_paid,
            created_at,
        };

        // Store blob in vault with Walrus metadata
        // Backend will have uploaded to Walrus and provides this data
        publication_vault::store_blob(
            vault, 
            publication, 
            blob_id, 
            blob_size,
            0u8, // encoding_type (RS erasure coding)
            0u32, // registered_epoch (current epoch)
            false, // is_deletable (permanent storage)
            is_paid, // is_encrypted (our content classification)
            ctx
        );

        event::emit(ArticlePublished {
            article_id,
            publication_id,
            author,
            title: article.title,
            blob_id,
            is_paid,
            created_at,
        });

        article
    }

    public fun publish_article(
        publication: &Publication,
        vault: &mut PublicationVault,
        title: String,
        summary: String,
        blob_id: u256,
        blob_size: u64,
        is_paid: bool,
        ctx: &mut TxContext
    ): Article {
        let author = tx_context::sender(ctx);

        // Verify author is a contributor
        assert!(publication::is_contributor(publication, author), ENotAuthorized);

        publish_article_internal(
            publication,
            vault,
            author,
            title,
            summary,
            blob_id,
            blob_size,
            is_paid,
            ctx,
        )
    }

    public fun publish_article_as_owner(
        publication: &Publication,
        vault: &mut PublicationVault,
        owner_cap: &PublicationOwnerCap,
        title: String,
        summary: String,
        blob_id: u256,
        blob_size: u64,
        is_paid: bool,
        ctx: &mut TxContext
    ): Article {
        let author = tx_context::sender(ctx);
        let publication_id = object::id(publication);

        // Verify ownership
        assert!(publication::get_publication_id(owner_cap) == publication_id, ENotAuthorized);

        publish_article_internal(
            publication,
            vault,
            author,
            title,
            summary,
            blob_id,
            blob_size,
            is_paid,
            ctx,
        )
    }

    public fun update_article(
        article: &mut Article,
        publication: &Publication,
        new_title: String,
        new_summary: String,
        ctx: &TxContext
    ) {
        let updater = tx_context::sender(ctx);
        
        // Only author can update
        assert!(article.author == updater, ENotAuthorized);

        assert!(article.publication_id == object::id(publication), EInvalidPublication);

        article.title = new_title;
        article.summary = new_summary;

        event::emit(ArticleUpdated {
            article_id: object::id(article),
            updated_by: updater,
            updated_at: tx_context::epoch_timestamp_ms(ctx),
        });
    }

    // === View Functions ===
    public fun get_article_info(article: &Article): (ID, address, String, String, u256, bool, u64) {
        (
            article.publication_id,
            article.author,
            article.title,
            article.summary,
            article.blob_id,
            article.is_paid,
            article.created_at
        )
    }

    public fun get_blob_id(article: &Article): u256 {
        article.blob_id
    }

    public fun is_paid_content(article: &Article): bool {
        article.is_paid
    }

    public fun get_author(article: &Article): address {
        article.author
    }

    public fun get_publication_id(article: &Article): ID {
        article.publication_id
    }

    public fun get_article_title(article: &Article): String {
        article.title
    }

    public fun get_created_at(article: &Article): u64 {
        article.created_at
    }
}