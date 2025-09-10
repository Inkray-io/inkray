module contracts::policy {
    use sui::bcs::{Self, BCS};
    use sui::clock::Clock;
    use contracts::publication::{Self, Publication};
    use contracts::articles::{Self, Article};
    use contracts::subscription::{Self, Subscription};
    use contracts::nft::{Self, ArticleAccessNft};

    // === Constants ===
    const TAG_ARTICLE_CONTENT: u8 = 0;
    const ID_VERSION_V1: u16 = 1;

    // === Errors ===
    const E_BAD_ID: u64 = 10;
    const E_TRAILING: u64 = 11;
    const E_WRONG_TAG: u64 = 12;
    const E_WRONG_VERSION: u64 = 13;
    const E_ACCESS_DENIED: u64 = 14;

    // === Structs ===
    public struct IdV1 has store, drop {
        tag: u8,              // = TAG_ARTICLE_CONTENT
        version: u16,         // = ID_VERSION_V1
        publication: address, // publication object id as address
        article: address,     // article object id as address
        nonce: u64,           // uniqueness; avoid identity reuse
    }

    // === BCS Parsing Functions ===
    
    /// Parse IdV1 with strict validation (no trailing bytes)
    public fun parse_id_v1(id: &vector<u8>): IdV1 {
        let mut cur: BCS = bcs::new(*id);
        let tag = bcs::peel_u8(&mut cur);
        let version = bcs::peel_u16(&mut cur);
        let publication = bcs::peel_address(&mut cur);
        let article = bcs::peel_address(&mut cur);
        let nonce = bcs::peel_u64(&mut cur);
        let rest = bcs::into_remainder_bytes(cur);
        
        // Strict validation
        assert!(vector::length(&rest) == 0, E_TRAILING);
        assert!(tag == TAG_ARTICLE_CONTENT, E_WRONG_TAG);
        assert!(version == ID_VERSION_V1, E_WRONG_VERSION);
        
        IdV1 { tag, version, publication, article, nonce }
    }

    // === Seal Policy Functions ===
    // All functions start with "seal_approve" and take id: vector<u8> as first parameter
    
    /// Free content access - anyone can access
    public fun seal_approve_free(
        id: vector<u8>,
        article: &Article
    ) {
        let p = parse_id_v1(&id);
        assert!(p.article == articles::get_article_address(article), E_BAD_ID);
        assert!(articles::is_free_content(article), E_ACCESS_DENIED);
    }

    /// NFT holder access - must own the article NFT
    public fun seal_approve_nft(
        id: vector<u8>,
        access_nft: &ArticleAccessNft
    ) {
        let p = parse_id_v1(&id);
        assert!(nft::nft_matches_article(access_nft, p.article), E_ACCESS_DENIED);
    }

    /// Publication roles access - owner or contributor
    public fun seal_approve_roles(
        id: vector<u8>,
        publication: &Publication,
        ctx: &TxContext
    ) {
        let p = parse_id_v1(&id);
        assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);
        let who = tx_context::sender(ctx);
        
        // Check if sender is contributor (owner access requires capability)
        assert!(publication::is_contributor(publication, who), E_ACCESS_DENIED);
    }

    /// Platform subscription access - must have active subscription
    public fun seal_approve_subscription(
        id: vector<u8>,
        sub: &Subscription,
        clock: &Clock
    ) {
        let _p = parse_id_v1(&id);
        assert!(subscription::is_valid(sub, clock), E_ACCESS_DENIED);
    }

    /// Composite approval (optional) - tries free, then roles only
    /// Keeps arg list minimal by excluding NFT and subscription paths
    public fun seal_approve_any(
        id: vector<u8>,
        publication: &Publication,
        article: &Article,
        ctx: &TxContext
    ) {
        let p = parse_id_v1(&id);
        assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);
        assert!(p.article == articles::get_article_address(article), E_BAD_ID);
        
        // Try free content first
        if (articles::is_free_content(article)) return;
        
        // Try contributor role (owner access requires capability)
        let who = tx_context::sender(ctx);
        assert!(publication::is_contributor(publication, who), E_ACCESS_DENIED);
    }

    // === View Functions ===
    public fun get_constants(): (u8, u16) {
        (TAG_ARTICLE_CONTENT, ID_VERSION_V1)
    }

    public fun get_tag_article_content(): u8 {
        TAG_ARTICLE_CONTENT
    }

    public fun get_id_version_v1(): u16 {
        ID_VERSION_V1
    }

    public fun get_id_v1_fields(id: &IdV1): (u8, u16, address, address, u64) {
        (id.tag, id.version, id.publication, id.article, id.nonce)
    }

    public fun validate_id_format(id: &vector<u8>): bool {
        // Basic size check first
        if (vector::length(id) < 1 + 2 + 32 + 32 + 8) {  // tag + version + pub + article + nonce
            return false
        };
        
        // In a real implementation, you'd want proper error handling here
        // For now, we'll assume proper validation is done by parse_id_v1
        true
    }
}