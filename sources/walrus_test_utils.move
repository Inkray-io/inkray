#[test_only]
module contracts::walrus_test_utils {
    use sui::tx_context::TxContext;
    use walrus::blob::{Self, Blob};
    use walrus::system::{Self, System};
    use walrus::storage_resource::Storage;
    use walrus::encoding;
    use sui::coin;
    use walrus::wal::WAL;

    const ROOT_HASH: u256 = 0xABC;
    const SIZE: u64 = 5_000_000;
    const RS2: u8 = 1;
    const N_COINS: u64 = 1_000_000_000;

    public fun new_test_blob(
        ctx: &mut TxContext,
    ): Blob {
        let mut system = system::new_for_testing(ctx);
        let storage = get_storage_resource(&mut system, SIZE, 3, ctx);
        let blob = register_default_blob(&mut system, storage, false, ctx);
        blob
    }

    public fun new_test_blob_with_system(
        root_hash: u256,
        ctx: &mut TxContext,
        system: &mut System,
    ): Blob {
        let storage = get_storage_resource(system, SIZE, 3, ctx);
        let mut fake_coin = coin::mint_for_testing<WAL>(N_COINS, ctx);
        let blob_id = blob::derive_blob_id(root_hash, RS2, SIZE);
        let blob = system.register_blob(
            storage,
            blob_id,
            root_hash,
            SIZE,
            RS2,
            false,
            &mut fake_coin,
            ctx,
        );
        coin::burn_for_testing(fake_coin);
        blob
    }

    fun get_storage_resource(
        system: &mut System,
        unencoded_size: u64,
        epochs_ahead: u32,
        ctx: &mut TxContext,
    ): Storage {
        let mut fake_coin = coin::mint_for_testing<WAL>(N_COINS, ctx);
        let storage_size = encoding::encoded_blob_length(
            unencoded_size,
            RS2,
            system.n_shards(),
        );
        let storage = system.reserve_space(
            storage_size,
            epochs_ahead,
            &mut fake_coin,
            ctx,
        );
        coin::burn_for_testing(fake_coin);
        storage
    }

    fun register_default_blob(
        system: &mut System,
        storage: Storage,
        deletable: bool,
        ctx: &mut TxContext,
    ): Blob {
        let mut fake_coin = coin::mint_for_testing<WAL>(N_COINS, ctx);
        // Register a Blob
        let blob_id = blob::derive_blob_id(ROOT_HASH, RS2, SIZE);
        let blob = system.register_blob(
            storage,
            blob_id,
            ROOT_HASH,
            SIZE,
            RS2,
            deletable,
            &mut fake_coin,
            ctx,
        );

        coin::burn_for_testing(fake_coin);
        blob
    }

    public fun new_test_blob_without_system(
        ctx: &mut TxContext,
    ): Blob {
        let storage = storage_resource::new_for_testing(0, 1, 1, ctx);
        let blob_id = blob::derive_blob_id(ROOT_HASH, RS2, SIZE);
        blob::new_for_testing(
            storage,
            blob_id,
            ROOT_HASH,
            SIZE,
            RS2,
            false,
            0,
            1,
            ctx,
        )
    }

    public fun get_test_blob_id(): u256 {
        blob::derive_blob_id(ROOT_HASH, RS2, SIZE)
    }

    public fun get_test_encrypted_blob_id(): u256 {
        blob::derive_blob_id(ROOT_HASH, 1, SIZE)
    }
}
