#[test_only]
module contracts::config_tests {
    use contracts::config::{Self, GlobalConfig, AdminCap};
    use contracts::inkray_test_utils as test_utils;
    use sui::test_scenario;

    #[test]
    fun test_assert_version_passes_when_matching() {
        let mut scenario = test_utils::begin_scenario(test_utils::admin());
        test_utils::setup_global_config(&mut scenario, test_utils::admin());

        test_utils::next_tx(&mut scenario, test_utils::admin());
        {
            let global_config = test_utils::take_shared<GlobalConfig>(&scenario);
            // Fresh config has version == VERSION; assert_version succeeds.
            config::assert_version(&global_config);
            test_utils::return_shared(global_config);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    #[expected_failure(abort_code = contracts::config::E_WRONG_VERSION)]
    fun test_assert_version_aborts_when_stale() {
        let mut scenario = test_utils::begin_scenario(test_utils::admin());
        test_utils::setup_global_config(&mut scenario, test_utils::admin());

        test_utils::next_tx(&mut scenario, test_utils::admin());
        {
            let mut global_config = test_utils::take_shared<GlobalConfig>(&scenario);
            // Force the config to a stale version; assert_version must abort.
            config::set_version_for_testing(&mut global_config, 0);
            config::assert_version(&global_config);
            test_utils::return_shared(global_config);
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_migrate_bumps_version() {
        let mut scenario = test_utils::begin_scenario(test_utils::admin());
        test_utils::setup_global_config(&mut scenario, test_utils::admin());

        test_utils::next_tx(&mut scenario, test_utils::admin());
        {
            let mut global_config = test_utils::take_shared<GlobalConfig>(&scenario);
            let admin_cap = test_utils::take_from_sender<AdminCap>(&scenario);

            // Pretend the package was just upgraded: roll the on-chain version
            // back below VERSION so migrate has work to do.
            config::set_version_for_testing(&mut global_config, 0);
            config::test_call_migrate(&mut global_config, &admin_cap);

            // After migrate, assert_version must pass again.
            config::assert_version(&global_config);

            test_utils::return_shared(global_config);
            config::transfer_admin_cap(admin_cap, test_utils::admin());
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    #[expected_failure(abort_code = contracts::config::E_NOT_UPGRADE)]
    fun test_migrate_rejects_already_migrated() {
        let mut scenario = test_utils::begin_scenario(test_utils::admin());
        test_utils::setup_global_config(&mut scenario, test_utils::admin());

        test_utils::next_tx(&mut scenario, test_utils::admin());
        {
            let mut global_config = test_utils::take_shared<GlobalConfig>(&scenario);
            let admin_cap = test_utils::take_from_sender<AdminCap>(&scenario);

            // Fresh config is already at VERSION; migrate must abort E_NOT_UPGRADE.
            config::test_call_migrate(&mut global_config, &admin_cap);

            test_utils::return_shared(global_config);
            config::transfer_admin_cap(admin_cap, test_utils::admin());
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_issue_additional_admin_cap_succeeds() {
        let mut scenario = test_utils::begin_scenario(test_utils::admin());
        test_utils::setup_global_config(&mut scenario, test_utils::admin());

        test_utils::next_tx(&mut scenario, test_utils::admin());
        {
            let mut global_config = test_utils::take_shared<GlobalConfig>(&scenario);
            let admin_cap = test_utils::take_from_sender<AdminCap>(&scenario);

            // Mint a second cap to a different recipient.
            config::issue_additional_admin_cap(
                &admin_cap,
                &mut global_config,
                test_utils::user1(),
                test_scenario::ctx(&mut scenario),
            );

            test_utils::return_shared(global_config);
            config::transfer_admin_cap(admin_cap, test_utils::admin());
        };

        // The second cap is now owned by user1 — verify it can be picked up
        // and that it can also drive migrate (i.e. it's a real authorized cap).
        test_utils::next_tx(&mut scenario, test_utils::user1());
        {
            let mut global_config = test_utils::take_shared<GlobalConfig>(&scenario);
            let user_cap = test_utils::take_from_sender<AdminCap>(&scenario);

            config::set_version_for_testing(&mut global_config, 0);
            config::test_call_migrate(&mut global_config, &user_cap);
            config::assert_version(&global_config);

            test_utils::return_shared(global_config);
            config::transfer_admin_cap(user_cap, test_utils::user1());
        };

        test_utils::end_scenario(scenario);
    }

    #[test]
    fun test_destroy_admin_cap_removes_authority() {
        let mut scenario = test_utils::begin_scenario(test_utils::admin());
        test_utils::setup_global_config(&mut scenario, test_utils::admin());

        // Mint a second cap so destroying the original doesn't leave the config orphaned.
        test_utils::next_tx(&mut scenario, test_utils::admin());
        {
            let mut global_config = test_utils::take_shared<GlobalConfig>(&scenario);
            let admin_cap = test_utils::take_from_sender<AdminCap>(&scenario);

            config::issue_additional_admin_cap(
                &admin_cap,
                &mut global_config,
                test_utils::admin(),
                test_scenario::ctx(&mut scenario),
            );
            // Destroy the original; the additional cap remains authoritative.
            config::destroy_admin_cap(admin_cap, &mut global_config);

            test_utils::return_shared(global_config);
        };

        test_utils::end_scenario(scenario);
    }
}
