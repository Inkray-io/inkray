module contracts::nft;

use contracts::articles::{Self, Article};
use contracts::config::{Self, GlobalConfig};
use contracts::inkray_events;
use contracts::publication::{Self, Publication};
use std::string::{Self, String};
use sui::display;
use sui::package;
use sui::table::{Self, Table};

const E_WRONG_PUBLICATION: u64 = 501;
const E_ALREADY_MINTED:    u64 = 502;

public struct ArticleAccessNft has key, store {
    id: UID,
    article_id: ID,
    minted_at: u64,
    title: String,
    author: address,
}

public struct MintKey has copy, drop, store {
    article_id: ID,
    recipient: address,
}

public struct MintRegistry has key {
    id: UID,
    minted: Table<MintKey, bool>,
}

public struct NFT has drop {}

#[allow(lint(share_owned))]
fun init(otw: NFT, ctx: &mut TxContext) {
    let keys = vector[
        string::utf8(b"name"),
        string::utf8(b"description"),
        string::utf8(b"image_url"),
        string::utf8(b"external_url"),
        string::utf8(b"creator"),
    ];
    let values = vector[
        string::utf8(b"Article Access: {title}"),
        string::utf8(b"Permanent access NFT for gated article: {title}"),
        string::utf8(b"https://inkray.xyz/api/nft/{id}/image"),
        string::utf8(b"https://inkray.xyz/article/{article_id}"),
        string::utf8(b"{author}"),
    ];

    let publisher = package::claim(otw, ctx);
    let mut display = display::new_with_fields<ArticleAccessNft>(
        &publisher, keys, values, ctx,
    );
    display::update_version(&mut display);

    let registry = MintRegistry {
        id: object::new(ctx),
        minted: table::new<MintKey, bool>(ctx),
    };

    transfer::public_transfer(publisher, tx_context::sender(ctx));
    transfer::public_share_object(display);
    transfer::share_object(registry);
}

public fun mint(
    config: &GlobalConfig,
    recipient: address,
    article: &Article,
    publication: &Publication,
    registry: &mut MintRegistry,
    ctx: &mut TxContext,
): ArticleAccessNft {
    config::assert_version(config);
    let article_id = articles::get_article_id(article);
    assert!(
        articles::publication_id(article)
            == publication::get_publication_object_id(publication),
        E_WRONG_PUBLICATION,
    );

    let key = MintKey { article_id, recipient };
    assert!(!table::contains(&registry.minted, key), E_ALREADY_MINTED);
    table::add(&mut registry.minted, key, true);

    let (title, _slug, _pub_id, _vault_id, author, _gating)
        = articles::get_article_info(article);

    let nft_id = object::new(ctx);
    let nft_addr = object::uid_to_address(&nft_id);
    let minted_at = tx_context::epoch_timestamp_ms(ctx);
    let nft = ArticleAccessNft { id: nft_id, article_id, minted_at, title, author };
    inkray_events::emit_article_nft_minted(article_id, nft_addr, recipient);
    nft
}
