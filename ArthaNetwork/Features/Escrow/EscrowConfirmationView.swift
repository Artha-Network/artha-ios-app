import SwiftUI

struct EscrowConfirmationView: View {
    let dealId: String
    /// Called when "View Deal" is tapped. The caller is responsible for resetting the
    /// coordinator and navigating to the deal — this view does not touch AppRouter directly.
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Escrow Created!")
                    .font(.title.bold())
                Text("Your deal has been submitted to the Solana blockchain.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Text("What happens next?")
                    .font(.headline)
                ConfirmationStep(number: 1, text: "Counterparty receives an email with deal details")
                ConfirmationStep(number: 2, text: "Buyer funds the escrow to lock in the deal")
                ConfirmationStep(number: 3, text: "Seller delivers, buyer releases funds")
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Spacer()

            Button("View Deal", action: onComplete)
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Done")
        .navigationBarBackButtonHidden()
    }
}

private struct ConfirmationStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 20, height: 20)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
