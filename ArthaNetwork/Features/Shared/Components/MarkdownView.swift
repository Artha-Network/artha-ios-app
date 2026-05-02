import SwiftUI
import WebKit

/// Renders either HTML or Markdown contract content.
/// The AI contract endpoint now returns HTML starting with `<article>`.
/// If the string begins with `<` it is rendered via WKWebView;
/// otherwise the existing AttributedString Markdown path is used.
struct MarkdownView: View {
    let markdown: String
    var font: Font = .body

    private var isHTML: Bool {
        markdown.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<")
    }

    var body: some View {
        if isHTML {
            ContractHTMLView(html: markdown)
        } else {
            ScrollView {
                Text(attributedString)
                    .font(font)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var attributedString: AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(markdown)
    }
}

// MARK: - WKWebView HTML renderer

private struct ContractHTMLView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let css = """
        body {
            font-family: -apple-system, Helvetica, sans-serif;
            font-size: 13px;
            line-height: 1.6;
            color: #000;
            background: transparent;
            margin: 0; padding: 0;
        }
        @media (prefers-color-scheme: dark) { body { color: #e0e0e0; } }
        h1, h2, h3, h4 { font-weight: 600; margin: 0.7em 0 0.3em; font-size: 1em; }
        p { margin: 0.3em 0; }
        ul, ol { padding-left: 1.4em; margin: 0.3em 0; }
        li { margin: 0.15em 0; }
        strong, b { font-weight: 600; }
        """
        let page = """
        <!DOCTYPE html><html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>\(css)</style>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(page, baseURL: nil)
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
