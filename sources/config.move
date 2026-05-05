module contracts::config;

use sui::vec_set::{Self, VecSet};

const E_WRONG_VERSION: u64 = 801;
const E_NOT_ADMIN:     u64 = 802;
const E_NOT_UPGRADE:   u64 = 803;

const VERSION: u64 = 1;

public struct AdminCap has key {
    id: UID,
}

public struct GlobalConfig has key {
    id: UID,
    version: u64,
    admin_caps: VecSet<ID>,
}

fun init(ctx: &mut TxContext) {
    let admin_cap = AdminCap { id: object::new(ctx) };
    let mut admin_caps = vec_set::empty<ID>();
    vec_set::insert(&mut admin_caps, object::id(&admin_cap));
    let config = GlobalConfig {
        id: object::new(ctx),
        version: VERSION,
        admin_caps,
    };
    transfer::share_object(config);
    transfer::transfer(admin_cap, tx_context::sender(ctx));
}

public fun assert_version(config: &GlobalConfig) {
    assert!(config.version == VERSION, E_WRONG_VERSION);
}

entry fun migrate(config: &mut GlobalConfig, cap: &AdminCap) {
    assert!(vec_set::contains(&config.admin_caps, &object::id(cap)), E_NOT_ADMIN);
    assert!(config.version < VERSION, E_NOT_UPGRADE);
    config.version = VERSION;
}

public fun transfer_admin_cap(cap: AdminCap, recipient: address) {
    transfer::transfer(cap, recipient);
}

public fun issue_additional_admin_cap(
    cap: &AdminCap,
    config: &mut GlobalConfig,
    recipient: address,
    ctx: &mut TxContext,
) {
    assert!(vec_set::contains(&config.admin_caps, &object::id(cap)), E_NOT_ADMIN);
    let new_cap = AdminCap { id: object::new(ctx) };
    vec_set::insert(&mut config.admin_caps, object::id(&new_cap));
    transfer::transfer(new_cap, recipient);
}

public fun destroy_admin_cap(cap: AdminCap, config: &mut GlobalConfig) {
    assert!(vec_set::contains(&config.admin_caps, &object::id(&cap)), E_NOT_ADMIN);
    vec_set::remove(&mut config.admin_caps, &object::id(&cap));
    let AdminCap { id } = cap;
    object::delete(id);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun set_version_for_testing(config: &mut GlobalConfig, v: u64) {
    config.version = v;
}

#[test_only]
public fun test_call_migrate(config: &mut GlobalConfig, cap: &AdminCap) {
    migrate(config, cap);
}
