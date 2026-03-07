import Foundation

enum AppConfiguration {
    // MARK: - API

    static var apiBaseURL: String {
        // Set API_BASE_URL in the scheme's environment variables for dev/staging/prod.
        // Falls back to localhost for local development.
        ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? "http://localhost:4000"
    }

    // MARK: - Solana

    static var solanaRPCURL: String {
        ProcessInfo.processInfo.environment["SOLANA_RPC_URL"]
            ?? "https://api.devnet.solana.com"
    }

    static var solanaCluster: String {
        ProcessInfo.processInfo.environment["SOLANA_CLUSTER"]
            ?? "devnet"
    }

    static var usdcMint: String {
        ProcessInfo.processInfo.environment["USDC_MINT"]
            ?? "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
    }

    static var programID: String {
        ProcessInfo.processInfo.environment["PROGRAM_ID"]
            ?? "B1a1oejNg8uWz7USuuFSqmRQRUSZ95kk2e4PzRZ7Uti4"
    }

    // MARK: - Wallet Deeplinks

    static let phantomDeeplinkScheme = "phantom"
    static let solflareDeeplinkScheme = "solflare"
    static let appURLScheme = "artha"
}
