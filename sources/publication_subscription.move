module contracts::publication_subscription;

use contracts::publication::{Self, Publication};
use contracts::inkray_events;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::sui::SUI;

const E_INVALID_PAYMENT: u64 = 0;
const E_SUBSCRIPTION_NOT_REQUIRED: u64 = 1;
const E_INSUFFICIENT_PAYMENT: u64 = 3;
const E_ZERO_DURATION: u64 = 4;

const MILLISECONDS_PER_MONTH: u64 = 30 * 24 * 60 * 60 * 1000;

public struct PublicationSubscription has key, store {
    id: UID,
    publication_id: ID,
    subscriber: address,
    expires_at: u64,
    created_at: u64,
}

public fun subscribe_to_publication(
    publication: &mut Publication,
    payment: Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
): PublicationSubscription {
    let subscriber = tx_context::sender(ctx);
    let subscription_price = publication::get_subscription_price(publication);
    let current_time = clock::timestamp_ms(clock);

    assert!(subscription_price > 0, E_SUBSCRIPTION_NOT_REQUIRED);
    let payment_amount = coin::value(&payment);
    assert!(payment_amount >= subscription_price, E_INSUFFICIENT_PAYMENT);
    let months_paid = payment_amount / subscription_price;
    assert!(months_paid > 0, E_ZERO_DURATION);

    let expires_at = current_time + (months_paid * MILLISECONDS_PER_MONTH);
    publication::add_subscription_balance(publication, coin::into_balance(payment));

    let subscription_uid = object::new(ctx);
    let subscription_id = subscription_uid.to_inner();
    let publication_id = publication::get_publication_object_id(publication);

    let subscription = PublicationSubscription {
        id: subscription_uid, publication_id, subscriber,
        expires_at, created_at: current_time,
    };

    inkray_events::emit_publication_subscription_created(
        subscription_id, publication_id, subscriber, payment_amount, expires_at,
    );

    subscription
}

public fun extend_subscription(
    subscription: &mut PublicationSubscription,
    publication: &mut Publication,
    payment: Coin<SUI>,
    clock: &Clock,
    ctx: &TxContext,
) {
    let subscriber = tx_context::sender(ctx);
    let subscription_price = publication::get_subscription_price(publication);
    let _current_time = clock::timestamp_ms(clock);

    assert!(subscription.subscriber == subscriber, E_INVALID_PAYMENT);
    assert!(subscription.publication_id == publication::get_publication_object_id(publication), E_INVALID_PAYMENT);
    assert!(subscription_price > 0, E_SUBSCRIPTION_NOT_REQUIRED);
    let payment_amount = coin::value(&payment);
    assert!(payment_amount >= subscription_price, E_INSUFFICIENT_PAYMENT);
    let months_paid = payment_amount / subscription_price;
    assert!(months_paid > 0, E_ZERO_DURATION);

    subscription.expires_at = subscription.expires_at + (months_paid * MILLISECONDS_PER_MONTH);
    publication::add_subscription_balance(publication, coin::into_balance(payment));

    inkray_events::emit_publication_subscription_extended(
        subscription.id.to_inner(), subscription.publication_id,
        subscriber, payment_amount, subscription.expires_at,
    );
}

// === View Functions ===

public fun is_subscription_valid(subscription: &PublicationSubscription, clock: &Clock): bool {
    subscription.expires_at > clock::timestamp_ms(clock)
}

public fun get_subscription_info(subscription: &PublicationSubscription): (ID, address, u64, u64, ID) {
    (
        subscription.publication_id, subscription.subscriber,
        subscription.expires_at, subscription.created_at, subscription.id.to_inner(),
    )
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
