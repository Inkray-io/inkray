module contracts::seal_content_policy {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::vec_set::{Self, VecSet};
    use contracts::publication::{Self, Publication, PublicationOwnerCap};

    // Error codes
    const E_NO_ACCESS: u64 = 0;
    const E_NOT_OWNER: u64 = 1;

    // Content access policy for publication-based and allowlist-based access
    // Note: Platform subscription and NFT access are handled in their respective modules
    public struct ContentAccessPolicy has key, store {
        id: UID,
        publication_id: ID,
        article_id: ID,
        // Access control flags
        allow_contributors: bool,    // Allow publication contributors to access
        // Additional allowlist for specific addresses
        allowlist: VecSet<address>,
    }

    // Create content access policy
    public fun create_policy(
        publication_id: ID,
        article_id: ID,
        allow_contributors: bool,
        ctx: &mut TxContext
    ): ContentAccessPolicy {
        ContentAccessPolicy {
            id: object::new(ctx),
            publication_id,
            article_id,
            allow_contributors,
            allowlist: vec_set::empty(),
        }
    }

    // Create and share content access policy
    public entry fun create_and_share_policy(
        publication_id: ID,
        article_id: ID,
        allow_contributors: bool,
        ctx: &mut TxContext
    ) {
        let policy = create_policy(
            publication_id, 
            article_id, 
            allow_contributors, 
            ctx
        );
        transfer::share_object(policy);
    }

    // Add address to allowlist
    public entry fun add_to_allowlist(
        policy: &mut ContentAccessPolicy,
        owner_cap: &PublicationOwnerCap,
        address_to_add: address,
        _ctx: &TxContext
    ) {
        // Verify ownership
        assert!(publication::get_publication_id(owner_cap) == policy.publication_id, E_NOT_OWNER);
        
        vec_set::insert(&mut policy.allowlist, address_to_add);
    }

    // Remove address from allowlist
    public entry fun remove_from_allowlist(
        policy: &mut ContentAccessPolicy,
        owner_cap: &PublicationOwnerCap,
        address_to_remove: address,
        _ctx: &TxContext
    ) {
        // Verify ownership
        assert!(publication::get_publication_id(owner_cap) == policy.publication_id, E_NOT_OWNER);
        
        vec_set::remove(&mut policy.allowlist, &address_to_remove);
    }

    // === Specialized Seal Approval Functions ===
    // Each function handles a specific access method for cleaner separation

    // Seal approval for publication owner using owner cap
    entry fun seal_approve_publication_owner(
        _id: vector<u8>,
        owner_cap: &PublicationOwnerCap,
        publication: &Publication,
        _ctx: &TxContext
    ) {
        // Verify the owner cap matches the publication
        assert!(
            publication::get_publication_id(owner_cap) == object::id(publication),
            E_NO_ACCESS
        );
    }

    // Seal approval for publication contributors
    entry fun seal_approve_publication(
        id: vector<u8>,
        policy: &ContentAccessPolicy,
        publication: &Publication,
        ctx: &TxContext
    ) {
        assert!(
            approve_publication_internal(id, policy, publication, ctx),
            E_NO_ACCESS
        );
    }

    // Seal approval for allowlist-based access
    entry fun seal_approve_allowlist(
        id: vector<u8>,
        policy: &ContentAccessPolicy,
        ctx: &TxContext
    ) {
        assert!(
            approve_allowlist_internal(id, policy, ctx),
            E_NO_ACCESS
        );
    }

    // === Internal Approval Functions ===

    // Check publication owner or contributor access
    fun approve_publication_internal(
        _id: vector<u8>,
        policy: &ContentAccessPolicy,
        publication: &Publication,
        ctx: &TxContext
    ): bool {
        // Verify this is the correct publication
        if (object::id(publication) != policy.publication_id) {
            return false
        };

        let caller = tx_context::sender(ctx);

        // Check if caller is a contributor
        if (policy.allow_contributors && publication::is_contributor(publication, caller)) {
            return true
        };

        // Note: Owner verification would require the OwnerCap to be passed
        // Since users typically don't have the OwnerCap in their wallet,
        // owner access is better handled through the contributor list
        false
    }

    // Check allowlist-based access
    fun approve_allowlist_internal(
        _id: vector<u8>,
        policy: &ContentAccessPolicy,
        ctx: &TxContext
    ): bool {
        let caller = tx_context::sender(ctx);
        vec_set::contains(&policy.allowlist, &caller)
    }

    // View functions
    public fun get_policy_info(policy: &ContentAccessPolicy): (ID, ID, bool) {
        (
            policy.publication_id,
            policy.article_id,
            policy.allow_contributors
        )
    }

    public fun is_in_allowlist(policy: &ContentAccessPolicy, addr: address): bool {
        vec_set::contains(&policy.allowlist, &addr)
    }
}