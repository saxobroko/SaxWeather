//
//  CosmeticTilePlaceholder.swift
//  SaxWeather
//
//  Phase 3 — Per-IAP tile image system helper.
//
//  Every cosmetic in the catalog now carries an optional
//  `tileImageName` referencing an imageset in
//  `Assets.xcassets/cosmetic_tile_<short_id>.imageset/`. If
//  the image is dropped in by the user, the store card and
//  detail-view hero show it. If the image is missing (the
//  user hasn't dropped one in yet, or the JPEG is the wrong
//  filename), this placeholder renders a kind-appropriate
//  SF Symbol on a SwiftUI gradient so the user can still
//  tell at a glance which kind they're looking at.
//
//  The placeholder is intentionally simple — no asset
//  references, no image I/O beyond `UIImage(named:)` — so it
//  compiles even if no imageset exists in the bundle. That
//  matches the existing Aurora Backgrounds hero, which
//  already falls back to a gradient via the same pattern.
//
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Resolves the tile image for a cosmetic. Returns `nil`
/// when the product has no `tileImageName`, or when
/// `UIImage(named:)` returns `nil` (the JPEG hasn't been
/// dropped into the asset catalog yet — defensive so the
/// placeholder always renders *something* readable).
///
/// The caller is responsible for branching on `nil` to
/// render the placeholder.
enum CosmeticTileImage {
    /// `true` when a custom tile image exists for the
    /// product. Cached via the bundle, so the lookup is
    /// cheap.
    static func hasCustomImage(for product: CosmeticProduct) -> Bool {
        guard let name = product.tileImageName, !name.isEmpty else {
            return false
        }
        #if os(iOS)
        return UIImage(named: name) != nil
        #elseif os(macOS)
        return NSImage(named: name) != nil
        #else
        return false
        #endif
    }

    /// The SwiftUI `Image` for the product's tile, or `nil`
    /// when no custom image is present.
    static func image(for product: CosmeticProduct) -> Image? {
        guard let name = product.tileImageName, !name.isEmpty else {
            return nil
        }
        #if os(iOS)
        if let uiImage = UIImage(named: name) {
            return Image(uiImage: uiImage)
        }
        #elseif os(macOS)
        if let nsImage = NSImage(named: name) {
            return Image(nsImage: nsImage)
        }
        #endif
        return nil
    }
}

/// The fallback view rendered when no custom tile image is
/// available. Visually distinct per cosmetic kind so the
/// user can identify the kind at a glance.
///
/// Sized to fill whatever container the caller puts it in —
/// it always uses `frame(maxWidth: .infinity, maxHeight:
/// .infinity)`.
struct CosmeticTilePlaceholder: View {
    let product: CosmeticProduct

    var body: some View {
        ZStack {
            // Distinct gradient per kind so the placeholder
            // is visually distinguishable even with no
            // symbols or text.
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                Text(product.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }
        }
    }

    /// SF Symbol appropriate for the cosmetic kind. Chosen
    /// to be visually distinct even at small sizes.
    private var symbolName: String {
        switch product.productKind {
        case .backgrounds: return "photo.stack.fill"
        case .palette:     return "swatchpalette.fill"
        case .chart:       return "chart.line.uptrend.xyaxis"
        case .icons:       return "cloud.sun.rain.fill"
        case .font:        return "textformat"
        case .haptic:      return "iphone.radiowaves.left.and.right"
        case .sound:       return "speaker.wave.2.fill"
        case .widgetTheme: return "rectangle.3.group.fill"
        case .appIcon:     return "app.fill"
        case .badge:       return "rosette"
        case .supporterPack: return "sparkles"
        case .bundle:      return "square.stack.3d.up.fill"
        }
    }

    /// Gradient stops per kind — varies the placeholder
    /// palette so the user can tell the kinds apart even
    /// before reading the label.
    ///
    /// The Supporter Pack uses a distinctive gold/amber
    /// gradient so it reads as "premium" without being
    /// manipulative — different from every other kind's
    /// palette.
    private var gradientColors: [Color] {
        switch product.productKind {
        case .backgrounds:
            return [.teal.opacity(0.7), .indigo.opacity(0.7)]
        case .palette:
            return [.pink.opacity(0.7), .purple.opacity(0.7)]
        case .chart:
            return [.blue.opacity(0.7), .green.opacity(0.7)]
        case .icons:
            return [.orange.opacity(0.7), .red.opacity(0.7)]
        case .font:
            return [.gray.opacity(0.7), .black.opacity(0.7)]
        case .haptic:
            return [.yellow.opacity(0.7), .orange.opacity(0.7)]
        case .sound:
            return [.cyan.opacity(0.7), .blue.opacity(0.7)]
        case .widgetTheme:
            return [.mint.opacity(0.7), .teal.opacity(0.7)]
        case .appIcon:
            return [.purple.opacity(0.7), .pink.opacity(0.7)]
        case .badge:
            return [.yellow.opacity(0.7), .orange.opacity(0.7)]
        case .supporterPack:
            // Distinctive gold/amber gradient — reads as
            // "premium" without being manipulative. Different
            // from every other kind's palette so the user can
            // tell the Supporter Pack apart at a glance.
            return [
                Color(red: 1.00, green: 0.84, blue: 0.30),  // gold
                Color(red: 0.95, green: 0.55, blue: 0.10)   // amber
            ]
        case .bundle:
            return [.brown.opacity(0.7), .orange.opacity(0.7)]
        }
    }
}