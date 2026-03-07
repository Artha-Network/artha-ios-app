# Artha Network iOS — Release Readiness Status

Last updated: 2026-03-07

---

## What works (verified)

| Feature | Verification level |
|---|---|
| Project generates cleanly via `make generate` | Code review — build confirmed by developer |
| App launches without crash | Simulator runtime test (iPhone 15 Pro sim) |
| Tab navigation (Home / Deals / Escrow / Notifications / Profile) | Simulator runtime test |
| Phantom "not installed" guard fires correctly in simulator | Simulator runtime test |
| Phantom deeplink session flow (connect, sign-message, sign-transaction) | Code review only — requires physical iPhone + Phantom |
| NaCl box encrypt/decrypt (`PhantomCrypto`) | Code review — correct swift-sodium API usage verified |
| Deal list and detail (API-backed) | Code review — functional with live backend and a valid wallet session (requires physical device to authenticate) |
| Fund / Release / Refund / Open Dispute actions | Code review — Phantom signing deeplink wired |
| Evidence submission (text, photo, document) | Code review — multipart upload implemented; requires authenticated session (physical device) |
| HEIC-safe photo upload (`Data` → `UIImage(data:)`) | Code review — correct `Transferable` usage verified |
| AI arbitration request + resolution display | Code review — wired to arbiter endpoint |
| Notifications feed + unread badge (cold launch) | Code review — badge seeded during `restoreSession()` |
| Session restore on launch | Code review — httpOnly cookie re-used |
| MarkdownView for contract display | Code review — correct `AttributedString` API |

---

## What requires a physical iPhone

All Phantom wallet flows. The simulator cannot run App Store apps, so the `phantom://` URL scheme is never registered. The "Phantom is not installed" message is the correct, expected guard.

- Wallet connect (full deeplink round-trip)
- Auth challenge signing
- Fund / Release / Refund / Open Dispute (all use `signTransaction`)
- End-to-end escrow creation (Step 3 funding)

---

## Not yet implemented

| Area | Detail |
|---|---|
| `SolanaClient` USDC balance | `getUSDCBalance` returns `0` hardcoded (TODO); `getBalance`, `sendTransaction`, and `confirmTransaction` are fully implemented JSON-RPC |
| Push notifications | `UNUserNotificationCenter` registration not wired; in-app feed functional |
| Profile avatar upload | No backend endpoint; display name and email editing is implemented and wired to `PATCH /api/users/me` |
| App icon | Placeholder asset in `Assets.xcassets/AppIcon.appiconset` |
| Solflare deeplink | Architecture mirrors Phantom but handler not connected |
| Unit / UI tests | No test targets in `project.yml` |

---

## Before TestFlight / production

- [ ] Set `DEVELOPMENT_TEAM` in `project.yml` (currently `""`)
- [ ] Implement `getUSDCBalance` in `SolanaClient` (currently returns `0`)
- [ ] Wire `UNUserNotificationCenter` for push delivery
- [ ] Create production `API_BASE_URL` and set via Xcode scheme or CI environment
- [ ] Switch `SOLANA_CLUSTER` / `SOLANA_RPC_URL` / `USDC_MINT` to mainnet values
- [ ] Design and export final app icon
- [ ] Add privacy usage descriptions to `Info.plist` if camera or contacts access is added
- [ ] Review App Store data usage declarations (wallet address, deal data)
- [ ] Enable App Transport Security exceptions only for devnet RPC in debug builds
- [ ] Run end-to-end Phantom flow on physical device before submission
