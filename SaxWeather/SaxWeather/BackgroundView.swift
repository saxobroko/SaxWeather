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
}
