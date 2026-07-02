
import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

/// Loads a preset weather background — `default` from the app
/// bundle, every other condition from the CDN cache.
struct PresetCachedBackgroundView: View {
    @ObservedObject private var assetStore = PresetBackgroundAssetStore.shared

    let condition: String

    private var normalizedCondition: String {
        assetStore.normalizedCondition(condition)
    }

    var body: some View {
        Group {
            if assetStore.usesBundledAsset(forCondition: normalizedCondition) {
                bundledBackground
            } else {
                remoteBackground
            }
        }
        .id("\(normalizedCondition)-\(assetStore.downloadedConditions.contains(normalizedCondition))")
        .task(id: normalizedCondition) {
            guard !assetStore.usesBundledAsset(forCondition: normalizedCondition) else {
                return
            }
            try? await assetStore.download(condition: normalizedCondition)
        }
    }

    @ViewBuilder
    private var bundledBackground: some View {
        #if os(iOS)
        if let uiImage = UIImage(named: "weather_background_default") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            Color.blue.opacity(0.2).ignoresSafeArea()
        }
        #elseif os(macOS)
        if let nsImage = NSImage(named: "weather_background_default") {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            Color.blue.opacity(0.2).ignoresSafeArea()
        }
        #endif
    }

    @ViewBuilder
    private var remoteBackground: some View {
        #if os(iOS)
        if let data = assetStore.localImageData(forCondition: normalizedCondition),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            bundledBackground
        }
        #elseif os(macOS)
        if let data = assetStore.localImageData(forCondition: normalizedCondition),
           let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            bundledBackground
        }
        #endif
    }
}
