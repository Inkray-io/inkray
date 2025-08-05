module contracts::publication {
    use sui::vec_set::{Self, VecSet};
    use sui::event;
    use std::string::String;

    // === Errors ===
    const ENotOwner: u64 = 0;
    const EContributorNotFound: u64 = 1;
    const EContributorAlreadyExists: u64 = 2;

    // === Structs ===
    public struct Publication has key, store {
        id: UID,
        name: String,
        description: String,
        owner: address,
        vault_id: ID,
        contributors: VecSet<address>,
    }

    public struct PublicationOwnerCap has key, store {
        id: UID,
        publication_id: ID,
    }

    // === Events ===
    public struct PublicationCreated has copy, drop {
        publication_id: ID,
        owner: address,
        name: String,
        vault_id: ID,
    }

    public struct ContributorAdded has copy, drop {
        publication_id: ID,
        contributor: address,
        added_by: address,
    }

    public struct ContributorRemoved has copy, drop {
        publication_id: ID,
        contributor: address,
        removed_by: address,
    }

    // === Public Functions ===
    public fun create_publication(
        name: String,
        description: String,
        vault_id: ID,
        ctx: &mut TxContext
    ): (Publication, PublicationOwnerCap) {
        let id = object::new(ctx);
        let publication_id = object::uid_to_inner(&id);
        let owner = tx_context::sender(ctx);

        let publication = Publication {
            id,
            name,
            description,
            owner,
            vault_id,
            contributors: vec_set::empty(),
        };

        let owner_cap = PublicationOwnerCap {
            id: object::new(ctx),
            publication_id,
        };

        event::emit(PublicationCreated {
            publication_id,
            owner,
            name: publication.name,
            vault_id,
        });

        (publication, owner_cap)
    }

    public fun add_contributor(
        owner_cap: &PublicationOwnerCap,
        publication: &mut Publication,
        contributor: address,
        ctx: &TxContext
    ) {
        assert!(owner_cap.publication_id == object::id(publication), ENotOwner);
        assert!(!vec_set::contains(&publication.contributors, &contributor), EContributorAlreadyExists);
        
        vec_set::insert(&mut publication.contributors, contributor);
        
        event::emit(ContributorAdded {
            publication_id: object::id(publication),
            contributor,
            added_by: tx_context::sender(ctx),
        });
    }

    public fun remove_contributor(
        owner_cap: &PublicationOwnerCap,
        publication: &mut Publication,
        contributor: address,
        ctx: &TxContext
    ) {
        assert!(owner_cap.publication_id == object::id(publication), ENotOwner);
        assert!(vec_set::contains(&publication.contributors, &contributor), EContributorNotFound);
        
        vec_set::remove(&mut publication.contributors, &contributor);
        
        event::emit(ContributorRemoved {
            publication_id: object::id(publication),
            contributor,
            removed_by: tx_context::sender(ctx),
        });
    }

    // === View Functions ===
    public fun is_authorized_with_cap(
        publication: &Publication,
        user: address,
        owner_cap: &PublicationOwnerCap
    ): bool {
        // Check if user is owner (has capability)
        if (owner_cap.publication_id == object::id(publication)) {
            return true
        };
        
        // Check if user is a contributor
        vec_set::contains(&publication.contributors, &user)
    }

    public fun is_contributor(
        publication: &Publication,
        user: address
    ): bool {
        vec_set::contains(&publication.contributors, &user)
    }

    public fun get_contributors(publication: &Publication): &VecSet<address> {
        &publication.contributors
    }

    public fun get_vault_id(publication: &Publication): ID {
        publication.vault_id
    }

    public fun get_owner(publication: &Publication): address {
        publication.owner
    }

    public fun is_owner(publication: &Publication, addr: address): bool {
        publication.owner == addr
    }

    public fun set_vault_id(owner_cap: &PublicationOwnerCap, publication: &mut Publication, vault_id: ID) {
        assert!(owner_cap.publication_id == object::id(publication), ENotOwner);
        publication.vault_id = vault_id;
    }

    public fun get_publication_info(publication: &Publication): (String, String, ID) {
        (publication.name, publication.description, publication.vault_id)
    }

    public fun get_publication_id(owner_cap: &PublicationOwnerCap): ID {
        owner_cap.publication_id
    }
}