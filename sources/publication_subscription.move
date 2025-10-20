/// Publication subscription module for Inkray decentralized blogging platform.
///
/// This module handles paid subscriptions to publications, separate from the free follow system.
/// Users can subscribe to publications to access premium content, with time-based expiry.
module contracts::publication_subscription;

use contracts::publication::{Self, Publication};
use contracts::inkray_events;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::sui::SUI;

// === Error Constants ===
const E_INVALID_PAYMENT: u64 = 0;
const E_SUBSCRIPTION_NOT_REQUIRED: u64 = 1;
const E_INSUFFICIENT_PAYMENT: u64 = 3;
const E_ZERO_DURATION: u64 = 4;

// === Constants ===
const MILLISECONDS_PER_MONTH: u64 = 30 * 24 * 60 * 60 * 1000; // 30 days in milliseconds

// === Core Data Structures ===

/// PublicationSubscription represents a time-based paid subscription to a publication.
/// This provides access to premium content for a specific duration.
public struct PublicationSubscription has key, store {
    id: UID,
    publication_id: ID, // ID of the publication this subscription is for
    subscriber: address, // Address of the subscriber
    expires_at: u64, // Timestamp when subscription expires (milliseconds)
    created_at: u64, // Timestamp when subscription was created (milliseconds)
}

// === Public Functions ===

/// Subscribe to a publication by paying the subscription price
/// Creates a new subscription object owned by the subscriber
public fun subscribe_to_publication(
    publication: &mut Publication,
    payment: Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
): PublicationSubscription {
    let subscriber = tx_context::sender(ctx);
    let subscription_price = publication::get_subscription_price(publication);
    let current_time = clock::timestamp_ms(clock);
    
    // Check that subscription is required
    assert!(subscription_price > 0, E_SUBSCRIPTION_NOT_REQUIRED);
    
    // Verify payment amount
    let payment_amount = coin::value(&payment);
    assert!(payment_amount >= subscription_price, E_INSUFFICIENT_PAYMENT);
    
    // Calculate subscription duration (1 month per subscription price paid)
    let months_paid = payment_amount / subscription_price;
    assert!(months_paid > 0, E_ZERO_DURATION);
    
    let expires_at = current_time + (months_paid * MILLISECONDS_PER_MONTH);
    
    // Add payment to publication's subscription balance
    let payment_balance = coin::into_balance(payment);
    publication::add_subscription_balance(publication, payment_balance);
    
    // Create subscription object
    let subscription_uid = object::new(ctx);
    let subscription_id = subscription_uid.to_inner();
    let publication_id = publication::get_publication_object_id(publication);
    
    let subscription = PublicationSubscription {
        id: subscription_uid,
        publication_id,
        subscriber,
        expires_at,
        created_at: current_time,
    };
    
    // Emit event
    inkray_events::emit_publication_subscription_created(
        subscription_id,
        publication_id,
        subscriber,
        payment_amount,
        expires_at,
    );
    
    subscription
}

/// Extend an existing subscription by paying additional months
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
    
    // Verify caller is the subscriber
    assert!(subscription.subscriber == subscriber, E_INVALID_PAYMENT);
    
    // Verify subscription is for this publication
    assert!(subscription.publication_id == publication::get_publication_object_id(publication), E_INVALID_PAYMENT);
    
    // Check that subscription is still required
    assert!(subscription_price > 0, E_SUBSCRIPTION_NOT_REQUIRED);
    
    // Verify payment amount
    let payment_amount = coin::value(&payment);
    assert!(payment_amount >= subscription_price, E_INSUFFICIENT_PAYMENT);
    
    // Calculate additional duration
    let months_paid = payment_amount / subscription_price;
    assert!(months_paid > 0, E_ZERO_DURATION);
    
    let additional_duration = months_paid * MILLISECONDS_PER_MONTH;
    
    // Extend from current expiry date (not current time) to avoid losing time
    subscription.expires_at = subscription.expires_at + additional_duration;
    
    // Add payment to publication's subscription balance
    let payment_balance = coin::into_balance(payment);
    publication::add_subscription_balance(publication, payment_balance);
    
    // Emit event
    inkray_events::emit_publication_subscription_extended(
        subscription.id.to_inner(),
        subscription.publication_id,
        subscriber,
        payment_amount,
        subscription.expires_at,
    );
}

// === View Functions ===

/// Check if a subscription is currently valid (not expired)
public fun is_subscription_valid(subscription: &PublicationSubscription, clock: &Clock): bool {
    let current_time = clock::timestamp_ms(clock);
    subscription.expires_at > current_time
}

/// Get subscription details
public fun get_subscription_info(subscription: &PublicationSubscription): (ID, address, u64, u64, ID) {
    (
        subscription.publication_id,
        subscription.subscriber,
        subscription.expires_at,
        subscription.created_at,
        subscription.id.to_inner(),
    )
}

/// Get subscription expiry timestamp
public fun get_expires_at(subscription: &PublicationSubscription): u64 {
    subscription.expires_at
}

/// Get subscription publication ID
public fun get_publication_id(subscription: &PublicationSubscription): ID {
    subscription.publication_id
}

/// Get subscriber address
public fun get_subscriber(subscription: &PublicationSubscription): address {
    subscription.subscriber
}

/// Check if subscription is for a specific publication
public fun is_subscription_for_publication(
    subscription: &PublicationSubscription, 
    publication: &Publication
): bool {
    subscription.publication_id == publication::get_publication_object_id(publication)
}

/// Get time until subscription expires (0 if already expired)
public fun time_until_expiry(subscription: &PublicationSubscription, clock: &Clock): u64 {
    let current_time = clock::timestamp_ms(clock);
    if (subscription.expires_at > current_time) {
        subscription.expires_at - current_time
    } else {
        0
    }
}

/// Check if a user has a valid subscription to a publication
/// This function is used by the Seal policy for access control
public fun validate_subscription_access(
    subscription: &PublicationSubscription,
    publication: &Publication,
    user: address,
    clock: &Clock,
): bool {
    // Check subscription is for this publication
    if (subscription.publication_id != publication::get_publication_object_id(publication)) {
        return false
    };
    
    // Check user is the subscriber
    if (subscription.subscriber != user) {
        return false
    };
    
    // Check subscription is not expired
    is_subscription_valid(subscription, clock)
}