import SwiftUI

struct StatusBadge: View {
    let status: DealStatus

    var body: some View {
        Text(status.displayLabel)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.15))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .INIT:      return .blue
        case .FUNDED:    return .green
        case .DISPUTED:  return .orange
        case .RESOLVED:  return .purple
        case .RELEASED:  return .teal
        case .REFUNDED:  return .gray
        }
    }
}

#Preview {
    HStack {
        ForEach(DealStatus.allCases, id: \.self) { status in
            StatusBadge(status: status)
        }
    }
    .padding()
}
