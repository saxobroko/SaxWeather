
import SwiftUI

struct PreviewCountdownOverlay: View {
    /// The preview manager. The overlay reads
    /// `remainingSeconds` from this object so it re-renders
    /// every second.
    @ObservedObject var previewManager: PreviewProfileManager
    /// Display name of the product being previewed.
    let productName: String
    /// Invoked when the user taps the stop button.
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(
                    localized: "Previewing \(productName)",
                    comment: "Headline of the live-preview countdown overlay. %@ is the cosmetic display name."
                ))
                .font(.subheadline.bold())
                Text("Ends in \(previewManager.remainingSeconds)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                onStop()
            } label: {
                Text(String(
                    localized: "Stop Preview",
                    comment: "Button on the countdown overlay that ends the preview immediately."
                ))
                .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        .padding(.horizontal, 12)
    }
}

struct WithPreviewCountdown<Content: View>: View {
    let previewManager: PreviewProfileManager
    let productName: String?
    let onStop: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if previewManager.remainingSeconds > 0, let name = productName {
                PreviewCountdownOverlay(
                    previewManager: previewManager,
                    productName: name,
                    onStop: onStop
                )
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            content()
        }
        .animation(.easeInOut(duration: 0.25), value: previewManager.remainingSeconds)
    }
}