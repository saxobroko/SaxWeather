
import SwiftUI

struct ScaledFontModifier: ViewModifier {
    /// Active profile source. Defaults to the shared singleton;
    /// tests can inject a fresh registry.
    @ObservedObject var registry: CustomisationRegistry

    /// The font size before applying the user's `fontScale`.
    let baseSize: CGFloat
    /// Font weight before applying the user's `boldText` override.
    let weight: Font.Weight
    /// Font design before applying the user's `typography` family.
    let design: Font.Design

    func body(content: Content) -> some View {
        let visual = registry.profile.knobs.visual
        let scale = visual.useSystemTextSize ? 1.0 : visual.fontScale
        let finalWeight = visual.boldText ? .bold : weight
        let finalDesign = resolvedDesign(from: visual.typography, fallback: design)
        let size = baseSize * CGFloat(scale)

        return content
            .font(.system(size: size, weight: finalWeight, design: finalDesign))
    }

    private func resolvedDesign(
        from family: TypographyFamily,
        fallback: Font.Design
    ) -> Font.Design {
        switch family {
        case .system:  return fallback
        case .rounded: return .rounded
        case .serif:   return .serif
        case .mono:    return .monospaced
        }
    }
}

extension View {
    @MainActor
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        registry: CustomisationRegistry = .shared
    ) -> some View {
        modifier(ScaledFontModifier(
            registry: registry,
            baseSize: size,
            weight: weight,
            design: design
        ))
    }
}
