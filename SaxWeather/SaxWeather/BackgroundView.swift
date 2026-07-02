//
//  BackgroundView.swift
//  SaxWeather
//
//  Created by Saxon on 2/3/2025.
//  Phase 5 — Background engine: now renders a `BackgroundStrategy`
//  instead of a raw condition string. The view is deliberately
//  dumb — it switches on the strategy and draws the right thing.
//  All decisions (mode, time-of-day, per-condition overrides) live
//  in `BackgroundResolver`.
//
//  See `plans/INFINITE_CUSTOMISATION_PLAN.md` §2.5 and §4.5.
//
//  Phase 3 — `.auroraImage(name:)` renders the Aurora-themed
//  JPEGs. If the named asset can't be loaded at runtime (e.g.
//  the JPEGs haven't been dropped into the asset catalog yet,
//  or an asset was renamed by accident), the view falls back to
//  `BackgroundResolver.auroraGradient(forCondition:)` so the
//  user never sees a blank background.
//

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
            presetBackground(condition: condition)
        case .customImage(let data):
            customImageBackground(data: data)
        case .gradient(let top, let bottom, let topOp, let bottomOp):
            gradientBackground(top: top, bottom: bottom,
                               topOpacity: topOp, bottomOpacity: bottomOp)
        case .dynamicAccent(let tint, let condition):
            dynamicAccentBackground(tint: tint, condition: condition)
        case .auroraImage(let name):
            auroraImageBackground(name: name)
        }
    }

    // MARK: - Preset (shipped imageset)

    @ViewBuilder
    private func presetBackground(condition: String) -> some View {
        #if os(iOS)
        if let uiImage = UIImage(named: "weather_background_\(condition)") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else if let uiImage = UIImage(named: "weather_background_default") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            Color.blue.opacity(0.2).ignoresSafeArea()
        }
        #elseif os(macOS)
        if let nsImage = NSImage(named: "weather_background_\(condition)") {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else if let nsImage = NSImage(named: "weather_background_default") {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            Color.blue.opacity(0.2).ignoresSafeArea()
        }
        #endif
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
            presetBackground(condition: "default")
        }
        #elseif os(macOS)
        if let data = data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        } else {
            presetBackground(condition: "default")
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
        presetBackground(condition: condition)
            .overlay(
                tint.color(for: colorScheme)
                    .opacity(0.35)
                    .blendMode(.multiply)
                    .ignoresSafeArea()
            )
    }

    // MARK: - Aurora image (Phase 3)
    //
    // Attempts to load the named Aurora JPEG from the asset
    // catalog and falls back to the Aurora palette gradient
    // if the asset is missing. The condition key used for the
    // fallback is parsed out of the asset name (the format is
    // always `weather_background_aurora_<condition>`) so the
    // gradient colours match the missing image's intent.

    @ViewBuilder
    private func auroraImageBackground(name: String) -> some View {
        #if os(iOS)
        if let uiImage = UIImage(named: name) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            // Missing-asset fallback — defensive, should not
            // happen in production. See BackgroundResolver.swift
            // header for the rationale.
            let fallbackStrategy = BackgroundResolver.auroraGradient(
                forCondition: Self.conditionKey(from: name)
            )
            gradientBackgroundForStrategy(fallbackStrategy)
        }
        #elseif os(macOS)
        if let nsImage = NSImage(named: name) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            let fallbackStrategy = BackgroundResolver.auroraGradient(
                forCondition: Self.conditionKey(from: name)
            )
            gradientBackgroundForStrategy(fallbackStrategy)
        }
        #endif
    }

    /// Pull the condition key out of an asset name like
    /// `weather_background_aurora_sunny` → `"sunny"`. Falls
    /// back to `"default"` if the name doesn't match the
    /// expected format (defensive — the gradient lookup will
    /// return its own default branch in that case).
    private static func conditionKey(from assetName: String) -> String {
        let prefix = "weather_background_aurora_"
        guard assetName.hasPrefix(prefix) else { return "default" }
        let stripped = String(assetName.dropFirst(prefix.count))
        // The condition key is everything before the first
        // ".", "_2x", "_3x", etc. (defensive against any
        // future image-set variants).
        if let dot = stripped.firstIndex(of: ".") {
            return String(stripped[..<dot])
        }
        return stripped
    }

    /// Convenience: render a gradient `BackgroundStrategy` as
    /// a `LinearGradient` view. Used only by the Aurora
    /// missing-asset fallback path.
    @ViewBuilder
    private func gradientBackgroundForStrategy(
        _ strategy: BackgroundStrategy
    ) -> some View {
        if case let .gradient(top, bottom, topOp, bottomOp) = strategy {
            gradientBackground(
                top: top, bottom: bottom,
                topOpacity: topOp, bottomOpacity: bottomOp
            )
        } else {
            // auroraGradient always returns a `.gradient` —
            // this branch is unreachable but keeps the
            // function total.
            Color.blue.opacity(0.2).ignoresSafeArea()
        }
    }
}
