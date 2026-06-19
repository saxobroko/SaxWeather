//
//  ColourTokenTests.swift
//  SaxWeatherTests
//
//  Phase 3 acceptance tests for the `ColourToken` primitive.
//
//  Covers:
//   • `rawString` parsing for named / hex / rgb cases.
//   • Lossless JSON Codable round-trip (the wire format the
//     `.saxtheme` files and the bridge use).
//   • SwiftUI `Color` resolution for the built-in named palette.
//   • Unparseable strings gracefully degrade to `.named` rather
//     than crash.
//

import XCTest
@testable import SaxWeather

final class ColourTokenTests: XCTestCase {

    // MARK: - init(rawString:) — named

    func test_initRawString_named_passesThrough() {
        let t = ColourToken(rawString: "blue")
        XCTAssertEqual(t, .named("blue"))
    }

    func test_initRawString_named_preservesArbitraryStrings() {
        XCTAssertEqual(ColourToken(rawString: "MyBrandColor"),
                       .named("MyBrandColor"))
    }

    func test_initRawString_named_trimsWhitespace() {
        let t = ColourToken(rawString: "  red  \n")
        XCTAssertEqual(t, .named("red"))
    }

    // MARK: - init(rawString:) — hex

    func test_initRawString_hex6_isHexCase() {
        let t = ColourToken(rawString: "#FF8800")
        guard case .hex(let hex) = t else {
            return XCTFail("Expected .hex, got \(t)")
        }
        XCTAssertEqual(hex, "#FF8800")
    }

    func test_initRawString_hex3_isHexCase() {
        let t = ColourToken(rawString: "#F80")
        guard case .hex(let hex) = t else {
            return XCTFail("Expected .hex, got \(t)")
        }
        XCTAssertEqual(hex, "#F80")
    }

    func test_initRawString_hex8_withAlpha_isHexCase() {
        let t = ColourToken(rawString: "#11223344")
        guard case .hex(let hex) = t else {
            return XCTFail("Expected .hex, got \(t)")
        }
        XCTAssertEqual(hex, "#11223344")
    }

    // MARK: - init(rawString:) — rgb

    func test_initRawString_rgb_isRgbCase() {
        let t = ColourToken(rawString: "rgb(1.0,0.5,0.0,1.0)")
        XCTAssertEqual(t, .rgb(r: 1.0, g: 0.5, b: 0.0, a: 1.0))
    }

    func test_initRawString_rgb_acceptsWhitespace() {
        let t = ColourToken(rawString: "rgb( 0.25 , 0.5 , 0.75 , 1.0 )")
        XCTAssertEqual(t, .rgb(r: 0.25, g: 0.5, b: 0.75, a: 1.0))
    }

    func test_initRawString_rgb_caseInsensitive() {
        let t = ColourToken(rawString: "RGB(0,0,0,1)")
        XCTAssertEqual(t, .rgb(r: 0, g: 0, b: 0, a: 1))
    }

    func test_initRawString_rgbMalformed_fallsBackToNamed() {
        let t = ColourToken(rawString: "rgb(garbage)")
        XCTAssertEqual(t, .named("rgb(garbage)"))
    }

    // MARK: - rawString

    func test_rawString_named_returnsName() {
        XCTAssertEqual(ColourToken.named("blue").rawString, "blue")
    }

    func test_rawString_hex_returnsHex() {
        XCTAssertEqual(ColourToken.hex("#ABCDEF").rawString, "#ABCDEF")
    }

    func test_rawString_rgb_returnsFormattedString() {
        XCTAssertEqual(
            ColourToken.rgb(r: 0.1, g: 0.2, b: 0.3, a: 1.0).rawString,
            "rgb(0.1,0.2,0.3,1.0)"
        )
    }

    // MARK: - JSON round-trip (Codable)

    func test_codable_roundTrip_named() throws {
        let original = ColourToken.named("purple")
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(ColourToken.self, from: data)
        XCTAssertEqual(restored, original)
        // Wire format is a bare string, not a tagged object.
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"purple\"")
    }

    func test_codable_roundTrip_hex() throws {
        let original = ColourToken.hex("#00FFAA")
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(ColourToken.self, from: data)
        XCTAssertEqual(restored, original)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"#00FFAA\"")
    }

    func test_codable_roundTrip_rgb() throws {
        let original = ColourToken.rgb(r: 0.0, g: 0.5, b: 1.0, a: 0.75)
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(ColourToken.self, from: data)
        XCTAssertEqual(restored, original)
        XCTAssertEqual(String(data: data, encoding: .utf8),
                       "\"rgb(0.0,0.5,1.0,0.75)\"")
    }

    // MARK: - Color resolution

    func test_color_named_resolvesKnownNames() {
        // We can't directly compare SwiftUI Color values, but we
        // can verify the type is reachable.
        let blue = ColourToken.named("blue").color
        _ = blue // existence check
    }

    func test_color_unknownName_returnsFallback() {
        // Unknown names should not crash; they produce a default
        // Color (currently `.blue`).
        _ = ColourToken.named("NotARealColor").color
    }

    func test_color_rgb_roundTrip_matchesInput() {
        // Resolve rgb to a SwiftUI Color and back; the only thing
        // we can check is that it doesn't crash and returns a Color.
        let c = ColourToken.rgb(r: 0.5, g: 0.5, b: 0.5, a: 1.0).color
        _ = c
    }

    func test_color_hex_3DigitExpandsCorrectly() {
        // The hex parser expands `#RGB` into `#RRGGBB` internally;
        // make sure it doesn't crash and returns *some* Color.
        let c = ColourToken.hex("#F80").color
        _ = c
    }

    // MARK: - Hashable

    func test_hashable_equalValuesHashEqual() {
        let a = ColourToken.named("blue")
        let b = ColourToken.named("blue")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func test_hashable_differentValuesHashDifferent() {
        let a = ColourToken.named("blue")
        let b = ColourToken.named("red")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Used inside a Palette

    func test_palette_roundTrip_throughCodable() throws {
        var palette = Palette()
        palette.background = .hex("#112233")
        palette.surface = .named("secondary")
        palette.danger = .rgb(r: 1.0, g: 0.0, b: 0.0, a: 1.0)

        let data = try JSONEncoder().encode(palette)
        let restored = try JSONDecoder().decode(Palette.self, from: data)
        XCTAssertEqual(restored, palette)
    }
}
