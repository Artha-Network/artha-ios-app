import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            dashboardContent
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.refresh(wallet: currentWallet) }
        .overlay {
            if viewModel.isLoading && viewModel.recentDeals.isEmpty {
                ProgressView()
            }
        }
        .task { await viewModel.load(wallet: currentWallet) }
    }

    private var currentWallet: String {
        appState.currentUser?.walletAddress ?? ""
    }

    // MARK: - Top-level layout

    @ViewBuilder
    private var dashboardContent: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            greetingSection
            profileBannerIfNeeded
            solWarningIfNeeded
            statsGrid
            if let deal = viewModel.urgentDeal {
                urgentDealCard(deal)
            }
            recentActivitySection
            recentNotificationsSection
            quickActionsSection
        }
        .padding()
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.title2.bold())
            Text(currentWallet.prefix(6) + "…" + currentWallet.suffix(4))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var greetingText: String {
        let name = appState.currentUser?.displayName
        if let name, !name.isEmpty {
            let first = name.split(separator: " ").first.map(String.init) ?? name
            return "Hi, \(first)!"
        }
        return "Welcome back!"
    }

    // MARK: - Profile incomplete banner

    @ViewBuilder
    private var profileBannerIfNeeded: some View {
        if !appState.isProfileComplete {
            Button {
                router.selectedTab = .profile
            } label: {
                GroupBox {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Complete Your Profile")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("Add your name and email to participate in deals")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .backgroundStyle(Color.orange.opacity(0.07))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Low SOL warning

    @ViewBuilder
    private var solWarningIfNeeded: some View {
        if viewModel.hasLowSOL {
            GroupBox {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Low SOL Balance")
                            .font(.subheadline.bold())
                        if let sol = viewModel.solBalance {
                            Text("You have \(String(format: "%.4f", sol)) SOL. At least 0.005 SOL is needed for Solana transaction fees.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .backgroundStyle(Color.orange.opacity(0.07))
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(
                label: "Active Deals",
                value: "\(viewModel.activeDealCount)",
                hint: "\(viewModel.totalDealCount) total",
                icon: "doc.text.fill",
                color: .blue
            )
            statCard(
                label: "In Escrow",
                value: viewModel.inEscrowAmount > 0 ? "$\(String(format: "%.0f", viewModel.inEscrowAmount))" : "—",
                hint: "USDC locked",
                icon: "lock.fill",
                color: .green
            )
            statCard(
                label: "Reputation",
                value: viewModel.reputationScore.map { "\($0)" } ?? "—",
                hint: viewModel.reputationLabel,
                icon: "shield.fill",
                color: .purple
            )
            statCard(
                label: "USDC Balance",
                value: viewModel.usdcBalance.map { "$\(String(format: "%.2f", $0))" } ?? "—",
                hint: viewModel.solBalance.map { "\(String(format: "%.3f", $0)) SOL" } ?? "—",
                icon: "creditcard.fill",
                color: .teal
            )
        }
    }

    private func statCard(label: String, value: String, hint: String, icon: String, color: Color) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title2.bold().monospacedDigit())
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.caption.bold())
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Urgent deal

    @ViewBuilder
    private func urgentDealCard(_ deal: Deal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Needs Attention", systemImage: "bell.badge.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Spacer()
                StatusBadge(status: deal.status)
            }

            Text(deal.title ?? "Untitled Deal")
                .font(.headline)

            HStack {
                let role = deal.buyerWallet == currentWallet ? "Buyer" : "Seller"
                Label(role, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("$\(String(format: "%.2f", deal.priceUsd)) USDC")
                    .font(.subheadline.bold().monospacedDigit())
            }

            NavigationLink(value: AppRouter.Destination.dealDetail(deal.id)) {
                Label("Take Action", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                NavigationLink(value: AppRouter.Destination.allDeals) {
                    Text("All deals")
                        .font(.subheadline)
                }
            }

            if viewModel.recentEvents.isEmpty && !viewModel.isLoading {
                Text("No on-chain activity yet. Create your first deal to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(viewModel.recentEvents) { event in
                    Button {
                        router.navigateToDeal(event.dealId)
                    } label: {
                        activityRow(event)
                    }
                    .buttonStyle(.plain)

                    if event.id != viewModel.recentEvents.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func activityRow(_ event: DealEventRow) -> some View {
        let info = instructionInfo(event.instruction)
        return HStack(spacing: 10) {
            Image(systemName: info.icon)
                .font(.subheadline)
                .foregroundStyle(info.color)
                .frame(width: 28, height: 28)
                .background(info.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(info.label)
                    .font(.subheadline)
                Text(event.dealId.prefix(8).uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let date = event.createdAt {
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func instructionInfo(_ instruction: String) -> (label: String, icon: String, color: Color) {
        switch instruction.uppercased() {
        case "INITIATE":          return ("Deal Created",        "doc.text.fill",                    .gray)
        case "FUND":              return ("Funds Locked",         "lock.fill",                        .blue)
        case "RELEASE":           return ("Funds Released",       "arrow.up.right.circle.fill",       .green)
        case "REFUND":            return ("Refund Processed",     "arrow.down.left.circle.fill",      .orange)
        case "OPEN_DISPUTE":      return ("Dispute Opened",       "exclamationmark.triangle.fill",    .red)
        case "RESOLVE":           return ("Verdict Issued",       "scale.3d",                         .purple)
        case "CONFIRM_DELIVERY":  return ("Delivery Confirmed",   "checkmark.circle.fill",            .green)
        case "APPROVE_REFUND":    return ("Refund Approved",      "arrow.uturn.backward.circle.fill", .orange)
        default:
            return (instruction.replacingOccurrences(of: "_", with: " ").capitalized, "circle.fill", .gray)
        }
    }

    // MARK: - Recent Notifications preview

    @ViewBuilder
    private var recentNotificationsSection: some View {
        let unread = viewModel.recentNotifications.filter { !$0.isRead }
        if !unread.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Unread Notifications")
                        .font(.headline)
                    Spacer()
                    Button {
                        router.selectedTab = .notifications
                    } label: {
                        Text("View all")
                            .font(.subheadline)
                    }
                }

                ForEach(unread.prefix(3)) { notif in
                    Button {
                        if let dealId = notif.dealId {
                            router.navigateToDeal(dealId)
                        } else {
                            router.selectedTab = .notifications
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(notif.title)
                                    .font(.subheadline.bold())
                                    .lineLimit(1)
                                Text(notif.body)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if let notif = notif.createdAt {
                                Text(notif, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)

                    if notif.id != unread.prefix(3).last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            Button {
                router.selectedTab = .create
            } label: {
                Label("New Deal", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            NavigationLink(value: AppRouter.Destination.allDeals) {
                Label("All Deals", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }
}
