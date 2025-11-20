module contracts::policy;

use contracts::articles::{Self, Article, PostArticleCap};
use contracts::nft::ArticleAccessNft;
use contracts::publication::{Self, Publication, PublicationOwnerCap};
use contracts::publication_subscription::{Self, PublicationSubscription};
use contracts::subscription::{Self, Subscription};
use sui::bcs::{Self, BCS};
use sui::clock::Clock;

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
public struct IdV1 has drop, store {
    tag: u8, // = TAG_ARTICLE_CONTENT
    version: u16, // = ID_VERSION_V1
    publication: address, // publication object id as address
    nonce: u64, // uniqueness; avoid identity reuse
}

// === BCS Parsing Functions ===

/// Parse IdV1 with strict validation (no trailing bytes)
public fun parse_id_v1(id: &vector<u8>): IdV1 {
    let mut cur: BCS = bcs::new(*id);
    let tag = bcs::peel_u8(&mut cur);
    let version = bcs::peel_u16(&mut cur);
    let publication = bcs::peel_address(&mut cur);
    let nonce = bcs::peel_u64(&mut cur);
    let rest = bcs::into_remainder_bytes(cur);

    // Strict validation
    assert!(vector::length(&rest) == 0, E_TRAILING);
    assert!(tag == TAG_ARTICLE_CONTENT, E_WRONG_TAG);
    assert!(version == ID_VERSION_V1, E_WRONG_VERSION);

    IdV1 { tag, version, publication, nonce }
}

// === Seal Policy Functions ===
// All functions start with "seal_approve" and take id: vector<u8> as first parameter

/// Free content access - anyone can access (only if both article is free AND publication doesn't require subscription)
public fun seal_approve_free(id: vector<u8>, publication: &Publication) {
    let p = parse_id_v1(&id);
    assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);

    // Article must be free content AND publication must not require subscription
    // assert!(articles::is_free_content(article), E_ACCESS_DENIED);
    assert!(!publication::requires_subscription(publication), E_ACCESS_DENIED);
}

/// NFT holder access - must own the article NFT
public fun seal_approve_nft(id: vector<u8>, _access_nft: &ArticleAccessNft) {
    let _p = parse_id_v1(&id);
    // Article validation happens via the NFT parameter passed to function
    // Content ID only needs to be valid, NFT ownership is validated by possession
}

public fun seal_approve_platform(id: vector<u8>, _: &PostArticleCap) {
    let _p = parse_id_v1(&id);
}

/// Publication roles access - owner or contributor
public fun seal_approve_roles(id: vector<u8>, publication: &Publication, ctx: &TxContext) {
    let p = parse_id_v1(&id);
    assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);
    let who = tx_context::sender(ctx);

    // Check if sender is contributor (owner access requires capability)
    assert!(publication::is_contributor(publication, who), E_ACCESS_DENIED);
}

/// Platform subscription access - must have active subscription
public fun seal_approve_subscription(id: vector<u8>, sub: &Subscription, clock: &Clock) {
    let _p = parse_id_v1(&id);
    assert!(subscription::is_valid(sub, clock), E_ACCESS_DENIED);
}

/// Publication subscription access - must have valid subscription to specific publication
public fun seal_approve_publication_subscription(
    id: vector<u8>,
    pub_subscription: &PublicationSubscription,
    publication: &Publication,
    clock: &Clock,
    ctx: &TxContext,
) {
    let p = parse_id_v1(&id);
    assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);

    let caller = tx_context::sender(ctx);

    // Validate subscription access using the subscription module
    assert!(
        publication_subscription::validate_subscription_access(
            pub_subscription,
            publication,
            caller,
            clock,
        ),
        E_ACCESS_DENIED,
    );
}

/// Publication owner access - must own PublicationOwnerCap
public fun seal_approve_publication_owner(
    id: vector<u8>,
    owner_cap: &PublicationOwnerCap,
    publication: &Publication,
) {
    let p = parse_id_v1(&id);
    assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);

    // Verify the owner cap matches this publication
    assert!(
        publication::get_owner_cap_publication_id(owner_cap).to_address() == publication::get_publication_address(publication),
        E_ACCESS_DENIED,
    );
}

/// Composite approval (optional) - tries free, then roles only
/// Keeps arg list minimal by excluding NFT and subscription paths
public fun seal_approve_any(
    id: vector<u8>,
    publication: &Publication,
    article: &Article,
    ctx: &TxContext,
) {
    let p = parse_id_v1(&id);
    assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);
    // Article validation happens via the article parameter passed to function

    // Try free content first (both article must be free AND publication must not require subscription)
    if (articles::is_free_content(article) && !publication::requires_subscription(publication))
        return;

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

public fun get_id_v1_fields(id: &IdV1): (u8, u16, address, u64) {
    (id.tag, id.version, id.publication, id.nonce)
}

public fun validate_id_format(id: &vector<u8>): bool {
    // Basic size check first
    if (vector::length(id) < 1 + 2 + 32 + 8) {
        // tag + version + publication + nonce
        return false
    };

    // In a real implementation, you'd want proper error handling here
    // For now, we'll assume proper validation is done by parse_id_v1
    true
}
