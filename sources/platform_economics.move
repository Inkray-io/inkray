module contracts::platform_economics {
    use contracts::content_registry::{Self, Article};
    use contracts::publication::{Publication, PublicationOwnerCap};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::event;
    use std::string::String;

    // === Errors ===
    const EInsufficientAmount: u64 = 0;
    const ENotOwner: u64 = 1;
    const EInvalidWithdrawal: u64 = 2;
    const ENoFundsAvailable: u64 = 3;

    // === Structs ===
    public struct CreatorTreasury has key, store {
        id: UID,
        publication_id: ID,
        balance: Balance<SUI>,
        owner: address,
        total_tips_received: u64,
        total_earnings: u64,
    }

    public struct PlatformTreasury has key, store {
        id: UID,
        balance: Balance<SUI>,
        owner: address,
        total_fees_collected: u64,
    }

    // === Events ===
    public struct TipSent has copy, drop {
        article_id: ID,
        publication_id: ID,
        tipper: address,
        recipient: address,
        amount: u64,
        message: String,
        timestamp: u64,
    }

    public struct CreatorWithdrawal has copy, drop {
        publication_id: ID,
        creator: address,
        amount: u64,
        timestamp: u64,
    }

    public struct TreasuryCreated has copy, drop {
        treasury_id: ID,
        publication_id: ID,
        owner: address,
    }

    public struct EarningsAdded has copy, drop {
        publication_id: ID,
        amount: u64,
        source: String,
    }

    // === Admin Functions ===
    fun init(ctx: &mut TxContext) {
        let platform_treasury = PlatformTreasury {
            id: object::new(ctx),
            balance: balance::zero(),
            owner: tx_context::sender(ctx),
            total_fees_collected: 0,
        };
        
        transfer::share_object(platform_treasury);
    }

    // === Public Functions ===
    public fun create_creator_treasury(
        publication: &Publication,
        owner_cap: &PublicationOwnerCap,
        ctx: &mut TxContext
    ): CreatorTreasury {
        let publication_id = object::id(publication);
        assert!(contracts::publication::get_publication_id(owner_cap) == publication_id, ENotOwner);

        let id = object::new(ctx);
        let treasury_id = object::uid_to_inner(&id);
        let owner = tx_context::sender(ctx);

        let treasury = CreatorTreasury {
            id,
            publication_id,
            balance: balance::zero(),
            owner,
            total_tips_received: 0,
            total_earnings: 0,
        };

        event::emit(TreasuryCreated {
            treasury_id,
            publication_id,
            owner,
        });

        treasury
    }

    public fun tip_article(
        article: &Article,
        treasury: &mut CreatorTreasury,
        tip: Coin<SUI>,
        message: String,
        ctx: &TxContext
    ) {
        let tip_amount = coin::value(&tip);
        assert!(tip_amount > 0, EInsufficientAmount);

        let article_id = object::id(article);
        let publication_id = content_registry::get_publication_id(article);
        assert!(treasury.publication_id == publication_id, ENotOwner);

        let tipper = tx_context::sender(ctx);
        let recipient = content_registry::get_author(article);

        // Add tip to treasury
        let tip_balance = coin::into_balance(tip);
        balance::join(&mut treasury.balance, tip_balance);
        treasury.total_tips_received = treasury.total_tips_received + tip_amount;

        event::emit(TipSent {
            article_id,
            publication_id,
            tipper,
            recipient,
            amount: tip_amount,
            message,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });
    }

    public fun add_earnings(
        treasury: &mut CreatorTreasury,
        earnings: Coin<SUI>,
        source: String,
        _ctx: &TxContext
    ) {
        let amount = coin::value(&earnings);
        let earnings_balance = coin::into_balance(earnings);
        
        balance::join(&mut treasury.balance, earnings_balance);
        treasury.total_earnings = treasury.total_earnings + amount;

        event::emit(EarningsAdded {
            publication_id: treasury.publication_id,
            amount,
            source,
        });
    }

    public fun withdraw_funds(
        treasury: &mut CreatorTreasury,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<SUI> {
        assert!(tx_context::sender(ctx) == treasury.owner, ENotOwner);
        assert!(balance::value(&treasury.balance) >= amount, EInsufficientAmount);
        assert!(amount > 0, EInvalidWithdrawal);

        let withdrawn_balance = balance::split(&mut treasury.balance, amount);
        let withdrawn_coin = coin::from_balance(withdrawn_balance, ctx);

        event::emit(CreatorWithdrawal {
            publication_id: treasury.publication_id,
            creator: treasury.owner,
            amount,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        withdrawn_coin
    }

    public fun withdraw_all_funds(
        treasury: &mut CreatorTreasury,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let total_balance = balance::value(&treasury.balance);
        assert!(total_balance > 0, ENoFundsAvailable);
        
        withdraw_funds(treasury, total_balance, ctx)
    }

    // === Platform Treasury Functions ===
    public fun add_platform_fees(
        platform_treasury: &mut PlatformTreasury,
        fees: Coin<SUI>,
        _ctx: &TxContext
    ) {
        let fee_amount = coin::value(&fees);
        let fee_balance = coin::into_balance(fees);
        
        balance::join(&mut platform_treasury.balance, fee_balance);
        platform_treasury.total_fees_collected = platform_treasury.total_fees_collected + fee_amount;
    }

    public fun withdraw_platform_funds(
        platform_treasury: &mut PlatformTreasury,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<SUI> {
        assert!(tx_context::sender(ctx) == platform_treasury.owner, ENotOwner);
        assert!(balance::value(&platform_treasury.balance) >= amount, EInsufficientAmount);

        let withdrawn_balance = balance::split(&mut platform_treasury.balance, amount);
        coin::from_balance(withdrawn_balance, ctx)
    }

    // === View Functions ===
    public fun get_treasury_balance(treasury: &CreatorTreasury): u64 {
        balance::value(&treasury.balance)
    }

    public fun get_treasury_stats(treasury: &CreatorTreasury): (u64, u64, u64) {
        (
            balance::value(&treasury.balance),
            treasury.total_tips_received,
            treasury.total_earnings
        )
    }

    public fun get_platform_treasury_stats(platform_treasury: &PlatformTreasury): (u64, u64) {
        (
            balance::value(&platform_treasury.balance),
            platform_treasury.total_fees_collected
        )
    }

    public fun get_treasury_owner(treasury: &CreatorTreasury): address {
        treasury.owner
    }

    public fun get_treasury_publication(treasury: &CreatorTreasury): ID {
        treasury.publication_id
    }
}