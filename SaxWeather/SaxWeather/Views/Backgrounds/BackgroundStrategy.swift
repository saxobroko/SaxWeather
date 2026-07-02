//
//  BackgroundStrategy.swift
//  SaxWeather
//
//  Phase 5 — Background engine.
//
//  A `BackgroundStrategy` is the *resolved* background to render at
//  the current moment. It's the output of `BackgroundResolver` and
//  the input of `BackgroundView`. Splitting "what to draw" from
//  "how to draw it" keeps the view dumb (a switch on the strategy)
//  and the resolver pure (a function from inputs to a strategy).
//
//  The strategy is intentionally a value type so SwiftUI can diff
//  it cheaply, the registry can include it in its profile hash
//  (Phase 8), and the widget can serialise a subset of it across
//  the App Group boundary.
//
//  See `plans/INFINITE_CUSTOMISATION_PLAN.md` §2.5 and §4.5.
//

import SwiftUI

/// The resolved background to render. One variant per
/// `BackgroundMode`, with the data each variant needs baked in.
enum BackgroundStrategy: Equatable, Hashable, Codable {
    /// Use the shipped `Assets.xcassets` image for `condition`.
    /// The view looks up `weather_background_<condition>` and
    /// falls back to `weather_background_default`.
    case preset(condition: String)
    /// A user-supplied image. `nil` data means "fall back to
    /// preset" — should never happen after the resolver runs, but
    /// the view handles it defensively.
    case customImage(Data?)
    /// A two-stop vertical gradient.
    case gradient(top: ColourToken, bottom: ColourToken,
                  topOpacity: Double, bottomOpacity: Double)
    /// The shipped preset image, tinted with `tint` via
    /// `.colorMultiply(_:)`. Used to give the same photo a fresh
    /// mood without shipping new art.
    case dynamicAccent(tint: ColourToken, condition: String)
    /// Phase 3 — one of the eight Aurora-themed background images
    /// (`weather_background_aurora_<condition>`). The view looks
    /// up `name` and falls back to the palette gradient if the
    /// image can't be loaded (defensive — should only happen if
    /// the asset was renamed and the build is stale).
    case auroraImage(name: String)

    // MARK: - Codable (for the widget subset in Phase 8)

    private enum CodingKeys: String, CodingKey {
        case kind, condition, data, top, bottom, topOpacity, bottomOpacity, tint, name
    }
    private enum Kind: String, Codable {
        case preset, customImage, gradient, dynamicAccent, auroraImage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .preset:
            self = .preset(condition: try c.decode(String.self, forKey: .condition))
        case .customImage:
            self = .customImage(try c.decodeIfPresent(Data.self, forKey: .data))
        case .gradient:
            self = .gradient(
                top: try c.decode(ColourToken.self, forKey: .top),
                bottom: try c.decode(ColourToken.self, forKey: .bottom),
                topOpacity: try c.decode(Double.self, forKey: .topOpacity),
                bottomOpacity: try c.decode(Double.self, forKey: .bottomOpacity)
            )
        case .dynamicAccent:
            self = .dynamicAccent(
                tint: try c.decode(ColourToken.self, forKey: .tint),
                condition: try c.decode(String.self, forKey: .condition)
            )
        case .auroraImage:
            self = .auroraImage(name: try c.decode(String.self, forKey: .name))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .preset(let condition):
            try c.encode(Kind.preset, forKey: .kind)
            try c.encode(condition, forKey: .condition)
        case .customImage(let data):
            try c.encode(Kind.customImage, forKey: .kind)
            try c.encodeIfPresent(data, forKey: .data)
        case .gradient(let top, let bottom, let topOp, let bottomOp):
            try c.encode(Kind.gradient, forKey: .kind)
            try c.encode(top, forKey: .top)
            try c.encode(bottom, forKey: .bottom)
            try c.encode(topOp, forKey: .topOpacity)
            try c.encode(bottomOp, forKey: .bottomOpacity)
        case .dynamicAccent(let tint, let condition):
            try c.encode(Kind.dynamicAccent, forKey: .kind)
            try c.encode(tint, forKey: .tint)
            try c.encode(condition, forKey: .condition)
        case .auroraImage(let name):
            try c.encode(Kind.auroraImage, forKey: .kind)
            try c.encode(name, forKey: .name)
        }
    }
}
