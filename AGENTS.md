# AGENTS.md — Implementation Guide for Sui Move Smart‑Contracts

_This file tells a Codex/Autonomous Agent how to generate, test, and publish the Move contracts that power the decentralized publishing platform described in **`Decentralized Publishing Architecture Plan`**._

---

## 0 Target Repo Layout

```
contracts/
  Move.toml
  sources/
    storage_vault.move
    publication_nft.move
    publication_policy.move
    tipping.move
    subscription.move
  tests/
    storage_vault.test.ts
    publication_nft.test.ts
    seal_policy.test.ts
scripts/
  deploy.sh
  publish_manifest.json
README.md
```

---

## 1 High‑level Requirements

1. **StorageVault** (`storage_vault.move`)
   - Aggregate Walrus `StorageResource` IDs.
   - Allow only the vault owner to deposit blobs.
   - `extend()` callable by addresses that hold a platform‑granted `RenewCap`.
2. **Publication‑Access NFT** (`publication_nft.move`)
   - ERC‑721‑style NFT (implements Sui Transfer traits automatically).
   - Stores `vault_id` + `renew_cap_id` so that ownership of the NFT ≡ ownership of vault.
3. **Seal Policy** (`publication_policy.move`)
   - Implements `seal::policy::Policy` trait.
   - Authorize if `object::owner(nft_id)==caller`.
4. **Tipping & Subscription** modules (Phase‑2 but stub now).
   - Simple `pay<SUI>` to creator.
   - Subscription NFT mint & validity check.
5. **Unit tests** in TypeScript (Sui TS SDK + Mocha) exercising:
   - Vault creation, deposit, extend with and without renew cap.
   - NFT mint, transfer, automatic vault ownership change.
   - Seal policy returning `true/false` for owner vs non‑owner.

---

## 2 Coding Standards

- Use `sui::object`, `sui::transfer`, `sui::coin` idioms.
- Comment every public function with Move‑doc.
- Abort codes: use low integers (0‑10) per invariant; document them in a section at top of file.
- Max line length 100 chars.
- Feature‑gate `test` code with `#[test_only]`.

---

## 3 Build & Test Pipeline

1. `npm i` (installs `@mysten/sui.js` and `@mysten/mocha` helpers).
2. `cargo run -p sui-move build` (or `sui move build`).
3. `npm test` — runs Mocha tests that spin up a local Sui network via `sui-test-validator`.
4. `./scripts/deploy.sh` publishes the bundle to a specified network; outputs object IDs to `publish_manifest.json`.

---

## 4 Detailed Task List for Codex Agent

| ID  | Description                                                                                                     | File                              | Acceptance                                               |
| --- | --------------------------------------------------------------------------------------------------------------- | --------------------------------- | -------------------------------------------------------- |
| A1  | Scaffold **Move.toml** with package name `dewrite_contracts`, addr aliases `storage_vault`, `pub_nft`, `policy` | `Move.toml`                       | `sui move build` succeeds                                |
| A2  | Implement **StorageVault** per spec §1                                                                          | `sources/storage_vault.move`      | Unit tests: create vault, deposit ID, extend w/ renewcap |
| A3  | Implement **PublicationNFT** incl. `mint()` returning `(PubNFT, Vault, RenewCap)`                               | `sources/publication_nft.move`    | Transfer test: new owner owns vault resources            |
| A4  | Implement **PublicationPolicy** implementing `seal::policy::Policy`                                             | `sources/publication_policy.move` | `is_authorized` positive for holder, negative otherwise  |
| A5  | Write TypeScript tests `storage_vault.test.ts`                                                                  | `tests/`                          | Mocha green                                              |
| A6  | Write TS tests `publication_nft.test.ts`                                                                        | `tests/`                          | Mocha green                                              |
| A7  | Write TS tests `seal_policy.test.ts` using mock Seal call                                                       | `tests/`                          | Mocha green                                              |
| A8  | Lint: run `move-analyzer` (if available)                                                                        | —                                 | No warnings                                              |
| A9  | Update `deploy.sh` to read ENV `SUI_PRIVATE_KEY` and publish                                                    | `scripts/`                        | Deployed IDs logged                                      |

---

## 5 Testing Notes

- Use `sui::test_scenario` macros for pure Move unit tests when logic is self‑contained.
- For cross‑module flows (Vault+NFT), prefer JS integration tests hitting a local validator.
- Mock Walrus `StorageResource` IDs as simple `0x1` addresses — logic only stores IDs.

---

## 6 Security Checklist

- ***

## 7 Delivery Definition of Done

1. All tasks A1‑A9 complete.
2. `sui move test` + JS Mocha pass.
3. CI pipeline builds & publishes to testnet.
4. Docs generated (`move‑doc`) and committed.

---

> **Codex agent hint:** Implement logic incrementally, run `sui move test` after each module, keep diffs small and well‑commented.
