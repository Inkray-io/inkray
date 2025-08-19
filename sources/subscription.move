module contracts::subscription {
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use contracts::inkray_events;

    // === Errors ===
    const E_INSUFFICIENT_PAYMENT: u64 = 0;
    const E_INVALID_PLAN: u64 = 1;
    // E_SUBSCRIPTION_EXPIRED removed - not used in current implementation
    const E_NOT_SUBSCRIBER: u64 = 3;

    // === Constants ===
    const PLAN_BASIC: u8 = 0;
    const PLAN_PREMIUM: u8 = 1;
    const PLAN_PRO: u8 = 2;

    // === Structs ===
    
    /// Platform-wide subscription (address-owned)
    public struct Subscription has key, store {
        id: UID,
        holder: address,     // optional; Sui enforces ownership by type anyway
        plan: u8,            // tier code
        expires_ms: u64,     // epoch ms
        version: u16,        // for future upgrades
    }

    /// Platform service configuration (shared)
    public struct PlatformService has key, store {
        id: UID,
        monthly_fees: vector<u64>,    // fees by plan [basic, premium, pro]
        duration_ms: u64,             // subscription duration in ms
        admin: address,               // admin address
    }

    // === Admin Functions ===
    fun init(ctx: &mut TxContext) {
        let service = PlatformService {
            id: object::new(ctx),
            monthly_fees: vector[
                5_000_000_000,    // 5 SUI for basic
                10_000_000_000,   // 10 SUI for premium  
                20_000_000_000    // 20 SUI for pro
            ],
            duration_ms: 30 * 24 * 60 * 60 * 1000, // 30 days in milliseconds
            admin: tx_context::sender(ctx),
        };
        
        transfer::share_object(service);
    }

    // === Public Functions ===
    
    /// Mint new platform subscription
    public fun mint_platform(
        service: &PlatformService,
        plan: u8,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Subscription {
        // Validate plan
        assert!((plan as u64) < vector::length(&service.monthly_fees), E_INVALID_PLAN);
        
        // Check payment
        let required_fee = *vector::borrow(&service.monthly_fees, (plan as u64));
        assert!(coin::value(&payment) >= required_fee, E_INSUFFICIENT_PAYMENT);
        
        let holder = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);
        let expires_ms = current_time + service.duration_ms;
        
        let subscription_id = object::new(ctx);
        let subscription_addr = object::uid_to_address(&subscription_id);
        
        let subscription = Subscription {
            id: subscription_id,
            holder,
            plan,
            expires_ms,
            version: 1,
        };
        
        // Transfer payment to admin
        transfer::public_transfer(payment, service.admin);
        
        // Emit event
        inkray_events::emit_subscription_minted(
            holder,
            subscription_addr,
            plan,
            expires_ms
        );
        
        subscription
    }

    /// Extend subscription (add time from current expiry)
    public fun extend(
        subscription: &mut Subscription,
        service: &PlatformService,
        payment: Coin<SUI>,
        _clock: &Clock,
        ctx: &TxContext
    ) {
        assert!(subscription.holder == tx_context::sender(ctx), E_NOT_SUBSCRIBER);
        
        // Check payment
        let required_fee = *vector::borrow(&service.monthly_fees, (subscription.plan as u64));
        assert!(coin::value(&payment) >= required_fee, E_INSUFFICIENT_PAYMENT);
        
        let old_expires_ms = subscription.expires_ms;
        subscription.expires_ms = subscription.expires_ms + service.duration_ms;
        
        // Transfer payment to admin
        transfer::public_transfer(payment, service.admin);
        
        // Emit event
        inkray_events::emit_subscription_extended(
            subscription.holder,
            object::uid_to_address(&subscription.id),
            old_expires_ms,
            subscription.expires_ms
        );
    }

    /// Renew subscription (fresh period from now)
    public fun renew(
        subscription: &mut Subscription,
        service: &PlatformService,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &TxContext
    ) {
        assert!(subscription.holder == tx_context::sender(ctx), E_NOT_SUBSCRIBER);
        
        // Check payment
        let required_fee = *vector::borrow(&service.monthly_fees, (subscription.plan as u64));
        assert!(coin::value(&payment) >= required_fee, E_INSUFFICIENT_PAYMENT);
        
        let current_time = clock::timestamp_ms(clock);
        let old_expires_ms = subscription.expires_ms;
        subscription.expires_ms = current_time + service.duration_ms;
        
        // Transfer payment to admin
        transfer::public_transfer(payment, service.admin);
        
        // Emit event
        inkray_events::emit_subscription_extended(  // Use same event for simplicity
            subscription.holder,
            object::uid_to_address(&subscription.id),
            old_expires_ms,
            subscription.expires_ms
        );
    }

    // === Admin Functions ===
    
    /// Update service configuration
    public fun update_service(
        service: &mut PlatformService,
        new_fees: vector<u64>,
        new_duration_ms: u64,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == service.admin, E_NOT_SUBSCRIBER);
        
        service.monthly_fees = new_fees;
        service.duration_ms = new_duration_ms;
    }

    // === View Functions ===
    
    /// Check if subscription is currently valid
    public fun is_valid(subscription: &Subscription, clock: &Clock): bool {
        let current_time = clock::timestamp_ms(clock);
        current_time < subscription.expires_ms
    }
    
    /// Check if subscription is expired
    public fun is_expired(subscription: &Subscription, clock: &Clock): bool {
        !is_valid(subscription, clock)
    }
    
    /// Get subscription info
    public fun get_subscription_info(subscription: &Subscription): (address, u8, u64, u16) {
        (subscription.holder, subscription.plan, subscription.expires_ms, subscription.version)
    }
    
    /// Get time until expiry (0 if expired)
    public fun time_until_expiry(subscription: &Subscription, clock: &Clock): u64 {
        let current_time = clock::timestamp_ms(clock);
        if (current_time >= subscription.expires_ms) {
            0
        } else {
            subscription.expires_ms - current_time
        }
    }
    
    /// Get service info
    public fun get_service_info(service: &PlatformService): (&vector<u64>, u64, address) {
        (&service.monthly_fees, service.duration_ms, service.admin)
    }
    
    /// Get plan name
    public fun get_plan_name(plan: u8): vector<u8> {
        if (plan == PLAN_BASIC) {
            b"Basic"
        } else if (plan == PLAN_PREMIUM) {
            b"Premium"
        } else if (plan == PLAN_PRO) {
            b"Pro"
        } else {
            b"Unknown"
        }
    }
    
    /// Get all plan constants
    public fun get_plan_constants(): (u8, u8, u8) {
        (PLAN_BASIC, PLAN_PREMIUM, PLAN_PRO)
    }
}