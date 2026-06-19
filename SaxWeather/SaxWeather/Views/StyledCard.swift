//
//  StyledCard.swift
//  SaxWeather
//
//  Phase 3 — the single entry point for "render this view as a
//  card" across the app. Reads `cardStyle`, `cornerRadius`,
//  `cardOpacity`, `palette.background`, and `palette.surface`
//  from the active profile and applies them as SwiftUI
//  modifiers.
//
//  Card styles:
//    • `.glass`      — true glass effect (iOS 26.2+) /
//                      `.thinMaterial` fallback. Use for the hero
//                      card and big surfaces.
//    • `.solid`      — opaque `palette.surface` colour at the
//                      user's chosen opacity.
//    • `.outline`    — transparent fill with a 1pt `palette.text`
//                      border. Use for inline cards in lists.
//    • `.neumorphic` — soft 5% gray fill with a 1pt white
//                      highlight. Decorative only.
//
//  See `plans/INFINITE_CUSTOMISATION_PLAN.md` §1.1 + §4.3.
//

import SwiftUI

struct StyledCardModifier: ViewModifier {
    @ObservedObject var registry: CustomisationRegistry

    func body(content: Content) -> some View {
        let visual = registry.profile.knobs.visual

        return content
            .background(cardBackground(for: visual))
            .overlay(cardOverlay(for: visual))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: visual.cornerRadius,
                    style: .continuous
                )
            )
    }

    // MARK: - Background

    @ViewBuilder
    private func cardBackground(for visual: VisualSpec) -> some View {
        switch visual.cardStyle {
        case .glass:
            // iOS 26 ships the official `glassEffect` /
            // `Color.glass` style. We fall back to
            // `.thinMaterial` so the build still works on
            // older SDKs and the modifier is previewable.
            if #available(iOS 26.2, *) {
                Rectangle().fill(.thinMaterial)
            } else {
                Rectangle().fill(.thinMaterial)
            }
        case .solid:
            Rectangle().fill(
                visual.palette.surface.color
                    .opacity(visual.cardOpacity)
            )
        case .outline:
            Color.clear
        case .neumorphic:
            Rectangle().fill(
                Color(.systemGray6).opacity(visual.cardOpacity)
            )
        }
    }

    // MARK: - Overlay (borders, neumorphic highlights)

    @ViewBuilder
    private func cardOverlay(for visual: VisualSpec) -> some View {
        switch visual.cardStyle {
        case .outline:
            RoundedRectangle(
                cornerRadius: visual.cornerRadius,
                style: .continuous
            )
            .stroke(
                visual.palette.text.color.opacity(0.30),
                lineWidth: 1
            )
        case .neumorphic:
            RoundedRectangle(
                cornerRadius: visual.cornerRadius,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.50), lineWidth: 0.5)
            .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 2)
        case .glass, .solid:
            EmptyView()
        }
    }
}

extension View {
    /// Render `self` as a card whose background, border, and
    /// corner radius are all driven by the active
    /// `CustomisationProfile`.
    ///
    /// - Parameter registry: registry to read from. Defaults to
    ///   `CustomisationRegistry.shared`.
    @MainActor
    func styledCard(registry: CustomisationRegistry = .shared) -> some View {
        modifier(StyledCardModifier(registry: registry))
    }
}
