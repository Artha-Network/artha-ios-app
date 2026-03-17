import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct EvidenceListView: View {
    let dealId: String
    @Environment(AppState.self) private var appState
    @State private var viewModel = EvidenceListViewModel()
    @State private var showSubmitText = false
    @State private var showDocumentPicker = false
    @State private var selectedPhoto: PhotosPickerItem?

    private var myWallet: String {
        appState.currentUser?.walletAddress ?? ""
    }

    var body: some View {
        List {
            // MARK: - Summary Stats
            if !viewModel.evidence.isEmpty {
                Section {
                    HStack(spacing: 0) {
                        statCell("Total", value: viewModel.evidence.count, color: .primary)
                        Divider().frame(height: 32)
                        statCell("Buyer", value: viewModel.buyerCount, color: .blue)
                        Divider().frame(height: 32)
                        statCell("Seller", value: viewModel.sellerCount, color: .orange)
                    }
                }
                .listRowInsets(EdgeInsets())
            }

            // MARK: - Evidence List
            Section("Submitted Evidence") {
                if viewModel.evidence.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Evidence",
                        systemImage: "doc.badge.plus",
                        description: Text("Add evidence using the buttons below.")
                    )
                } else {
                    ForEach(viewModel.evidence) { item in
                        EvidenceRowView(evidence: item, myWallet: myWallet)
                    }
                }
            }

            // MARK: - Add Evidence
            Section("Add Evidence") {
                Button {
                    showSubmitText = true
                } label: {
                    Label("Submit Text Note", systemImage: "text.quote")
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Upload Photo", systemImage: "photo")
                }

                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Upload Document", systemImage: "doc")
                }
            }
        }
        .navigationTitle("Evidence")
        .sheet(isPresented: $showSubmitText) {
            EvidenceSubmitView(dealId: dealId, walletAddress: myWallet) {
                Task { await viewModel.loadEvidence(dealId: dealId) }
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    viewModel.error = "Could not load photo."
                    return
                }
                await viewModel.uploadPhoto(image, dealId: dealId, wallet: myWallet)
            }
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await viewModel.uploadDocument(url, dealId: dealId, wallet: myWallet) }
            }
        }
        .alert("Upload Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay(message: "Uploading…")
            }
        }
        .task {
            await viewModel.loadEvidence(dealId: dealId)
        }
    }

    private func statCell(_ label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Evidence Row

struct EvidenceRowView: View {
    let evidence: Evidence
    var myWallet: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: mimeTypeIcon(evidence.mimeType))
                    .foregroundStyle(roleColor)

                // Submitter name or truncated wallet
                if let name = evidence.submittedByName, !name.isEmpty {
                    Text(name)
                        .font(.subheadline.bold())
                } else if let wallet = evidence.submittedBy {
                    Text(wallet.prefix(6) + "…" + wallet.suffix(4))
                        .font(.subheadline.bold().monospaced())
                }

                // Role badge
                if let role = evidence.role {
                    Text(role.capitalized)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(roleColor.opacity(0.15))
                        .foregroundStyle(roleColor)
                        .clipShape(Capsule())
                }

                // "You" badge
                if let wallet = evidence.submittedBy,
                   !myWallet.isEmpty,
                   wallet == myWallet {
                    Text("You")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }

                Spacer()

                if let date = evidence.submittedAt {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let desc = evidence.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(roleColor.opacity(0.03))
    }

    private var roleColor: Color {
        switch evidence.role {
        case "buyer": return .blue
        case "seller": return .orange
        default: return .gray
        }
    }

    private func mimeTypeIcon(_ mime: String?) -> String {
        guard let mime else { return "doc" }
        if mime.hasPrefix("image") { return "photo" }
        if mime.contains("pdf") { return "doc.text" }
        return "doc"
    }
}
