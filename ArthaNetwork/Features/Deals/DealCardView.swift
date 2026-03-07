import SwiftUI

struct DealCardView: View {
    let deal: Deal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(deal.title ?? "Untitled Deal")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                StatusBadge(status: deal.status)
            }

            HStack {
                USDCAmountView(amount: deal.priceUsd)
                Spacer()
                if let date = deal.createdAt {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "person.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(deal.sellerWallet.prefix(6) + "..." + deal.sellerWallet.suffix(4))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
        }
        .padding(.vertical, 4)
    }
}
