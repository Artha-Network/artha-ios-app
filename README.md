# Artha Network — iOS App

SwiftUI iOS client for the Artha Network decentralized escrow protocol on Solana.

Artha lets two parties create an on-chain USDC escrow for a P2P transaction (initial focus: vehicle sales), with AI-assisted dispute arbitration powered by Claude and Ed25519-signed verdicts.

---

## Features

- **Wallet authentication** — Phantom deeplink connect with NaCl box encrypted channel; wallet-signature challenge/response session
- **Deal management** — Browse deals, track state machine (INIT → FUNDED → DISPUTED → RESOLVED → RELEASED / REFUNDED)
- **Escrow creation** — 3-step wizard: deal details → AI-generated contract review → fund via Phantom-signed Solana transaction
- **Escrow actions** — Fund, Release, Refund, Open Dispute — each triggers a Phantom `signTransaction` deeplink
- **Dispute & evidence** — Submit text notes, photos (HEIC-safe), and documents; view all submitted evidence per deal
- **AI arbitration** — Request Claude-powered verdict; view signed resolution with ruling and reasoning
- **Notifications** — In-app notification feed with unread badge; badge seeded on cold launch from session restore
- **Profile** — Display wallet address and reputation score; edit display name and email (save calls `PATCH /api/users/me`)

---

## Architecture

MVVM + Clean Architecture. Full detail: [ARCHITECTURE.md](ARCHITECTURE.md)

```
artha-ios-app/
├── project.yml               # XcodeGen spec — source of truth for project structure
├── Makefile                  # setup / generate / open / clean
├── Configs/
│   ├── Debug.xcconfig        # Debug build settings (no secrets)
│   └── Release.xcconfig      # Release build settings (no secrets)
└── ArthaNetwork/
    ├── App/
    │   ├── ArthaNetworkApp.swift   # Entry point, environment injection, session restore
    │   ├── AppState.swift          # @Observable global auth/user state
    │   ├── AppRouter.swift         # NavigationStack path + destination enum
    │   └── Environment/
    │       └── AppConfiguration.swift  # Runtime config via environment variables
    ├── Core/
    │   ├── Domain/
    │   │   ├── Models/         # Pure Swift value types (Deal, Evidence, User…)
    │   │   └── UseCases/       # Business logic, no I/O (AuthUseCase, EscrowActionUseCase…)
    │   ├── Networking/
    │   │   ├── APIClient.swift         # URLSession wrapper, httpOnly cookie auth, multipart upload
    │   │   ├── APIEndpoints.swift      # All endpoint paths
    │   │   ├── APIError.swift          # Typed network errors
    │   │   └── RequestInterceptor.swift
    │   ├── Solana/
    │   │   ├── WalletManager.swift     # Phantom deeplink session management
    │   │   ├── PhantomCrypto.swift     # NaCl box encrypt/decrypt (swift-sodium)
    │   │   ├── SolanaClient.swift      # JSON-RPC client (stubs — see STATUS.md)
    │   │   ├── TransactionBuilder.swift
    │   │   ├── TokenAccounts.swift
    │   │   └── Base58.swift
    │   └── Storage/
    │       ├── KeychainService.swift
    │       ├── EscrowFlowCache.swift
    │       └── UserDefaultsExtensions.swift
    ├── Data/
    │   ├── DTOs/               # Codable request/response models
    │   └── Repositories/       # Network + Keychain implementations
    └── Features/
        ├── Auth/               # WalletConnectView, AuthViewModel
        ├── Deals/              # DealListView, DealDetailView (+ fund/release/refund/dispute actions)
        ├── Escrow/             # 3-step creation wizard
        ├── Dispute/            # DisputeView, EvidenceListView, EvidenceSubmitView, ResolutionView
        ├── Home/               # HomeView (tab root)
        ├── Notifications/      # NotificationsView, NotificationsViewModel
        ├── Profile/            # ProfileView, ProfileViewModel
        └── Shared/             # ErrorBanner, LoadingOverlay, MarkdownView, reusable components
```

**Third-party dependencies** (managed via SwiftPM in XcodeGen):

| Package | Purpose |
|---|---|
| [swift-sodium](https://github.com/jedisct1/swift-sodium) 0.10.0 | NaCl box crypto for Phantom deeplink encryption |

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Xcode | 15.4+ | Mac App Store |
| iOS deployment target | 17.0+ | — |
| XcodeGen | 2.40+ | `brew install xcodegen` |
| Homebrew | any | [brew.sh](https://brew.sh) |
| Phantom wallet app | any | Physical iPhone only (App Store) |

> **Note:** The backend (`actions-server`) must be running for any API-dependent flow. See [Backend setup](#backend-setup).

---

## Setup

### 1. Install XcodeGen

```bash
cd artha-ios-app
make setup
```

This runs `brew install xcodegen` if not already present.

### 2. Generate the Xcode project

```bash
make generate
```

This runs `xcodegen generate` and produces `ArthaNetwork.xcodeproj` from `project.yml`.
**Do not commit `ArthaNetwork.xcodeproj/`** — it is gitignored. `project.yml` is the source of truth.

### 3. Open in Xcode

```bash
make open
```

Combines steps 2 and 3: generates the project then opens it in Xcode.

### 4. Select a simulator or device and build (Cmd+B)

The project builds cleanly against Xcode 15.4+ / iOS 17.0+. SwiftPM will resolve `swift-sodium` automatically on first build.

---

## Configuration

All runtime values are supplied via environment variables — nothing is hardcoded in committed files.

Set these in **Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**:

| Variable | Default (fallback in code) | Description |
|---|---|---|
| `API_BASE_URL` | `http://localhost:4000` | Actions server base URL |
| `SOLANA_RPC_URL` | `https://api.devnet.solana.com` | Solana JSON-RPC endpoint |
| `SOLANA_CLUSTER` | `devnet` | Cluster name |
| `USDC_MINT` | `EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v` | USDC SPL token mint (devnet) |
| `PROGRAM_ID` | `B1a1oejNg8uWz7USuuFSqmRQRUSZ95kk2e4PzRZ7Uti4` | On-chain escrow program |

The `Configs/Debug.xcconfig` and `Configs/Release.xcconfig` are intentionally empty — do not add secrets there.

### Backend setup

The app talks to `actions-server` (Express.js). To run it locally:

```bash
cd ../actions-server
cp .env.example .env        # fill in Supabase / Solana credentials
npm install
npm run dev                 # starts on port 4000
```

---

## URL scheme (Phantom / Solflare callbacks)

The app registers the `artha://` custom URL scheme. Phantom redirects back here after wallet operations:

| URL | Triggered by |
|---|---|
| `artha://connected?...` | Wallet connect approval |
| `artha://signed?...` | Sign-message approval (auth) |
| `artha://signedTransaction?...` | Sign-transaction approval (fund/release/refund/dispute) |

---

## Running in simulator vs physical iPhone

### Simulator

UI navigation and layout are fully testable. **Phantom connect shows "Phantom is not installed"** — this is expected and correct. The simulator cannot run App Store apps, so the `phantom://` URL scheme is never registered.

**Important:** wallet connect requires Phantom on a physical device. Without a valid wallet session, all authenticated API calls (deal list, evidence, notifications, profile) return 401. You cannot create a session in the simulator.

What is testable in simulator:
- App launch, tab navigation, and screen layouts
- The Phantom "not installed" guard (confirms correct defensive behaviour)
- Any screen that reaches the server with a pre-existing session cookie — possible only if you share a cookie from a prior real-device session, which is not a standard workflow

### Physical iPhone (required for Phantom flows)

Install Phantom from the App Store, then:
1. Build and run the app on device via Xcode (requires a signing team — set `DEVELOPMENT_TEAM` in project.yml or Xcode)
2. Tap **Connect Phantom** — this opens the Phantom app via deeplink
3. Approve the connection in Phantom — Phantom redirects back via `artha://connected?...`
4. All subsequent actions (fund, release, dispute) follow the same deeplink pattern

Flows that require a physical iPhone with Phantom:
- Wallet connect / session creation
- Auth challenge signing
- Fund / Release / Refund / Open Dispute (all trigger `signTransaction`)
- Full escrow creation (Step 3 funding)

---

## Known limitations

| Area | Status |
|---|---|
| `SolanaClient` USDC balance | `getUSDCBalance` returns `0` hardcoded; `getBalance`, `sendTransaction`, and `confirmTransaction` are fully implemented |
| Push notifications | `UNUserNotificationCenter` registration not wired; in-app feed works, no push delivery |
| Profile avatar upload | Not implemented — display name and email save is wired; photo upload has no backend endpoint |
| App icon | Placeholder asset — no branded icon yet |
| Solflare deeplink | Architecture is identical to Phantom but not wired to a separate deeplink handler |
| Physical device signing | `DEVELOPMENT_TEAM` is empty in `project.yml` — must be set per-developer locally |

---

## Troubleshooting

**`xcodegen: command not found`**
Run `make setup` to install it via Homebrew.

**`ArthaNetwork.xcodeproj` does not exist after clone**
Run `make generate`. The project file is gitignored by design.

**SwiftPM fails to resolve `swift-sodium`**
Xcode resolves packages on first build. If it fails, go to File → Packages → Reset Package Caches.

**"Phantom is not installed" in simulator**
Expected — see [Running in simulator](#running-in-simulator-vs-physical-iphone). Test wallet flows on a physical device.

**Build fails with code signing error**
Set your Apple Developer Team in Xcode (project target → Signing & Capabilities) or add `DEVELOPMENT_TEAM = YOUR_TEAM_ID` to `Configs/Debug.xcconfig` locally (that file is gitignored if named `*.local.xcconfig`).

**API calls fail / 401 errors**
The backend must be running and your session cookie must be valid. Connect your wallet first. On simulator you can test API flows directly if the backend is on localhost.

---

## Git initialisation (first push)

```bash
cd artha-ios-app
git init
git add .
git commit -m "feat: initial iOS app — MVVM + Clean Architecture, Phantom auth, escrow/dispute/AI flows"
git branch -M main
git remote add origin git@github.com:YOUR_ORG/artha-ios-app.git
git push -u origin main
```
