module contracts::publication_vault {
    use contracts::publication::{Self as publication, Publication};
    use sui::event;
    use sui::table::{Self, Table};
    // use std::string::String; // Not needed currently
    
    // === Errors ===
    const ENotAuthorized: u64 = 0;
    
    // === Structs ===
    
    // Walrus-compatible blob structure containing all data from actual Walrus Blob objects
    // This matches the fields available in walrus::system::blob::Blob
    public struct WalrusBlob has store, drop {
        blob_id: u256,
        size: u64,
        encoding_type: u8,
        registered_epoch: u32,
        is_deletable: bool,
        // Application-level metadata
        is_encrypted: bool, // Our content classification
    }
    
    public struct PublicationVault has key, store {
        id: UID,
        publication_id: ID,
        blobs: Table<u256, WalrusBlob>, // Store Walrus-compatible blob objects
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

    // Store blob with all Walrus metadata
    // In production: Backend uploads to Walrus, gets Blob object, extracts this data, then calls this function
    public fun store_blob(
        vault: &mut PublicationVault,
        publication: &Publication,
        blob_id: u256,
        size: u64,
        encoding_type: u8,
        registered_epoch: u32,
        is_deletable: bool,
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

        let walrus_blob = WalrusBlob {
            blob_id,
            size,
            encoding_type,
            registered_epoch,
            is_deletable,
            is_encrypted,
        };
        
        table::add(&mut vault.blobs, blob_id, walrus_blob);

        event::emit(BlobAdded {
            vault_id: object::id(vault),
            publication_id: vault.publication_id,
            blob_id,
            is_encrypted,
            author,
        });
    }

    public fun get_blob(vault: &PublicationVault, blob_id: u256): &WalrusBlob {
        table::borrow(&vault.blobs, blob_id)
    }

    public fun remove_blob(
        vault: &mut PublicationVault,
        publication: &Publication,
        blob_id: u256,
        ctx: &TxContext,
    ): WalrusBlob {
        let author = tx_context::sender(ctx);
        assert!(object::id(publication) == vault.publication_id, ENotAuthorized);
        assert!(
            publication::is_owner(publication, author), // Only owner can remove blobs
            ENotAuthorized,
        );

        table::remove(&mut vault.blobs, blob_id)
    }

    public fun get_blob_info(blob: &WalrusBlob): (u256, u64, u8, u32, bool, bool) {
        (
            blob.blob_id,
            blob.size,
            blob.encoding_type,
            blob.registered_epoch,
            blob.is_deletable,
            blob.is_encrypted
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
            next_renewal_epoch: 0,
            renewal_batch_size,
        }
    }

    #[test_only]
    public fun create_test_walrus_blob(
        blob_id: u256,
        size: u64,
        encoding_type: u8,
        is_encrypted: bool,
    ): WalrusBlob {
        WalrusBlob {
            blob_id,
            size,
            encoding_type,
            registered_epoch: 0,
            is_deletable: false,
            is_encrypted,
        }
    }
    
    // === Backend Integration Notes ===
    // 
    // Production Integration Workflow:
    // 1. User uploads file via frontend
    // 2. Backend uploads to Walrus via API: `PUT /v1/blobs`
    // 3. Walrus returns actual Blob object with properties:
    //    - blob_id: u256
    //    - size: u64  
    //    - encoding_type: u8
    //    - registered_epoch: u32
    //    - is_deletable: bool
    // 4. Backend extracts these values from the Walrus Blob object
    // 5. Backend calls store_blob() with extracted values + is_encrypted flag
    // 6. Smart contract stores WalrusBlob with all original Walrus data
    //
    // Future Enhancement:
    // When Walrus module imports are resolved, we can:
    // - Accept actual walrus::system::Blob objects directly
    // - Use walrus::system::blob_id(), walrus::system::size(), etc.
    // - Store actual Blob objects instead of extracted data
}