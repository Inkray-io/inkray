module contracts::platform_economics;

use contracts::publication::{Self, Publication, PublicationOwnerCap};
use contracts::inkray_events;
use sui::coin::{Self, Coin};
use sui::sui::SUI;

const E_NOT_OWNER: u64 = 0;
const E_INVALID_TIP_AMOUNT: u64 = 2;

public fun tip_publication(
    publication: &mut Publication,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    let publication_id = publication::get_publication_object_id(publication);
    let tipper = tx_context::sender(ctx);
    let amount = coin::value(&payment);
    assert!(amount > 0, E_INVALID_TIP_AMOUNT);
    publication::add_tip_balance(publication, coin::into_balance(payment));
    inkray_events::emit_publication_tipped(publication_id, tipper, amount);
}

public fun withdraw_all_tips(
    owner_cap: &PublicationOwnerCap,
    publication: &mut Publication,
    ctx: &mut TxContext,
): Coin<SUI> {
    assert!(publication::verify_owner_cap(owner_cap, publication), E_NOT_OWNER);
    let total_balance = publication::get_tip_balance(publication);
    publication::withdraw_tip_balance(publication, total_balance, ctx)
}
