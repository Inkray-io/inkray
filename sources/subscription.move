module contracts::subscription {
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use contracts::inkray_events;

    const E_INSUFFICIENT_PAYMENT: u64 = 0;
    const E_INVALID_PLAN: u64 = 1;
    const E_NOT_SUBSCRIBER: u64 = 3;

    public struct Subscription has key, store {
        id: UID,
        holder: address,
        plan: u8,
        expires_ms: u64,
        version: u16,
    }

    public struct PlatformService has key, store {
        id: UID,
        monthly_fees: vector<u64>,
        duration_ms: u64,
        admin: address,
    }

    fun init(ctx: &mut TxContext) {
        let service = PlatformService {
            id: object::new(ctx),
            monthly_fees: vector[5_000_000_000, 10_000_000_000, 20_000_000_000],
            duration_ms: 30 * 24 * 60 * 60 * 1000,
            admin: tx_context::sender(ctx),
        };
        transfer::share_object(service);
    }

    public fun mint_platform(
        service: &PlatformService,
        plan: u8,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Subscription {
        assert!((plan as u64) < vector::length(&service.monthly_fees), E_INVALID_PLAN);
        let required_fee = *vector::borrow(&service.monthly_fees, (plan as u64));
        assert!(coin::value(&payment) >= required_fee, E_INSUFFICIENT_PAYMENT);

        let holder = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);
        let expires_ms = current_time + service.duration_ms;
        let subscription_id = object::new(ctx);
        let subscription_addr = object::uid_to_address(&subscription_id);

        let subscription = Subscription {
            id: subscription_id, holder, plan, expires_ms, version: 1,
        };

        transfer::public_transfer(payment, service.admin);
        inkray_events::emit_subscription_minted(holder, subscription_addr, plan, expires_ms);
        subscription
    }

    public fun extend(
        subscription: &mut Subscription,
        service: &PlatformService,
        payment: Coin<SUI>,
        _clock: &Clock,
        ctx: &TxContext,
    ) {
        assert!(subscription.holder == tx_context::sender(ctx), E_NOT_SUBSCRIBER);
        let required_fee = *vector::borrow(&service.monthly_fees, (subscription.plan as u64));
        assert!(coin::value(&payment) >= required_fee, E_INSUFFICIENT_PAYMENT);

        let old_expires_ms = subscription.expires_ms;
        subscription.expires_ms = subscription.expires_ms + service.duration_ms;
        transfer::public_transfer(payment, service.admin);
        inkray_events::emit_subscription_extended(
            subscription.holder, object::uid_to_address(&subscription.id),
            old_expires_ms, subscription.expires_ms,
        );
    }

    public fun renew(
        subscription: &mut Subscription,
        service: &PlatformService,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        assert!(subscription.holder == tx_context::sender(ctx), E_NOT_SUBSCRIBER);
        let required_fee = *vector::borrow(&service.monthly_fees, (subscription.plan as u64));
        assert!(coin::value(&payment) >= required_fee, E_INSUFFICIENT_PAYMENT);

        let current_time = clock::timestamp_ms(clock);
        let old_expires_ms = subscription.expires_ms;
        subscription.expires_ms = current_time + service.duration_ms;
        transfer::public_transfer(payment, service.admin);
        inkray_events::emit_subscription_extended(
            subscription.holder, object::uid_to_address(&subscription.id),
            old_expires_ms, subscription.expires_ms,
        );
    }

    public fun update_service(
        service: &mut PlatformService,
        new_fees: vector<u64>,
        new_duration_ms: u64,
        ctx: &TxContext,
    ) {
        assert!(tx_context::sender(ctx) == service.admin, E_NOT_SUBSCRIBER);
        service.monthly_fees = new_fees;
        service.duration_ms = new_duration_ms;
    }

    // === View Functions ===

    public fun is_valid(subscription: &Subscription, clock: &Clock): bool {
        clock::timestamp_ms(clock) < subscription.expires_ms
    }

    public fun get_subscription_info(subscription: &Subscription): (address, u8, u64, u16) {
        (subscription.holder, subscription.plan, subscription.expires_ms, subscription.version)
    }

    public fun get_service_info(service: &PlatformService): (&vector<u64>, u64, address) {
        (&service.monthly_fees, service.duration_ms, service.admin)
    }
}
