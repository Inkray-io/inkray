module contracts::nft;

use contracts::articles::{Self, Article};
use contracts::inkray_events;
use std::string::{Self, String};
use sui::coin::Coin;
use sui::display;
use sui::package;
use sui::sui::SUI;

// === Errors ===
const E_NOT_ADMIN: u64 = 1;
const E_INVALID_ARTICLE: u64 = 2;

// === Structs ===

/// Article access NFT (address-owned)
public struct ArticleAccessNft has key, store {
    id: UID,
    article_id: ID, // bound to Article object ID
    title: String,
    author: address,
    minted_at: u64,
}

/// Minting configuration (shared)
public struct MintConfig has key, store {
    id: UID,
    base_price: u64, // base price in SUI
    platform_fee_percent: u8, // platform fee percentage
    admin: address, // admin address
}

// === One Time Witness ===
public struct NFT has drop {}

// === Init Function ===
fun init(otw: NFT, ctx: &mut TxContext) {
    // Create display template
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
        &publisher,
        keys,
        values,
        ctx,
    );
    display::update_version(&mut display);

    // Create mint config
    let mint_config = MintConfig {
        id: object::new(ctx),
        base_price: 0, // Free NFT minting
        platform_fee_percent: 10, // 10% platform fee (not used since price is 0)
        admin: tx_context::sender(ctx),
    };

    transfer::public_transfer(publisher, tx_context::sender(ctx));
    transfer::public_transfer(display, tx_context::sender(ctx));
    transfer::share_object(mint_config);
}

// === Public Functions ===

/// Mint article access NFT for any article - Now free!
public fun mint(
    recipient: address,
    article: &Article,
    _config: &MintConfig,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
): ArticleAccessNft {
    // Any article can now be minted as NFT

    // NFT minting is now free - return payment to sender
    transfer::public_transfer(payment, tx_context::sender(ctx));

    let article_id = articles::get_article_id(article);
    let (title, _, _, _, author, _) = articles::get_article_info(article);

    let nft_id = object::new(ctx);
    let nft_addr = object::uid_to_address(&nft_id);
    let minted_at = tx_context::epoch_timestamp_ms(ctx);

    let nft = ArticleAccessNft {
        id: nft_id,
        article_id,
        title,
        author,
        minted_at,
    };

    // Emit event (with 0 payment value since it's free)
    inkray_events::emit_article_nft_minted(
        article_id,
        nft_addr,
        recipient,
        0, // Free minting
    );

    nft
}

/// Transfer NFT to recipient
public fun transfer_nft(nft: ArticleAccessNft, recipient: address, _ctx: &TxContext) {
    transfer::public_transfer(nft, recipient);
}

// === Helper Functions ===

/// Check if NFT matches article ID
public fun nft_matches_article(nft: &ArticleAccessNft, article_id: ID): bool {
    nft.article_id == article_id
}

// === Admin Functions ===

/// Update mint configuration
public fun update_mint_config(
    config: &mut MintConfig,
    new_base_price: u64,
    new_platform_fee_percent: u8,
    ctx: &TxContext,
) {
    assert!(tx_context::sender(ctx) == config.admin, E_NOT_ADMIN);
    assert!(new_platform_fee_percent <= 100, E_INVALID_ARTICLE);

    config.base_price = new_base_price;
    config.platform_fee_percent = new_platform_fee_percent;
}

// === View Functions ===

/// Get NFT info
public fun get_nft_info(nft: &ArticleAccessNft): (ID, String, address, u64) {
    (nft.article_id, nft.title, nft.author, nft.minted_at)
}

/// Get article ID from NFT
public fun get_article_id(nft: &ArticleAccessNft): ID {
    nft.article_id
}

/// Get mint config info
public fun get_mint_config(config: &MintConfig): (u64, u8, address) {
    (config.base_price, config.platform_fee_percent, config.admin)
}
