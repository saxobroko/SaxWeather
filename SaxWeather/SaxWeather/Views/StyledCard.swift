
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct StyledCardModifier: ViewModifier {
    @ObservedObject var registry: CustomisationRegistry
    @EnvironmentObject private var colourTokenStore: ColourTokenStore

    func body(content: Content) -> some View {
        let _ = colourTokenStore.palette
        let visual = registry.profile.knobs.visual
        return content
            .padding(.horizontal, visual.cardPaddingH)
            .padding(.vertical, visual.cardPaddingV)
            .frame(maxWidth: .infinity)
            .background(cardBackground(for: visual))
            .overlay(cardOverlay(for: visual).allowsHitTesting(false))
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
        cardBackgroundBase(for: visual)
}
    @ViewBuilder
    private func cardBackgroundBase(for visual: VisualSpec) -> some View {
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
        #if canImport(UIKit)
        let fillColor: Color = Color(.systemGray6)
        #elseif canImport(AppKit)
        let fillColor: Color = Color(NSColor.controlBackgroundColor)
        #else
        let fillColor: Color = Color.gray
        #endif
        Rectangle().fill(fillColor.opacity(visual.cardOpacity))
    } else {
        Rectangle().fill(
            visual.cardFillColor.color
                .opacity(visual.cardOpacity)
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
            .overlay(themedOverlay.allowsHitTesting(false))
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
                    #if canImport(UIKit)
                    let fillColor: Color = Color(.systemGray6)
                    #elseif canImport(AppKit)
                    let fillColor: Color = Color(NSColor.controlBackgroundColor)
                    #else
                    let fillColor: Color = Color.gray
                    #endif
                    Rectangle().fill(fillColor.opacity(visual.cardOpacity))
                } else {
                    Rectangle().fill(
                        visual.cardFillColor.color
                            .opacity(visual.cardOpacity)
                    )
                }
            }
    }

    @ViewBuilder
    private var themedOverlay: some View {
        CardOverlay(visual: visual)
    }
}

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
