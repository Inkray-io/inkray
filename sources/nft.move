module contracts::nft;

use contracts::articles::{Self, Article};
use contracts::inkray_events;
use std::string::{Self, String};
use sui::coin::{Self, Coin};
use sui::display;
use sui::package;
use sui::sui::SUI;

// === Errors ===
const E_ONLY_GATED_CONTENT: u64 = 0;
const E_INSUFFICIENT_PAYMENT: u64 = 1;
const E_NOT_ADMIN: u64 = 2;
const E_INVALID_ARTICLE: u64 = 3;

// === Structs ===

/// Article access NFT (address-owned)
public struct ArticleAccessNft has key, store {
    id: UID,
    article: address, // bound to Article object id (as address)
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
        string::utf8(b"attributes"),
    ];

    let values = vector[
        string::utf8(b"Article Access: {title}"),
        string::utf8(b"Permanent access NFT for gated article: {title}"),
        string::utf8(b"https://inkray.app/api/nft/{id}/image"),
        string::utf8(b"https://inkray.app/article/{article}"),
        string::utf8(b"{author}"),
        string::utf8(
            b"[{\"trait_type\": \"Article\", \"value\": \"{article}\"}, {\"trait_type\": \"Type\", \"value\": \"Access NFT\"}]",
        ),
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
        base_price: 10_000_000_000, // 10 SUI in MIST
        platform_fee_percent: 10, // 10% platform fee
        admin: tx_context::sender(ctx),
    };

    transfer::public_transfer(publisher, tx_context::sender(ctx));
    transfer::public_transfer(display, tx_context::sender(ctx));
    transfer::share_object(mint_config);
}

// === Public Functions ===

/// Mint article access NFT (only for gated content)
public fun mint(
    recipient: address,
    article: &Article,
    config: &MintConfig,
    mut payment: Coin<SUI>,
    ctx: &mut TxContext,
): ArticleAccessNft {
    // Only gated content can be minted as NFT
    assert!(articles::is_gated_content(article), E_ONLY_GATED_CONTENT);

    // Check payment
    assert!(coin::value(&payment) >= config.base_price, E_INSUFFICIENT_PAYMENT);

    let article_addr = articles::get_article_address(article);
    let (title, _, _, _, author, _) = articles::get_article_info(article);

    let nft_id = object::new(ctx);
    let nft_addr = object::uid_to_address(&nft_id);
    let minted_at = tx_context::epoch_timestamp_ms(ctx);

    let nft = ArticleAccessNft {
        id: nft_id,
        article: article_addr,
        title,
        author,
        minted_at,
    };

    // Handle payment
    let payment_value = coin::value(&payment);
    let platform_fee = (payment_value * (config.platform_fee_percent as u64)) / 100;

    if (platform_fee > 0) {
        let platform_coin = coin::split(&mut payment, platform_fee, ctx);
        transfer::public_transfer(platform_coin, config.admin);
    };

    // Rest goes to author
    transfer::public_transfer(payment, author);

    // Emit event
    inkray_events::emit_article_nft_minted(
        article_addr,
        nft_addr,
        recipient,
        payment_value,
    );

    nft
}

/// Transfer NFT to recipient
public fun transfer_nft(nft: ArticleAccessNft, recipient: address, _ctx: &TxContext) {
    transfer::public_transfer(nft, recipient);
}

// === Helper Functions ===

/// Check if NFT matches article address
public fun nft_matches_article(nft: &ArticleAccessNft, article_addr: address): bool {
    nft.article == article_addr
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
public fun get_nft_info(nft: &ArticleAccessNft): (address, String, address, u64) {
    (nft.article, nft.title, nft.author, nft.minted_at)
}

/// Get article address from NFT
public fun get_article_address(nft: &ArticleAccessNft): address {
    nft.article
}

/// Get mint config info
public fun get_mint_config(config: &MintConfig): (u64, u8, address) {
    (config.base_price, config.platform_fee_percent, config.admin)
}
