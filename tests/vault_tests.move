#[test_only]
module contracts::vault_tests {
    use contracts::publication_vault::{Self, PublicationVault, RenewCap};
    use contracts::publication as publication;
    use contracts::publication::{Publication, PublicationOwnerCap};
    use contracts::inkray_test_utils::{admin, creator, contributor, user1};
    use contracts::inkray_test_utils as test_utils;
    use contracts::inkray_test_utils::{get_test_registered_epoch, is_test_blob_deletable, get_test_encrypted_encoding_type};
    use sui::test_scenario::{Self, Scenario};
    use std::string;

    #[test]
    fun test_create_shared_vault() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create shared vault
        test_utils::next_tx(&mut scenario, creator());
        {
            let publication_id = @0x1.to_id();
            let batch_size = 10u64;
            
            publication_vault::create_vault(
                publication_id,
                batch_size,
                test_scenario::ctx(&mut scenario)
            );
        };
        
        // Verify vault was created and shared
        test_utils::next_tx(&mut scenario, creator());
        {
            let vault = test_utils::take_shared<PublicationVault>(&scenario);
            
            // Verify vault properties
            let (pub_id, renewal_epoch, vault_batch_size) = publication_vault::get_vault_info(&vault);
            test_utils::assert_eq(pub_id, @0x1.to_id());
            test_utils::assert_eq(renewal_epoch, 0); // Initially no renewal scheduled
            test_utils::assert_eq(vault_batch_size, 10u64);

            // Verify initial state
            test_utils::assert_false(publication_vault::has_renewal_scheduled(&vault));
            test_utils::assert_eq(publication_vault::get_renewal_batch_size(&vault), 10u64);
            test_utils::assert_eq(publication_vault::get_blob_count(&vault), 0);

            test_utils::return_shared(vault);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_store_blob_as_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication and add contributor
        test_utils::next_tx(&mut scenario, creator());
        {
            let (mut publication, owner_cap) = publication::create_publication(
                string::utf8(b"Test Publication"),
                string::utf8(b"Test Description"),
                @0x0.to_id(),
                test_scenario::ctx(&mut scenario)
            );
            
            // Add contributor
            publication::add_contributor(&owner_cap, &mut publication, contributor(), test_scenario::ctx(&mut scenario));
            
            // Create shared vault
            publication_vault::create_vault(
                object::id(&publication),
                10,
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Contributor stores blob
        test_utils::next_tx(&mut scenario, contributor());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());
            
            publication_vault::store_blob(
                &mut vault,
                &publication,
                test_utils::get_test_blob_id(),
                test_utils::get_test_blob_size(),
                test_utils::get_test_encoding_type(),
                test_utils::get_test_registered_epoch(),
                test_utils::is_test_blob_deletable(),
                false, // not encrypted
                test_scenario::ctx(&mut scenario)
            );
            
            // Verify blob was stored
            test_utils::assert_eq(publication_vault::get_blob_count(&vault), 1);
            test_utils::assert_true(publication_vault::has_blob(&vault, test_utils::get_test_blob_id()));
            
            // Store encrypted blob
            publication_vault::store_blob(
                &mut vault,
                &publication,
                test_utils::get_test_encrypted_blob_id(),
                test_utils::get_test_blob_size(),
                test_utils::get_test_encrypted_encoding_type(),
                test_utils::get_test_registered_epoch(),
                test_utils::is_test_blob_deletable(),
                true, // encrypted
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::assert_eq(publication_vault::get_blob_count(&vault), 2);
            
            test_utils::return_shared(vault);
            test_utils::return_to_address(creator(), publication);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_store_blob_as_owner() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let (mut publication, owner_cap) = publication::create_publication(
                string::utf8(b"Owner Publication"),
                string::utf8(b"Owner Description"),
                @0x0.to_id(),
                test_scenario::ctx(&mut scenario)
            );
            
            // Create shared vault
            publication_vault::create_vault(
                object::id(&publication),
                10,
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Owner stores blob
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_sender<Publication>(&scenario);
            
            publication_vault::store_blob(
                &mut vault,
                &publication,
                test_utils::get_test_blob_id(),
                test_utils::get_test_blob_size(),
                test_utils::get_test_encoding_type(),
                test_utils::get_test_registered_epoch(),
                test_utils::is_test_blob_deletable(),
                false,
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::assert_eq(publication_vault::get_blob_count(&vault), 1);
            
            test_utils::return_shared(vault);
            test_utils::return_to_sender(&scenario, publication);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    #[expected_failure(abort_code = contracts::publication_vault::ENotAuthorized)]
    fun test_unauthorized_store_blob() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication (user1 is not a contributor)
        test_utils::next_tx(&mut scenario, creator());
        {
            let (publication, owner_cap) = publication::create_publication(
                string::utf8(b"Private Publication"),
                string::utf8(b"Private Description"),
                @0x0.to_id(),
                test_scenario::ctx(&mut scenario)
            );
            
            publication_vault::create_vault(
                object::id(&publication),
                10,
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // user1 tries to store blob (should fail)
        test_utils::next_tx(&mut scenario, user1());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());
            
            publication_vault::store_blob(
                &mut vault,
                &publication,
                test_utils::get_test_blob_id(),
                test_utils::get_test_blob_size(),
                test_utils::get_test_encoding_type(),
                test_utils::get_test_registered_epoch(),
                test_utils::is_test_blob_deletable(),
                false,
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_shared(vault);
            test_utils::return_to_address(creator(), publication);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_get_and_remove_blob() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication and store blob
        test_utils::next_tx(&mut scenario, creator());
        {
            let (publication, owner_cap) = publication::create_publication(
                string::utf8(b"Blob Management"),
                string::utf8(b"Test Description"),
                @0x0.to_id(),
                test_scenario::ctx(&mut scenario)
            );
            
            publication_vault::create_vault(
                object::id(&publication),
                10,
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // Store blob
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_sender<Publication>(&scenario);
            
            publication_vault::store_blob(
                &mut vault,
                &publication,
                test_utils::get_test_blob_id(),
                test_utils::get_test_blob_size(),
                test_utils::get_test_encoding_type(),
                test_utils::get_test_registered_epoch(),
                test_utils::is_test_blob_deletable(),
                false,
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_shared(vault);
            test_utils::return_to_sender(&scenario, publication);
        };
        
        // Get and verify blob info
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_sender<Publication>(&scenario);
            
            let blob = publication_vault::get_blob(&vault, test_utils::get_test_blob_id());
            let (blob_id, size, encoding, registered_epoch, is_deletable, is_encrypted) = publication_vault::get_blob_info(blob);
            
            test_utils::assert_eq(blob_id, test_utils::get_test_blob_id());
            test_utils::assert_eq(size, test_utils::get_test_blob_size());
            test_utils::assert_eq(encoding, test_utils::get_test_encoding_type());
            test_utils::assert_false(is_encrypted);
            
            // Remove blob (only owner can remove)
            let removed_blob = publication_vault::remove_blob(
                &mut vault,
                &publication,
                test_utils::get_test_blob_id(),
                test_scenario::ctx(&mut scenario)
            );
            
            // Verify removal
            test_utils::assert_eq(publication_vault::get_blob_count(&vault), 0);
            test_utils::assert_false(publication_vault::has_blob(&vault, test_utils::get_test_blob_id()));
            
            // Clean up removed blob
            let (_, _, _, _, _, _) = publication_vault::get_blob_info(&removed_blob);
            
            test_utils::return_shared(vault);
            test_utils::return_to_sender(&scenario, publication);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_renewal_system_with_shared_vault() {
        let mut scenario = test_utils::begin_scenario(admin());
        
        // Initialize with RenewCap
        test_utils::next_tx(&mut scenario, admin());
        {
            publication_vault::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        // Create shared vault and test renewal
        test_utils::next_tx(&mut scenario, admin()); 
        {
            publication_vault::create_vault(
                @0x1.to_id(),
                10,
                test_scenario::ctx(&mut scenario)
            );
        };

        test_utils::next_tx(&mut scenario, admin()); 
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let renew_cap = test_utils::take_from_sender<RenewCap>(&scenario);
            
            let current_epoch = 100u64;
            
            // Initially no renewal needed
            test_utils::assert_false(
                publication_vault::needs_renewal(&vault, current_epoch)
            );

            // Update renewal epoch
            let future_renewal_epoch = current_epoch + 50;
            publication_vault::update_renewal_epoch(
                &renew_cap,
                &mut vault,
                future_renewal_epoch,
                test_scenario::ctx(&mut scenario)
            );

            // Should not need renewal yet
            test_utils::assert_false(
                publication_vault::needs_renewal(&vault, current_epoch)
            );

            // Should need renewal when epoch passes
            test_utils::assert_true(
                publication_vault::needs_renewal(&vault, future_renewal_epoch)
            );

            test_utils::return_shared(vault);
            test_utils::return_to_sender(&scenario, renew_cap);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_multiple_contributors_shared_access() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create publication with multiple contributors
        test_utils::next_tx(&mut scenario, creator());
        {
            let (mut publication, owner_cap) = publication::create_publication(
                string::utf8(b"Multi-Contributor"),
                string::utf8(b"Test Description"),
                @0x0.to_id(),
                test_scenario::ctx(&mut scenario)
            );
            
            // Add contributors
            publication::add_contributor(&owner_cap, &mut publication, contributor(), test_scenario::ctx(&mut scenario));
            publication::add_contributor(&owner_cap, &mut publication, user1(), test_scenario::ctx(&mut scenario));
            
            publication_vault::create_vault(
                object::id(&publication),
                10,
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };
        
        // First contributor stores blob
        test_utils::next_tx(&mut scenario, contributor());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());
            
            publication_vault::store_blob(
                &mut vault,
                &publication,
                1000u256,
                test_utils::get_test_blob_size(),
                test_utils::get_test_encoding_type(),
                test_utils::get_test_registered_epoch(),
                test_utils::is_test_blob_deletable(),
                false,
                test_scenario::ctx(&mut scenario)
            );
            
            test_utils::return_shared(vault);
            test_utils::return_to_address(creator(), publication);
        };
        
        // Second contributor stores blob
        test_utils::next_tx(&mut scenario, user1());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());
            
            publication_vault::store_blob(
                &mut vault,
                &publication,
                2000u256,
                test_utils::get_test_blob_size(),
                test_utils::get_test_encoding_type(),
                test_utils::get_test_registered_epoch(),
                test_utils::is_test_blob_deletable(),
                true, // encrypted
                test_scenario::ctx(&mut scenario)
            );
            
            // Verify both blobs exist
            test_utils::assert_eq(publication_vault::get_blob_count(&vault), 2);
            test_utils::assert_true(publication_vault::has_blob(&vault, 1000u256));
            test_utils::assert_true(publication_vault::has_blob(&vault, 2000u256));
            
            test_utils::return_shared(vault);
            test_utils::return_to_address(creator(), publication);
        };

        test_utils::end_scenario(scenario);
    }
}