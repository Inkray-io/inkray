module contracts::publication_vault {
    use sui::event;
    use sui::table::{Self, Table};
    
    // === Errors ===
    const ENotAuthorized: u64 = 0;
    
    // === Structs ===
    
    public struct PublicationVault<B: store> has key, store {
        id: UID,
        blobs: Table<u256, B>, // Generic blob type
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
        creator: address,
    }

    public struct BlobAdded has copy, drop {
        vault_id: ID,
        blob_id: u256,
        is_encrypted: bool,
        author: address,
    }

    public struct VaultRenewed has copy, drop {
        vault_id: ID,
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
    public fun create_vault<B: store>(renewal_batch_size: u64, ctx: &mut TxContext): ID {
        let id = object::new(ctx);
        let vault_id = object::uid_to_inner(&id);

        let vault = PublicationVault<B> {
            id,
            blobs: table::new(ctx),
            blob_is_encrypted: table::new(ctx),
            next_renewal_epoch: 0,
            renewal_batch_size,
        };

        event::emit(VaultCreated {
            vault_id,
            creator: tx_context::sender(ctx),
        });

        // Share the vault so contributors can access it
        transfer::share_object(vault);
        vault_id
    }

    public fun store_blob<B: store>(
        vault: &mut PublicationVault<B>,
        blob_id: u256,
        blob: B,
        is_encrypted: bool,
        ctx: &TxContext,
    ) {
        let author = tx_context::sender(ctx);

        table::add(&mut vault.blobs, blob_id, blob);
        table::add(&mut vault.blob_is_encrypted, blob_id, is_encrypted);

        event::emit(BlobAdded {
            vault_id: object::id(vault),
            blob_id,
            is_encrypted,
            author,
        });
    }

    public fun get_blob<B: store>(vault: &PublicationVault<B>, blob_id: u256): &B {
        table::borrow(&vault.blobs, blob_id)
    }

    public fun get_blob_is_encrypted<B: store>(vault: &PublicationVault<B>, blob_id: u256): bool {
        *table::borrow(&vault.blob_is_encrypted, blob_id)
    }

    public fun remove_blob<B: store>(
        vault: &mut PublicationVault<B>,
        blob_id: u256,
        _ctx: &TxContext,
    ): B {
        // Authorization should be handled at higher level (e.g., content_registry)
        
        // Also remove our app-specific metadata
        table::remove(&mut vault.blob_is_encrypted, blob_id);
        table::remove(&mut vault.blobs, blob_id)
    }

    public fun has_blob<B: store>(vault: &PublicationVault<B>, blob_id: u256): bool {
        table::contains(&vault.blobs, blob_id)
    }

    public fun needs_renewal<B: store>(vault: &PublicationVault<B>, current_epoch: u64): bool {
        vault.next_renewal_epoch > 0 && current_epoch >= vault.next_renewal_epoch
    }

    public fun update_renewal_epoch<B: store>(
        _: &RenewCap,
        vault: &mut PublicationVault<B>,
        new_renewal_epoch: u64,
        ctx: &TxContext,
    ) {
        vault.next_renewal_epoch = new_renewal_epoch;

        event::emit(VaultRenewed {
            vault_id: object::id(vault),
            new_renewal_epoch,
            renewed_at: tx_context::epoch_timestamp_ms(ctx),
        });
    }

    // === View Functions ===
    public fun get_vault_info<B: store>(vault: &PublicationVault<B>): (u64, u64) {
        (vault.next_renewal_epoch, vault.renewal_batch_size)
    }

    public fun get_blob_count<B: store>(vault: &PublicationVault<B>): u64 {
        table::length(&vault.blobs)
    }

    public fun has_renewal_scheduled<B: store>(vault: &PublicationVault<B>): bool {
        vault.next_renewal_epoch > 0
    }

    public fun get_renewal_batch_size<B: store>(vault: &PublicationVault<B>): u64 {
        vault.renewal_batch_size
    }

    public fun set_renewal_batch_size<B: store>(vault: &mut PublicationVault<B>, new_batch_size: u64) {
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

    // === Test Helper Functions ===
    // Note: Blob creation is done off-chain, so we don't provide test blob creation functions
    // Tests should focus on vault management functions that don't require actual blobs
}