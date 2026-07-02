
import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

struct BackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var storeManager: StoreManager

    let strategy: BackgroundStrategy

    var body: some View {
        GeometryReader { geometry in
            contents(in: geometry)
        }
    }

    // MARK: - Dispatch

    @ViewBuilder
    private func contents(in geometry: GeometryProxy) -> some View {
        switch strategy {
        case .preset(let condition):
            PresetCachedBackgroundView(condition: condition)
        case .customImage(let data):
            customImageBackground(data: data)
        case .gradient(let top, let bottom, let topOp, let bottomOp):
            gradientBackground(top: top, bottom: bottom,
                               topOpacity: topOp, bottomOpacity: bottomOp)
        case .dynamicAccent(let tint, let condition):
            dynamicAccentBackground(tint: tint, condition: condition)
        case .auroraImage(let name):
            AuroraCachedBackgroundView(assetName: name)
        }
    }

    // MARK: - Custom image (user-supplied)

    @ViewBuilder
    private func customImageBackground(data: Data?) -> some View {
        #if os(iOS)
        if let data = data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        } else {
            PresetCachedBackgroundView(condition: "default")
        }
        #elseif os(macOS)
        if let data = data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        } else {
            PresetCachedBackgroundView(condition: "default")
        }
        #endif
    }

    // MARK: - Gradient

    @ViewBuilder
    private func gradientBackground(
        top: ColourToken,
        bottom: ColourToken,
        topOpacity: Double,
        bottomOpacity: Double
    ) -> some View {
        LinearGradient(
            colors: [
                top.color(for: colorScheme).opacity(topOpacity),
                bottom.color(for: colorScheme).opacity(bottomOpacity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Dynamic accent (preset image + tint)

    @ViewBuilder
    private func dynamicAccentBackground(tint: ColourToken, condition: String) -> some View {
        PresetCachedBackgroundView(condition: condition)
            .overlay(
                tint.color(for: colorScheme)
                    .opacity(0.35)
                    .blendMode(.multiply)
                    .ignoresSafeArea()
            )
    }

    // MARK: - Aurora image (on-demand CDN cache)
    //
    // Rendered by `AuroraCachedBackgroundView`, which loads
    // JPEGs from disk after download from weather.saxobroko.com.
}
