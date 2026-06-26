//
//  StyledCard.swift
//  SaxWeather
//
//  Phase 3 — the single entry point for "render this view as a
//  card" across the app. Reads `cardStyle`, `cornerRadius`,
//  `cardOpacity`, `cardBorderColor`, `cardBorderWidth`,
//  `cardShadowOpacity`, `cardShadowRadius`, `cardShadowX`,
//  `cardShadowY`, `cardBlurIntensity`, `cardHighlightIntensity`,
//  `cardTint`, `cardTintOverlay`, `cardNeumorphicInset`, and the
//  palette from the active profile and applies them as SwiftUI
//  modifiers.
//
//  Card styles:
//    • `.glass`      — true glass effect (iOS 26.2+) /
//                      `.ultraThinMaterial` fallback. The
//                      shipped default for the home screen.
//    • `.solid`      — opaque `palette.surface` colour at the
//                      user's chosen opacity, with the optional
//                      `cardTint` accent wash on top.
//    • `.outline`    — transparent fill with a 1pt user-chosen
//                      `cardBorderColor` border. Use for inline
//                      cards in lists.
//    • `.neumorphic` — soft 5% gray fill with a 1pt white
//                      highlight and a 1pt inner shadow. Decorative.
//
//  The `cardStyle(theme:)` variant takes a `VisualSpec` directly
//  so the live-preview Card Settings submenu can render an
//  example card without committing the values to the registry.
//
//  Phase 4 — Aurora Palette reactivity fix. The body now
//  directly references `registry.profile` so SwiftUI tracks
//  the dependency and re-renders when the profile changes
//  (e.g. during a live preview). Previously the body only
//  referenced `visual` (a local variable), which meant
//  SwiftUI didn't always re-evaluate the body when the
//  profile changed.
//
//  Part E — Aurora Palette visibility fix. The `.glass` card
//  style now tints the material with the palette's `surface`
//  colour at low opacity so the palette is visible on the
//  default home screen. Previously the `.glass` style used
//  `Material.ultraThin` etc. which doesn't consume any
//  palette colours, so the Aurora Palette was invisible on
//  the default home screen even with the reactivity fix.
//

import SwiftUI

/// Theme-driven card styling. Reads from the active
/// `CustomisationRegistry` by default; pass an explicit
/// `VisualSpec` to render a preview without touching the
/// registry.
struct StyledCardModifier: ViewModifier {
    @ObservedObject var registry: CustomisationRegistry
    // Part B — observe the reactive palette store so the card
    // re-renders when the palette changes (e.g. during a live
    // preview of the Aurora Palette cosmetic). The store
    // observes `CustomisationRegistry` and updates its
    // `@Published var palette` when the profile changes.
    @EnvironmentObject private var colourTokenStore: ColourTokenStore

    func body(content: Content) -> some View {
        // Phase 4 — direct reference to `registry.profile` so
        // SwiftUI tracks the dependency and re-renders when the
        // profile changes (e.g. during a live preview). Without
        // this, the body might not re-evaluate when the profile
        // changes because `visual` is a local variable.
        // Part B — direct reference to `colourTokenStore.palette`
        // so SwiftUI tracks the dependency and re-renders when
        // the palette changes (e.g. during a live preview of
        // the Aurora Palette cosmetic).
        let _ = colourTokenStore.palette
        let visual = registry.profile.knobs.visual
        return content
            .padding(.horizontal, visual.cardPaddingH)
            .padding(.vertical, visual.cardPaddingV)
            .frame(maxWidth: .infinity)
            .background(cardBackground(for: visual))
            .overlay(cardOverlay(for: visual))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: visual.cornerRadius,
                    style: .continuous
                )
            )
            .shadow(
                color: .black.opacity(visual.cardShadowOpacity),
                radius: visual.cardShadowRadius,
                x: visual.cardShadowX,
                y: visual.cardShadowY
            )
    }

    // MARK: - Background

    @ViewBuilder
    private func cardBackground(for visual: VisualSpec) -> some View {
        // Layer 1: the base fill (style-dependent).
        Group {
            switch visual.cardStyle {
            case .glass:
                // iOS 26 ships the official `glassEffect` /
                // `Color.glass` style. We fall back to
                // `.ultraThinMaterial` so the build still works
                // on older SDKs and the modifier is previewable.
                // The intensity knob scales between thin and
                // regular materials. The `cardGlassOpacity`
                // knob matches the original
                // `WeatherDetailsView` treatment
                // (`.ultraThinMaterial.opacity(0.6)`).
                let material: AnyShapeStyle = {
                    if visual.cardBlurIntensity < 0.34 {
                        return AnyShapeStyle(Material.ultraThin)
                    } else if visual.cardBlurIntensity < 0.67 {
                        return AnyShapeStyle(Material.thin)
                    } else {
                        return AnyShapeStyle(Material.regular)
                    }
                }()
                Rectangle()
                    .fill(material)
                    .opacity(visual.cardGlassOpacity)
                // Part E (reverted) — Aurora Palette visibility
                // tint. The always-on tint was removed because
                // it changed the default look of the app even
                // when the Aurora Palette was not selected. The
                // tint is now applied via `CardColorScheme.tint`
                // and only when the Aurora Palette is selected
                // AND owned (see `CardColorScheme.resolve`).
                // Previously the `.glass` style used
                // `Material.ultraThin` etc. which doesn't
                // consume any palette colours, so the Aurora
                // Palette was invisible on the default home
                // screen even with the reactivity fix.
                if visual.palette == .cosmeticAurora {
                    Rectangle()
                        .fill(
                            visual.palette.surface.color
                                .opacity(0.15)
                        )
                }
            case .solid:
                // Honour the user-picked fill colour. When the
                // token is empty we fall back to `palette.surface`
                // so the legacy look is preserved.
                if visual.cardFillColor.isEmpty {
                    Rectangle().fill(
                        visual.palette.surface.color
                            .opacity(visual.cardOpacity)
                    )
                } else {
                    Rectangle().fill(
                        visual.cardFillColor.color
                            .opacity(visual.cardOpacity)
                    )
                }
            case .outline:
                Color.clear
            case .neumorphic:
                if visual.cardFillColor.isEmpty {
                    Rectangle().fill(
                        Color(.systemGray6).opacity(visual.cardOpacity)
                    )
                } else {
                    Rectangle().fill(
                        visual.cardFillColor.color
                            .opacity(visual.cardOpacity)
                    )
                }
            }
        }
        // Layer 2: the optional tint wash. Skipped when the
        // token resolves to a no-op (`rawString == ""`).
        .overlay {
            if !visual.cardTint.isEmpty {
                Rectangle().fill(
                    visual.cardTint.color.opacity(0.18)
                )
            }
        }
        // Layer 3: an optional warm/cool overlay rendered as a
        // top-leading → bottom-trailing linear gradient. The
        // original WeatherDetailsView used this exact treatment
        // (3 stops, dark mode vs light mode) so the user can
        // reproduce it through the Card Settings submenu.
        .overlay {
            if !visual.cardTintOverlay.isEmpty {
                LinearGradient(
                    colors: [
                        visual.cardTintOverlay.color
                            .opacity(visual.cardTintOverlayOpacity),
                        visual.cardTintOverlay.color
                            .opacity(visual.cardTintOverlayOpacity * 0.5),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    // MARK: - Overlay (borders, neumorphic highlights)

    @ViewBuilder
    private func cardOverlay(for visual: VisualSpec) -> some View {
        CardOverlay(visual: visual)
    }
}

// MARK: - Theme-driven preview variant

/// Card styling that takes a `VisualSpec` directly. Used by the
/// live-preview Card Settings submenu so the example card
/// updates in real time without writing back to the registry.
struct ThemedCardModifier: ViewModifier {
    let visual: VisualSpec

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, visual.cardPaddingH)
            .padding(.vertical, visual.cardPaddingV)
            .frame(maxWidth: .infinity)
            .background(themedBackground)
            .overlay(themedOverlay)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: visual.cornerRadius,
                    style: .continuous
                )
            )
            .shadow(
                color: .black.opacity(visual.cardShadowOpacity),
                radius: visual.cardShadowRadius,
                x: visual.cardShadowX,
                y: visual.cardShadowY
            )
    }

    @ViewBuilder
    private var themedBackground: some View {
        Group {
            switch visual.cardStyle {
            case .glass:
                // Match the original `WeatherDetailsView`
                // treatment: pick a material based on the blur
                // intensity, then apply `cardGlassOpacity` so the
                // user can dial the translucency up or down.
                let material: AnyShapeStyle = {
                    if visual.cardBlurIntensity < 0.34 {
                        return AnyShapeStyle(Material.ultraThin)
                    } else if visual.cardBlurIntensity < 0.67 {
                        return AnyShapeStyle(Material.thin)
                    } else {
                        return AnyShapeStyle(Material.regular)
                    }
                }()
                Rectangle()
                    .fill(material)
                    .opacity(visual.cardGlassOpacity)
                // Part E (reverted) — Aurora Palette visibility
                // tint. The always-on tint was removed because
                // it changed the default look of the app even
                // when the Aurora Palette was not selected. The
                // tint is now applied via `CardColorScheme.tint`
                // and only when the Aurora Palette is selected
                // AND owned (see `CardColorScheme.resolve`).
                // Previously the `.glass` style used
                // `Material.ultraThin` etc. which doesn't
                // consume any palette colours, so the Aurora
                // Palette was invisible on the default home
                // screen even with the reactivity fix.
                if visual.palette == .cosmeticAurora {
                    Rectangle()
                        .fill(
                            visual.palette.surface.color
                                .opacity(0.15)
                        )
                }
            case .solid:
                if visual.cardFillColor.isEmpty {
                    Rectangle().fill(
                        visual.palette.surface.color
                            .opacity(visual.cardOpacity)
                    )
                } else {
                    Rectangle().fill(
                        visual.cardFillColor.color
                            .opacity(visual.cardOpacity)
                    )
                }
            case .outline:
                Color.clear
            case .neumorphic:
                if visual.cardFillColor.isEmpty {
                    Rectangle().fill(
                        Color(.systemGray6).opacity(visual.cardOpacity)
                    )
                } else {
                    Rectangle().fill(
                        visual.cardFillColor.color
                            .opacity(visual.cardOpacity)
                    )
                }
            }
        }
        .overlay {
            if !visual.cardTint.isEmpty {
                Rectangle().fill(visual.cardTint.color.opacity(0.18))
            }
        }
        .overlay {
            if !visual.cardTintOverlay.isEmpty {
                LinearGradient(
                    colors: [
                        visual.cardTintOverlay.color
                            .opacity(visual.cardTintOverlayOpacity),
                        visual.cardTintOverlay.color
                            .opacity(visual.cardTintOverlayOpacity * 0.5),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    @ViewBuilder
    private var themedOverlay: some View {
        CardOverlay(visual: visual)
    }
}

/// Renders the border, neumorphic inset, and glass edge highlight
/// for a card. Shared between the registry-driven
/// `StyledCardModifier` and the live-preview `ThemedCardModifier`
/// so the live preview matches the real render exactly.
struct CardOverlay: View {
    let visual: VisualSpec

    var body: some View {
        ZStack {
            if visual.cardBorderWidth > 0 {
                RoundedRectangle(
                    cornerRadius: visual.cornerRadius,
                    style: .continuous
                )
                .stroke(borderStroke, lineWidth: visual.cardBorderWidth)
            }
            if visual.cardStyle == .neumorphic {
                RoundedRectangle(
                    cornerRadius: visual.cornerRadius,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.50), lineWidth: 0.5)
                if visual.cardNeumorphicInset {
                    RoundedRectangle(
                        cornerRadius: max(2, visual.cornerRadius - 2),
                        style: .continuous
                    )
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    .padding(1)
                }
            }
            if visual.cardStyle == .glass && visual.cardHighlightIntensity > 0 {
                LinearGradient(
                    colors: [
                        Color.white.opacity(visual.cardHighlightIntensity),
                        Color.clear,
                        Color.white.opacity(visual.cardHighlightIntensity * 0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.overlay)
            }
        }
    }

    /// Gradient or solid stroke for the card border. Reusing the
    /// same logic as `StyledCardModifier.borderStroke(for:)`.
    private var borderStroke: AnyShapeStyle {
        if !visual.cardBorderGradientStart.isEmpty
            && !visual.cardBorderGradientEnd.isEmpty {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        visual.cardBorderGradientStart.color
                            .opacity(visual.cardBorderGradientOpacity),
                        visual.cardBorderGradientEnd.color
                            .opacity(visual.cardBorderGradientOpacity * 0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        let borderColor: Color = visual.cardBorderColor.isEmpty
            ? visual.palette.text.color
            : visual.cardBorderColor.color
        return AnyShapeStyle(
            borderColor.opacity(
                visual.cardStyle == .outline ? 0.45 : 0.20
            )
        )
    }
}

extension View {
    /// Render `self` as a card whose background, border,
    /// corner radius, shadow, and tint are all driven by the
    /// active `CustomisationProfile`.
    ///
    /// - Parameter registry: registry to read from. Defaults to
    ///   `CustomisationRegistry.shared`.
    @MainActor
    func styledCard(registry: CustomisationRegistry = .shared) -> some View {
        modifier(StyledCardModifier(registry: registry))
    }

    /// Theme-driven variant. Use from the live-preview Card
    /// Settings submenu so changes can be reviewed before
    /// they're written to the registry.
    @MainActor
    func themedCard(_ visual: VisualSpec) -> some View {
        modifier(ThemedCardModifier(visual: visual))
    }
}

// MARK: - Empty-token helper

extension ColourToken {
    /// `true` when the token is a no-op — an empty name. Used by
    /// the card renderer to skip optional overlays without
    /// resorting to a separate Bool.
    var isEmpty: Bool {
        switch self {
        case .named(let name): return name.isEmpty
        case .rgb, .hex:       return false
        }
    }
}
