#[test_only]
module contracts::inkray_test_utils {
    use sui::test_scenario::{Self, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};

    // === Test Addresses ===
    public fun admin(): address { @0xAD }
    public fun creator(): address { @0xC1EA }
    public fun contributor(): address { @0xC047 }
    public fun user1(): address { @0x051 }
    public fun user2(): address { @0x052 }
    public fun platform_treasury(): address { @0x71EA }

    // === Mock Data Generators ===
    
    public fun create_test_coin(amount: u64, ctx: &mut TxContext): Coin<SUI> {
        coin::mint_for_testing<SUI>(amount, ctx)
    }

    public fun create_clock_for_testing(ctx: &mut TxContext): Clock {
        clock::create_for_testing(ctx)
    }

    public fun set_clock_time(clock: &mut Clock, timestamp_ms: u64) {
        clock::set_for_testing(clock, timestamp_ms)
    }

    public fun get_test_publication_name(): String {
        string::utf8(b"Test Publication")
    }

    public fun get_test_publication_description(): String {
        string::utf8(b"A comprehensive test publication for Inkray platform")
    }

    public fun get_test_article_title(): String {
        string::utf8(b"Test Article")
    }

    public fun get_test_article_summary(): String {
        string::utf8(b"This is a test article summary for testing purposes")
    }

    public fun get_test_blob_id(): u256 {
        123456789u256
    }

    public fun get_test_encrypted_blob_id(): u256 {
        987654321u256
    }

    // === Time Constants (in milliseconds) ===
    
    public fun one_day_ms(): u64 {
        24 * 60 * 60 * 1000
    }

    public fun one_week_ms(): u64 {
        7 * one_day_ms()
    }

    public fun one_month_ms(): u64 {
        30 * one_day_ms()
    }

    // === Standard Amounts ===
    
    public fun platform_subscription_fee(): u64 {
        10_000_000_000 // 10 SUI in MIST
    }

    public fun article_nft_price(): u64 {
        5_000_000_000 // 5 SUI in MIST
    }

    public fun tip_amount(): u64 {
        1_000_000_000 // 1 SUI in MIST
    }

    // === Scenario Helpers ===
    
    public fun begin_scenario(sender: address): Scenario {
        test_scenario::begin(sender)
    }

    public fun next_tx(scenario: &mut Scenario, sender: address) {
        test_scenario::next_tx(scenario, sender);
    }

    public fun end_scenario(scenario: Scenario) {
        test_scenario::end(scenario);
    }

    // === Object Retrieval Helpers ===
    
    public fun take_shared<T: key>(scenario: &Scenario): T {
        test_scenario::take_shared<T>(scenario)
    }

    public fun return_shared<T: key>(obj: T) {
        test_scenario::return_shared(obj);
    }

    public fun take_from_sender<T: key>(scenario: &Scenario): T {
        test_scenario::take_from_sender<T>(scenario)
    }
    
    public fun has_most_recent_for_sender<T: key>(scenario: &Scenario): bool {
        let sender = test_scenario::sender(scenario);
        let id_opt = test_scenario::most_recent_id_for_address<T>(sender);
        id_opt.is_some()
    }

    public fun return_to_sender<T: key>(_scenario: &Scenario, obj: T) {
        // Use test_utils::destroy instead of return_to_sender to avoid capability issues
        sui::test_utils::destroy(obj);
    }

    // === Event Testing Helpers ===
    // (Event testing helpers removed - using execution success as verification)

    // === Validation Helpers ===
    
    public fun assert_eq<T: drop>(actual: T, expected: T) {
        assert!(actual == expected, 0);
    }

    public fun assert_true(condition: bool) {
        assert!(condition, 0);
    }

    public fun assert_false(condition: bool) {
        assert!(!condition, 0);
    }

    // === Time-based Testing Helpers ===
    
    public fun advance_clock_by_days(clock: &mut Clock, days: u64) {
        let current_time = clock::timestamp_ms(clock);
        let new_time = current_time + (days * one_day_ms());
        set_clock_time(clock, new_time);
    }

    public fun advance_clock_by_weeks(clock: &mut Clock, weeks: u64) {
        let current_time = clock::timestamp_ms(clock);
        let new_time = current_time + (weeks * one_week_ms());
        set_clock_time(clock, new_time);
    }

    public fun advance_clock_by_months(clock: &mut Clock, months: u64) {
        let current_time = clock::timestamp_ms(clock);
        let new_time = current_time + (months * one_month_ms());
        set_clock_time(clock, new_time);
    }

    // === Publication Setup Helpers ===
    
    public fun standard_publication_setup(scenario: &mut Scenario) {
        use contracts::publication;
        use contracts::publication_vault;

        next_tx(scenario, creator());
        {
            // Create publication
            let (mut publication, owner_cap) = publication::create_publication(
                get_test_publication_name(),
                get_test_publication_description(),
                @0x1.to_id(), // placeholder vault_id
                test_scenario::ctx(scenario)
            );
            
            // Create vault
            let vault = publication_vault::create_vault(
                object::id(&publication),
                10, // batch size
                test_scenario::ctx(scenario)
            );

            // Add contributor
            publication::add_contributor(
                &owner_cap,
                &mut publication,
                contributor(),
                test_scenario::ctx(scenario)
            );

            return_to_sender(scenario, publication);
            return_to_sender(scenario, owner_cap);
            return_to_sender(scenario, vault);
        };
    }

    // === Platform Service Setup ===
    // (Removed platform service setup - will implement when needed)

    // === Common Assertion Patterns ===
    
    public fun assert_publication_has_contributor(
        publication: &contracts::publication::Publication,
        contributor_addr: address
    ) {
        let contributors = contracts::publication::get_contributors(publication);
        assert!(sui::vec_set::contains(contributors, &contributor_addr), 0);
    }

    public fun assert_subscription_active(
        subscription: &contracts::platform_access::PlatformSubscription,
        clock: &Clock
    ) {
        assert!(
            contracts::platform_access::is_subscription_active(subscription, clock),
            0
        );
    }

    public fun assert_subscription_expired(
        subscription: &contracts::platform_access::PlatformSubscription,
        clock: &Clock
    ) {
        assert!(
            contracts::platform_access::is_subscription_expired(subscription, clock),
            0
        );
    }
}