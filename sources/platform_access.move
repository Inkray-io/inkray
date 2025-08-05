module contracts::platform_access {
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::event;

    // === Errors ===
    const ESubscriptionExpired: u64 = 0;
    const ENotSubscriber: u64 = 1;
    const EInsufficientPayment: u64 = 2;
    const ENotOwner: u64 = 3;

    // === Structs ===
    public struct PlatformSubscription has key {
        id: UID,
        subscriber: address,
        expires_at: u64,
        tier: u8,
    }

    public struct PlatformService has key {
        id: UID,
        monthly_fee: u64,
        time_to_live: u64,
        owner: address,
    }

    // === Events ===
    public struct SubscriptionCreated has copy, drop {
        subscription_id: ID,
        subscriber: address,
        expires_at: u64,
        tier: u8,
        price_paid: u64,
    }

    public struct ServiceUpdated has copy, drop {
        service_id: ID,
        new_monthly_fee: u64,
        new_time_to_live: u64,
        updated_by: address,
    }

    public struct SubscriptionExtended has copy, drop {
        subscription_id: ID,
        subscriber: address,
        old_expires_at: u64,
        new_expires_at: u64,
        price_paid: u64,
        extended_at: u64,
    }

    public struct SubscriptionRenewed has copy, drop {
        subscription_id: ID,
        subscriber: address,
        old_expires_at: u64,
        new_expires_at: u64,
        price_paid: u64,
        renewed_at: u64,
    }

    // === Admin Functions ===
    fun init(ctx: &mut TxContext) {
        let platform_service = PlatformService {
            id: object::new(ctx),
            monthly_fee: 10_000_000_000, // 10 SUI in MIST
            time_to_live: 30 * 24 * 60 * 60 * 1000, // 30 days in milliseconds
            owner: tx_context::sender(ctx),
        };
        
        transfer::share_object(platform_service);
    }

    // === Public Functions ===
    public fun subscribe_to_platform(
        service: &PlatformService,
        payment: Coin<SUI>,
        tier: u8,
        clock: &Clock,
        ctx: &mut TxContext
    ): PlatformSubscription {
        let payment_amount = coin::value(&payment);
        assert!(payment_amount >= service.monthly_fee, EInsufficientPayment);

        let subscriber = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);
        let expires_at = current_time + service.time_to_live;

        let id = object::new(ctx);
        let subscription_id = object::uid_to_inner(&id);

        let subscription = PlatformSubscription {
            id,
            subscriber,
            expires_at,
            tier,
        };

        // Transfer payment to service owner
        transfer::public_transfer(payment, service.owner);

        event::emit(SubscriptionCreated {
            subscription_id,
            subscriber,
            expires_at,
            tier,
            price_paid: payment_amount,
        });

        subscription
    }

    public fun update_service(
        service: &mut PlatformService,
        new_monthly_fee: u64,
        new_time_to_live: u64,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == service.owner, ENotOwner);
        
        service.monthly_fee = new_monthly_fee;
        service.time_to_live = new_time_to_live;

        event::emit(ServiceUpdated {
            service_id: object::id(service),
            new_monthly_fee,
            new_time_to_live,
            updated_by: tx_context::sender(ctx),
        });
    }

    public fun extend_subscription(
        subscription: &mut PlatformSubscription,
        service: &PlatformService,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &TxContext
    ) {
        let payment_amount = coin::value(&payment);
        assert!(payment_amount >= service.monthly_fee, EInsufficientPayment);
        assert!(subscription.subscriber == tx_context::sender(ctx), ENotSubscriber);
        
        let current_time = clock::timestamp_ms(clock);
        let old_expires_at = subscription.expires_at;
        
        // Extend from current expiry date (even if already expired)
        let new_expires_at = subscription.expires_at + service.time_to_live;
        subscription.expires_at = new_expires_at;
        
        // Transfer payment to service owner
        transfer::public_transfer(payment, service.owner);
        
        // Emit extension event
        event::emit(SubscriptionExtended {
            subscription_id: object::id(subscription),
            subscriber: subscription.subscriber,
            old_expires_at,
            new_expires_at,
            price_paid: payment_amount,
            extended_at: current_time,
        });
    }

    public fun renew_subscription(
        subscription: &mut PlatformSubscription,
        service: &PlatformService,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &TxContext
    ) {
        let payment_amount = coin::value(&payment);
        assert!(payment_amount >= service.monthly_fee, EInsufficientPayment);
        assert!(subscription.subscriber == tx_context::sender(ctx), ENotSubscriber);
        
        let current_time = clock::timestamp_ms(clock);
        let old_expires_at = subscription.expires_at;
        
        // Set new expiry from current time (fresh start)
        let new_expires_at = current_time + service.time_to_live;
        subscription.expires_at = new_expires_at;
        
        // Transfer payment to service owner
        transfer::public_transfer(payment, service.owner);
        
        // Emit renewal event
        event::emit(SubscriptionRenewed {
            subscription_id: object::id(subscription),
            subscriber: subscription.subscriber,
            old_expires_at,
            new_expires_at,
            price_paid: payment_amount,
            renewed_at: current_time,
        });
    }

    // === Seal Approval Functions ===
    // These functions are called by Seal to verify access to encrypted content

    public fun seal_approve_platform_subscription(
        _identity: vector<u8>,
        subscription: &PlatformSubscription,
        clock: &Clock,
        ctx: &TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time < subscription.expires_at, ESubscriptionExpired);
        assert!(subscription.subscriber == tx_context::sender(ctx), ENotSubscriber);
    }

    // === View Functions ===
    public fun is_subscription_active(
        subscription: &PlatformSubscription,
        clock: &Clock
    ): bool {
        let current_time = clock::timestamp_ms(clock);
        current_time < subscription.expires_at
    }

    public fun get_subscription_info(subscription: &PlatformSubscription): (address, u64, u8) {
        (subscription.subscriber, subscription.expires_at, subscription.tier)
    }

    public fun get_service_info(service: &PlatformService): (u64, u64, address) {
        (service.monthly_fee, service.time_to_live, service.owner)
    }

    public fun time_until_expiry(
        subscription: &PlatformSubscription,
        clock: &Clock
    ): u64 {
        let current_time = clock::timestamp_ms(clock);
        if (current_time >= subscription.expires_at) {
            0
        } else {
            subscription.expires_at - current_time
        }
    }

    public fun is_subscription_expired(
        subscription: &PlatformSubscription,
        clock: &Clock
    ): bool {
        let current_time = clock::timestamp_ms(clock);
        current_time >= subscription.expires_at
    }

    public fun should_extend_or_renew(
        subscription: &PlatformSubscription,
        clock: &Clock
    ): u8 {
        let current_time = clock::timestamp_ms(clock);
        if (current_time >= subscription.expires_at) {
            2 // Should renew (expired)
        } else if (subscription.expires_at - current_time <= 7 * 24 * 60 * 60 * 1000) {
            1 // Should extend (expires within 7 days)
        } else {
            0 // No action needed
        }
    }
}