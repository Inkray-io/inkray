module contracts::publication_vault {
    use contracts::publication::{Self as publication, Publication};
    use sui::event;
    use sui::table::{Self, Table};
    use walrus::blob::{Self, Blob};
    
    // === Errors ===
    const ENotAuthorized: u64 = 0;
    
    // === Structs ===
    
    public struct PublicationVault has key, store {
        id: UID,
        publication_id: ID,
        blobs: Table<u256, Blob>, // Store real Walrus Blob objects
        blob_is_encrypted: Table<u256, bool>, // Side table for our app-specific metadata
        next_renewal_epoch: u64,
        renewal_batch_size: u64,
    }

    public struct RenewCap has key, store {
        id: UID,
    }

    // === Events ===
    public struct VaultCreated has copy, drop {
        vault_id: ID,
        publication_id: ID,
        creator: address,
    }

    public struct BlobAdded has copy, drop {
        vault_id: ID,
        publication_id: ID,
        blob_id: u256,
        is_encrypted: bool,
        author: address,
    }

    public struct VaultRenewed has copy, drop {
        vault_id: ID,
        publication_id: ID,
        new_renewal_epoch: u64,
        renewed_at: u64,
    }

    // === Admin Functions ===
    fun init(ctx: &mut TxContext) {
        let renew_cap = RenewCap {
            id: object::new(ctx),
        };
        transfer::transfer(renew_cap, tx_context::sender(ctx));
    }

    // === Public Functions ===
    public fun create_vault(publication_id: ID, renewal_batch_size: u64, ctx: &mut TxContext) {
        let id = object::new(ctx);
        let vault_id = object::uid_to_inner(&id);

        let vault = PublicationVault {
            id,
            publication_id,
            blobs: table::new(ctx),
            blob_is_encrypted: table::new(ctx),
            next_renewal_epoch: 0,
            renewal_batch_size,
        };

        event::emit(VaultCreated {
            vault_id,
            publication_id,
            creator: tx_context::sender(ctx),
        });

        // Share the vault so contributors can access it
        transfer::share_object(vault);
    }

    // Store a real Walrus blob
    public fun store_blob(
        vault: &mut PublicationVault,
        publication: &Publication,
        blob: Blob,
        is_encrypted: bool,
        ctx: &TxContext,
    ) {
        let author = tx_context::sender(ctx);
        assert!(object::id(publication) == vault.publication_id, ENotAuthorized);
        assert!(
            publication::is_contributor(publication, author) ||
                publication::is_owner(publication, author),
            ENotAuthorized,
        );

        let blob_id = blob::blob_id(&blob);
        table::add(&mut vault.blobs, blob_id, blob);
        table::add(&mut vault.blob_is_encrypted, blob_id, is_encrypted);

        event::emit(BlobAdded {
            vault_id: object::id(vault),
            publication_id: vault.publication_id,
            blob_id,
            is_encrypted,
            author,
        });
    }

    public fun get_blob(vault: &PublicationVault, blob_id: u256): &Blob {
        table::borrow(&vault.blobs, blob_id)
    }

    public fun get_blob_is_encrypted(vault: &PublicationVault, blob_id: u256): bool {
        *table::borrow(&vault.blob_is_encrypted, blob_id)
    }

    public fun remove_blob(
        vault: &mut PublicationVault,
        publication: &Publication,
        blob_id: u256,
        ctx: &TxContext,
    ): Blob {
        let author = tx_context::sender(ctx);
        assert!(object::id(publication) == vault.publication_id, ENotAuthorized);
        assert!(
            publication::is_owner(publication, author), // Only owner can remove blobs
            ENotAuthorized,
        );

        // Also remove our app-specific metadata
        table::remove(&mut vault.blob_is_encrypted, blob_id);
        table::remove(&mut vault.blobs, blob_id)
    }

    public fun get_blob_info(blob: &Blob, is_encrypted: bool): (u256, u64, u8, u32, bool, bool) {
        (
            blob::blob_id(blob),
            blob::size(blob),
            blob::encoding_type(blob),
            blob::registered_epoch(blob),
            blob::is_deletable(blob),
            is_encrypted
        )
    }

    public fun has_blob(vault: &PublicationVault, blob_id: u256): bool {
        table::contains(&vault.blobs, blob_id)
    }

    public fun needs_renewal(vault: &PublicationVault, current_epoch: u64): bool {
        vault.next_renewal_epoch > 0 && current_epoch >= vault.next_renewal_epoch
    }

    public fun update_renewal_epoch(
        _: &RenewCap,
        vault: &mut PublicationVault,
        new_renewal_epoch: u64,
        ctx: &TxContext,
    ) {
        vault.next_renewal_epoch = new_renewal_epoch;

        event::emit(VaultRenewed {
            vault_id: object::id(vault),
            publication_id: vault.publication_id,
            new_renewal_epoch,
            renewed_at: tx_context::epoch_timestamp_ms(ctx),
        });
    }

    // === View Functions ===
    public fun get_vault_info(vault: &PublicationVault): (ID, u64, u64) {
        (vault.publication_id, vault.next_renewal_epoch, vault.renewal_batch_size)
    }

    public fun get_blob_count(vault: &PublicationVault): u64 {
        table::length(&vault.blobs)
    }

    public fun has_renewal_scheduled(vault: &PublicationVault): bool {
        vault.next_renewal_epoch > 0
    }

    public fun get_renewal_batch_size(vault: &PublicationVault): u64 {
        vault.renewal_batch_size
    }

    public fun set_renewal_batch_size(vault: &mut PublicationVault, new_batch_size: u64) {
        vault.renewal_batch_size = new_batch_size;
    }

    // === Test-only Functions ===
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun create_renew_cap_for_testing(ctx: &mut TxContext): RenewCap {
        RenewCap {
            id: object::new(ctx),
        }
    }

    #[test_only]
    public fun create_vault_for_testing(
        publication_id: ID,
        renewal_batch_size: u64,
        ctx: &mut TxContext,
    ): PublicationVault {
        let id = object::new(ctx);
        PublicationVault {
            id,
            publication_id,
            blobs: table::new(ctx),
            blob_is_encrypted: table::new(ctx),
            next_renewal_epoch: 0,
            renewal_batch_size,
        }
    }

    use contracts::walrus_test_utils;

    #[test_only]
    public fun create_and_store_test_blob(
        vault: &mut PublicationVault,
        publication: &Publication,
        is_encrypted: bool,
        ctx: &mut TxContext,
    ) {
        let blob = walrus_test_utils::new_test_blob_without_system(ctx);
        store_blob(vault, publication, blob, is_encrypted, ctx);
    }
}