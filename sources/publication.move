module contracts::publication;

use contracts::inkray_events;
use contracts::vault;
use std::string::String;

const E_NOT_OWNER: u64 = 0;
const E_CONTRIBUTOR_NOT_FOUND: u64 = 1;
const E_CONTRIBUTOR_EXISTS: u64 = 2;

public struct Publication has key, store {
    id: UID,
    name: String,
    contributors: vector<address>,
    vault_id: ID,
    tip_balance: sui::balance::Balance<sui::sui::SUI>,
    total_tips_received: u64,
    total_amount_received: u64,
    subscription_price: u64,
    subscription_balance: sui::balance::Balance<sui::sui::SUI>,
}

public struct PublicationOwnerCap has key, store {
    id: UID,
    publication_id: ID,
}

public fun create(name: String, ctx: &mut TxContext): PublicationOwnerCap {
    let owner = tx_context::sender(ctx);
    let publication_uid = object::new(ctx);
    let publication_id = publication_uid.to_inner();
    let vault_id = vault::create_and_share_vault(publication_id, ctx);

    let publication = Publication {
        id: publication_uid,
        name,
        contributors: vector::empty(),
        vault_id,
        tip_balance: sui::balance::zero<sui::sui::SUI>(),
        total_tips_received: 0,
        total_amount_received: 0,
        subscription_price: 0,
        subscription_balance: sui::balance::zero<sui::sui::SUI>(),
    };

    let owner_cap = PublicationOwnerCap {
        id: object::new(ctx),
        publication_id,
    };

    transfer::share_object(publication);

    inkray_events::emit_publication_created(publication_id, owner, name, vault_id);

    owner_cap
}

public fun add_contributor(
    owner_cap: &PublicationOwnerCap,
    publication: &mut Publication,
    contributor: address,
    ctx: &TxContext,
) {
    assert!(owner_cap.publication_id == publication.id.to_inner(), E_NOT_OWNER);
    assert!(!vector::contains(&publication.contributors, &contributor), E_CONTRIBUTOR_EXISTS);
    vector::push_back(&mut publication.contributors, contributor);
    inkray_events::emit_contributor_added(
        publication.id.to_inner(), contributor, tx_context::sender(ctx),
    );
}

public fun remove_contributor(
    owner_cap: &PublicationOwnerCap,
    publication: &mut Publication,
    contributor: address,
    ctx: &TxContext,
) {
    assert!(owner_cap.publication_id == publication.id.to_inner(), E_NOT_OWNER);
    let (found, index) = vector::index_of(&publication.contributors, &contributor);
    assert!(found, E_CONTRIBUTOR_NOT_FOUND);
    vector::remove(&mut publication.contributors, index);
    inkray_events::emit_contributor_removed(
        publication.id.to_inner(), contributor, tx_context::sender(ctx),
    );
}

// === View Functions ===

public fun is_contributor(publication: &Publication, user: address): bool {
    vector::contains(&publication.contributors, &user)
}

public fun get_vault_id(publication: &Publication): ID {
    publication.vault_id
}

public fun get_publication_object_id(publication: &Publication): ID {
    publication.id.to_inner()
}

public fun get_publication_address(publication: &Publication): address {
    object::uid_to_address(&publication.id)
}

public fun verify_owner_cap(owner_cap: &PublicationOwnerCap, publication: &Publication): bool {
    owner_cap.publication_id == publication.id.to_inner()
}

public fun get_tip_balance(publication: &Publication): u64 {
    sui::balance::value(&publication.tip_balance)
}

// === Package Functions ===

public(package) fun store_blob_in_vault(
    publication: &Publication,
    vault: &mut vault::PublicationVault,
    blob: walrus::blob::Blob,
    ctx: &TxContext,
) {
    let caller = tx_context::sender(ctx);
    assert!(vault::get_vault_publication_id(vault) == publication.id.to_inner(), E_NOT_OWNER);
    vault::store_blob(vault, blob, caller);
}

public(package) fun remove_blob_from_vault(
    publication: &Publication,
    vault: &mut vault::PublicationVault,
    blob_id: ID,
    ctx: &TxContext,
): walrus::blob::Blob {
    let caller = tx_context::sender(ctx);
    assert!(vault::get_vault_publication_id(vault) == publication.id.to_inner(), E_NOT_OWNER);
    vault::remove_blob(vault, blob_id, caller)
}

public(package) fun add_tip_balance(
    publication: &mut Publication,
    payment: sui::balance::Balance<sui::sui::SUI>,
) {
    let amount = sui::balance::value(&payment);
    sui::balance::join(&mut publication.tip_balance, payment);
    publication.total_tips_received = publication.total_tips_received + 1;
    publication.total_amount_received = publication.total_amount_received + amount;
}

public(package) fun withdraw_tip_balance(
    publication: &mut Publication,
    amount: u64,
    ctx: &mut TxContext,
): sui::coin::Coin<sui::sui::SUI> {
    let withdrawn_balance = sui::balance::split(&mut publication.tip_balance, amount);
    sui::coin::from_balance(withdrawn_balance, ctx)
}

// === Subscription Functions ===

public fun get_subscription_price(publication: &Publication): u64 {
    publication.subscription_price
}

public fun requires_subscription(publication: &Publication): bool {
    publication.subscription_price > 0
}

public fun update_name(
    owner_cap: &PublicationOwnerCap,
    publication: &mut Publication,
    new_name: String,
    ctx: &TxContext,
) {
    assert!(owner_cap.publication_id == publication.id.to_inner(), E_NOT_OWNER);
    let old_name = publication.name;
    publication.name = new_name;
    inkray_events::emit_publication_name_updated(
        publication.id.to_inner(), old_name, new_name, tx_context::sender(ctx),
    );
}

public fun set_subscription_price(
    owner_cap: &PublicationOwnerCap,
    publication: &mut Publication,
    price: u64,
    ctx: &TxContext,
) {
    assert!(owner_cap.publication_id == publication.id.to_inner(), E_NOT_OWNER);
    let old_price = publication.subscription_price;
    publication.subscription_price = price;
    inkray_events::emit_publication_subscription_price_updated(
        publication.id.to_inner(), old_price, price, tx_context::sender(ctx),
    );
}

public(package) fun add_subscription_balance(
    publication: &mut Publication,
    payment: sui::balance::Balance<sui::sui::SUI>,
) {
    sui::balance::join(&mut publication.subscription_balance, payment);
}

public fun withdraw_subscription_balance(
    owner_cap: &PublicationOwnerCap,
    publication: &mut Publication,
    amount: u64,
    ctx: &mut TxContext,
): sui::coin::Coin<sui::sui::SUI> {
    assert!(owner_cap.publication_id == publication.id.to_inner(), E_NOT_OWNER);
    let withdrawn_balance = sui::balance::split(&mut publication.subscription_balance, amount);
    inkray_events::emit_subscription_balance_withdrawn(
        publication.id.to_inner(), amount, tx_context::sender(ctx),
    );
    sui::coin::from_balance(withdrawn_balance, ctx)
}

public fun get_owner_cap_publication_id(owner_cap: &PublicationOwnerCap): ID {
    owner_cap.publication_id
}
