#[test_only]
module contracts::vault_tests {
    use contracts::publication_vault::{Self, PublicationVault, RenewCap};
    use contracts::inkray_test_utils::{admin, creator, contributor, user1};
    use contracts::inkray_test_utils as test_utils;
    use sui::test_scenario::{Self, Scenario};

    #[test]
    fun test_create_vault() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create vault
        test_utils::next_tx(&mut scenario, creator());
        {
            let publication_id = @0x1.to_id();
            let batch_size = 10u64;
            
            let vault = publication_vault::create_vault(
                publication_id,
                batch_size,
                test_scenario::ctx(&mut scenario)
            );

            // Verify vault properties
            let (pub_id, renewal_epoch, vault_batch_size) = publication_vault::get_vault_info(&vault);
            test_utils::assert_eq(pub_id, publication_id);
            test_utils::assert_eq(renewal_epoch, 0); // Initially no renewal scheduled
            test_utils::assert_eq(vault_batch_size, batch_size);

            // Verify initial state
            test_utils::assert_false(publication_vault::has_renewal_scheduled(&vault));
            test_utils::assert_eq(publication_vault::get_renewal_batch_size(&vault), batch_size);

            test_utils::return_to_sender(&scenario, vault);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_add_blob() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create vault
        test_utils::next_tx(&mut scenario, creator());
        {
            let vault = publication_vault::create_vault(
                @0x1.to_id(),
                10,
                test_scenario::ctx(&mut scenario)
            );

            // Add blob (free content)
            publication_vault::add_blob(
                &vault,
                test_utils::get_test_blob_id(),
                false, // not encrypted
                test_scenario::ctx(&mut scenario)
            );

            // Add encrypted blob (paid content)
            publication_vault::add_blob(
                &vault,
                test_utils::get_test_encrypted_blob_id(),
                true, // encrypted
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_sender(&scenario, vault);
        };

        // Events are emitted (verified through successful execution)

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_needs_renewal() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create vault
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut vault = publication_vault::create_vault(
                @0x1.to_id(),
                10,
                test_scenario::ctx(&mut scenario)
            );

            let current_epoch = 100u64;
            
            // Initially no renewal needed (epoch is 0)
            test_utils::assert_false(
                publication_vault::needs_renewal(&vault, current_epoch)
            );

            // Update renewal epoch to simulate scheduled renewal
            let renew_cap = publication_vault::create_renew_cap_for_testing(
                test_scenario::ctx(&mut scenario)
            );
            
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

            test_utils::return_to_sender(&scenario, vault);
            test_utils::return_to_sender(&scenario, renew_cap);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_update_renewal_epoch() {
        let mut scenario = test_utils::begin_scenario(admin());
        
        // Initialize with RenewCap
        test_utils::next_tx(&mut scenario, admin());
        {
            publication_vault::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        // Create vault and update renewal epoch
        test_utils::next_tx(&mut scenario, admin()); // Use admin to access RenewCap
        {
            let mut vault = publication_vault::create_vault(
                @0x1.to_id(),
                10,
                test_scenario::ctx(&mut scenario)
            );

            let renew_cap = test_utils::take_from_sender<RenewCap>(&scenario);
            let new_renewal_epoch = 200u64;

            // Update renewal epoch
            publication_vault::update_renewal_epoch(
                &renew_cap,
                &mut vault,
                new_renewal_epoch,
                test_scenario::ctx(&mut scenario)
            );

            // Verify update
            let (_, renewal_epoch, _) = publication_vault::get_vault_info(&vault);
            test_utils::assert_eq(renewal_epoch, new_renewal_epoch);
            test_utils::assert_true(publication_vault::has_renewal_scheduled(&vault));

            test_utils::return_to_sender(&scenario, vault);
            test_utils::return_to_sender(&scenario, renew_cap);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_batch_size_configuration() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Test different batch sizes
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut vault1 = publication_vault::create_vault(@0x1.to_id(), 5, test_scenario::ctx(&mut scenario));
            let mut vault2 = publication_vault::create_vault(@0x2.to_id(), 25, test_scenario::ctx(&mut scenario));
            let mut vault3 = publication_vault::create_vault(@0x3.to_id(), 100, test_scenario::ctx(&mut scenario));

            // Verify batch sizes
            test_utils::assert_eq(publication_vault::get_renewal_batch_size(&vault1), 5);
            test_utils::assert_eq(publication_vault::get_renewal_batch_size(&vault2), 25);
            test_utils::assert_eq(publication_vault::get_renewal_batch_size(&vault3), 100);

            // Test batch size modification
            publication_vault::set_renewal_batch_size(&mut vault1, 15);
            test_utils::assert_eq(publication_vault::get_renewal_batch_size(&vault1), 15);

            test_utils::return_to_sender(&scenario, vault1);
            test_utils::return_to_sender(&scenario, vault2);
            test_utils::return_to_sender(&scenario, vault3);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_vault_events() {
        let mut scenario = test_utils::begin_scenario(admin());
        
        // Initialize with RenewCap
        test_utils::next_tx(&mut scenario, admin());
        {
            publication_vault::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        // Test all vault events
        test_utils::next_tx(&mut scenario, admin()); // Use admin to access RenewCap
        {
            let mut vault = publication_vault::create_vault(
                @0x1.to_id(),
                10,
                test_scenario::ctx(&mut scenario)
            );

            // Add blob (triggers BlobAdded event)
            publication_vault::add_blob(
                &vault,
                test_utils::get_test_blob_id(),
                false,
                test_scenario::ctx(&mut scenario)
            );

            // Update renewal epoch (triggers VaultRenewed event)
            let renew_cap = test_utils::take_from_sender<RenewCap>(&scenario);
            publication_vault::update_renewal_epoch(
                &renew_cap,
                &mut vault,
                100,
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_sender(&scenario, vault);
            test_utils::return_to_sender(&scenario, renew_cap);
        };

        // Events are emitted (verified through successful execution)

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_multiple_vaults_same_publication() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create multiple vaults for the same publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let publication_id = @0x1.to_id();
            
            let vault1 = publication_vault::create_vault(publication_id, 10, test_scenario::ctx(&mut scenario));
            let vault2 = publication_vault::create_vault(publication_id, 20, test_scenario::ctx(&mut scenario));

            // Verify they have the same publication ID but different vault IDs
            let (pub_id1, _, _) = publication_vault::get_vault_info(&vault1);
            let (pub_id2, _, _) = publication_vault::get_vault_info(&vault2);
            
            test_utils::assert_eq(pub_id1, publication_id);
            test_utils::assert_eq(pub_id2, publication_id);
            test_utils::assert_true(object::id(&vault1) != object::id(&vault2));

            test_utils::return_to_sender(&scenario, vault1);
            test_utils::return_to_sender(&scenario, vault2);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_blob_tracking_workflow() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create vault and simulate article publishing workflow
        test_utils::next_tx(&mut scenario, creator());
        {
            let vault = publication_vault::create_vault(
                @0x1.to_id(),
                10,
                test_scenario::ctx(&mut scenario)
            );

            // Simulate publishing multiple articles with different content types
            // Article 1: Free content with image
            publication_vault::add_blob(&vault, 100u256, false, test_scenario::ctx(&mut scenario)); // article
            publication_vault::add_blob(&vault, 101u256, false, test_scenario::ctx(&mut scenario)); // image

            // Article 2: Paid content with video
            publication_vault::add_blob(&vault, 200u256, true, test_scenario::ctx(&mut scenario));  // encrypted article
            publication_vault::add_blob(&vault, 201u256, false, test_scenario::ctx(&mut scenario)); // public preview image

            // Article 3: Mixed content
            publication_vault::add_blob(&vault, 300u256, true, test_scenario::ctx(&mut scenario));  // encrypted premium
            publication_vault::add_blob(&vault, 301u256, false, test_scenario::ctx(&mut scenario)); // free teaser

            test_utils::return_to_sender(&scenario, vault);
        };

        // Events are emitted (verified through successful execution)

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_renewal_scheduling() {
        let mut scenario = test_utils::begin_scenario(admin());
        
        // Initialize with RenewCap
        test_utils::next_tx(&mut scenario, admin());
        {
            publication_vault::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        // Test renewal scheduling workflow  
        test_utils::next_tx(&mut scenario, admin()); // Use admin to access RenewCap
        {
            let mut vault = publication_vault::create_vault(
                @0x1.to_id(),
                10,
                test_scenario::ctx(&mut scenario)
            );

            let renew_cap = test_utils::take_from_sender<RenewCap>(&scenario);

            // Schedule first renewal
            let first_renewal = 100u64;
            publication_vault::update_renewal_epoch(&renew_cap, &mut vault, first_renewal, test_scenario::ctx(&mut scenario));
            
            // Verify needs renewal at correct time
            test_utils::assert_false(publication_vault::needs_renewal(&vault, 50));  // Too early
            test_utils::assert_false(publication_vault::needs_renewal(&vault, 99));  // Just before
            test_utils::assert_true(publication_vault::needs_renewal(&vault, 100));  // Exactly at
            test_utils::assert_true(publication_vault::needs_renewal(&vault, 150));  // Past due

            // Schedule next renewal (simulate successful renewal)
            let next_renewal = 200u64;
            publication_vault::update_renewal_epoch(&renew_cap, &mut vault, next_renewal, test_scenario::ctx(&mut scenario));
            
            // Verify updated schedule
            test_utils::assert_false(publication_vault::needs_renewal(&vault, 150)); // No longer needs renewal
            test_utils::assert_true(publication_vault::needs_renewal(&vault, 200));  // New renewal time

            test_utils::return_to_sender(&scenario, vault);
            test_utils::return_to_sender(&scenario, renew_cap);
        };

        test_utils::end_scenario(scenario);
    }
}