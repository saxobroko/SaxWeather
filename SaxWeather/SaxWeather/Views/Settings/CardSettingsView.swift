//
//  CardSettingsView.swift
//  SaxWeather
//
//  Live-preview submenu for the card theme. The example card
//  sits at the top of the screen and stays pinned while the
//  user scrolls the controls below it, so the live preview is
//  always visible.
//
//  Reached via Settings → Appearance → Card → Card Style…
//  (the row in `AppearanceSettingsView`), or by typing "card"
//  in the settings search bar.
//

import SwiftUI

struct CardSettingsView: View {
    @EnvironmentObject private var customisation: CustomisationRegistry

    /// Local working copy so the preview can show the result of
    /// an in-flight edit (e.g. a colour picker drag) before the
    /// user lets go. We commit to the registry on every `onChange`.
    @State private var workingVisual: VisualSpec

    init() {
        _workingVisual = State(initialValue: VisualSpec())
    }

    // Catalogue of border colour tokens the user can pick from.
    private let borderColorChoices: [(name: String, token: ColourToken)] = [
        ("System",        .named("system")),
        ("Accent",        .named("blue")),
        ("White",         .named("white")),
        ("Black",         .named("black")),
        ("Slate",         .named("gray")),
        ("Forest Green",  .named("green")),
        ("Sunset Orange", .named("orange")),
        ("Berry Red",     .named("red"))
    ]

    // Catalogue of tint washes. Empty string = no tint.
    private let tintChoices: [(name: String, token: ColourToken)] = [
        ("Off",        .named("")),
        ("Warm",       .named("orange")),
        ("Cool",       .named("blue")),
        ("Mint",       .named("green")),
        ("Lavender",   .named("purple")),
        ("Sand",       .named("yellow"))
    ]

    // Quick-pick fill colour presets. Empty = use the
    // palette's `surface` colour.
    private let fillPresets: [(name: String, token: ColourToken, swatch: Color)] = [
        ("Default (Palette)",  .named(""),                Color.gray.opacity(0.30)),
        ("Pure White",         .named("white"),           Color.white),
        ("Soft Cream",         .named("cream"),           Color(red: 0.98, green: 0.96, blue: 0.90)),
        ("Sky Blue",           .named("skyblue"),         Color(red: 0.62, green: 0.82, blue: 0.99)),
        ("Mint",               .named("mint"),            Color(red: 0.78, green: 0.95, blue: 0.85)),
        ("Sand",               .named("sand"),            Color(red: 0.96, green: 0.89, blue: 0.74)),
        ("Lavender",           .named("lavender"),        Color(red: 0.85, green: 0.80, blue: 0.96)),
        ("Coral",              .named("coral"),           Color(red: 1.00, green: 0.62, blue: 0.55)),
        ("Charcoal",           .named("charcoal"),        Color(red: 0.20, green: 0.20, blue: 0.22))
    ]

    var body: some View {
        // `safeAreaInset(edge: .top)` keeps the preview card
        // glued to the top of the screen while the controls
        // scroll under it. It also avoids the floating "black
        // box" issue a shadowed ZStack can produce on dark
        // mode — the form is just scrolled, the preview is
        // pinned by SwiftUI's safe-area machinery.
        settingsForm
            .safeAreaInset(edge: .top, spacing: 0) {
                previewHeader
            }
            .navigationTitle("Card Style")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                // Pull the latest values from the registry so
                // the preview starts in sync with whatever the
                // user has configured elsewhere.
                workingVisual = customisation.profile.knobs.visual
            }
    }

    // MARK: - Sticky preview

    private var previewHeader: some View {
        LivePreviewCard(visual: workingVisual)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(
                Rectangle()
                    .fill(.bar)
                    .ignoresSafeArea(edges: .top)
            )
    }

    // MARK: - Form

    private var settingsForm: some View {
        Form {
            // 1. Style picker
            Section {
                Picker("Style", selection: $workingVisual.cardStyle) {
                    ForEach(CardStyle.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: workingVisual.cardStyle) { newValue in
                    customisation.set(\.visual.cardStyle, newValue)
                }
                Button {
                    applyOriginalGlassPreset()
                } label: {
                    Label("Match Original Glass Look", systemImage: "wand.and.stars")
                }
                .tint(.accentColor)
            } header: {
                Label("Style", systemImage: "rectangle.stack.fill")
            } footer: {
                Text("Glass uses Apple’s translucent material. Solid is opaque. Outline is transparent with a border. Neumorphic adds a soft inner shadow.")
            }

            // 2. Shape
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Corner Radius")
                        Spacer()
                        Text("\(Int(workingVisual.cornerRadius)) pt")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $workingVisual.cornerRadius, in: 0...32, step: 1) {
                        Text("Corner Radius")
                    } onEditingChanged: { _ in
                        customisation.set(\.visual.cornerRadius, workingVisual.cornerRadius)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Padding (Horizontal)")
                        Spacer()
                        Text("\(Int(workingVisual.cardPaddingH)) pt")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $workingVisual.cardPaddingH, in: 0...32, step: 1) {
                        Text("Padding H")
                    } onEditingChanged: { _ in
                        customisation.set(\.visual.cardPaddingH, workingVisual.cardPaddingH)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Padding (Vertical)")
                        Spacer()
                        Text("\(Int(workingVisual.cardPaddingV)) pt")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $workingVisual.cardPaddingV, in: 0...40, step: 1) {
                        Text("Padding V")
                    } onEditingChanged: { _ in
                        customisation.set(\.visual.cardPaddingV, workingVisual.cardPaddingV)
                    }
                }
            } header: {
                Label("Shape", systemImage: "square.on.circle")
            } footer: {
                Text("Corner radius and inner padding. Original WeatherDetailsView used 24 pt radius, 16 pt horizontal padding, 20 pt vertical padding.")
            }

            // 3. Fill
            if workingVisual.cardStyle == .solid || workingVisual.cardStyle == .neumorphic {
                Section {
                    Picker("Preset", selection: fillPresetBinding) {
                        ForEach(fillPresets, id: \.name) { preset in
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(preset.swatch)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5)
                                    )
                                Text(preset.name)
                            }
                            .tag(preset.token.rawString)
                        }
                    }
                    // Free-form colour picker, only shown when
                    // the user has picked one of the named
                    // presets (or typed a hex). Disabled for the
                    // "Default (Palette)" choice because that
                    // already drives the fill from the
                    // palette tokens.
                    if !workingVisual.cardFillColor.isEmpty {
                        ColorPicker(
                            "Custom Fill",
                            selection: customFillColorBinding,
                            supportsOpacity: false
                        )
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Fill Opacity")
                            Spacer()
                            Text("\(Int(workingVisual.cardOpacity * 100))%")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $workingVisual.cardOpacity, in: 0.3...1.0, step: 0.05) {
                            Text("Fill Opacity")
                        } onEditingChanged: { _ in
                            customisation.set(\.visual.cardOpacity, workingVisual.cardOpacity)
                        }
                    }
                } header: {
                    Label("Fill", systemImage: "paintbrush.fill")
                } footer: {
                    Text("Choose a preset for a quick look, or pick a custom colour. Empty (\"Default\") means the card uses your palette surface colour.")
                }
            }

            // 4. Glass controls
            if workingVisual.cardStyle == .glass {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Blur Intensity")
                            Spacer()
                            Text("\(Int(workingVisual.cardBlurIntensity * 100))%")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $workingVisual.cardBlurIntensity, in: 0.0...1.0, step: 0.05) {
                            Text("Blur")
                        } onEditingChanged: { _ in
                            customisation.set(\.visual.cardBlurIntensity, workingVisual.cardBlurIntensity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Edge Highlight")
                            Spacer()
                            Text("\(Int(workingVisual.cardHighlightIntensity * 100))%")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $workingVisual.cardHighlightIntensity, in: 0.0...0.6, step: 0.05) {
                            Text("Highlight")
                        } onEditingChanged: { _ in
                            customisation.set(\.visual.cardHighlightIntensity, workingVisual.cardHighlightIntensity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Material Opacity")
                            Spacer()
                            Text("\(Int(workingVisual.cardGlassOpacity * 100))%")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $workingVisual.cardGlassOpacity, in: 0.2...1.0, step: 0.05) {
                            Text("Material Opacity")
                        } onEditingChanged: { _ in
                            customisation.set(\.visual.cardGlassOpacity, workingVisual.cardGlassOpacity)
                        }
                    }
                } header: {
                    Label("Glass", systemImage: "sparkles")
                } footer: {
                    Text("Blur picks between ultra-thin, thin, and regular materials. Material Opacity controls how much the background shows through (60% matches the original look). Edge highlight draws a soft light sweep across the card.")
                }
            }

            // 5. Neumorphic controls
            if workingVisual.cardStyle == .neumorphic {
                Section {
                    Toggle("Inner shadow", isOn: $workingVisual.cardNeumorphicInset)
                        .onChange(of: workingVisual.cardNeumorphicInset) { newValue in
                            customisation.set(\.visual.cardNeumorphicInset, newValue)
                        }
                } header: {
                    Label("Neumorphic", systemImage: "circle.lefthalf.filled")
                }
            }

            // 6. Border
            Section {
                Picker("Colour", selection: borderColorBinding) {
                    ForEach(borderColorChoices, id: \.name) { choice in
                        HStack {
                            Circle()
                                .fill(choice.token.color)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
                            Text(choice.name)
                        }
                        .tag(choice.token.rawString)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Width")
                        Spacer()
                        Text("\(workingVisual.cardBorderWidth, specifier: "%.1f") pt")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $workingVisual.cardBorderWidth, in: 0...4, step: 0.5) {
                        Text("Width")
                    } onEditingChanged: { _ in
                        customisation.set(\.visual.cardBorderWidth, workingVisual.cardBorderWidth)
                    }
                }
            } header: {
                Label("Border", systemImage: "scribble.variable")
            } footer: {
                Text("Width 0 removes the border entirely. Outline style uses a 45%-opacity stroke; other styles use 20%.")
            }

            // 6b. Border Gradient
            // Independent of the solid border colour. The
            // original WeatherDetailsView used a white-to-white
            // gradient border; this control lets the user pick
            // any two colours and an opacity.
            Section {
                Picker("Start", selection: borderGradientStartBinding) {
                    ForEach(borderColorChoices, id: \.name) { choice in
                        HStack {
                            Circle()
                                .fill(choice.token.color)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
                            Text(choice.name)
                        }
                        .tag(choice.token.rawString)
                    }
                }
                Picker("End", selection: borderGradientEndBinding) {
                    ForEach(borderColorChoices, id: \.name) { choice in
                        HStack {
                            Circle()
                                .fill(choice.token.color)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
                            Text(choice.name)
                        }
                        .tag(choice.token.rawString)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Strength")
                        Spacer()
                        Text("\(Int(workingVisual.cardBorderGradientOpacity * 100))%")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $workingVisual.cardBorderGradientOpacity, in: 0...1, step: 0.05) {
                        Text("Strength")
                    } onEditingChanged: { _ in
                        customisation.set(\.visual.cardBorderGradientOpacity, workingVisual.cardBorderGradientOpacity)
                    }
                }
            } header: {
                Label("Border Gradient", systemImage: "paintpalette")
            } footer: {
                Text("Overrides the solid border with a top-leading → bottom-trailing gradient. Leave both colours on “System” to fall back to the solid border.")
            }

            // 7. Tint wash
            Section {
                Picker("Tint", selection: tintBinding) {
                    ForEach(tintChoices, id: \.name) { choice in
                        HStack {
                            if choice.token.isEmpty {
                                Image(systemName: "circle.slash")
                                    .foregroundStyle(.secondary)
                            } else {
                                Circle()
                                    .fill(choice.token.color)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
                            }
                            Text(choice.name)
                        }
                        .tag(choice.token.rawString)
                    }
                }
                Picker("Overlay", selection: tintOverlayBinding) {
                    ForEach(tintChoices, id: \.name) { choice in
                        HStack {
                            if choice.token.isEmpty {
                                Image(systemName: "circle.slash")
                                    .foregroundStyle(.secondary)
                            } else {
                                Circle()
                                    .fill(choice.token.color)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
                            }
                            Text(choice.name)
                        }
                        .tag(choice.token.rawString)
                    }
                }
                if !workingVisual.cardTintOverlay.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Overlay Strength")
                            Spacer()
                            Text("\(Int(workingVisual.cardTintOverlayOpacity * 100))%")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $workingVisual.cardTintOverlayOpacity, in: 0...0.6, step: 0.02) {
                            Text("Overlay Strength")
                        } onEditingChanged: { _ in
                            customisation.set(\.visual.cardTintOverlayOpacity, workingVisual.cardTintOverlayOpacity)
                        }
                    }
                }
            } header: {
                Label("Tint", systemImage: "drop.fill")
            } footer: {
                Text("Tint lays a soft wash over the card. Overlay layers a warm/cool gradient on top of everything. Original look used a dark wash at 20%.")
            }

            // 8. Shadow
            Section {
                Toggle("Shadow", isOn: shadowEnabledBinding)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Opacity")
                        Spacer()
                        Text("\(Int(workingVisual.cardShadowOpacity * 100))%")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $workingVisual.cardShadowOpacity, in: 0...0.4, step: 0.02) {
                        Text("Opacity")
                    } onEditingChanged: { _ in
                        customisation.set(\.visual.cardShadowOpacity, workingVisual.cardShadowOpacity)
                    }
                    .disabled(workingVisual.cardShadowOpacity == 0 && !isShadowOn)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Radius")
                        Spacer()
                        Text("\(Int(workingVisual.cardShadowRadius)) pt")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $workingVisual.cardShadowRadius, in: 0...32, step: 1) {
                        Text("Radius")
                    } onEditingChanged: { _ in
                        customisation.set(\.visual.cardShadowRadius, workingVisual.cardShadowRadius)
                    }
                }
                HStack {
                    Text("Offset X")
                    Spacer()
                    Text("\(Int(workingVisual.cardShadowX)) pt")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $workingVisual.cardShadowX, in: -16...16, step: 1) {
                    Text("X")
                } onEditingChanged: { _ in
                    customisation.set(\.visual.cardShadowX, workingVisual.cardShadowX)
                }
                HStack {
                    Text("Offset Y")
                    Spacer()
                    Text("\(Int(workingVisual.cardShadowY)) pt")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $workingVisual.cardShadowY, in: -16...16, step: 1) {
                    Text("Y")
                } onEditingChanged: { _ in
                    customisation.set(\.visual.cardShadowY, workingVisual.cardShadowY)
                }
            } header: {
                Label("Shadow", systemImage: "shadow")
            }

            // 9. Reset
            Section {
                Button(role: .destructive) {
                    resetToDefaults()
                } label: {
                    Label("Reset Card to Defaults", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    // MARK: - Bindings

    /// Bridge the picker-selected raw String to the
    /// `ColourToken` stored in `workingVisual`.
    private var borderColorBinding: Binding<String> {
        Binding(
            get: { workingVisual.cardBorderColor.rawString },
            set: { newValue in
                workingVisual.cardBorderColor = ColourToken(rawString: newValue)
                customisation.set(\.visual.cardBorderColor, ColourToken(rawString: newValue))
            }
        )
    }

    /// Border gradient start colour.
    private var borderGradientStartBinding: Binding<String> {
        Binding(
            get: { workingVisual.cardBorderGradientStart.rawString },
            set: { newValue in
                let token = ColourToken(rawString: newValue)
                workingVisual.cardBorderGradientStart = token
                customisation.set(\.visual.cardBorderGradientStart, token)
            }
        )
    }

    /// Border gradient end colour.
    private var borderGradientEndBinding: Binding<String> {
        Binding(
            get: { workingVisual.cardBorderGradientEnd.rawString },
            set: { newValue in
                let token = ColourToken(rawString: newValue)
                workingVisual.cardBorderGradientEnd = token
                customisation.set(\.visual.cardBorderGradientEnd, token)
            }
        )
    }

    /// Quick-pick fill colour. Empty string ("") = use the
    /// palette surface colour.
    private var fillPresetBinding: Binding<String> {
        Binding(
            get: { workingVisual.cardFillColor.rawString },
            set: { newValue in
                let token = ColourToken(rawString: newValue)
                workingVisual.cardFillColor = token
                customisation.set(\.visual.cardFillColor, token)
            }
        )
    }

    private var customFillColorBinding: Binding<Color> {
        Binding(
            get: {
                workingVisual.cardFillColor.color
            },
            set: { newColor in
                let token = nearestFillToken(for: newColor)
                workingVisual.cardFillColor = token
                customisation.set(\.visual.cardFillColor, token)
            }
        )
    }

    private func nearestFillToken(for color: Color) -> ColourToken {
        let components = rgbComponents(of: color)
        let r = components.r
        let g = components.g
        let b = components.b
        var bestToken: ColourToken = .named("")
        var bestDistance: Double = .greatestFiniteMagnitude
        for preset in fillPresets where !preset.token.isEmpty {
            let presetComponents = rgbComponents(of: preset.token.color)
            let dr = presetComponents.r - r
            let dg = presetComponents.g - g
            let db = presetComponents.b - b
            let distance = dr * dr + dg * dg + db * db
            if distance < bestDistance {
                bestDistance = distance
                bestToken = preset.token
            }
        }
        // If the closest preset is "close enough" (< 0.02
        // squared error ≈ 0.14 RMSE per channel), use it.
        if bestDistance < 0.02 {
            return bestToken
        }
        // Otherwise encode the raw colour as a hex string. We
        // use the leading `#rrggbb` format that the rest of the
        // ColourToken parser already understands.
        let rInt = max(0, min(255, Int(round(r * 255))))
        let gInt = max(0, min(255, Int(round(g * 255))))
        let bInt = max(0, min(255, Int(round(b * 255))))
        return .hex(String(format: "#%02X%02X%02X", rInt, gInt, bInt))
    }

    private func rgbComponents(of color: Color) -> (r: Double, g: Double, b: Double) {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        // `.getRed(_:green:blue:alpha:)` is documented as
        // "may return false if the colour is not expressible in
        // the sRGB colour space", but in practice every colour
        // the user can pick from `ColorPicker` is sRGB so the
        // conversion succeeds.
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
        #else
        let ns = NSColor(color)
        let rgb = ns.usingColorSpace(.sRGB) ?? ns
        return (Double(rgb.redComponent),
                Double(rgb.greenComponent),
                Double(rgb.blueComponent))
        #endif
    }

    private var tintBinding: Binding<String> {
        Binding(
            get: { workingVisual.cardTint.rawString },
            set: { newValue in
                workingVisual.cardTint = ColourToken(rawString: newValue)
                customisation.set(\.visual.cardTint, ColourToken(rawString: newValue))
            }
        )
    }

    private var tintOverlayBinding: Binding<String> {
        Binding(
            get: { workingVisual.cardTintOverlay.rawString },
            set: { newValue in
                workingVisual.cardTintOverlay = ColourToken(rawString: newValue)
                customisation.set(\.visual.cardTintOverlay, ColourToken(rawString: newValue))
            }
        )
    }

    /// The "Shadow" toggle proxies the opacity. `opacity == 0`
    /// is treated as off; we restore the previous value when the
    /// user turns it back on.
    @State private var rememberedShadowOpacity: Double = 0.10
    private var isShadowOn: Bool { workingVisual.cardShadowOpacity > 0.001 }

    private var shadowEnabledBinding: Binding<Bool> {
        Binding(
            get: { isShadowOn },
            set: { newValue in
                if newValue {
                    let restored = rememberedShadowOpacity > 0.001
                        ? rememberedShadowOpacity
                        : 0.10
                    workingVisual.cardShadowOpacity = restored
                    customisation.set(\.visual.cardShadowOpacity, restored)
                } else {
                    rememberedShadowOpacity = workingVisual.cardShadowOpacity
                    workingVisual.cardShadowOpacity = 0
                    customisation.set(\.visual.cardShadowOpacity, 0)
                }
            }
        )
    }

    // MARK: - Preset

    private func applyOriginalGlassPreset() {
        var preset = workingVisual
        preset.cardStyle = .glass
        preset.cornerRadius = 24
        preset.cardBlurIntensity = 0.34        // `ultraThinMaterial`
        preset.cardGlassOpacity = 0.6          // matches the
                                                // original
                                                // `.ultraThinMaterial.opacity(0.6)`
        preset.cardTintOverlay = .named("black") // dark wash in dark mode
        preset.cardTintOverlayOpacity = 0.20
        preset.cardBorderGradientStart = .named("white")
        preset.cardBorderGradientEnd = .named("white")
        preset.cardBorderGradientOpacity = 0.20
        preset.cardBorderWidth = 1
        preset.cardShadowOpacity = 0.12
        preset.cardShadowRadius = 20
        preset.cardShadowX = 0
        preset.cardShadowY = 10
        preset.cardPaddingH = 16
        preset.cardPaddingV = 20
        workingVisual = preset
        applyVisual(preset)
    }

    private func applyVisual(_ v: VisualSpec) {
        // Push every value from `v` to the registry so the live
        // preview, the home screen, the forecast, the alerts
        // list, and the widget all update in lockstep.
        customisation.set(\.visual.cardStyle, v.cardStyle)
        customisation.set(\.visual.cornerRadius, v.cornerRadius)
        customisation.set(\.visual.cardBlurIntensity, v.cardBlurIntensity)
        customisation.set(\.visual.cardGlassOpacity, v.cardGlassOpacity)
        customisation.set(\.visual.cardTintOverlay, v.cardTintOverlay)
        customisation.set(\.visual.cardTintOverlayOpacity, v.cardTintOverlayOpacity)
        customisation.set(\.visual.cardBorderGradientStart, v.cardBorderGradientStart)
        customisation.set(\.visual.cardBorderGradientEnd, v.cardBorderGradientEnd)
        customisation.set(\.visual.cardBorderGradientOpacity, v.cardBorderGradientOpacity)
        customisation.set(\.visual.cardBorderWidth, v.cardBorderWidth)
        customisation.set(\.visual.cardShadowOpacity, v.cardShadowOpacity)
        customisation.set(\.visual.cardShadowRadius, v.cardShadowRadius)
        customisation.set(\.visual.cardShadowX, v.cardShadowX)
        customisation.set(\.visual.cardShadowY, v.cardShadowY)
        customisation.set(\.visual.cardPaddingH, v.cardPaddingH)
        customisation.set(\.visual.cardPaddingV, v.cardPaddingV)
    }

    // MARK: - Reset

    private func resetToDefaults() {
        let defaults = VisualSpec()
        workingVisual = defaults
        customisation.set(\.visual.cardStyle, defaults.cardStyle)
        customisation.set(\.visual.cornerRadius, defaults.cornerRadius)
        customisation.set(\.visual.cardOpacity, defaults.cardOpacity)
        customisation.set(\.visual.cardFillColor, defaults.cardFillColor)
        customisation.set(\.visual.cardBorderColor, defaults.cardBorderColor)
        customisation.set(\.visual.cardBorderWidth, defaults.cardBorderWidth)
        customisation.set(\.visual.cardShadowOpacity, defaults.cardShadowOpacity)
        customisation.set(\.visual.cardShadowRadius, defaults.cardShadowRadius)
        customisation.set(\.visual.cardShadowX, defaults.cardShadowX)
        customisation.set(\.visual.cardShadowY, defaults.cardShadowY)
        customisation.set(\.visual.cardBlurIntensity, defaults.cardBlurIntensity)
        customisation.set(\.visual.cardGlassOpacity, defaults.cardGlassOpacity)
        customisation.set(\.visual.cardHighlightIntensity, defaults.cardHighlightIntensity)
        customisation.set(\.visual.cardTint, defaults.cardTint)
        customisation.set(\.visual.cardTintOverlay, defaults.cardTintOverlay)
        customisation.set(\.visual.cardTintOverlayOpacity, defaults.cardTintOverlayOpacity)
        customisation.set(\.visual.cardBorderGradientStart, defaults.cardBorderGradientStart)
        customisation.set(\.visual.cardBorderGradientEnd, defaults.cardBorderGradientEnd)
        customisation.set(\.visual.cardBorderGradientOpacity, defaults.cardBorderGradientOpacity)
        customisation.set(\.visual.cardNeumorphicInset, defaults.cardNeumorphicInset)
        customisation.set(\.visual.cardPaddingH, defaults.cardPaddingH)
        customisation.set(\.visual.cardPaddingV, defaults.cardPaddingV)
    }
}

// MARK: - Live preview card

private struct LivePreviewCard: View {
    let visual: VisualSpec

    var body: some View {
        HStack(spacing: 20) {
            // Left: weather glyph + temperatures, like the
            // existing `ForecastDayCard` in `ForecastView`.
            HStack(spacing: 12) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text("22°")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("14°")
                        .font(.system(size: 17, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            // Right: key weather data columns, matching the
            // `WeatherDataColumn` layout used by the daily
            // forecast cards.
            HStack(spacing: 16) {
                weatherDataColumn(icon: "💧", label: "Hum", value: "62%")
                weatherDataColumn(icon: "🌧️", label: "Rain", value: "20%")
                weatherDataColumn(icon: "💨", label: "Wind", value: "12")
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .themedCard(visual)
    }

    private func weatherDataColumn(icon: String, label: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 4) {
            Text(icon).font(.system(size: 18))
            Text(label)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
}

// MARK: - CardStyle display names

extension CardStyle {
    var displayName: String {
        switch self {
        case .glass:       return "Glass"
        case .solid:       return "Solid"
        case .outline:     return "Outline"
        case .neumorphic:  return "Neumorphic"
        }
    }
}
