/// Platform Economics - Tipping system for publications and articles
///
/// This module handles direct tipping functionality, allowing users to tip
/// publications and articles with SUI payments. Tips are stored directly in
/// publications and can be withdrawn by publication owners using their PublicationOwnerCap.
module contracts::platform_economics;

use contracts::articles::{Self, Article};
use contracts::publication::{Self, Publication, PublicationOwnerCap};
use contracts::inkray_events;
use sui::coin::{Self, Coin};
use sui::sui::SUI;

// === Error Constants ===
const E_NOT_OWNER: u64 = 0;
const E_INSUFFICIENT_BALANCE: u64 = 1;
const E_INVALID_TIP_AMOUNT: u64 = 2;
const E_WRONG_PUBLICATION: u64 = 3;

// === Public Functions ===

/// Tip a publication directly (treasury embedded in publication)
public fun tip_publication(
    publication: &mut Publication,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    let publication_id = publication::get_publication_object_id(publication);
    let tipper = tx_context::sender(ctx);
    let amount = coin::value(&payment);
    
    // Validate tip amount
    assert!(amount > 0, E_INVALID_TIP_AMOUNT);
    
    // Add tip to embedded treasury (this requires friend access to Publication)
    add_tip_to_publication(publication, payment);
    
    // Emit event
    inkray_events::emit_publication_tipped(
        publication_id,
        tipper,
        amount,
    );
}

/// Tip a specific article (tip goes to the publication that owns the article)
public fun tip_article(
    article: &Article,
    publication: &mut Publication,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    let article_id = articles::get_article_id(article);
    let publication_id = publication::get_publication_object_id(publication);
    let tipper = tx_context::sender(ctx);
    let amount = coin::value(&payment);
    
    // Validate tip amount
    assert!(amount > 0, E_INVALID_TIP_AMOUNT);
    
    // Verify article belongs to this publication
    let (_, _, article_publication_id, _, _, _) = articles::get_article_info(article);
    assert!(article_publication_id == publication_id, E_WRONG_PUBLICATION);
    
    // Add tip to embedded treasury
    add_tip_to_publication(publication, payment);
    
    // Emit event
    inkray_events::emit_article_tipped(
        article_id,
        publication_id,
        tipper,
        amount,
    );
}

/// Withdraw specific amount from publication treasury (owner only)
public fun withdraw_tips(
    owner_cap: &PublicationOwnerCap,
    publication: &mut Publication,
    amount: u64,
    ctx: &mut TxContext,
): Coin<SUI> {
    // Verify ownership
    assert!(publication::verify_owner_cap(owner_cap, publication), E_NOT_OWNER);
    
    // Get current balance and check sufficiency
    let available_balance = publication::get_tip_balance(publication);
    assert!(available_balance >= amount, E_INSUFFICIENT_BALANCE);
    
    // Withdraw specified amount (requires friend access to Publication)
    withdraw_from_publication(publication, amount, ctx)
}

/// Withdraw all tips from publication treasury (owner only)
public fun withdraw_all_tips(
    owner_cap: &PublicationOwnerCap,
    publication: &mut Publication,
    ctx: &mut TxContext,
): Coin<SUI> {
    // Verify ownership
    assert!(publication::verify_owner_cap(owner_cap, publication), E_NOT_OWNER);
    
    // Get current balance
    let total_balance = publication::get_tip_balance(publication);
    
    // Withdraw all available balance
    withdraw_from_publication(publication, total_balance, ctx)
}

// === Helper Functions ===

/// Add tip to publication's embedded treasury
fun add_tip_to_publication(publication: &mut Publication, payment: Coin<SUI>) {
    let balance = coin::into_balance(payment);
    publication::add_tip_balance(publication, balance);
}

/// Withdraw from publication's embedded treasury
fun withdraw_from_publication(
    publication: &mut Publication, 
    amount: u64, 
    ctx: &mut TxContext
): Coin<SUI> {
    publication::withdraw_tip_balance(publication, amount, ctx)
}

// === View Functions ===

/// Get treasury balance (delegates to publication module)
public fun get_treasury_balance(publication: &Publication): u64 {
    publication::get_tip_balance(publication)
}

/// Get treasury statistics (delegates to publication module)
public fun get_treasury_stats(publication: &Publication): (u64, u64, u64) {
    publication::get_treasury_stats(publication)
}