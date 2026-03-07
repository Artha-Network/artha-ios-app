import Foundation

extension UserDefaults {
    private enum Keys {
        static let escrowFlowData = "artha:escrow-flow"
        static let lastConnectedWallet = "artha:last-wallet"
    }

    var escrowFlowData: Data? {
        get { data(forKey: Keys.escrowFlowData) }
        set { set(newValue, forKey: Keys.escrowFlowData) }
    }

    func clearEscrowFlow() {
        removeObject(forKey: Keys.escrowFlowData)
    }

    var lastConnectedWallet: String? {
        get { string(forKey: Keys.lastConnectedWallet) }
        set { set(newValue, forKey: Keys.lastConnectedWallet) }
    }
}
