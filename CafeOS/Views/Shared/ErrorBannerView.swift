import SwiftUI

struct ErrorBannerView: View {
    let message: String
    var onRetry: (() -> Void)? = nil
    @Binding var isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                Spacer()
                if let onRetry {
                    Button("Retry") { onRetry() }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
                Button {
                    withAnimation { isVisible = false }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            .background(Color.red.cornerRadius(10))
            .padding(.horizontal)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut, value: isVisible)
        }
    }
}
