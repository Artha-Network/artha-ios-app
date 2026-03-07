# Artha Network - System Architecture & iOS App Planning Document

## Table of Contents

1. [Overall System Architecture](#1-overall-system-architecture)
2. [Repository Roles](#2-repository-roles)
3. [Backend Services the iOS App Must Interact With](#3-backend-services-the-ios-app-must-interact-with)
4. [API Endpoints Used by the Web App](#4-api-endpoints-used-by-the-web-app)
5. [User Flows Extracted from the Web App](#5-user-flows-extracted-from-the-web-app)
6. [Recommended SwiftUI Architecture for iOS](#6-recommended-swiftui-architecture-for-ios)

---

## 1. Overall System Architecture

Artha Network is a **decentralized, AI-assisted escrow protocol** built on Solana. It enables secure peer-to-peer transactions (with a focus on vehicle sales) by combining on-chain smart contracts, AI-powered dispute arbitration, and a traditional backend API layer.

### High-Level Architecture Diagram

```
+-------------------+       +-------------------+       +---------------------+
|                   |       |                   |       |                     |
|   Web App (React) | ----->|  Actions Server   |------>|  Arbiter Service    |
|   iOS App (Swift) |       |  (Express/Node)   |       |  (Express/Node)     |
|                   |       |                   |       |  Claude AI Engine   |
+-------------------+       +--------+----------+       +---------------------+
        |                            |
        |  Wallet Signing            |  Prisma ORM
        v                            v
+-------------------+       +-------------------+       +---------------------+
|                   |       |                   |       |                     |
|  Solana Blockchain|       |  Supabase         |       |  Core Domain        |
|  (Escrow Program) |       |  (PostgreSQL +    |       |  (Shared TS Library)|
|  USDC via SPL     |       |   File Storage)   |       |                     |
+-------------------+       +-------------------+       +---------------------+
```

### System Layers

| Layer | Component | Technology | Purpose |
|-------|-----------|------------|---------|
| **Clients** | web-app, iOS app | React/Vite, SwiftUI | User interface, wallet interaction |
| **API Gateway** | actions-server | Express.js, Prisma, Node.js | REST API, auth, escrow orchestration, email |
| **AI Arbitration** | arbiter-service | Express.js, Anthropic Claude | Dispute resolution, contract generation |
| **Domain Logic** | core-domain | TypeScript library (Zod) | Shared types, validation, state machines |
| **Smart Contract** | onchain-escrow | Rust/Anchor on Solana | On-chain escrow vault, fund custody |
| **Database** | Supabase | PostgreSQL + Storage | Users, deals, evidence, sessions |
| **Blockchain** | Solana (Devnet/Mainnet) | SPL Token (USDC) | Trustless fund custody and settlement |

### Data Flow Summary

1. **Client** (web or iOS) connects a Solana wallet and authenticates via signature
2. **Actions Server** validates the signature, creates a session, and serves as the REST API
3. Deal creation builds a Solana transaction; the client signs it with their wallet
4. Funds are held in a **program-owned vault** (PDA) on Solana
5. Disputes trigger the **Arbiter Service**, which uses Claude AI to analyze evidence
6. The arbiter signs a `ResolveTicket` with Ed25519; the on-chain program verifies and executes

---

## 2. Repository Roles

### 2.1 `actions-server` - Backend API & Orchestration Layer

**Purpose:** The central backend service that the web app (and iOS app) communicates with. It handles authentication, deal management, escrow transaction building, email notifications, and proxies to the arbiter service.

| Aspect | Detail |
|--------|--------|
| **Stack** | TypeScript, Express.js 4, Prisma ORM, Node.js |
| **Database** | PostgreSQL via Supabase (schema: "artha") |
| **Auth** | Wallet-signature-based sessions (Ed25519 via NaCl), httpOnly cookies |
| **Blockchain** | Builds Solana transactions for escrow operations (initiate, fund, release, refund, dispute) |
| **Email** | Nodemailer + Gmail SMTP, Claude-generated email copy |
| **AI Proxy** | Forwards arbitration requests to arbiter-service |
| **Rate Limits** | 100 req/15min general, 10 req/15min escrow, 20 req/15min auth |

**Key Services:**
- `EscrowService` - Orchestrates all escrow operations
- `EmailService` - AI-generated notification emails
- `UserService` - User creation and profile management
- `NotificationService` - In-app notification creation

### 2.2 `arbiter-service` - AI Dispute Resolution Engine

**Purpose:** An independent microservice that analyzes dispute evidence using Claude AI and produces cryptographically signed verdicts that the on-chain program can verify and execute.

| Aspect | Detail |
|--------|--------|
| **Stack** | TypeScript, Express.js, Anthropic Claude SDK |
| **AI Model** | claude-sonnet-4-6 (primary) |
| **Signing** | Ed25519 via TweetNaCl (signs ResolveTickets) |
| **Auth** | `x-admin-key` header (internal service-to-service) |
| **Storage** | Reads evidence from Supabase Storage |
| **Rate Limits** | 10 arbitrations per 15 minutes |

**Endpoints:**
- `POST /arbitrate` - Analyze evidence, return signed verdict
- `POST /generate-contract` - AI-generated escrow contract
- `POST /verify` - Verify a signed ticket
- `GET /arbiter/pubkey` - Public key for on-chain registration
- `GET /health` - Service health check

**Policy Engine (7 immutable rules in precedence order):**
1. Seller deadline miss -> REFUND (precedence 100)
2. Seller fraud proof -> REFUND (95)
3. Buyer fraud proof -> RELEASE (95)
4. Seller delivery proof -> RELEASE (90)
5. Item not as described -> REFUND (80)
6. Buyer damage proof -> REFUND (75)
7. Insufficient evidence -> REFUND (10, default)

### 2.3 `core-domain` - Shared Business Logic Library

**Purpose:** A pure TypeScript library (`@trust-escrow/core-domain`) with zero I/O dependencies. It provides the single source of truth for domain types, validation rules, state machines, and business logic shared across all services.

| Module | Responsibility |
|--------|---------------|
| `deal.ts` | Deal state machine (INIT -> FUNDED -> DISPUTED -> RESOLVED -> RELEASED/REFUNDED) |
| `dispute.ts` | Dispute validation, evidence requirements, escalation rules |
| `evidence.ts` | CID validation (IPFS/Arweave), MIME allowlists, file size constraints |
| `reputation.ts` | Scoring algorithm (0-1000), tiers (NEW -> BRONZE -> SILVER -> GOLD -> PLATINUM) |
| `risk.ts` | Risk scoring (0-100), recommended hold times |
| `fees.ts` | Fee calculation with basis points, affiliate splits |
| `validation.ts` | Solana addresses, USDC amounts, emails, transaction signatures |
| `notifications.ts` | Event enums and template system |
| `negotiation.ts` | Offer state machine with counter-offers |
| `matching.ts` | Juror selection algorithm (future feature) |

### 2.4 `onchain-escrow` - Solana Smart Contract

**Purpose:** The trustless on-chain escrow program that holds funds in program-owned vaults. Deployed on Solana using the Anchor framework.

| Aspect | Detail |
|--------|--------|
| **Stack** | Rust, Anchor 0.32.1 |
| **Program ID** | `B1a1oejNg8uWz7USuuFSqmRQRUSZ95kk2e4PzRZ7Uti4` (Devnet) |
| **Token** | Any SPL token (designed for USDC) |

**Instructions (6 total):**

| Instruction | Actor | State Transition | Description |
|-------------|-------|-------------------|-------------|
| `initiate` | Seller | -> INIT | Create escrow with terms |
| `fund` | Buyer | INIT -> FUNDED | Deposit tokens into vault |
| `open_dispute` | Either | FUNDED -> DISPUTED | Open dispute before deadline |
| `resolve` | Arbiter | DISPUTED/FUNDED -> RESOLVED | Submit signed verdict |
| `release` | Seller | RESOLVED -> RELEASED | Claim funds (if verdict = RELEASE) |
| `refund` | Buyer | RESOLVED -> REFUNDED | Claim refund (if verdict = REFUND) |

**Key Data Structure - `EscrowState` (297 bytes):**
- `seller`, `buyer`, `arbiter` (Pubkeys)
- `mint`, `vault_ata` (token accounts)
- `amount`, `fee_bps`, `dispute_by` (terms)
- `status` (enum), `nonce` (replay protection)
- `bump` (PDA derivation)

### 2.5 `web-app` - React Frontend

**Purpose:** The primary user-facing application. A Vite + React SPA with Solana wallet integration, TanStack Query for server state, and a multi-step escrow creation wizard.

| Aspect | Detail |
|--------|--------|
| **Stack** | React 18, TypeScript, Vite, Tailwind CSS, shadcn/ui |
| **Routing** | React Router DOM 6 (client-side) |
| **State** | TanStack React Query + Context API + localStorage |
| **Wallets** | Phantom, Solflare, Coinbase, Trust, Ledger, Torus |
| **Network** | Devnet (default), configurable via env vars |

### 2.6 `whitepaper` - Protocol Documentation

**Purpose:** Describes the vision, protocol design, market opportunity, and technical architecture of Artha Network. Key takeaways:

- Target market: P2P sales, freelance, NFTs, cross-border remittances
- Revenue model: Flat $1-2 per escrow or percentage for large deals
- Mainnet target: May 2026
- Future features: governance token, jury staking, portable reputation

---

## 3. Backend Services the iOS App Must Interact With

The iOS app needs to communicate with **two** backend services, though in practice **only one** is called directly:

### 3.1 Actions Server (PRIMARY - Direct Communication)

**Base URL:** Configured via environment (e.g., `https://api.artha.network` or `http://localhost:4000`)

The iOS app will call the actions-server for **all** operations. This is the single API gateway.

### 3.2 Arbiter Service (INDIRECT - Via Actions Server)

The iOS app does **NOT** call the arbiter service directly. The actions-server proxies arbitration requests:
- `POST /api/deals/{dealId}/arbitrate` on the actions-server internally calls `POST /arbitrate` on the arbiter service
- `POST /api/ai/generate-contract` on the actions-server internally calls `POST /generate-contract` on the arbiter service

### 3.3 Solana Blockchain (Direct from Client)

The iOS app must interact with Solana RPC directly for:
- **Transaction signing** - The actions-server returns base64-encoded transactions; the app must decode, sign with the wallet, and submit to the Solana RPC
- **Balance queries** - SOL and USDC balance checks
- **Transaction confirmation** - Monitoring transaction status

**Solana RPC Endpoints:**
- Devnet: `https://api.devnet.solana.com`
- Mainnet: `https://api.mainnet-beta.solana.com`

### 3.4 Supabase (Optional Direct Access)

The web app has direct Supabase client access for some operations, but the iOS app should prefer going through the actions-server API for consistency and security. The only exception might be real-time subscriptions if needed in the future.

### Summary: What the iOS App Talks To

```
iOS App
  |
  |-- REST API --> Actions Server (ALL business logic)
  |                    |-- internally --> Arbiter Service
  |                    |-- internally --> Supabase (DB + Storage)
  |                    |-- internally --> Gmail SMTP
  |
  |-- RPC ---------> Solana Blockchain (sign, send, confirm transactions)
  |
  |-- Wallet ------> Phantom / Solflare Mobile SDK (transaction signing)
```

---

## 4. API Endpoints Used by the Web App

Below is the complete catalog of every API endpoint the web-app calls, organized by domain. **All endpoints use the actions-server base URL.**

### 4.1 Authentication

| Method | Endpoint | Body / Params | Response | Notes |
|--------|----------|---------------|----------|-------|
| `POST` | `/auth/sign-in` | `{ pubkey, message, signature }` | User profile + session cookie | Message format: `{ app: "Artha Network", action: "session_confirm", nonce, ts }` |
| `GET` | `/auth/me` | - | Session + user profile | Checks session validity; returns `profileComplete` flag |
| `POST` | `/auth/logout` | - | - | Clears session cookie |
| `POST` | `/auth/keepalive` | - | - | Heartbeat every 5 min + on user activity |
| `POST` | `/auth/upsert-wallet` | wallet data | - | Legacy wallet registration |

### 4.2 User Profile

| Method | Endpoint | Body / Params | Response | Notes |
|--------|----------|---------------|----------|-------|
| `GET` | `/api/users/me` | - | `{ id, walletAddress, displayName, emailAddress, reputationScore, kycLevel, createdAt, updatedAt }` | Requires session |
| `PATCH` | `/api/users/me` | `{ displayName, emailAddress }` | Updated user | Profile must be complete before creating deals |

### 4.3 Deal Management

| Method | Endpoint | Body / Params | Response | Notes |
|--------|----------|---------------|----------|-------|
| `GET` | `/api/deals` | `?wallet_address={wallet}&offset={n}&limit={n}` | `{ deals[], total }` | Paginated deal list |
| `GET` | `/api/deals/{dealId}` | - | `DealWithEvents` (includes buyer/seller profiles, onchain_events, ai_resolution, metadata) | Full deal detail |
| `DELETE` | `/api/deals/{dealId}` | - | - | Only allowed when deal status = INIT |
| `GET` | `/api/deals/events/recent` | `?wallet_address={wallet}&limit={n}` | `DealEventRow[]` with tx_sig, instruction, created_at | Recent activity feed |

### 4.4 Escrow Actions (Transaction Building)

| Method | Endpoint | Body | Response | Notes |
|--------|----------|------|----------|-------|
| `POST` | `/actions/initiate` | `{ sellerWallet, buyerWallet, amount, feeBps, deliverBy, disputeDeadline, description, title, buyerEmail, sellerEmail, vin, contract, payer, metadata }` | `{ dealId, txMessageBase64, nextClientAction, latestBlockhash, lastValidBlockHeight, feePayer }` | Creates deal + returns unsigned transaction |
| `POST` | `/actions/fund` | `{ dealId, buyerWallet, amount }` | `ActionResponse` | Returns unsigned fund transaction |
| `POST` | `/actions/release` | `{ dealId, sellerWallet }` | `ActionResponse` | Returns unsigned release transaction |
| `POST` | `/actions/refund` | `{ dealId, buyerWallet }` | `ActionResponse` | Returns unsigned refund transaction |
| `POST` | `/actions/open-dispute` | `{ dealId, callerWallet }` | `ActionResponse` | Returns unsigned dispute transaction |
| `POST` | `/actions/confirm` | `{ dealId, txSig, action, actorWallet }` | - | Confirms on-chain TX was successful; updates DB |

**ActionResponse shape:**
```json
{
  "dealId": "uuid",
  "txMessageBase64": "base64-encoded-solana-transaction",
  "latestBlockhash": "string",
  "lastValidBlockHeight": 123456,
  "feePayer": "pubkey-string"
}
```

**Client-side transaction flow:**
1. Call action endpoint -> receive `txMessageBase64`
2. Decode base64 -> `VersionedMessage`
3. Create `VersionedTransaction`
4. Sign with wallet adapter
5. Send to Solana RPC
6. Call `/actions/confirm` with `txSig`

### 4.5 Evidence & Disputes

| Method | Endpoint | Body / Params | Response | Notes |
|--------|----------|---------------|----------|-------|
| `GET` | `/api/deals/{dealId}/evidence` | - | `{ evidence[], total }` | List all evidence for deal |
| `POST` | `/api/deals/{dealId}/evidence` | `{ description, wallet_address, type }` | `EvidenceItem` | Submit text evidence |
| `POST` | `/api/deals/{dealId}/evidence/upload` | `FormData` (multipart) + `?wallet_address={wallet}` | `EvidenceItem` | Upload file evidence |
| `POST` | `/api/deals/{dealId}/arbitrate` | `{}` (empty) | `{ ticket: { outcome, confidence, rationale_cid, expires_at_utc }, arbiter_pubkey, ed25519_signature }` | Triggers AI arbitration |
| `GET` | `/api/deals/{dealId}/resolution` | - | `{ outcome, confidence, reason_short, rationale_cid, violated_rules[], arbiter_pubkey, signature, issued_at, expires_at }` | Fetch stored verdict |

### 4.6 AI & Contract Generation

| Method | Endpoint | Body | Response | Notes |
|--------|----------|------|----------|-------|
| `POST` | `/api/ai/generate-contract` | `{ title, role, counterparty, amount, description, initiatorDeadline, completionDeadline, deliveryDeadline, disputeDeadline }` | `{ contract (markdown), questions[], source }` | Claude-generated or fallback template |
| `POST` | `/api/deals/car-escrow/plan` | `{ priceUsd, deliveryType, hasTitleInHand, odometerMiles, year, isSalvageTitle }` | `{ riskScore, riskLevel, reasons[], deliveryDeadlineHoursFromNow, disputeWindowHours[], ... }` | Risk assessment for vehicle sales |

### 4.7 Notifications

| Method | Endpoint | Params | Response | Notes |
|--------|----------|--------|----------|-------|
| `GET` | `/api/notifications` | `?wallet_address={wallet}&limit={n}&unread_only={bool}` | `{ notifications[], total, unread_count }` | User notifications |
| `PATCH` | `/api/notifications/{id}/read` | - | - | Mark single as read |
| `PATCH` | `/api/notifications/mark-all-read` | `?wallet_address={wallet}` | - | Mark all as read |

### 4.8 Government Integration

| Method | Endpoint | Params | Response | Notes |
|--------|----------|--------|----------|-------|
| `GET` | `/gov/title/{vin}` | - | `{ vin, title_status, current_owner_wallet, transfer_date }` | VIN title lookup |

### 4.9 Analytics

| Method | Endpoint | Body | Response | Notes |
|--------|----------|------|----------|-------|
| `POST` | `/api/events` | `{ event, user_id, deal_id, case_id, ts, extras }` | - | Fire-and-forget tracking |

---

## 5. User Flows Extracted from the Web App

### Flow 1: Wallet Connection & Authentication

```
1. User opens app -> Landing page (/)
2. User taps "Connect Wallet"
3. Wallet adapter shows available wallets (Phantom, Solflare, etc.)
4. User selects wallet and approves connection
5. App generates nonce + timestamp
6. Canonical message created: { app: "Artha Network", action: "session_confirm", nonce, ts }
7. Wallet signs message (user approves in wallet)
8. POST /auth/sign-in with { pubkey, message, signature }
9. Server verifies signature, creates session (24h TTL)
10. Cookie set, user redirected to /deals (or /profile if incomplete)
11. Background: keepalive heartbeat every 5 min
```

### Flow 2: Profile Setup (Required Before Deal Creation)

```
1. User navigates to /profile (or auto-redirected)
2. App fetches GET /api/users/me
3. User enters display name + email address
4. PATCH /api/users/me with { displayName, emailAddress }
5. Profile marked as complete
6. Reputation score displayed (calculated from deal history)
```

### Flow 3: Create Escrow Deal (4-Step Wizard)

```
Step 1 - Deal Details (/escrow/new):
  1. User enters: title, description, counterparty wallet, counterparty email
  2. User enters: amount ($10 - $1,000,000 USDC)
  3. User sets: funding deadline (>= 1 hour from now)
  4. User sets: completion/delivery deadline
  5. Optional: VIN number for car sales
  6. Optional: car metadata (year, make, model, delivery type, title status)
  7. If car sale: POST /api/deals/car-escrow/plan for risk assessment
  8. Data saved to localStorage (persists across refresh)

Step 2 - AI Contract (/escrow/step2):
  1. POST /api/ai/generate-contract with deal terms
  2. Claude generates markdown contract + compliance questions
  3. User reviews contract (can regenerate)
  4. Contract stored in escrow flow state

Step 3 - Review & Submit (/escrow/step3):
  1. Full deal summary displayed (parties, amount, deadlines, contract)
  2. Platform fee shown (0.5% / 50 bps)
  3. User clicks "Create Escrow"
  4. POST /actions/initiate -> returns unsigned transaction
  5. App decodes base64 transaction
  6. Wallet prompts user to sign
  7. Transaction sent to Solana RPC
  8. POST /actions/confirm with txSig
  9. Deal created with status = INIT
  10. Email sent to counterparty
  11. localStorage cleared
  12. User redirected to deal detail page
```

### Flow 4: Fund a Deal (Buyer)

```
1. Buyer receives email notification or sees deal in /deals list
2. Buyer navigates to /deal/:id
3. Deal shows status = INIT, amount, terms
4. App checks buyer's USDC balance (via Solana RPC)
5. Buyer clicks "Fund Escrow"
6. POST /actions/fund with { dealId, buyerWallet, amount }
7. Returns unsigned fund transaction
8. Wallet prompts signature
9. Transaction submitted to Solana
10. POST /actions/confirm
11. Status changes: INIT -> FUNDED
12. Seller notified via email + in-app notification
```

### Flow 5: Release Funds (Happy Path)

```
1. Seller delivers goods/services off-platform
2. Buyer navigates to /deal/:id (status = FUNDED)
3. Buyer is satisfied -> clicks "Release Funds"
   (Or if auto-release conditions met)
4. POST /actions/release with { dealId, sellerWallet }
5. Unsigned transaction returned
6. Seller signs and submits
7. POST /actions/confirm
8. Status: FUNDED -> RELEASED
9. Both parties notified
```

### Flow 6: Open a Dispute

```
1. Either party navigates to /deal/:id (status = FUNDED)
2. User clicks "Open Dispute" (must be before dispute deadline)
3. POST /actions/open-dispute with { dealId, callerWallet }
4. Wallet signs transaction
5. Transaction submitted
6. POST /actions/confirm
7. Status: FUNDED -> DISPUTED
8. Both parties notified
9. User redirected to /evidence/:id to submit evidence
```

### Flow 7: Submit Evidence

```
1. User navigates to /evidence/:id (deal must be DISPUTED)
2. Existing evidence listed via GET /api/deals/{dealId}/evidence
3. User can submit text evidence:
   - POST /api/deals/{dealId}/evidence with { description, wallet_address, type }
4. User can upload file evidence:
   - POST /api/deals/{dealId}/evidence/upload (multipart FormData)
   - Supported: images, PDFs, documents
5. Evidence stored in Supabase Storage with CID reference
```

### Flow 8: AI Arbitration & Resolution

```
1. After evidence submitted, user clicks "Request Arbitration"
2. POST /api/deals/{dealId}/arbitrate
3. Actions-server forwards to arbiter-service:
   - Sends deal details + all evidence + party claims
   - Claude AI analyzes against 7 policy rules
   - Returns: { outcome (RELEASE/REFUND), confidence (0-1), rationale_cid }
   - Arbiter signs ticket with Ed25519
4. Signed verdict stored in DB (resolve_tickets table)
5. User navigates to /deal/:id/resolution
6. GET /api/deals/{dealId}/resolution
7. Resolution displayed: outcome, confidence, violated rules, rationale
8. Winning party sees "Execute Resolution" button:
   - If RELEASE: seller calls POST /actions/release
   - If REFUND: buyer calls POST /actions/refund
9. Wallet signs transaction
10. Funds transferred on-chain
11. POST /actions/confirm
12. Status: RESOLVED -> RELEASED or REFUNDED
13. Both parties receive completion email
```

### Flow 9: Notifications

```
1. User navigates to /notifications
2. GET /api/notifications?wallet_address={wallet}
3. Notifications displayed (deal events, system messages)
4. Unread count shown in nav badge
5. Click notification -> mark as read (PATCH /api/notifications/{id}/read)
6. "Mark all read" button (PATCH /api/notifications/mark-all-read)
7. Auto-refresh every 60 seconds
```

### Flow 10: Dashboard / Deal List

```
1. User navigates to /deals
2. GET /api/deals?wallet_address={wallet}&offset=0&limit=10
3. Deals listed with status badges, amounts, counterparty info
4. Pagination controls for large lists
5. GET /api/deals/events/recent for activity timeline
6. Click deal -> navigate to /deal/:id for details
7. INIT deals show delete option (DELETE /api/deals/{dealId})
8. Auto-refresh every 10 seconds
```

---

## 6. Recommended SwiftUI Architecture for iOS

### 6.1 Architecture Pattern: MVVM + Clean Architecture

Recommended: **MVVM** with a **Clean Architecture** layered approach, leveraging SwiftUI's native patterns.

```
Presentation Layer (SwiftUI Views + ViewModels)
         |
   Domain Layer (Use Cases + Domain Models)
         |
   Data Layer (Repositories + API Client + Wallet SDK)
```

**Why this pattern:**
- MVVM is SwiftUI's natural fit (`@Observable`, `@State`, `@Environment`)
- Clean Architecture provides clear separation of concerns
- Repository pattern abstracts API vs. local cache
- Use Cases encapsulate business logic (mirrors core-domain)

### 6.2 Project Structure

```
artha-ios-app/
|-- ArthaNetwork/
|   |-- App/
|   |   |-- ArthaNetworkApp.swift          # App entry point
|   |   |-- AppState.swift                 # Global app state
|   |   |-- AppRouter.swift                # Navigation coordinator
|   |   |-- Environment/
|   |   |   |-- AppConfiguration.swift     # API URLs, program IDs, env config
|   |
|   |-- Core/
|   |   |-- Networking/
|   |   |   |-- APIClient.swift            # Base HTTP client (URLSession)
|   |   |   |-- APIEndpoints.swift         # Endpoint definitions
|   |   |   |-- APIError.swift             # Error types
|   |   |   |-- RequestInterceptor.swift   # Cookie/session management
|   |   |
|   |   |-- Solana/
|   |   |   |-- SolanaClient.swift         # RPC client wrapper
|   |   |   |-- TransactionBuilder.swift   # Decode, sign, send transactions
|   |   |   |-- WalletManager.swift        # Wallet connection (Phantom, Solflare)
|   |   |   |-- TokenAccounts.swift        # USDC balance queries
|   |   |
|   |   |-- Storage/
|   |   |   |-- KeychainService.swift      # Secure session storage
|   |   |   |-- UserDefaults+Extensions.swift
|   |   |   |-- EscrowFlowCache.swift      # Persist escrow wizard state
|   |   |
|   |   |-- Domain/
|   |   |   |-- Models/
|   |   |   |   |-- User.swift
|   |   |   |   |-- Deal.swift
|   |   |   |   |-- Evidence.swift
|   |   |   |   |-- Resolution.swift
|   |   |   |   |-- Notification.swift
|   |   |   |   |-- DealStatus.swift       # State machine enum
|   |   |   |   |-- ActionResponse.swift
|   |   |   |
|   |   |   |-- UseCases/
|   |   |       |-- AuthUseCase.swift
|   |   |       |-- DealUseCase.swift
|   |   |       |-- EscrowActionUseCase.swift
|   |   |       |-- EvidenceUseCase.swift
|   |   |       |-- NotificationUseCase.swift
|   |   |       |-- ProfileUseCase.swift
|   |
|   |-- Features/
|   |   |-- Auth/
|   |   |   |-- AuthViewModel.swift
|   |   |   |-- WalletConnectView.swift
|   |   |
|   |   |-- Home/
|   |   |   |-- HomeView.swift
|   |   |   |-- HomeViewModel.swift
|   |   |
|   |   |-- Profile/
|   |   |   |-- ProfileView.swift
|   |   |   |-- ProfileViewModel.swift
|   |   |
|   |   |-- Deals/
|   |   |   |-- DealListView.swift
|   |   |   |-- DealListViewModel.swift
|   |   |   |-- DealDetailView.swift
|   |   |   |-- DealDetailViewModel.swift
|   |   |   |-- DealCardView.swift          # Reusable card component
|   |   |
|   |   |-- Escrow/
|   |   |   |-- EscrowFlowCoordinator.swift # Multi-step wizard coordinator
|   |   |   |-- Step1_DealDetailsView.swift
|   |   |   |-- Step1_ViewModel.swift
|   |   |   |-- Step2_ContractView.swift
|   |   |   |-- Step2_ViewModel.swift
|   |   |   |-- Step3_ReviewFundView.swift
|   |   |   |-- Step3_ViewModel.swift
|   |   |   |-- EscrowConfirmationView.swift
|   |   |
|   |   |-- Dispute/
|   |   |   |-- DisputeView.swift
|   |   |   |-- DisputeViewModel.swift
|   |   |   |-- EvidenceListView.swift
|   |   |   |-- EvidenceSubmitView.swift
|   |   |   |-- ResolutionView.swift
|   |   |   |-- ResolutionViewModel.swift
|   |   |
|   |   |-- Notifications/
|   |   |   |-- NotificationsView.swift
|   |   |   |-- NotificationsViewModel.swift
|   |   |
|   |   |-- Shared/
|   |       |-- Components/
|   |       |   |-- StatusBadge.swift
|   |       |   |-- WalletAddressView.swift
|   |       |   |-- USDCAmountView.swift
|   |       |   |-- LoadingOverlay.swift
|   |       |   |-- ErrorBanner.swift
|   |       |   |-- MarkdownView.swift      # For contract display
|   |       |
|   |       |-- Modifiers/
|   |           |-- AuthGuard.swift         # Protected route modifier
|   |           |-- PullToRefresh.swift
|   |
|   |-- Data/
|       |-- Repositories/
|       |   |-- AuthRepository.swift
|       |   |-- DealRepository.swift
|       |   |-- EvidenceRepository.swift
|       |   |-- NotificationRepository.swift
|       |   |-- UserRepository.swift
|       |
|       |-- DTOs/
|           |-- AuthDTOs.swift              # API request/response shapes
|           |-- DealDTOs.swift
|           |-- ActionDTOs.swift
|           |-- EvidenceDTOs.swift
|           |-- NotificationDTOs.swift
```

### 6.3 Key Architectural Decisions

#### State Management

| Concern | Approach |
|---------|----------|
| **Global auth state** | `@Observable` singleton `AuthManager` injected via `.environment()` |
| **Server data** | Repository pattern with in-memory caching + periodic polling (mirror TanStack Query behavior) |
| **Escrow wizard state** | `@Observable` `EscrowFlowState` persisted to UserDefaults (mirrors localStorage approach) |
| **Navigation** | `NavigationStack` with `NavigationPath` + coordinator pattern |
| **View-local state** | `@State` / `@Binding` as standard SwiftUI |

#### Networking

| Decision | Rationale |
|----------|-----------|
| **URLSession** (not Alamofire) | Sufficient for REST calls; reduces dependencies |
| **Cookie-based auth** | Match existing backend (httpOnly cookie via `HTTPCookieStorage`) |
| **Polling for updates** | Match web-app behavior (10-60s intervals via `Timer` or `Task.sleep`) |
| **Codable DTOs** | Map API JSON to Swift structs with `JSONDecoder` |

#### Wallet Integration

| Decision | Rationale |
|----------|-----------|
| **Phantom deeplink / universal link** | Most popular Solana mobile wallet |
| **Solflare mobile SDK** | Second most common |
| **Custom `WalletManager` protocol** | Abstract wallet operations for testability |
| **Transaction flow** | Receive base64 from API -> decode -> send to wallet for signing -> submit to RPC -> confirm |

#### Data Flow for Escrow Actions

```
View (tap "Fund")
  -> ViewModel.fund()
    -> EscrowActionUseCase.fund(dealId, wallet)
      -> DealRepository.buildFundTransaction(dealId, wallet)
        -> APIClient.post("/actions/fund", body)
          <- ActionResponse { txMessageBase64, ... }
      -> WalletManager.signAndSend(txMessageBase64)
        -> Phantom/Solflare signs
        -> SolanaClient.sendTransaction(signedTx)
          <- txSignature
      -> DealRepository.confirmTransaction(dealId, txSig)
        -> APIClient.post("/actions/confirm", body)
    -> ViewModel updates state
  -> View re-renders
```

### 6.4 iOS-Specific Considerations

| Concern | Recommendation |
|---------|---------------|
| **Session persistence** | Store session cookie in Keychain; URLSession handles cookies automatically |
| **Background refresh** | Use `BGAppRefreshTask` for notification count updates |
| **Push notifications** | Future: add APNS support on actions-server; for now, poll `/api/notifications` |
| **Deep links** | Support `artha://deal/{id}` for email links to deals |
| **Offline support** | Cache deal list in UserDefaults/CoreData; show stale data with refresh indicator |
| **Biometrics** | FaceID/TouchID to unlock wallet operations (sign transactions) |
| **File uploads** | Use `PHPickerViewController` for evidence photos; `UIDocumentPickerViewController` for files |
| **Markdown rendering** | Use `AttributedString` (iOS 15+) or lightweight markdown renderer for contracts |
| **Minimum iOS** | iOS 17+ (for `@Observable` macro, modern SwiftUI navigation) |

### 6.5 Dependency Recommendations

| Package | Purpose | Notes |
|---------|---------|-------|
| **Solana.Swift** (or custom) | Solana RPC + transaction handling | Evaluate maturity vs. rolling custom |
| **KeychainAccess** | Secure storage | Session tokens, wallet references |
| **swift-markdown** | Markdown rendering | For AI-generated contracts |
| None (URLSession) | HTTP networking | Keep dependency-light |
| None (@Observable) | State management | Native SwiftUI, no Combine wrappers needed |

### 6.6 Navigation Map (iOS Screens)

```
App Launch
  |
  |-- Unauthenticated:
  |     |-- HomeScreen (landing)
  |     |-- WalletConnectSheet
  |
  |-- Authenticated:
        |-- TabBar
        |     |-- Tab 1: Deals
        |     |     |-- DealListScreen
        |     |     |-- DealDetailScreen
        |     |     |     |-- ResolutionScreen
        |     |     |     |-- EvidenceScreen
        |     |
        |     |-- Tab 2: Create Escrow
        |     |     |-- Step1_DealDetails
        |     |     |-- Step2_Contract
        |     |     |-- Step3_ReviewFund
        |     |     |-- ConfirmationScreen
        |     |
        |     |-- Tab 3: Notifications
        |     |     |-- NotificationsListScreen
        |     |
        |     |-- Tab 4: Profile
        |           |-- ProfileScreen
        |           |-- SettingsScreen (wallet, sessions)
```

---

## Appendix A: Environment Configuration

The iOS app needs these configurable values (via `xcconfig` or `Info.plist`):

| Key | Example Value | Description |
|-----|---------------|-------------|
| `API_BASE_URL` | `https://api.artha.network` | Actions-server URL |
| `SOLANA_RPC_URL` | `https://api.devnet.solana.com` | Solana RPC endpoint |
| `SOLANA_CLUSTER` | `devnet` | Network identifier |
| `USDC_MINT` | `EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v` | USDC token mint address |
| `PROGRAM_ID` | `B1a1oejNg8uWz7USuuFSqmRQRUSZ95kk2e4PzRZ7Uti4` | Escrow program ID |

## Appendix B: Deal State Machine (Reference)

```
       initiate          fund           open_dispute        resolve
INIT ---------> FUNDED ---------> DISPUTED ---------> RESOLVED
                  |                                     |    |
                  | (no dispute, direct resolve)        |    |
                  +------------------------------------>+    |
                                                        |    |
                                              release   |    | refund
                                                   v    |    v
                                               RELEASED | REFUNDED
```

**Terminal states:** RELEASED, REFUNDED

## Appendix C: Authentication Message Format

```json
{
  "app": "Artha Network",
  "action": "session_confirm",
  "nonce": "<random-uuid>",
  "ts": "<iso-8601-timestamp>"
}
```

The message is serialized to a UTF-8 byte array, signed with Ed25519 via the wallet, and sent as `{ pubkey, message, signature }` to `/auth/sign-in`.
