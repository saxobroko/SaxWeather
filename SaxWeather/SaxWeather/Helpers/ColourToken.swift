//
//  ColourToken.swift
//  SaxWeather
//
//  Phase 3 — typed colour primitive used by every visual knob.
//
//  Why a dedicated type? Three reasons:
//    1. **Type safety** — `\.visual.accentColor` is `ColourToken`,
//       not `String`. The compiler catches typos at the call site.
//    2. **Pluggable sources** — `.named("blue")` reuses the
//       shipped palette; `.rgb(...)` and `.hex(...)` let power
//       users pick exact colours via the JSON profile editor or
//       `.saxtheme` import.
//    3. **JSON + UserDefaults friendly** — `ColourToken` encodes
//       as a single `String` (`"blue"` / `"#FF8800"` /
//       `"rgb(1.0,0.5,0.0,1.0)"`), so it round-trips losslessly
//       through `.saxtheme` and through the bridge's
//       `@AppStorage` keys without a custom container.
//
//  See `plans/INFINITE_CUSTOMISATION_PLAN.md` §1.1 + §4.3.
//

import SwiftUI

/// A colour value expressed as one of three formats. Codable as
/// a single `String` so it round-trips cleanly through both
/// `.saxtheme` JSON and `UserDefaults` `String` keys.
enum ColourToken: Codable, Hashable, Sendable {
    /// A semantic or named colour. Resolved via `Color(.systemBlue)`-
    /// style references, or matched against a small built-in
    /// palette (`"blue"`, `"red"`, …).
    case named(String)
    /// An sRGB colour with explicit alpha in 0…1.
    case rgb(r: Double, g: Double, b: Double, a: Double)
    /// A CSS-style hex string (`"#RGB"`, `"#RRGGBB"`, or
    /// `"#RRGGBBAA"`).
    case hex(String)

    // MARK: - String interop

    /// Parses a raw string into a token. Used by the bridge and
    /// by the JSON decoder (see `init(from:)`).
    init(rawString: String) {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            self = .hex(trimmed)
        } else if trimmed.lowercased().hasPrefix("rgb(") && trimmed.hasSuffix(")") {
            let inner = trimmed.dropFirst(4).dropLast()
            let parts = inner.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if parts.count == 4,
               let r = Double(parts[0]),
               let g = Double(parts[1]),
               let b = Double(parts[2]),
               let a = Double(parts[3]) {
                self = .rgb(r: r, g: g, b: b, a: a)
            } else {
                self = .named(trimmed) // unparseable → treat as a name
            }
        } else {
            self = .named(trimmed)
        }
    }

    /// Inverse of `init(rawString:)`. Used by the bridge to write
    /// a single `String` to `UserDefaults` and by `encode(to:)`.
    var rawString: String {
        switch self {
        case .named(let v):  return v
        case .hex(let v):    return v
        case .rgb(let r, let g, let b, let a):
            return "rgb(\(r),\(g),\(b),\(a))"
        }
    }

    // MARK: - Codable

    /// Encode as a single `String` (the `rawString`). Matches
    /// `init(rawString:)` losslessly.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawString: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawString)
    }

    // MARK: - SwiftUI Color conversion

    /// Resolve to a SwiftUI `Color`. The optional `colorScheme`
    /// lets `.named("system")` resolve to the right semantic
    /// colour in light vs dark mode.
    func color(for colorScheme: ColorScheme = .light) -> Color {
        switch self {
        case .named(let name):
            return Self.swiftUIColor(named: name, colorScheme: colorScheme)
        case .rgb(let r, let g, let b, let a):
            return Color(.sRGB,
                         red: clamp01(r),
                         green: clamp01(g),
                         blue: clamp01(b),
                         opacity: clamp01(a))
        case .hex(let hex):
            return Self.colorFromHex(hex) ?? .gray
        }
    }

    /// Convenience for SwiftUI views that don't care about
    /// colour scheme (most cards, lists, etc.). Uses the current
    /// environment colour scheme via the system `Color.primary`
    /// / `.secondary` references that adapt automatically.
    var color: Color { color(for: .light) }

    // MARK: - Built-in palette

    /// Built-in named colours. Mirrors the palette the existing
    /// `AccentColorHelper` already understands so legacy
    /// `"accentColor": "blue"` values resolve the same way.
    private static func swiftUIColor(named name: String, colorScheme: ColorScheme) -> Color {
        switch name.lowercased() {
        case "blue":        return .blue
        case "purple":      return .purple
        case "pink":        return .pink
        case "red":         return .red
        case "orange":      return .orange
        case "yellow":      return .yellow
        case "green":       return .green
        case "teal":        return .teal
        case "cyan":        return .cyan
        case "indigo":      return .indigo
        case "mint":        return .mint
        case "brown":       return .brown
        case "white":       return .white
        case "black":       return .black
        case "gray", "grey": return .gray

        // Semantic colours that adapt to colour scheme.
        case "system":      return .primary
        case "primary":     return .primary
        case "secondary":   return .secondary
        case "label":       return .primary
        case "background":  return Color(.systemBackground)
        case "surface":     return Color(.secondarySystemBackground)
        case "muted":       return .secondary
        case "danger":      return .red

        default:            return .blue
        }
    }

    private static func colorFromHex(_ hex: String) -> Color? {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard let value = UInt64(str, radix: 16) else { return nil }

        let r, g, b, a: Double
        switch str.count {
        case 3: // RGB (4-bit per channel) → 8-bit
            r = Double((value >> 8) & 0xF) / 15
            g = Double((value >> 4) & 0xF) / 15
            b = Double(value & 0xF) / 15
            a = 1.0
        case 6: // RRGGBB
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >>  8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1.0
        case 8: // RRGGBBAA
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >>  8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            return nil
        }
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    private func clamp01(_ x: Double) -> Double {
        min(1.0, max(0.0, x))
    }
}

// Note: `ColourToken.named("blue")` already works because Swift
// synthesises a case constructor for `case named(String)`. No
// convenience extension needed.
