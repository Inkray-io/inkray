# AGENTS.md

## 🧠 Project Purpose

This repository contains the smart contracts for **Inkray**, a decentralized publishing platform on the **Sui blockchain**. It gives creators control over content distribution, monetization, and access — while enabling readers to own and unlock content through NFTs or subscriptions.

Smart contracts in this repo handle:

- NFT minting for articles
- Platform-level subscriptions
- Gated access via Vaults + Seal conditions
- Tips and payments
- Event emission for off-chain logic & indexing

---

## 🔐 Content Access Model – Tip, Free, Paid, Subscribed

Inkray supports four distinct content access scenarios. These determine how content files are stored (Vaults) and unlocked (Seal logic):

### 1. **Tip a Creator**

- One-time, optional payment
- No content unlock is triggered
- Purpose: Support the creator with no expectation of access

✅ Smart Contract:

- `tipping.move`

✅ On-chain action:

- Emits `TipSent` with `sender`, `receiver`, `amount`, `message`

---

### 2. **Free Article**

- No tip, NFT, or subscription required
- Public Vault file
- No Seal condition attached

✅ Smart Contract:

- None needed

✅ Off-chain:

- Article stored in Vault as **public file** (no encryption, no gating)

---

### 3. **Paid Article – NFT Unlock**

- User mints an **Article NFT**
- Article is sealed to users who own the NFT
- Access is permanent (NFT = forever access)

✅ Smart Contract:

- `article_nft.move`

✅ Seal Condition:

- `owns_nft(0x...::article_nft::ArticleNFT, article_id)`

✅ On-chain:

- Emits `NFTMinted` with `minter`, `article_id`, `vault_id`

---

### 4. **Paid Article – Subscription Unlock**

- User subscribes to the platform
- Access all gated content for a set duration (e.g., 30 days)
- After expiry, access is revoked unless renewed

✅ Smart Contract:

- `subscription.move`

✅ Seal Condition:

- `has_active_subscription(user_address, timestamp)`

✅ On-chain:

- Emits `SubscriptionStarted`, `SubscriptionRenewed`, `SubscriptionExpired`

---

## 🗃️ Vault + Seal Overview

### Vault

- Each creator has their own Walrus Vault (object stored on-chain)
- Every article links to one or more files inside the Vault
- Gated content is encrypted; public content is open

### Seal

- Walrus enforces file access based on on-chain conditions
- Seal conditions are:
  - Referenced by file metadata
  - Based on NFT ownership or active subscriptions
- Conditions are verified cryptographically and never leak user identity

✅ Codex Tip:
Emit meaningful events so that Walrus can derive Seal access from on-chain logs. Structure event fields carefully.

---

## 📦 Modules Overview

| Module                | Purpose                                            |
| --------------------- | -------------------------------------------------- |
| `article_nft.move`    | Mint NFTs that grant access to individual articles |
| `subscription.move`   | Manage platform-wide subscriptions with expiry     |
| `tipping.move`        | One-time payments to creators (no access tied)     |
| `vault_registry.move` | Track creator Vaults and register articles         |
| `events.move`         | Common events for indexing and Seal integration    |

---

## 🛠️ Codex Agent Responsibilities

You should:

- Implement logic to handle all 4 access scenarios above
- Emit standardized events for each action (`TipSent`, `NFTMinted`, `SubscriptionStarted`, etc.)
- Ensure NFT and subscription types are **unique and queryable**
- Help construct dynamic Seal conditions off-chain (via event data)

Use the `sui` CLI to:

- Compile: `sui move build`
- Test: `sui move test`
- Publish: `sui client publish`
- Simulate tx: `sui client call`

---

## 🧪 Suggested Test Scenarios

- ✅ Tip without any unlock
- ✅ Read free article (no restrictions)
- ✅ Mint article NFT → access gated content
- ✅ Subscribe → read all paid content
- ✅ Subscription expires → access revoked
- ✅ Ownership of NFT is transferred → new owner gains access

---

## 🧰 Supporting Tools

- `sui` CLI
- Walrus SDK (for Vault and Seal management)
- Plausible (for basic analytics)
- Stripe or Aggregator SDKs (for payments)

---

## 🧭 Future Additions

- Time-limited NFTs
- Group-based or tiered subscriptions
- Access rules based on token holdings (e.g., SUI ≥ threshold)
- Reward logic for top subscribers (airdrop module)

---

### Codex: Read this

- Your main job is to **securely define access rights on-chain** that the Seal engine can enforce off-chain
- Be modular, emit clear events, and don’t hardcode Vault logic — let the frontend/backend pass Vault IDs
- Move carefully and test well
