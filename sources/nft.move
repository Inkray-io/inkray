module contracts::nft;

use contracts::inkray_events;
use std::string;
use sui::coin::Coin;
use sui::display;
use sui::package;
use sui::sui::SUI;



public struct ArticleAccessNft has key, store {
    id: UID,
    article_id: ID,
    minted_at: u64,
}

public struct MintConfig has key, store {
    id: UID,
    base_price: u64,
    platform_fee_percent: u8,
    admin: address,
}

public struct NFT has drop {}

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

    let mint_config = MintConfig {
        id: object::new(ctx),
        base_price: 0,
        platform_fee_percent: 10,
        admin: tx_context::sender(ctx),
    };

    transfer::public_transfer(publisher, tx_context::sender(ctx));
    transfer::public_transfer(display, tx_context::sender(ctx));
    transfer::share_object(mint_config);
}

public fun mint(
    recipient: address,
    article_id: ID,
    _config: &MintConfig,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
): ArticleAccessNft {
    transfer::public_transfer(payment, tx_context::sender(ctx));
    let nft_id = object::new(ctx);
    let nft_addr = object::uid_to_address(&nft_id);
    let minted_at = tx_context::epoch_timestamp_ms(ctx);
    let nft = ArticleAccessNft { id: nft_id, article_id, minted_at };
    inkray_events::emit_article_nft_minted(article_id, nft_addr, recipient, 0);
    nft
}

