module contracts::policy;

use contracts::articles::{Self, Article, PostArticleCap};
use contracts::config::{Self, GlobalConfig};
use contracts::nft::ArticleAccessNft;
use contracts::publication::{Self, Publication, PublicationOwnerCap};
use contracts::publication_subscription::{Self, PublicationSubscription};
use sui::bcs::{Self, BCS};
use sui::clock::Clock;

const TAG_ARTICLE_CONTENT: u8 = 0;
const ID_VERSION_V1: u16 = 1;

const E_BAD_ID: u64 = 601;
const E_TRAILING: u64 = 602;
const E_WRONG_TAG: u64 = 603;
const E_WRONG_VERSION: u64 = 604;
const E_ACCESS_DENIED: u64 = 605;

public struct IdV1 has drop, store {
    tag: u8,
    version: u16,
    publication: address,
    nonce: u64,
}

public fun parse_id_v1(id: &vector<u8>): IdV1 {
    let mut cur: BCS = bcs::new(*id);
    let tag = bcs::peel_u8(&mut cur);
    let version = bcs::peel_u16(&mut cur);
    let publication = bcs::peel_address(&mut cur);
    let nonce = bcs::peel_u64(&mut cur);
    let rest = bcs::into_remainder_bytes(cur);
    assert!(vector::length(&rest) == 0, E_TRAILING);
    assert!(tag == TAG_ARTICLE_CONTENT, E_WRONG_TAG);
    assert!(version == ID_VERSION_V1, E_WRONG_VERSION);
    IdV1 { tag, version, publication, nonce }
}

// === Seal Policy Functions ===

// NOTE on argument order: Seal protocol requires `id: vector<u8>` to be the FIRST
// parameter of every `seal_approve_*` function. The `config: &GlobalConfig`
// version-gating arg therefore comes second, followed by the policy-specific args.

entry fun seal_approve_free(
    id: vector<u8>,
    config: &GlobalConfig,
    publication: &Publication,
) {
    config::assert_version(config);
    let p = parse_id_v1(&id);
    assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);
    assert!(!publication::requires_subscription(publication), E_ACCESS_DENIED);
}

entry fun seal_approve_platform(
    id: vector<u8>,
    config: &GlobalConfig,
    _: &PostArticleCap,
) {
    config::assert_version(config);
    let _p = parse_id_v1(&id);
}

entry fun seal_approve_roles(
    id: vector<u8>,
    config: &GlobalConfig,
    publication: &Publication,
    ctx: &TxContext,
) {
    config::assert_version(config);
    let p = parse_id_v1(&id);
    assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);
    let who = tx_context::sender(ctx);
    assert!(publication::is_contributor(publication, who), E_ACCESS_DENIED);
}

entry fun seal_approve_publication_subscription(
    id: vector<u8>,
    config: &GlobalConfig,
    pub_subscription: &PublicationSubscription,
    publication: &Publication,
    clock: &Clock,
    ctx: &TxContext,
) {
    config::assert_version(config);
    let p = parse_id_v1(&id);
    assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);
    let caller = tx_context::sender(ctx);
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

entry fun seal_approve_publication_owner(
    id: vector<u8>,
    config: &GlobalConfig,
    owner_cap: &PublicationOwnerCap,
    publication: &Publication,
) {
    config::assert_version(config);
    let p = parse_id_v1(&id);
    assert!(p.publication == publication::get_publication_address(publication), E_BAD_ID);
    assert!(
        publication::get_owner_cap_publication_id(owner_cap).to_address() == publication::get_publication_address(publication),
        E_ACCESS_DENIED,
    );
}

// === View Functions ===

public fun get_constants(): (u8, u16) {
    (TAG_ARTICLE_CONTENT, ID_VERSION_V1)
}

public fun get_id_v1_fields(id: &IdV1): (u8, u16, address, u64) {
    (id.tag, id.version, id.publication, id.nonce)
}
