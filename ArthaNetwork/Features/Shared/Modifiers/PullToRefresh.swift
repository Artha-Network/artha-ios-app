import SwiftUI

/// Convenience modifier for adding pull-to-refresh to any ScrollView.
/// SwiftUI's built-in `.refreshable` works on List and ScrollView natively.
/// This modifier is a thin ergonomic wrapper.
struct PullToRefresh: ViewModifier {
    let action: () async -> Void

    func body(content: Content) -> some View {
        content.refreshable {
            await action()
        }
    }
}

extension View {
    func onPullToRefresh(perform action: @escaping () async -> Void) -> some View {
        modifier(PullToRefresh(action: action))
    }
}
