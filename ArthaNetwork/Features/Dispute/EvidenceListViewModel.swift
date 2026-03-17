import Foundation
import UIKit
import Observation

@Observable
final class EvidenceListViewModel {
    var evidence: [Evidence] = []
    var isLoading = false
    var error: String?

    private let evidenceUseCase = EvidenceUseCase()

    var buyerCount: Int {
        evidence.filter { $0.role == "buyer" }.count
    }

    var sellerCount: Int {
        evidence.filter { $0.role == "seller" }.count
    }

    func loadEvidence(dealId: String) async {
        isLoading = true
        do {
            let page = try await evidenceUseCase.fetchEvidence(dealId: dealId)
            evidence = page.evidence
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // UIImage is passed in by EvidenceListView after loadTransferable — keeps PhotosUI
    // out of the ViewModel so PhotosPickerItem never appears in non-SwiftUI code.
    func uploadPhoto(_ image: UIImage, dealId: String, wallet: String) async {
        isLoading = true
        error = nil
        do {
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
                self.error = "Could not encode photo."
                isLoading = false
                return
            }
            let fileName = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
            _ = try await evidenceUseCase.uploadFileEvidence(
                dealId: dealId,
                fileData: jpegData,
                fileName: fileName,
                mimeType: "image/jpeg",
                walletAddress: wallet
            )
            await loadEvidence(dealId: dealId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func uploadDocument(_ url: URL, dealId: String, wallet: String) async {
        isLoading = true
        error = nil
        do {
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.lowercased()
            let mimeType: String
            switch ext {
            case "pdf":  mimeType = "application/pdf"
            case "doc":  mimeType = "application/msword"
            case "docx": mimeType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            default:     mimeType = "application/octet-stream"
            }
            _ = try await evidenceUseCase.uploadFileEvidence(
                dealId: dealId,
                fileData: data,
                fileName: url.lastPathComponent,
                mimeType: mimeType,
                walletAddress: wallet
            )
            await loadEvidence(dealId: dealId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
