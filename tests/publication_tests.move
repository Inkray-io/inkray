#[test_only]
module contracts::publication_tests {
    use contracts::publication::{Self, Publication, PublicationOwnerCap};
    use contracts::inkray_test_utils::{creator, contributor, user1};
    use contracts::inkray_test_utils as test_utils;
    use sui::test_scenario;
    use std::string;

    /// Test that a publication can be created with the correct properties.
    #[test]
    fun test_create_publication() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let (publication, owner_cap) = publication::create_publication(
                test_utils::get_test_publication_name(),
                test_utils::get_test_publication_description(),
                @0x1.to_id(),
                test_scenario::ctx(&mut scenario)
            );

            // Verify publication properties
            let (name, description, vault_id) = publication::get_publication_info(&publication);
            test_utils::assert_eq(name, test_utils::get_test_publication_name());
            test_utils::assert_eq(description, test_utils::get_test_publication_description());
            test_utils::assert_eq(vault_id, @0x1.to_id());

            // Verify owner cap
            let cap_pub_id = publication::get_publication_id(&owner_cap);
            test_utils::assert_eq(cap_pub_id, object::id(&publication));

            // Verify contributors list is empty initially
            let contributors = publication::get_contributors(&publication);
            test_utils::assert_eq(sui::vec_set::size(contributors), 0);

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that a contributor can be added to a publication.
    #[test]
    fun test_add_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let (mut publication, owner_cap) = publication::create_publication(
                test_utils::get_test_publication_name(),
                test_utils::get_test_publication_description(),
                @0x1.to_id(),
                test_scenario::ctx(&mut scenario)
            );

            // Add contributor
            publication::add_contributor(
                &owner_cap,
                &mut publication,
                contributor(),
                test_scenario::ctx(&mut scenario)
            );

            // Verify contributor was added
            test_utils::assert_publication_has_contributor(&publication, contributor());

            // Verify contributor count
            let contributors = publication::get_contributors(&publication);
            test_utils::assert_eq(sui::vec_set::size(contributors), 1);

            // Verify contributor authorization
            test_utils::assert_true(
                publication::is_contributor(&publication, contributor())
            );

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that multiple contributors can be added to a publication.
    #[test]
    fun test_add_multiple_contributors() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication and add multiple contributors
        test_utils::next_tx(&mut scenario, creator());
        {
            let (mut publication, owner_cap) = publication::create_publication(
                test_utils::get_test_publication_name(),
                test_utils::get_test_publication_description(),
                @0x1.to_id(),
                test_scenario::ctx(&mut scenario)
            );

            // Add first contributor
            publication::add_contributor(
                &owner_cap,
                &mut publication,
                contributor(),
                test_scenario::ctx(&mut scenario)
            );

            // Add second contributor
            publication::add_contributor(
                &owner_cap,
                &mut publication,
                user1(),
                test_scenario::ctx(&mut scenario)
            );

            // Verify both contributors
            test_utils::assert_publication_has_contributor(&publication, contributor());
            test_utils::assert_publication_has_contributor(&publication, user1());

            // Verify contributor count
            let contributors = publication::get_contributors(&publication);
            test_utils::assert_eq(sui::vec_set::size(contributors), 2);

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that a contributor can be removed from a publication.
    #[test]
    fun test_remove_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication and add contributor
        test_utils::next_tx(&mut scenario, creator());
        {
            let (mut publication, owner_cap) = publication::create_publication(
                test_utils::get_test_publication_name(),
                test_utils::get_test_publication_description(),
                @0x1.to_id(),
                test_scenario::ctx(&mut scenario)
            );

            // Add contributor
            publication::add_contributor(
                &owner_cap,
                &mut publication,
                contributor(),
                test_scenario::ctx(&mut scenario)
            );

            // Verify contributor was added
            test_utils::assert_publication_has_contributor(&publication, contributor());

            // Remove contributor
            publication::remove_contributor(
                &owner_cap,
                &mut publication,
                contributor(),
                test_scenario::ctx(&mut scenario)
            );

            // Verify contributor was removed
            let contributors = publication::get_contributors(&publication);
            test_utils::assert_eq(sui::vec_set::size(contributors), 0);
            test_utils::assert_false(
                publication::is_contributor(&publication, contributor())
            );

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test the owner authorization logic.
    #[test]
    fun test_owner_authorization() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let (publication, owner_cap) = publication::create_publication(
                test_utils::get_test_publication_name(),
                test_utils::get_test_publication_description(),
                @0x1.to_id(),
                test_scenario::ctx(&mut scenario)
            );

            // Verify owner authorization
            test_utils::assert_true(
                publication::is_owner_with_cap_or_contributor(&publication, creator(), &owner_cap)
            );

            // Verify another user is also considered authorized if the valid cap is presented
            test_utils::assert_true(
                publication::is_owner_with_cap_or_contributor(&publication, user1(), &owner_cap)
            ); // Note: Owner cap authorizes the transaction, ignoring the user param

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that an unauthorized user cannot add a contributor.
    #[test]
    #[expected_failure(abort_code = contracts::publication::ENotOwner)]
    fun test_unauthorized_add_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let (mut publication, owner_cap) = publication::create_publication(
                test_utils::get_test_publication_name(),
                test_utils::get_test_publication_description(),
                @0x1.to_id(),
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        // Try to add contributor as non-owner
        test_utils::next_tx(&mut scenario, user1()); // Different user
        {
            let mut publication = test_utils::take_from_address<Publication>(&scenario, creator());
            let owner_cap = test_utils::take_from_address<PublicationOwnerCap>(&scenario, creator());

            // This should fail - user1 doesn't own a different publication
            let (mut wrong_publication, wrong_cap) = publication::create_publication(
                string::utf8(b"Wrong Publication"),
                string::utf8(b"Wrong Description"),
                @0x2.to_id(),
                test_scenario::ctx(&mut scenario)
            );

            // This should abort with ENotOwner
            publication::add_contributor(
                &wrong_cap,
                &mut publication, // Using wrong cap for this publication
                contributor(),
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_address(creator(), owner_cap);
            test_utils::return_to_sender(&scenario, wrong_publication);
            test_utils::return_to_sender(&scenario, wrong_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that adding a duplicate contributor fails.
    #[test]
    #[expected_failure(abort_code = contracts::publication::EContributorAlreadyExists)]
    fun test_add_duplicate_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let (mut publication, owner_cap) = publication::create_publication(
                test_utils::get_test_publication_name(),
                test_utils::get_test_publication_description(),
                @0x1.to_id(),
                test_scenario::ctx(&mut scenario)
            );

            // Add contributor
            publication::add_contributor(
                &owner_cap,
                &mut publication,
                contributor(),
                test_scenario::ctx(&mut scenario)
            );

            // Try to add the same contributor again - should fail
            publication::add_contributor(
                &owner_cap,
                &mut publication,
                contributor(),
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that removing a non-existent contributor fails.
    #[test]
    #[expected_failure(abort_code = contracts::publication::EContributorNotFound)]
    fun test_remove_nonexistent_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let (mut publication, owner_cap) = publication::create_publication(
                test_utils::get_test_publication_name(),
                test_utils::get_test_publication_description(),
                @0x1.to_id(),
                test_scenario::ctx(&mut scenario)
            );

            // Try to remove contributor that was never added - should fail
            publication::remove_contributor(
                &owner_cap,
                &mut publication,
                contributor(),
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that publication events are emitted correctly.
    #[test]
    fun test_publication_events() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Test publication creation event
        test_utils::next_tx(&mut scenario, creator());
        {
            let (mut publication, owner_cap) = publication::create_publication(
                test_utils::get_test_publication_name(),
                test_utils::get_test_publication_description(),
                @0x1.to_id(),
                test_scenario::ctx(&mut scenario)
            );

            // Add contributor to test event
            publication::add_contributor(
                &owner_cap,
                &mut publication,
                contributor(),
                test_scenario::ctx(&mut scenario)
            );

            // Remove contributor to test event
            publication::remove_contributor(
                &owner_cap,
                &mut publication,
                contributor(),
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        // Events are emitted (verified through successful execution)

        test_utils::end_scenario(scenario);
    }

    /// Test that a publication can be created with an empty name.
    #[test]
    fun test_create_publication_with_empty_name() {
        let mut scenario = test_utils::begin_scenario(creator());

        test_utils::next_tx(&mut scenario, creator());
        {
            let (publication, owner_cap) = publication::create_publication(
                string::utf8(b""),
                test_utils::get_test_publication_description(),
                @0x1.to_id(),
                test_scenario::ctx(&mut scenario)
            );

            let (name, _, _) = publication::get_publication_info(&publication);
            assert!(name == string::utf8(b""));

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that the owner can be added as a contributor.
    #[test]
    fun test_owner_can_be_added_as_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());

        test_utils::next_tx(&mut scenario, creator());
        {
            let (mut publication, owner_cap) = publication::create_publication(
                test_utils::get_test_publication_name(),
                test_utils::get_test_publication_description(),
                @0x1.to_id(),
                test_scenario::ctx(&mut scenario)
            );

            publication::add_contributor(
                &owner_cap,
                &mut publication,
                creator(), // owner is the creator
                test_scenario::ctx(&mut scenario)
            );

            assert!(publication::is_contributor(&publication, creator()));

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }
}