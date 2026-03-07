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

    var body: some View {
        List {
            Section("Submitted Evidence") {
                if viewModel.evidence.isEmpty {
                    ContentUnavailableView(
                        "No Evidence",
                        systemImage: "doc.badge.plus",
                        description: Text("Add evidence using the buttons below")
                    )
                } else {
                    ForEach(viewModel.evidence) { item in
                        EvidenceRowView(evidence: item)
                    }
                }
            }

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
            EvidenceSubmitView(dealId: dealId, walletAddress: appState.currentUser?.walletAddress ?? "") {
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
                await viewModel.uploadPhoto(image, dealId: dealId, wallet: appState.currentUser?.walletAddress ?? "")
            }
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let wallet = appState.currentUser?.walletAddress ?? ""
                Task { await viewModel.uploadDocument(url, dealId: dealId, wallet: wallet) }
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
}

struct EvidenceRowView: View {
    let evidence: Evidence

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: mimeTypeIcon(evidence.mimeType))
                    .foregroundStyle(.blue)
                Text(evidence.type?.capitalized ?? "Evidence")
                    .font(.subheadline.bold())
                Spacer()
                if let date = evidence.createdAt {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let desc = evidence.description {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
    }

    private func mimeTypeIcon(_ mime: String?) -> String {
        guard let mime else { return "doc" }
        if mime.hasPrefix("image") { return "photo" }
        if mime.contains("pdf") { return "doc.text" }
        return "doc"
    }
}
