module contracts::publication_subscription;

use contracts::config::{Self, GlobalConfig};
use contracts::publication::{Self, Publication};
use contracts::inkray_events;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::sui::SUI;

const E_INVALID_PAYMENT: u64 = 401;
const E_SUBSCRIPTION_NOT_REQUIRED: u64 = 402;
const E_INSUFFICIENT_PAYMENT: u64 = 403;
const E_ZERO_DURATION: u64 = 404;

const MILLISECONDS_PER_MONTH: u64 = 30 * 24 * 60 * 60 * 1000;
const MAX_SUBSCRIPTION_MONTHS: u64 = 36;

public struct PublicationSubscription has key {
    id: UID,
    publication_id: ID,
    subscriber: address,
    expires_at: u64,
    created_at: u64,
}

#[allow(lint(self_transfer))]
public fun subscribe_to_publication(
    config: &GlobalConfig,
    publication: &mut Publication,
    mut payment: Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    config::assert_version(config);
    let subscriber = tx_context::sender(ctx);
    let subscription_price = publication::get_subscription_price(publication);
    let current_time = clock::timestamp_ms(clock);

    assert!(subscription_price > 0, E_SUBSCRIPTION_NOT_REQUIRED);
    let payment_amount = coin::value(&payment);
    assert!(payment_amount >= subscription_price, E_INSUFFICIENT_PAYMENT);
    let mut months_paid = payment_amount / subscription_price;
    assert!(months_paid > 0, E_ZERO_DURATION);
    if (months_paid > MAX_SUBSCRIPTION_MONTHS) {
        months_paid = MAX_SUBSCRIPTION_MONTHS;
    };

    let exact_amount = months_paid * subscription_price;
    let kept = coin::split(&mut payment, exact_amount, ctx);
    if (coin::value(&payment) == 0) {
        coin::destroy_zero(payment);
    } else {
        transfer::public_transfer(payment, subscriber);
    };

    let expires_at = current_time + (months_paid * MILLISECONDS_PER_MONTH);
    publication::add_subscription_balance(publication, coin::into_balance(kept));

    let subscription_uid = object::new(ctx);
    let subscription_id = subscription_uid.to_inner();
    let publication_id = publication::get_publication_object_id(publication);

    let subscription = PublicationSubscription {
        id: subscription_uid, publication_id, subscriber,
        expires_at, created_at: current_time,
    };

    inkray_events::emit_publication_subscription_created(
        subscription_id, publication_id, subscriber, exact_amount, expires_at,
    );

    transfer::transfer(subscription, subscriber);
}

#[allow(lint(self_transfer))]
public fun extend_subscription(
    config: &GlobalConfig,
    subscription: &mut PublicationSubscription,
    publication: &mut Publication,
    mut payment: Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    config::assert_version(config);
    let subscriber = tx_context::sender(ctx);
    let subscription_price = publication::get_subscription_price(publication);
    let current_time = clock::timestamp_ms(clock);

    assert!(subscription.subscriber == subscriber, E_INVALID_PAYMENT);
    assert!(subscription.publication_id == publication::get_publication_object_id(publication), E_INVALID_PAYMENT);
    assert!(subscription_price > 0, E_SUBSCRIPTION_NOT_REQUIRED);
    let payment_amount = coin::value(&payment);
    assert!(payment_amount >= subscription_price, E_INSUFFICIENT_PAYMENT);
    let mut months_paid = payment_amount / subscription_price;
    assert!(months_paid > 0, E_ZERO_DURATION);
    if (months_paid > MAX_SUBSCRIPTION_MONTHS) {
        months_paid = MAX_SUBSCRIPTION_MONTHS;
    };

    let exact_amount = months_paid * subscription_price;
    let kept = coin::split(&mut payment, exact_amount, ctx);
    if (coin::value(&payment) == 0) {
        coin::destroy_zero(payment);
    } else {
        transfer::public_transfer(payment, subscriber);
    };

    let base_time = if (subscription.expires_at > current_time) {
        subscription.expires_at
    } else {
        current_time
    };
    subscription.expires_at = base_time + (months_paid * MILLISECONDS_PER_MONTH);
    publication::add_subscription_balance(publication, coin::into_balance(kept));

    inkray_events::emit_publication_subscription_extended(
        subscription.id.to_inner(), subscription.publication_id,
        subscriber, exact_amount, subscription.expires_at,
    );
}

// === View Functions ===

public fun is_subscription_valid(subscription: &PublicationSubscription, clock: &Clock): bool {
    subscription.expires_at > clock::timestamp_ms(clock)
}

public fun validate_subscription_access(
    subscription: &PublicationSubscription,
    publication: &Publication,
    user: address,
    clock: &Clock,
): bool {
    if (subscription.publication_id != publication::get_publication_object_id(publication)) {
        return false
    };
    if (subscription.subscriber != user) {
        return false
    };
    is_subscription_valid(subscription, clock)
}
