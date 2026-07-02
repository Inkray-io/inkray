# Inkray — Smart Contracts

The **Move** smart contracts powering [Inkray](https://inkray.xyz), a publishing
platform on the **Sui** blockchain. They handle publications, content storage,
paid/gated access, subscriptions, article NFTs, and creator monetization —
with content stored on **Walrus** and gated content encrypted with **Seal**.

## Modules

| Module                          | Responsibility                                                        |
| ------------------------------- | -------------------------------------------------------------------- |
| `publication.move`              | Publication ownership (`OwnerCap`) and contributor management         |
| `vault.move`                    | Shared vault storing Walrus blobs, with platform-managed renewals     |
| `articles.move`                 | Article metadata and publishing into publication vaults               |
| `policy.move`                   | Seal access policies for encrypted content (owner / contributor / allowlist) |
| `publication_subscription.move` | Time-based platform subscriptions with Seal approval                  |
| `nft.move`                      | Minting articles as NFTs for permanent access                         |
| `platform_economics.move`       | Creator treasuries, tipping, earnings, and withdrawals                |
| `config.move`                   | Global platform configuration                                         |
| `inkray_events.move`            | Shared event definitions for off-chain indexing                      |

## Access model

Content is encrypted once and can be unlocked through any of these paths:

1. **Publication owner** — via `PublicationOwnerCap`
2. **Contributor** — verified against the publication
3. **Subscription** — active platform subscription
4. **Article NFT** — ownership of the article's NFT
5. **Allowlist** — explicit per-address permission

## Build & test

Requires the [Sui CLI](https://docs.sui.io/references/cli).

```bash
sui move build     # compile
sui move test      # run the test suite
```

## Deployment

```bash
sui client publish --gas-budget 500000000
```

Deployment records for each network live in
[`deployments/deployment-mainnet.json`](./deployments/deployment-mainnet.json) and
[`deployments/deployment-testnet.json`](./deployments/deployment-testnet.json).

### Mainnet

| Object        | ID                                                                   |
| ------------- | -------------------------------------------------------------------- |
| Package       | `0x02c666682f782b481fd05adfdfd4282acda8f8afb589ee62edc7882073d553e5` |
| Global config | `0x092a5cea6b68c4c83f25a24b14943297d3fcfda54b6d848f89691a097063ae5e` |
| Mint registry | `0x83f03183b7428e7d2fdf68c748ec4c0f324587b23750f9ecb350d6abe0e70645` |

## Dependencies

- **Sui framework** — resolved from the active Sui environment
- **Walrus** & **WAL** — mainnet contracts from
  [MystenLabs/walrus](https://github.com/MystenLabs/walrus)

## License

Licensed under the [Apache License 2.0](./LICENSE).
