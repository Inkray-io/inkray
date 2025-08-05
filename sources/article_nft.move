module contracts::article_nft {
    use contracts::content_registry::{Self, Article};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::display;
    use sui::package;
    use sui::event;
    use std::string::{Self, String};

    // === Errors ===
    const EOnlyPaidContent: u64 = 0;
    const EInsufficientPayment: u64 = 1;
    const ENotOwner: u64 = 2;
    const EInvalidRoyalty: u64 = 3;
    const EInvalidFeePercent: u64 = 4;

    // === Structs ===
    public struct ArticleNFT has key, store {
        id: UID,
        article_id: ID,
        publication_id: ID,
        title: String,
        author: address,
        blob_id: u256,
        minted_at: u64,
        royalty_percent: u8,
    }

    public struct MintConfig has key, store {
        id: UID,
        base_price: u64,
        max_royalty: u8,
        platform_fee_percent: u8,
        treasury: address,
    }

    // One time witness
    public struct ARTICLE_NFT has drop {}

    // === Events ===
    public struct ArticleNFTMinted has copy, drop {
        nft_id: ID,
        article_id: ID,
        publication_id: ID,
        owner: address,
        price_paid: u64,
        royalty_percent: u8,
        minted_at: u64,
    }

    public struct NFTTransferred has copy, drop {
        nft_id: ID,
        from: address,
        to: address,
        price: Option<u64>,
    }

    public struct MintConfigUpdated has copy, drop {
        config_id: ID,
        new_base_price: u64,
        new_max_royalty: u8,
        new_platform_fee_percent: u8,
        updated_by: address,
    }

    // === Init Function ===
    fun init(otw: ARTICLE_NFT, ctx: &mut TxContext) {
        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"description"),
            string::utf8(b"image_url"),
            string::utf8(b"external_url"),
            string::utf8(b"creator"),
            string::utf8(b"attributes"),
        ];

        let values = vector[
            string::utf8(b"{title}"),
            string::utf8(b"NFT for permanent access to premium article: {title}"),
            string::utf8(b"https://inkray.app/api/nft/{id}/image"),
            string::utf8(b"https://inkray.app/article/{article_id}"),
            string::utf8(b"{author}"),
            string::utf8(b"[{\"trait_type\": \"Article ID\", \"value\": \"{article_id}\"}, {\"trait_type\": \"Publication\", \"value\": \"{publication_id}\"}, {\"trait_type\": \"Royalty\", \"value\": \"{royalty_percent}%\"}]"),
        ];

        let publisher = package::claim(otw, ctx);
        let mut display = display::new_with_fields<ArticleNFT>(
            &publisher, keys, values, ctx
        );
        display::update_version(&mut display);

        let mint_config = MintConfig {
            id: object::new(ctx),
            base_price: 5_000_000_000, // 5 SUI in MIST
            max_royalty: 20, // 20% max royalty
            platform_fee_percent: 5, // 5% platform fee
            treasury: tx_context::sender(ctx),
        };

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
        transfer::share_object(mint_config);
    }

    // === Public Functions ===
    public fun mint_article_nft(
        article: &Article,
        config: &MintConfig,
        mut payment: Coin<SUI>,
        royalty_percent: u8,
        ctx: &mut TxContext
    ): ArticleNFT {
        // Only paid content can be minted as NFT
        assert!(content_registry::is_paid_content(article), EOnlyPaidContent);
        
        let payment_amount = coin::value(&payment);
        assert!(payment_amount >= config.base_price, EInsufficientPayment);
        assert!(royalty_percent <= config.max_royalty, EInvalidRoyalty);

        let minter = tx_context::sender(ctx);
        let (publication_id, author, title, _, blob_id, _, _) = content_registry::get_article_info(article);
        let article_id = object::id(article);
        
        let id = object::new(ctx);
        let nft_id = object::uid_to_inner(&id);
        let minted_at = tx_context::epoch_timestamp_ms(ctx);

        let nft = ArticleNFT {
            id,
            article_id,
            publication_id,
            title,
            author,
            blob_id,
            minted_at,
            royalty_percent,
        };

        // Calculate fees
        let platform_fee = (payment_amount * (config.platform_fee_percent as u64)) / 100;

        // Split payment
        if (platform_fee > 0) {
            let platform_coin = coin::split(&mut payment, platform_fee, ctx);
            transfer::public_transfer(platform_coin, config.treasury);
        };
        
        transfer::public_transfer(payment, author);

        event::emit(ArticleNFTMinted {
            nft_id,
            article_id,
            publication_id,
            owner: minter,
            price_paid: payment_amount,
            royalty_percent,
            minted_at,
        });

        nft
    }

    public fun transfer_nft(
        nft: ArticleNFT,
        recipient: address,
        ctx: &TxContext
    ) {
        let nft_id = object::id(&nft);
        let from = tx_context::sender(ctx);

        transfer::public_transfer(nft, recipient);

        event::emit(NFTTransferred {
            nft_id,
            from,
            to: recipient,
            price: option::none(),
        });
    }

    // === Seal Approval Function ===
    // This function is called by Seal to verify NFT ownership for premium content access
    public fun seal_approve_article_nft(
        _identity: vector<u8>,
        article_nft: &ArticleNFT,
        article: &Article,
        _ctx: &TxContext
    ) {
        // Verify the NFT is for the requested article
        assert!(article_nft.article_id == object::id(article), ENotOwner);
        // Verify the caller owns the NFT (implicit through object ownership)
        // This check happens automatically in Sui's object model
    }

    // === View Functions ===
    public fun get_nft_info(nft: &ArticleNFT): (ID, ID, String, address, u256, u64, u8) {
        (
            nft.article_id,
            nft.publication_id,
            nft.title,
            nft.author,
            nft.blob_id,
            nft.minted_at,
            nft.royalty_percent
        )
    }

    public fun get_article_id(nft: &ArticleNFT): ID {
        nft.article_id
    }

    public fun get_blob_id(nft: &ArticleNFT): u256 {
        nft.blob_id
    }

    public fun get_royalty_percent(nft: &ArticleNFT): u8 {
        nft.royalty_percent
    }

    public fun get_mint_config(config: &MintConfig): (u64, u8, u8, address) {
        (config.base_price, config.max_royalty, config.platform_fee_percent, config.treasury)
    }

    // === Admin Functions ===
    public fun update_mint_config(
        config: &mut MintConfig,
        new_base_price: u64,
        new_max_royalty: u8,
        new_platform_fee_percent: u8,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == config.treasury, ENotOwner);
        assert!(new_max_royalty <= 100, EInvalidRoyalty);
        assert!(new_platform_fee_percent <= 100, EInvalidFeePercent);

        config.base_price = new_base_price;
        config.max_royalty = new_max_royalty;
        config.platform_fee_percent = new_platform_fee_percent;

        event::emit(MintConfigUpdated {
            config_id: object::id(config),
            new_base_price,
            new_max_royalty,
            new_platform_fee_percent,
            updated_by: tx_context::sender(ctx),
        });
    }
}