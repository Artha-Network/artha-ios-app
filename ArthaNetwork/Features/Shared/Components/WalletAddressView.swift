import SwiftUI

/// Renders a shortened Solana wallet address with a copy button.
struct WalletAddressView: View {
    let address: String
    var showCopyButton = true
    @State private var copied = false

    var shortAddress: String {
        guard address.count > 10 else { return address }
        return address.prefix(6) + "..." + address.suffix(4)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(shortAddress)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)

            if showCopyButton {
                Button {
                    UIPasteboard.general.string = address
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
