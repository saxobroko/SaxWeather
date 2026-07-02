
import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

/// Loads an Aurora background from the on-disk cache, fetching
/// from `weather.saxobroko.com` when needed. Falls back to the
/// Aurora palette gradient while downloading or if offline.
struct AuroraCachedBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var assetStore = CosmeticAssetStore.shared

    let assetName: String

    private var conditionKey: String {
        let prefix = "weather_background_aurora_"
        guard assetName.hasPrefix(prefix) else { return "default" }
        let stripped = String(assetName.dropFirst(prefix.count))
        if let dot = stripped.firstIndex(of: ".") {
            return String(stripped[..<dot])
        }
        return stripped
    }

    var body: some View {
        Group {
            #if os(iOS)
            if let data = assetStore.localImageData(forCondition: conditionKey),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                auroraGradientFallback
            }
            #elseif os(macOS)
            if let data = assetStore.localImageData(forCondition: conditionKey),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                auroraGradientFallback
            }
            #endif
        }
        .task(id: conditionKey) {
            try? await assetStore.download(condition: conditionKey)
        }
    }

    @ViewBuilder
    private var auroraGradientFallback: some View {
        let strategy = BackgroundResolver.auroraGradient(
            forCondition: conditionKey
        )
        if case let .gradient(top, bottom, topOp, bottomOp) = strategy {
            LinearGradient(
                colors: [
                    top.color(for: colorScheme).opacity(topOp),
                    bottom.color(for: colorScheme).opacity(bottomOp)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        } else {
            Color.blue.opacity(0.2).ignoresSafeArea()
        }
    }
}
