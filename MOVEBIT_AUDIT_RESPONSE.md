# MoveBit Audit — Response & Resolution Report

This document summarizes our resolution of every finding from the MoveBit preliminary audit. Each item lists the final status and a brief description of the fix or, where applicable, our rationale for accepting the finding as designed.

---

## Status summary

| ID     | Title                                                    | Severity       | Status                       |
| ------ | -------------------------------------------------------- | -------------- | ---------------------------- |
| NFT-2  | NFT Minting Does Not Enforce Price or Fee Configuration  | Major          | **Fixed** (design-corrected) |
| PSU-6  | Inconsistent Subscription Object Transfer Design         | Major          | **Fixed**                    |
| IEV-3  | Public Event Emitters Allow Forged Protocol Events       | Medium         | **Fixed**                    |
| PSU-4  | Subscription Overpayment Is Retained                     | Medium         | **Fixed**                    |
| ART-5  | Article Metadata Updates Are Not Emitted                 | Minor          | **Fixed**                    |
| ART-7  | Slug Uniqueness Risk                                     | Minor          | **Fixed**                    |
| NFT-9  | NFT Display Object Transferred to Deployer               | Minor          | **Fixed**                    |
| POL-1  | Seal Free Approval Does Not Enforce Article-Level Gating | Minor          | **Acknowledged**             |
| VAU-8  | Inconsistent Abort Code Numbering Across Modules         | Minor          | **Fixed**                    |
| ART-12 | Centralization Risks                                     | Centralization | **Partially Fixed**          |
| PUB-10 | Inconsistent Visibility of Withdrawal Helpers            | Informational  | **Acknowledged**             |
| POL-11 | Discussion on nonce Design                               | Discussion     | **Acknowledged**             |

---

## Major

### NFT-2 — NFT Minting Does Not Enforce Price or Fee Configuration — **Fixed**

The NFT-mint product framing has been clarified: `ArticleAccessNft` is a **free collectible**, not a paid access token (and grants no content-decryption rights — no `seal_approve_article_nft` exists). The audit's "enforce pricing" suggestion was therefore wrong-direction; we instead removed the dead economic surface and introduced proper validation/dedup:

- Deleted `MintConfig` entirely (`base_price`, `platform_fee_percent`, `admin` were unused).
- Removed the `payment: Coin<SUI>` parameter from `mint`.
- Added a shared `MintRegistry` with `Table<MintKey, bool>` enforcing **one mint per `(recipient, article_id)` pair**.
- `mint` now takes `&Article` and `&Publication` and asserts `articles::publication_id(article) == publication_object_id` so it cannot mint against a forged article ID.
- Removed the misleading permanent-zero `price_paid` field from the `ArticleNftMinted` event.

### PSU-6 — Inconsistent Subscription Object Transfer Design — **Fixed**

`PublicationSubscription` is now soulbound: the `store` ability has been dropped (`has key` only). The bytecode verifier rejects `transfer::public_transfer<PublicationSubscription>`, and `transfer::transfer` is callable only from the defining module — so the brick-by-transfer scenario is now structurally impossible. `subscribe_to_publication` no longer returns the subscription; it transfers internally to `subscriber` via `transfer::transfer`.

---

## Medium

### IEV-3 — Public Event Emitters Allow Forged Protocol Events — **Fixed**

All 15 `emit_*` functions in `inkray_events.move` were changed from `public fun` to `public(package) fun`. External Move packages can no longer call them, eliminating the forgery vector. Event structs remain `public` so off-chain indexers continue parsing events by their fully qualified type name.

### PSU-4 — Subscription Overpayment Is Retained — **Fixed**

Both `subscribe_to_publication` and `extend_subscription` now `coin::split` exactly `months_paid * subscription_price` MIST and refund the remainder to the subscriber (with `coin::destroy_zero` on the exact-payment branch). Emitted events record the _exact_ amount charged rather than the gross payment, so downstream systems see what was actually billed.

---

## Minor

### ART-5 — Article Metadata Updates Are Not Emitted — **Fixed**

Added an `ArticleUpdated` event struct (`publication`, `article`, `old_title`, `new_title`, `old_slug`, `new_slug`, `updated_by`) and `inkray_events::emit_article_updated`. `articles::update_article` now captures the previous title/slug, performs the update, and emits the event with `tx_context::sender(ctx)` as `updated_by`.

### ART-7 — Slug Uniqueness Risk — **Fixed**

The UID-derived suffix in `generate_slug_from_title` was extended from 4 bytes (8 hex chars) to 8 bytes (16 hex chars). Birthday-bound collision threshold moves from ~2¹⁶ articles to ~2³², providing comfortable margin without an on-chain uniqueness registry.

### NFT-9 — NFT Display Object Transferred to Deployer — **Fixed**

`Display<ArticleAccessNft>` is now created and shared in `nft::init` via `transfer::public_share_object(display)` rather than being transferred to the deployer's address. Marketplaces and wallets can discover it by type as expected. The `Publisher` capability remains held privately by the deployer (correct, since it confers minting authority over the package's display objects).

### POL-1 — Seal Free Approval Does Not Enforce Article-Level Gating — **Acknowledged**

The product currently offers **publication-level access only**. The `Access::Free | Gated` enum on `Article` is reserved for future article-level gating but is not consulted by any access path today; access is determined entirely by publication-level policy. Adding the article-level check now would constrain the data model around a feature that isn't shipping. If/when article-level gating is reintroduced, `seal_approve_free` (and the other approval paths) will be updated together with the nonce binding (see POL-11) so the full granularity story is consistent.

### VAU-8 — Inconsistent Abort Code Numbering — **Fixed**

Adopted a per-module prefix convention so the leading digit of any abort code identifies the source module:

| Module                     | Range |
| -------------------------- | ----- |
| `publication`              | `1xx` |
| `articles`                 | `2xx` |
| `vault`                    | `3xx` |
| `publication_subscription` | `4xx` |
| `nft`                      | `5xx` |
| `policy`                   | `6xx` |
| `platform_economics`       | `7xx` |

All error constants in those modules were renumbered. Tests reference errors by name and continue to pass without literal updates.

---

## Centralization

### ART-12 — Centralization Risks — **Partially Fixed**

We treated this finding as three independent decisions and resolved them differently. The detail matters, so each is addressed separately.

#### (1) Universal posting via `PostArticleCap` — **Acknowledged as designed**

Platform-side posting is an **intentional product feature**, not a defect. It powers two flows that are central to the user experience:

- **Scheduled posts.** Authors compose articles through the Inkray UI and pick a future publication time; the platform's posting service posts on their behalf when the schedule fires. This is impossible without a platform-held cap that can post into any publication.
- **UX-managed publication.** The platform handles the Walrus upload, blob registration, and on-chain `Article` creation as a single backend operation, so authors don't need to orchestrate a multi-step PTB themselves.

The audit's recommendation to replace this with `post_as_owner(&PublicationOwnerCap, ...)` and `post_as_contributor(...)` would require every author to sign every post directly, removing scheduling and degrading UX. We've consciously accepted the trust-shape this implies (the platform can post on behalf of users) as a fair trade for the product's primary publishing flow. Authors can still self-publish via direct cap usage if they prefer; `post_with_cap` is an additive platform path, not the only one.

#### (2) Universal decryption via `seal_approve_platform` — **Acknowledged as designed**

A platform-level decryption credential is a **load-bearing requirement** for backend services that operate over the entire content set:

- **AI summary generation.** A backend job decrypts every paid article to produce summaries and TL;DRs that are presented to potential subscribers as a paywall preview.
- **Highlight extraction.** Similar batch decryption to surface noteworthy passages across the catalog.
- **Search indexing and analytics.** Future features that aggregate over all paid content.

Removing or scoping `seal_approve_platform` to a specific `&Publication` (the audit's suggestion) would prevent these cross-publication backend operations, or require N separate credentials that defeat the purpose. The current design is the minimum-friction path for these legitimate platform-internal data flows. Authors implicitly consent to this when publishing on the platform; this will be documented in the platform's Terms of Service.

#### (3) No recovery, rotation, or upgrade mechanism — **Fixed**

This is the part of ART-12 we agreed represented a real bug, and it's been fully addressed:

- **`PostArticleCap` is now soulbound** (`has key` only — `store` dropped). It cannot be wrapped, listed on a marketplace, or accidentally `public_transfer`-ed outside the package.
- **Three lifecycle functions** were added in `articles.move`:
  - `transfer_post_article_cap(cap, recipient)` — module-internal handoff to a new admin.
  - `issue_additional_post_article_cap(&existing, recipient, ctx)` — mint a redundancy cap from a valid one. The intended operational pattern is to maintain ≥ 2 caps in separate secure storage (hot + cold), so loss of one is recoverable from the other.
  - `destroy_post_article_cap(cap)` — explicit retirement for clean cap rotation.

A versioned-config revocation primitive for _compromised_ (rather than _lost_) caps was scoped out of this PR and tracked as a future enhancement; today, the multi-cap redundancy pattern is the answer to loss, and key rotation by the legitimate cap holder is the answer to compromise.

---

## Informational / Discussion

### PUB-10 — Inconsistent Visibility of Withdrawal Helpers — **Acknowledged**

We reviewed the asymmetry between `withdraw_tip_balance` (`public(package)`, gated externally) and `withdraw_subscription_balance` (`public`, gated inline). The current arrangement is intentional: `withdraw_tip_balance` is a package-internal primitive consumed only by `platform_economics::withdraw_all_tips`, where the cap check is centralized. We acknowledge the auditor's point that "auth at the deepest function that touches funds" is a safer convention; we have not made the change in this round, but we've recorded the recommendation and will revisit if the call graph evolves to add new wrappers around `withdraw_tip_balance`.

### POL-11 — Discussion on nonce Design — **Acknowledged**

The product offers **publication-level access only**, and `IdV1.nonce` is intentionally not bound to a specific `Article`. A subscriber to a publication, an owner cap holder, and contributors are all designed to grant decryption material across the entire publication's back-catalog. Binding nonce to article would force per-article re-encryption with no benefit under this access model. If per-article access (e.g. NFT-gated single-article decryption, single-article revocation) is ever added in the future, this design will be revisited together with POL-1 so the granularity story remains consistent end-to-end.

---

## Verification

- Test suite: 53/53 passing (47 prior + 6 new tests covering the new lifecycle paths and dedup).
- `sui move build` — clean (3 pre-existing unused-alias warnings in `policy.move` related to deprecated imports, untouched).
- All resolution code is on branch `for-audit` of the same repository as the original audit.

We're available for any follow-up questions or clarifications during the final-report review.
