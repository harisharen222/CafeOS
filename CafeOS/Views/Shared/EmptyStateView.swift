import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.6))
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.brown)
                    .padding(.top, 8)
            }
            Spacer()
        }
    }
}
