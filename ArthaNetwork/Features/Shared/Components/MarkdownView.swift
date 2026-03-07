import SwiftUI

/// Renders markdown text for displaying AI-generated contracts.
/// Uses AttributedString (iOS 15+). Upgrade to a full markdown package if
/// richer rendering is required (e.g., tables, nested lists).
struct MarkdownView: View {
    let markdown: String
    var font: Font = .body

    private var attributedString: AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(markdown)
    }

    var body: some View {
        // TODO: For tables and complex markdown, integrate swift-markdown package
        ScrollView {
            Text(attributedString)
                .font(font)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    MarkdownView(markdown: """
    # Escrow Agreement

    This agreement is between the **seller** and **buyer**.

    - Amount: $500 USDC
    - Delivery: within 7 days
    - Dispute window: 48 hours after delivery
    """)
    .padding()
}
