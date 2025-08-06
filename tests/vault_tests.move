#[test_only]
module contracts::vault_tests {
    use contracts::publication_vault::{Self, PublicationVault, RenewCap};
    use contracts::inkray_test_utils::{admin, creator};
    use contracts::inkray_test_utils as test_utils;
    use sui::test_scenario;

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

        // Test renewal functionality
        test_utils::next_tx(&mut scenario, admin());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let renew_cap = test_utils::take_from_sender<RenewCap>(&scenario);
            
            // Verify initial state
            test_utils::assert_false(publication_vault::needs_renewal(&vault, 100));
            test_utils::assert_false(publication_vault::has_renewal_scheduled(&vault));
            
            // Update renewal epoch
            publication_vault::update_renewal_epoch(
                &renew_cap,
                &mut vault,
                150,
                test_scenario::ctx(&mut scenario)
            );
            
            // Verify renewal scheduled
            test_utils::assert_true(publication_vault::has_renewal_scheduled(&vault));
            test_utils::assert_false(publication_vault::needs_renewal(&vault, 100)); // Still not due
            test_utils::assert_true(publication_vault::needs_renewal(&vault, 150)); // Now due
            
            let (_, renewal_epoch, _) = publication_vault::get_vault_info(&vault);
            test_utils::assert_eq(renewal_epoch, 150);

            // Test batch size modification
            publication_vault::set_renewal_batch_size(&mut vault, 20);
            test_utils::assert_eq(publication_vault::get_renewal_batch_size(&vault), 20);

            test_utils::return_shared(vault);
            test_utils::return_to_sender(&scenario, renew_cap);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_vault_management_functions() {
        let mut scenario = test_utils::begin_scenario(creator());
        
        // Create vault
        test_utils::next_tx(&mut scenario, creator());
        {
            publication_vault::create_vault(
                @0x1.to_id(),
                5,
                test_scenario::ctx(&mut scenario)
            );
        };

        // Test vault management functions
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            
            // Test basic properties
            let (pub_id, renewal_epoch, batch_size) = publication_vault::get_vault_info(&vault);
            test_utils::assert_eq(pub_id, @0x1.to_id());
            test_utils::assert_eq(renewal_epoch, 0);
            test_utils::assert_eq(batch_size, 5);
            
            // Test state functions
            test_utils::assert_eq(publication_vault::get_blob_count(&vault), 0);
            test_utils::assert_false(publication_vault::has_renewal_scheduled(&vault));
            test_utils::assert_eq(publication_vault::get_renewal_batch_size(&vault), 5);
            
            // Test batch size modification
            publication_vault::set_renewal_batch_size(&mut vault, 15);
            test_utils::assert_eq(publication_vault::get_renewal_batch_size(&vault), 15);

            test_utils::return_shared(vault);
        };

        test_utils::end_scenario(scenario);
    }
}