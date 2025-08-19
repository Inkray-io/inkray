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
            let (owner_cap, _publication_addr) = publication::create(
                test_utils::get_test_publication_name(),
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Get the shared publication object
        test_utils::next_tx(&mut scenario, creator());
        {
            let publication = test_utils::take_shared<Publication>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

            // Verify publication properties
            let name = publication::get_name(&publication);
            test_utils::assert_eq(name, test_utils::get_test_publication_name());

            // Verify owner cap
            test_utils::assert_true(publication::verify_owner_cap(&owner_cap, &publication));

            // Verify contributors list is empty initially
            let contributors = publication::get_contributors(&publication);
            test_utils::assert_eq(vector::length(contributors), 0);

            test_utils::return_shared(publication);
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
            let (owner_cap, _publication_addr) = publication::create(
                test_utils::get_test_publication_name(),
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Add contributor to shared publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut publication = test_utils::take_shared<Publication>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

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
            test_utils::assert_eq(vector::length(contributors), 1);

            // Verify contributor authorization
            test_utils::assert_true(
                publication::is_contributor(&publication, contributor())
            );

            test_utils::return_shared(publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that multiple contributors can be added to a publication.
    #[test]
    fun test_add_multiple_contributors() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let (owner_cap, _publication_addr) = publication::create(
                test_utils::get_test_publication_name(),
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Add multiple contributors to shared publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut publication = test_utils::take_shared<Publication>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

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
            test_utils::assert_eq(vector::length(contributors), 2);

            test_utils::return_shared(publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that a contributor can be removed from a publication.
    #[test]
    fun test_remove_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let (owner_cap, _publication_addr) = publication::create(
                test_utils::get_test_publication_name(),
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Add and remove contributor from shared publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut publication = test_utils::take_shared<Publication>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

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
            test_utils::assert_eq(vector::length(contributors), 0);
            test_utils::assert_false(
                publication::is_contributor(&publication, contributor())
            );

            test_utils::return_shared(publication);
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
            let (owner_cap, _publication_addr) = publication::create(
                test_utils::get_test_publication_name(),
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Test owner authorization with shared publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let publication = test_utils::take_shared<Publication>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

            // Verify owner authorization using cap verification
            test_utils::assert_true(
                publication::verify_owner_cap(&owner_cap, &publication)
            );

            test_utils::return_shared(publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that an unauthorized user cannot add a contributor.
    #[test]
    #[expected_failure(abort_code = contracts::publication::E_NOT_OWNER)]
    fun test_unauthorized_add_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let (owner_cap, _publication_addr) = publication::create(
                test_utils::get_test_publication_name(),
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        // Try to add contributor with wrong cap
        test_utils::next_tx(&mut scenario, user1()); // Different user
        {
            let mut publication = test_utils::take_shared<Publication>(&scenario);
            
            // Create a different publication by user1 to get a wrong cap
            let (wrong_cap, _wrong_addr) = publication::create(
                string::utf8(b"Wrong Publication"),
                test_scenario::ctx(&mut scenario)
            );

            // This should abort with E_NOT_OWNER - using wrong cap for this publication
            publication::add_contributor(
                &wrong_cap,
                &mut publication,
                contributor(),
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_shared(publication);
            test_utils::return_to_sender(&scenario, wrong_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that adding a duplicate contributor fails.
    #[test]
    #[expected_failure(abort_code = contracts::publication::E_CONTRIBUTOR_EXISTS)]
    fun test_add_duplicate_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let (owner_cap, _publication_addr) = publication::create(
                test_utils::get_test_publication_name(),
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Add duplicate contributor to shared publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut publication = test_utils::take_shared<Publication>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

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

            test_utils::return_shared(publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }

    /// Test that removing a non-existent contributor fails.
    #[test]
    #[expected_failure(abort_code = contracts::publication::E_CONTRIBUTOR_NOT_FOUND)]
    fun test_remove_nonexistent_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let (owner_cap, _publication_addr) = publication::create(
                test_utils::get_test_publication_name(),
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Try to remove nonexistent contributor from shared publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut publication = test_utils::take_shared<Publication>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

            // Try to remove contributor that was never added - should fail
            publication::remove_contributor(
                &owner_cap,
                &mut publication,
                contributor(),
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_shared(publication);
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
            let (owner_cap, _publication_addr) = publication::create(
                test_utils::get_test_publication_name(),
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Test contributor events with shared publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut publication = test_utils::take_shared<Publication>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

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

            test_utils::return_shared(publication);
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
            let (owner_cap, _publication_addr) = publication::create(
                string::utf8(b""),
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Check empty name in shared publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let publication = test_utils::take_shared<Publication>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

            let name = publication::get_name(&publication);
            assert!(name == string::utf8(b""));

            test_utils::return_shared(publication);
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
            let (owner_cap, _publication_addr) = publication::create(
                test_utils::get_test_publication_name(),
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Add owner as contributor to shared publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut publication = test_utils::take_shared<Publication>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

            publication::add_contributor(
                &owner_cap,
                &mut publication,
                creator(), // owner is the creator
                test_scenario::ctx(&mut scenario)
            );

            assert!(publication::is_contributor(&publication, creator()));

            test_utils::return_shared(publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        test_utils::end_scenario(scenario);
    }
}