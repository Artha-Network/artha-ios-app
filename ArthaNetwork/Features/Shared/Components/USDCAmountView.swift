import SwiftUI

/// Displays a USDC amount with consistent formatting.
struct USDCAmountView: View {
    let amount: Double
    var label: String?
    var font: Font = .subheadline

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    var body: some View {
        if let label {
            LabeledContent(label) {
                HStack(spacing: 4) {
                    Text(formattedAmount)
                        .font(font.bold())
                    Text("USDC")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            HStack(spacing: 4) {
                Text(formattedAmount)
                    .font(font.bold())
                Text("USDC")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
