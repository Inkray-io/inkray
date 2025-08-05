module contracts::publication_vault {
    use sui::event;
    use contracts::publication as publication;
    use contracts::publication::Publication;

    // === Errors ===
    const ENotAuthorized: u64 = 0;

    // === Structs ===
    public struct PublicationVault has key, store {
        id: UID,
        publication_id: ID,
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
    public fun create_vault(
        publication_id: ID,
        renewal_batch_size: u64,
        ctx: &mut TxContext
    ): PublicationVault {
        let id = object::new(ctx);
        let vault_id = object::uid_to_inner(&id);

        let vault = PublicationVault {
            id,
            publication_id,
            next_renewal_epoch: 0,
            renewal_batch_size,
        };

        event::emit(VaultCreated {
            vault_id,
            publication_id,
            creator: tx_context::sender(ctx),
        });

        vault
    }


    public fun add_blob(
        vault: &PublicationVault,
        publication: &Publication,
        blob_id: u256,
        is_encrypted: bool,
        ctx: &TxContext
    ) {
        let author = tx_context::sender(ctx);
        assert!(object::id(publication) == vault.publication_id, ENotAuthorized);
        assert!(
            publication::is_contributor(publication, author) ||
            publication::is_owner(publication, author),
            ENotAuthorized
        );

        event::emit(BlobAdded {
            vault_id: object::id(vault),
            publication_id: vault.publication_id,
            blob_id,
            is_encrypted,
            author,
        });
    }

    public fun needs_renewal(
        vault: &PublicationVault,
        current_epoch: u64
    ): bool {
        vault.next_renewal_epoch > 0 && current_epoch >= vault.next_renewal_epoch
    }

    public fun update_renewal_epoch(
        _: &RenewCap,
        vault: &mut PublicationVault,
        new_renewal_epoch: u64,
        ctx: &TxContext
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
        (
            vault.publication_id,
            vault.next_renewal_epoch,
            vault.renewal_batch_size
        )
    }

    public fun has_renewal_scheduled(vault: &PublicationVault): bool {
        vault.next_renewal_epoch > 0
    }

    public fun get_renewal_batch_size(vault: &PublicationVault): u64 {
        vault.renewal_batch_size
    }

    public fun set_renewal_batch_size(
        vault: &mut PublicationVault,
        new_batch_size: u64
    ) {
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
}