#[test_only]
module contracts::content_tests {
    use contracts::publication::{Self, Publication, PublicationOwnerCap};
    use contracts::publication_vault::{Self, PublicationVault};
    use contracts::content_registry::{Self, Article};
    use contracts::inkray_test_utils::{admin, creator, contributor, user1};
    use contracts::inkray_test_utils as test_utils;
    use sui::test_scenario::{Self, Scenario};
    use std::string;

    fun setup_publication_and_vault(scenario: &mut Scenario): ID {
        test_utils::next_tx(scenario, creator());
        let (mut publication, owner_cap) = publication::create_publication(
            test_utils::get_test_publication_name(),
            test_utils::get_test_publication_description(),
            @0x1.to_id(), // placeholder, will be updated
            test_scenario::ctx(scenario)
        );
        
        let publication_id = object::id(&publication);
        
        // Create shared vault
        publication_vault::create_vault(
            publication_id,
            10,
            test_scenario::ctx(scenario)
        );
        
        // Update publication with actual vault ID
        test_utils::next_tx(scenario, creator());
        {
            let vault = test_utils::take_shared<contracts::publication_vault::PublicationVault>(scenario);
            let vault_id = object::id(&vault);
            publication::set_vault_id(&owner_cap, &mut publication, vault_id);
            test_utils::return_shared(vault);
        };

        // Add contributor for testing
        publication::add_contributor(
            &owner_cap,
            &mut publication,
            contributor(),
            test_scenario::ctx(scenario)
        );

        test_utils::return_to_sender(scenario, publication);
        test_utils::return_to_sender(scenario, owner_cap);
        
        publication_id
    }

    #[test]
    fun test_publish_article_by_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        let _publication_id = setup_publication_and_vault(&mut scenario);

        // Contributor publishes article
        test_utils::next_tx(&mut scenario, contributor());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());

            let article = content_registry::publish_article(
                &publication,
                &mut vault,
                test_utils::get_test_article_title(),
                test_utils::get_test_article_summary(),
                test_utils::get_test_blob_id(),
                test_utils::get_test_blob_size(),
                false, // free content
                test_scenario::ctx(&mut scenario)
            );

            // Verify article properties
            let (pub_id, author, title, summary, blob_id, is_paid, _created_at) = 
                content_registry::get_article_info(&article);
            
            test_utils::assert_eq(pub_id, object::id(&publication));
            test_utils::assert_eq(author, contributor());
            test_utils::assert_eq(title, test_utils::get_test_article_title());
            test_utils::assert_eq(summary, test_utils::get_test_article_summary());
            test_utils::assert_eq(blob_id, test_utils::get_test_blob_id());
            test_utils::assert_false(is_paid);

            // Verify blob was stored in vault
            test_utils::assert_eq(publication_vault::get_blob_count(&vault), 1);
            test_utils::assert_true(publication_vault::has_blob(&vault, test_utils::get_test_blob_id()));

            test_utils::return_shared(vault);
            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_sender(&scenario, article);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_publish_article_by_owner() {
        let mut scenario = test_utils::begin_scenario(creator());
        let _publication_id = setup_publication_and_vault(&mut scenario);

        // Owner publishes article
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_sender<Publication>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

            let article = content_registry::publish_article_as_owner(
                &publication,
                &mut vault,
                &owner_cap,
                string::utf8(b"Owner Article"),
                string::utf8(b"Article by owner"),
                test_utils::get_test_encrypted_blob_id(),
                test_utils::get_test_blob_size(),
                true, // paid content
                test_scenario::ctx(&mut scenario)
            );

            // Verify article properties
            let (pub_id, author, title, _summary, blob_id, is_paid, _created_at) = 
                content_registry::get_article_info(&article);
            
            test_utils::assert_eq(pub_id, object::id(&publication));
            test_utils::assert_eq(author, creator());
            test_utils::assert_eq(title, string::utf8(b"Owner Article"));
            test_utils::assert_eq(blob_id, test_utils::get_test_encrypted_blob_id());
            test_utils::assert_true(is_paid);

            // Verify blob was stored in vault
            test_utils::assert_eq(publication_vault::get_blob_count(&vault), 1);
            test_utils::assert_true(publication_vault::has_blob(&vault, test_utils::get_test_encrypted_blob_id()));

            test_utils::return_shared(vault);
            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
            test_utils::return_to_sender(&scenario, article);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    #[expected_failure(abort_code = contracts::content_registry::ENotAuthorized)]
    fun test_unauthorized_publish_article() {
        let mut scenario = test_utils::begin_scenario(creator());
        let _publication_id = setup_publication_and_vault(&mut scenario);

        // user1 (not a contributor) tries to publish article
        test_utils::next_tx(&mut scenario, user1());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());

            let article = content_registry::publish_article(
                &publication,
                &mut vault,
                string::utf8(b"Unauthorized Article"),
                string::utf8(b"This should fail"),
                999u256,
                test_utils::get_test_blob_size(),
                false,
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_shared(vault);
            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_sender(&scenario, article);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_update_article() {
        let mut scenario = test_utils::begin_scenario(creator());
        let _publication_id = setup_publication_and_vault(&mut scenario);

        // Contributor publishes article
        test_utils::next_tx(&mut scenario, contributor());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());

            let article = content_registry::publish_article(
                &publication,
                &mut vault,
                string::utf8(b"Original Title"),
                string::utf8(b"Original summary"),
                test_utils::get_test_blob_id(),
                test_utils::get_test_blob_size(),
                false,
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_shared(vault);
            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_sender(&scenario, article);
        };

        // Contributor updates article
        test_utils::next_tx(&mut scenario, contributor());
        {
            let mut article = test_utils::take_from_sender<Article>(&scenario);
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());

            content_registry::update_article(
                &mut article,
                &publication,
                string::utf8(b"Updated Title"),
                string::utf8(b"Updated summary"),
                test_scenario::ctx(&mut scenario)
            );

            // Verify updates
            let (_pub_id, _author, title, summary, _blob_id, _is_paid, _created_at) = 
                content_registry::get_article_info(&article);
            
            test_utils::assert_eq(title, string::utf8(b"Updated Title"));
            test_utils::assert_eq(summary, string::utf8(b"Updated summary"));

            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_sender(&scenario, article);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_mixed_content_publishing() {
        let mut scenario = test_utils::begin_scenario(creator());
        let _publication_id = setup_publication_and_vault(&mut scenario);

        // Publish multiple articles with different content types
        test_utils::next_tx(&mut scenario, contributor());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());

            // Free article
            let free_article = content_registry::publish_article(
                &publication,
                &mut vault,
                string::utf8(b"Free Article"),
                string::utf8(b"Everyone can read this"),
                1001u256,
                test_utils::get_test_blob_size(),
                false,
                test_scenario::ctx(&mut scenario)
            );

            // Paid article
            let paid_article = content_registry::publish_article(
                &publication,
                &mut vault,
                string::utf8(b"Premium Article"),
                string::utf8(b"This costs money"),
                1002u256,
                test_utils::get_test_blob_size(),
                true,
                test_scenario::ctx(&mut scenario)
            );

            // Verify vault has both blobs
            test_utils::assert_eq(publication_vault::get_blob_count(&vault), 2);
            test_utils::assert_true(publication_vault::has_blob(&vault, 1001u256));
            test_utils::assert_true(publication_vault::has_blob(&vault, 1002u256));

            // Verify article properties
            test_utils::assert_false(content_registry::is_paid_content(&free_article));
            test_utils::assert_true(content_registry::is_paid_content(&paid_article));

            test_utils::return_shared(vault);
            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_sender(&scenario, free_article);
            test_utils::return_to_sender(&scenario, paid_article);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_multiple_contributors_publishing() {
        let mut scenario = test_utils::begin_scenario(creator());
        let _publication_id = setup_publication_and_vault(&mut scenario);

        // Add another contributor
        test_utils::next_tx(&mut scenario, creator());
        {
            let mut publication = test_utils::take_from_sender<Publication>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

            publication::add_contributor(
                &owner_cap,
                &mut publication,
                user1(),
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, owner_cap);
        };

        // First contributor publishes
        test_utils::next_tx(&mut scenario, contributor());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());

            let article1 = content_registry::publish_article(
                &publication,
                &mut vault,
                string::utf8(b"Article by Contributor 1"),
                string::utf8(b"First contributor's work"),
                2001u256,
                test_utils::get_test_blob_size(),
                false,
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_shared(vault);
            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_sender(&scenario, article1);
        };

        // Second contributor publishes
        test_utils::next_tx(&mut scenario, user1());
        {
            let mut vault = test_utils::take_shared<PublicationVault>(&scenario);
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());

            let article2 = content_registry::publish_article(
                &publication,
                &mut vault,
                string::utf8(b"Article by Contributor 2"),
                string::utf8(b"Second contributor's work"),
                2002u256,
                test_utils::get_test_blob_size(),
                false,
                test_scenario::ctx(&mut scenario)
            );

            // Verify different authors
            test_utils::assert_eq(content_registry::get_author(&article2), user1());

            // Verify both blobs exist in vault
            test_utils::assert_eq(publication_vault::get_blob_count(&vault), 2);
            test_utils::assert_true(publication_vault::has_blob(&vault, 2001u256));
            test_utils::assert_true(publication_vault::has_blob(&vault, 2002u256));

            test_utils::return_shared(vault);
            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_sender(&scenario, article2);
        };

        test_utils::end_scenario(scenario);
    }
}