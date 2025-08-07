#[test_only]
module contracts::vault_blob_tests {
    use contracts::publication_vault::{Self, PublicationVault};
    use contracts::publication::{Self, Publication, PublicationOwnerCap};
    use contracts::mock_blob::{Self, MockBlob};
    use contracts::inkray_test_utils as test_utils;
    use sui::test_scenario;

    fun setup_scenario(user: address): (test_scenario::Scenario, Publication, PublicationOwnerCap) {
        let mut scenario = test_utils::begin_scenario(user);

        test_utils::next_tx(&mut scenario, user);
        let (mut publication, owner_cap) = publication::create_publication(
            test_utils::get_test_publication_name(),
            test_utils::get_test_publication_description(),
            @0x1.to_id(),
            test_scenario::ctx(&mut scenario)
        );
        publication::add_contributor(&owner_cap, &mut publication, test_utils::contributor(), test_scenario::ctx(&mut scenario));

        (scenario, publication, owner_cap)
    }

    /// Test that a blob can be stored and retrieved from the vault.
    #[test]
    fun test_store_and_get_blob() {
        let (mut scenario, publication, owner_cap) = setup_scenario(test_utils::creator());

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            publication_vault::create_vault<MockBlob>(
                10, test_scenario::ctx(&mut scenario)
            );
        };

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            let mut vault = test_utils::take_shared<PublicationVault<MockBlob>>(&scenario);
            let blob_id = 1u256;
            let blob = mock_blob::new(blob_id, 1024, test_scenario::ctx(&mut scenario));

            publication_vault::store_blob(&mut vault, blob_id, blob, false, test_scenario::ctx(&mut scenario));

            assert!(publication_vault::has_blob(&vault, blob_id));
            let retrieved_blob = publication_vault::get_blob(&vault, blob_id);
            test_utils::assert_eq(mock_blob::size(retrieved_blob), 1024);
            assert!(!publication_vault::get_blob_is_encrypted(&vault, blob_id));

            test_utils::return_shared(vault);
        };
        test_utils::return_to_sender(&scenario, publication);
        test_utils::return_to_sender(&scenario, owner_cap);
        test_utils::end_scenario(scenario);
    }

    /// Test that a blob can be removed from the vault.
    #[test]
    fun test_remove_blob() {
        let (mut scenario, publication, owner_cap) = setup_scenario(test_utils::creator());

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            publication_vault::create_vault<MockBlob>(
                10, test_scenario::ctx(&mut scenario)
            );
        };

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            let mut vault = test_utils::take_shared<PublicationVault<MockBlob>>(&scenario);
            let blob_id = 1u256;
            let blob = mock_blob::new(blob_id, 1024, test_scenario::ctx(&mut scenario));

            publication_vault::store_blob(&mut vault, blob_id, blob, false, test_scenario::ctx(&mut scenario));
            assert!(publication_vault::has_blob(&vault, blob_id));

            let removed_blob = publication_vault::remove_blob<MockBlob>(&mut vault, blob_id, test_scenario::ctx(&mut scenario));
            mock_blob::size(&removed_blob); // Consume the blob

            assert!(!publication_vault::has_blob(&vault, blob_id));

            test_utils::return_shared(vault);
        };
        test_utils::return_to_sender(&scenario, publication);
        test_utils::return_to_sender(&scenario, owner_cap);
        test_utils::end_scenario(scenario);
    }

    /// Test that vault-level operations don't check authorization (handled at higher level).
    #[test]
    fun test_remove_blob_unauthorized() {
        let (mut scenario, publication, owner_cap) = setup_scenario(test_utils::creator());

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            publication_vault::create_vault<MockBlob>(
                10, test_scenario::ctx(&mut scenario)
            );
        };

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            let mut vault = test_utils::take_shared<PublicationVault<MockBlob>>(&scenario);
            let blob_id = 1u256;
            let blob = mock_blob::new(blob_id, 1024, test_scenario::ctx(&mut scenario));

            publication_vault::store_blob(&mut vault, blob_id, blob, false, test_scenario::ctx(&mut scenario));
            test_utils::return_shared(vault);
        };

        test_utils::next_tx(&mut scenario, test_utils::contributor());
        {
            let mut vault = test_utils::take_shared<PublicationVault<MockBlob>>(&scenario);
            // This now succeeds since authorization is handled at content_registry level
            let _removed_blob = publication_vault::remove_blob<MockBlob>(&mut vault, 1u256, test_scenario::ctx(&mut scenario));
            test_utils::return_shared(vault);
        };

        test_utils::return_to_address(test_utils::creator(), publication);
        test_utils::return_to_address(test_utils::creator(), owner_cap);
        test_utils::end_scenario(scenario);
    }

    /// Test storing a blob with zero values for id and size.
    #[test]
    fun test_store_blob_with_zero_values() {
        let (mut scenario, publication, owner_cap) = setup_scenario(test_utils::creator());

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            publication_vault::create_vault<MockBlob>(
                10, test_scenario::ctx(&mut scenario)
            );
        };

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            let mut vault = test_utils::take_shared<PublicationVault<MockBlob>>(&scenario);
            let blob_id = 0u256;
            let blob = mock_blob::new(blob_id, 0, test_scenario::ctx(&mut scenario));

            publication_vault::store_blob(&mut vault, blob_id, blob, false, test_scenario::ctx(&mut scenario));

            assert!(publication_vault::has_blob(&vault, blob_id));
            let retrieved_blob = publication_vault::get_blob(&vault, blob_id);
            assert!(mock_blob::size(retrieved_blob) == 0);

            test_utils::return_shared(vault);
        };
        test_utils::return_to_sender(&scenario, publication);
        test_utils::return_to_sender(&scenario, owner_cap);
        test_utils::end_scenario(scenario);
    }

    /// Test that getting a non-existent blob fails.
    #[test]
    #[expected_failure]
    fun test_get_nonexistent_blob() {
        let (mut scenario, publication, owner_cap) = setup_scenario(test_utils::creator());

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            publication_vault::create_vault<MockBlob>(
                10, test_scenario::ctx(&mut scenario)
            );
        };

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            let vault = test_utils::take_shared<PublicationVault<MockBlob>>(&scenario);
            publication_vault::get_blob(&vault, 123u256); // Should fail
            test_utils::return_shared(vault);
        };
        test_utils::return_to_sender(&scenario, publication);
        test_utils::return_to_sender(&scenario, owner_cap);
        test_utils::end_scenario(scenario);
    }

    /// Test that removing a non-existent blob fails.
    #[test]
    #[expected_failure]
    fun test_remove_nonexistent_blob() {
        let (mut scenario, publication, owner_cap) = setup_scenario(test_utils::creator());

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            publication_vault::create_vault<MockBlob>(
                10, test_scenario::ctx(&mut scenario)
            );
        };

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            let mut vault = test_utils::take_shared<PublicationVault<MockBlob>>(&scenario);
            publication_vault::remove_blob<MockBlob>(&mut vault, 123u256, test_scenario::ctx(&mut scenario)); // Should fail
            test_utils::return_shared(vault);
        };
        test_utils::return_to_sender(&scenario, publication);
        test_utils::return_to_sender(&scenario, owner_cap);
        test_utils::end_scenario(scenario);
    }

    /// Test that storing a blob with a duplicate ID fails.
    #[test]
    #[expected_failure]
    fun test_store_duplicate_blob() {
        let (mut scenario, publication, owner_cap) = setup_scenario(test_utils::creator());

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            publication_vault::create_vault<MockBlob>(
                10, test_scenario::ctx(&mut scenario)
            );
        };

        test_utils::next_tx(&mut scenario, test_utils::creator());
        {
            let mut vault = test_utils::take_shared<PublicationVault<MockBlob>>(&scenario);
            let blob_id = 1u256;
            let blob1 = mock_blob::new(blob_id, 1024, test_scenario::ctx(&mut scenario));
            let blob2 = mock_blob::new(blob_id, 2048, test_scenario::ctx(&mut scenario));

            publication_vault::store_blob(&mut vault, blob_id, blob1, false, test_scenario::ctx(&mut scenario));
            publication_vault::store_blob(&mut vault, blob_id, blob2, false, test_scenario::ctx(&mut scenario)); // Should fail

            test_utils::return_shared(vault);
        };
        test_utils::return_to_sender(&scenario, publication);
        test_utils::return_to_sender(&scenario, owner_cap);
        test_utils::end_scenario(scenario);
    }
}
