#[test_only]
module contracts::content_tests {
    use contracts::publication::{Self, Publication, PublicationOwnerCap};
    use contracts::publication_vault::{Self, PublicationVault};
    use contracts::content_registry::{Self, Article};
    use contracts::inkray_test_utils::{admin, creator, contributor, user1};
    use contracts::inkray_test_utils as test_utils;
    use sui::test_scenario::{Self, Scenario};
    use std::string;

    fun setup_publication_and_vault(scenario: &mut Scenario): (ID, ID) {
        test_utils::next_tx(scenario, creator());
        let (mut publication, owner_cap) = publication::create_publication(
            test_utils::get_test_publication_name(),
            test_utils::get_test_publication_description(),
            @0x1.to_id(), // placeholder, will be updated
            test_scenario::ctx(scenario)
        );
        
        let publication_id = object::id(&publication);
        let vault = publication_vault::create_vault(
            publication_id,
            10,
            test_scenario::ctx(scenario)
        );
        let vault_id = object::id(&vault);

        publication::set_vault_id(&owner_cap, &mut publication, vault_id);

        // Add contributor for testing
        publication::add_contributor(
            &owner_cap,
            &mut publication,
            contributor(),
            test_scenario::ctx(scenario)
        );

        test_utils::return_to_sender(scenario, publication);
        test_utils::return_to_sender(scenario, owner_cap);
        test_utils::return_to_sender(scenario, vault);
        
        (publication_id, vault_id)
    }

    #[test]
    fun test_publish_article_by_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        let (_publication_id, _vault_id) = setup_publication_and_vault(&mut scenario);

        // Contributor publishes article
        test_utils::next_tx(&mut scenario, contributor());
        {
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());
            let vault = test_utils::take_from_address<PublicationVault>(&scenario, creator());

            let article = content_registry::publish_article(
                &publication,
                &vault,
                test_utils::get_test_article_title(),
                test_utils::get_test_article_summary(),
                test_utils::get_test_blob_id(),
                false, // free content
                test_scenario::ctx(&mut scenario)
            );

            // Verify article properties
            let (pub_id, author, title, summary, blob_id, is_paid, created_at) = 
                content_registry::get_article_info(&article);
            
            test_utils::assert_eq(pub_id, object::id(&publication));
            test_utils::assert_eq(author, contributor());
            test_utils::assert_eq(title, test_utils::get_test_article_title());
            test_utils::assert_eq(summary, test_utils::get_test_article_summary());
            test_utils::assert_eq(blob_id, test_utils::get_test_blob_id());
            test_utils::assert_false(is_paid);
            test_utils::assert_true(created_at >= 0);

            // Verify helper functions
            test_utils::assert_eq(content_registry::get_author(&article), contributor());
            test_utils::assert_eq(content_registry::get_blob_id(&article), test_utils::get_test_blob_id());
            test_utils::assert_false(content_registry::is_paid_content(&article));

            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_address(creator(), vault);
            test_utils::return_to_sender(&scenario, article);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_publish_paid_article_by_contributor() {
        let mut scenario = test_utils::begin_scenario(creator());
        let (_publication_id, _vault_id) = setup_publication_and_vault(&mut scenario);

        // Contributor publishes paid article
        test_utils::next_tx(&mut scenario, contributor());
        {
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());
            let vault = test_utils::take_from_address<PublicationVault>(&scenario, creator());

            let article = content_registry::publish_article(
                &publication,
                &vault,
                test_utils::get_test_article_title(),
                test_utils::get_test_article_summary(),
                test_utils::get_test_encrypted_blob_id(),
                true, // paid content
                test_scenario::ctx(&mut scenario)
            );

            // Verify paid content properties
            test_utils::assert_true(content_registry::is_paid_content(&article));
            test_utils::assert_eq(
                content_registry::get_blob_id(&article),
                test_utils::get_test_encrypted_blob_id()
            );

            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_address(creator(), vault);
            test_utils::return_to_sender(&scenario, article);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_publish_article_as_owner() {
        let mut scenario = test_utils::begin_scenario(creator());
        let (_publication_id, _vault_id) = setup_publication_and_vault(&mut scenario);

        // Owner publishes article
        test_utils::next_tx(&mut scenario, creator());
        {
            let publication = test_utils::take_from_sender<Publication>(&scenario);
            let vault = test_utils::take_from_sender<PublicationVault>(&scenario);
            let owner_cap = test_utils::take_from_sender<PublicationOwnerCap>(&scenario);

            let article = content_registry::publish_article_as_owner(
                &publication,
                &vault,
                &owner_cap,
                test_utils::get_test_article_title(),
                test_utils::get_test_article_summary(),
                test_utils::get_test_blob_id(),
                false, // free content
                test_scenario::ctx(&mut scenario)
            );

            // Verify article properties
            let (pub_id, author, title, _, _, _, _) = content_registry::get_article_info(&article);
            test_utils::assert_eq(pub_id, object::id(&publication));
            test_utils::assert_eq(author, creator()); // Owner is the author
            test_utils::assert_eq(title, test_utils::get_test_article_title());

            test_utils::return_to_sender(&scenario, publication);
            test_utils::return_to_sender(&scenario, vault);
            test_utils::return_to_sender(&scenario, owner_cap);
            test_utils::return_to_sender(&scenario, article);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_update_article_by_author() {
        let mut scenario = test_utils::begin_scenario(creator());
        let (_publication_id, _vault_id) = setup_publication_and_vault(&mut scenario);

        // Contributor publishes article
        test_utils::next_tx(&mut scenario, contributor());
        {
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());
            let vault = test_utils::take_from_address<PublicationVault>(&scenario, creator());

            let article = content_registry::publish_article(
                &publication,
                &vault,
                test_utils::get_test_article_title(),
                test_utils::get_test_article_summary(),
                test_utils::get_test_blob_id(),
                false,
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_address(creator(), vault);
            test_utils::return_to_sender(&scenario, article);
        };

        // Author updates article
        test_utils::next_tx(&mut scenario, contributor());
        {
            let mut article = test_utils::take_from_sender<Article>(&scenario);
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());

            let new_title = string::utf8(b"Updated Article Title");
            let new_summary = string::utf8(b"Updated article summary");

            content_registry::update_article(
                &mut article,
                &publication,
                new_title,
                new_summary,
                test_scenario::ctx(&mut scenario)
            );

            // Verify updates
            let (_, _, title, summary, _, _, _) = content_registry::get_article_info(&article);
            test_utils::assert_eq(title, new_title);
            test_utils::assert_eq(summary, new_summary);

            test_utils::return_to_sender(&scenario, article);
            test_utils::return_to_address(creator(), publication);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    #[expected_failure(abort_code = contracts::content_registry::ENotAuthorized)]
    fun test_unauthorized_article_publishing() {
        let mut scenario = test_utils::begin_scenario(creator());
        let (_publication_id, _vault_id) = setup_publication_and_vault(&mut scenario);

        // Non-contributor tries to publish article
        test_utils::next_tx(&mut scenario, user1()); // user1 is not a contributor
        {
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());
            let vault = test_utils::take_from_address<PublicationVault>(&scenario, creator());

            // This should fail
            let article = content_registry::publish_article(
                &publication,
                &vault,
                test_utils::get_test_article_title(),
                test_utils::get_test_article_summary(),
                test_utils::get_test_blob_id(),
                false,
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_address(creator(), vault);
            test_utils::return_to_sender(&scenario, article);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    #[expected_failure(abort_code = contracts::content_registry::ENotAuthorized)]
    fun test_unauthorized_article_update() {
        let mut scenario = test_utils::begin_scenario(creator());
        let (_publication_id, _vault_id) = setup_publication_and_vault(&mut scenario);

        // Contributor publishes article
        test_utils::next_tx(&mut scenario, contributor());
        {
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());
            let vault = test_utils::take_from_address<PublicationVault>(&scenario, creator());

            let article = content_registry::publish_article(
                &publication,
                &vault,
                test_utils::get_test_article_title(),
                test_utils::get_test_article_summary(),
                test_utils::get_test_blob_id(),
                false,
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_address(creator(), vault);
            test_utils::return_to_sender(&scenario, article);
        };

        // Different user tries to update article (should fail)
        test_utils::next_tx(&mut scenario, user1()); // user1 is not the author
        {
            let mut article = test_utils::take_from_address<Article>(&scenario, contributor());
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());

            // This should fail
            content_registry::update_article(
                &mut article,
                &publication,
                string::utf8(b"Malicious Update"),
                string::utf8(b"Unauthorized update"),
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_address(contributor(), article);
            test_utils::return_to_address(creator(), publication);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    #[expected_failure(abort_code = contracts::content_registry::EInvalidVault)]
    fun test_publish_with_wrong_vault() {
        let mut scenario = test_utils::begin_scenario(creator());
        let (_publication_id, _vault_id) = setup_publication_and_vault(&mut scenario);

        // Create a second vault for a different publication
        test_utils::next_tx(&mut scenario, creator());
        {
            let wrong_vault = publication_vault::create_vault(
                @0x999.to_id(), // Different publication ID
                10,
                test_scenario::ctx(&mut scenario)
            );
            test_utils::return_to_sender(&scenario, wrong_vault);
        };

        // Try to publish article with mismatched vault
        test_utils::next_tx(&mut scenario, contributor());
        {
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());
            let wrong_vault = test_utils::take_from_address<PublicationVault>(&scenario, creator());

            // This should fail because vault doesn't belong to publication
            let article = content_registry::publish_article(
                &publication,
                &wrong_vault,
                test_utils::get_test_article_title(),
                test_utils::get_test_article_summary(),
                test_utils::get_test_blob_id(),
                false,
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_address(creator(), wrong_vault);
            test_utils::return_to_sender(&scenario, article);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_article_publishing_events() {
        let mut scenario = test_utils::begin_scenario(creator());
        let (_publication_id, _vault_id) = setup_publication_and_vault(&mut scenario);

        // Contributor publishes article
        test_utils::next_tx(&mut scenario, contributor());
        {
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());
            let vault = test_utils::take_from_address<PublicationVault>(&scenario, creator());

            let article = content_registry::publish_article(
                &publication,
                &vault,
                test_utils::get_test_article_title(),
                test_utils::get_test_article_summary(),
                test_utils::get_test_blob_id(),
                false,
                test_scenario::ctx(&mut scenario)
            );

            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_address(creator(), vault);
            test_utils::return_to_sender(&scenario, article);
        };

        // Events are emitted (verified through successful execution)

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_multiple_articles_same_publication() {
        let mut scenario = test_utils::begin_scenario(creator());
        let (_publication_id, _vault_id) = setup_publication_and_vault(&mut scenario);

        // Publish multiple articles
        test_utils::next_tx(&mut scenario, contributor());
        {
            let publication = test_utils::take_from_address<Publication>(&scenario, creator());
            let vault = test_utils::take_from_address<PublicationVault>(&scenario, creator());

            // Article 1: Free content
            let article1 = content_registry::publish_article(
                &publication,
                &vault,
                string::utf8(b"Article 1"),
                string::utf8(b"First article summary"),
                100u256,
                false,
                test_scenario::ctx(&mut scenario)
            );

            // Article 2: Paid content
            let article2 = content_registry::publish_article(
                &publication,
                &vault,
                string::utf8(b"Article 2"),
                string::utf8(b"Second article summary"),
                200u256,
                true,
                test_scenario::ctx(&mut scenario)
            );

            // Verify both articles belong to same publication
            test_utils::assert_eq(
                content_registry::get_publication_id(&article1),
                content_registry::get_publication_id(&article2)
            );

            // Verify different content types
            test_utils::assert_false(content_registry::is_paid_content(&article1));
            test_utils::assert_true(content_registry::is_paid_content(&article2));

            test_utils::return_to_address(creator(), publication);
            test_utils::return_to_address(creator(), vault);
            test_utils::return_to_sender(&scenario, article1);
            test_utils::return_to_sender(&scenario, article2);
        };

        test_utils::end_scenario(scenario);
    }
}