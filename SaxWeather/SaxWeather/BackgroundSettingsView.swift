
import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

// MARK: - Root view

struct BackgroundSettingsView: View {
    @EnvironmentObject var storeManager: StoreManager
    @StateObject private var registry = CustomisationRegistry.shared
    @State private var showingImagePicker = false
    @State private var showingAlert = false
    @State private var perConditionEditorTarget: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var pendingLockedProductID: String?

    private var knobs: Binding<KnobStorage> { registry.knobsBinding }

    var body: some View {
        NavigationStack {
            if storeManager.customBackgroundUnlocked {
                settingsForm
            } else {
                paywallForm
            }
        }
        .navigationTitle("Background")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(image: Binding(
                get: { nil },
                set: { newImage in
                    if let newImage = newImage { handleImagePicked(newImage) }
                }
            ), onImageSelected: { image in
                handleImagePicked(image)
            })
        }
        .sheet(item: Binding(
            get: { perConditionEditorTarget.map { PerConditionKey(value: $0) } },
            set: { perConditionEditorTarget = $0?.value }
        )) { key in
            PerConditionEditor(
                condition: key.value,
                spec: perConditionBinding(for: key.value)
            )
        }
        .alert("Purchase Error", isPresented: $showingAlert, presenting: storeManager.purchaseError) { _ in
            Button("OK") { }
        } message: { error in
            Text(error)
        }
        .onChange(of: storeManager.purchaseError) { error in
            showingAlert = error != nil
        }
        .sheet(item: Binding(
            get: { pendingLockedProductID.map { LockedProductID(value: $0) } },
            set: { pendingLockedProductID = $0?.value }
        )) { wrapper in
            CosmeticsStoreView(initialPendingProductID: wrapper.value)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Done") { dismiss() }
        }
    }

    // MARK: - Settings (unlocked)

    private var settingsForm: some View {
        Form {
            modeSection
            switch knobs.wrappedValue.background.mode {
            case .preset:
                presetSection
            case .customImage:
                customImageSection
            case .gradient:
                gradientSection
            case .dynamicAccent:
                dynamicAccentSection
            case .aurora:
                presetSection
            }
            perConditionSection
            overlaySection
            timeOfDaySection
        }
    }

    // MARK: - Per-condition binding helper

    private func perConditionBinding(for condition: String) -> Binding<PerConditionBackground> {
        Binding(
            get: { knobs.wrappedValue.background.perCondition[condition]
                   ?? PerConditionBackground() },
            set: { newValue in
                var knobsValue = knobs.wrappedValue
                knobsValue.background.perCondition[condition] = newValue
                knobs.wrappedValue = knobsValue
            }
        )
    }

    // MARK: - Mode section

    private var modeSection: some View {
        Section {
            ForEach(displayedBackgroundModes, id: \.self) { mode in
                BackgroundModeRow(
                    mode: mode,
                    isSelected: knobs.wrappedValue.background.mode == mode,
                    requiredProductID: mode.requiredProductID,
                    isOwned: { pid in storeManager.owns(pid) },
                    onTapOwned: {
                        registry.set(\.background.mode, mode)
                    },
                    onTapLocked: { productID in
                        pendingLockedProductID = productID
                    }
                )
            }
        } header: {
            Text("Background Mode")
        } footer: {
            Text(footerText(for: knobs.wrappedValue.background.mode))
        }
    }

    private var displayedBackgroundModes: [BackgroundMode] {
        BackgroundMode.allCases
    }

    private func footerText(for mode: BackgroundMode) -> String {
        switch mode {
        case .preset:
            return "Uses the shipped background images that match the current weather condition."
        case .customImage:
            return "Uses your own photo."
        case .gradient:
            return "A two-stop vertical gradient. Free to set up — no extra IAP beyond the one that unlocked this screen."
        case .dynamicAccent:
            return "Tints the shipped preset image with your accent colour. A fresh mood without new art."
        case .aurora:
            return "Aurora-themed background that automatically picks the right image for the current weather condition. Requires the Aurora Backgrounds cosmetic."
        }
    }

    // MARK: - Preset mode

    private var presetSection: some View {
        Section {
            Toggle("Use custom image if picked", isOn: knobs.background.useCustom)
        } header: {
            Text("Preset")
        } footer: {
            Text("Turn on to overlay a custom image on top of the preset when one is set.")
        }
    }

    // MARK: - Custom image mode

    private var customImageSection: some View {
        Section {
            customImagePicker
            Toggle("Use custom background", isOn: knobs.background.useCustom)
            if knobs.wrappedValue.background.customImageData != nil {
                Button("Reset to Default") {
                    registry.set(\.background.customImageData, nil as Data?)
                }
                .foregroundColor(.red)
            }
        } header: {
            Text("Custom Image")
        }
    }

    @ViewBuilder
    private var customImagePicker: some View {
        Button {
            showingImagePicker = true
        } label: {
            HStack {
                if let data = knobs.wrappedValue.background.customImageData {
                    #if os(iOS)
                    if let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    #elseif os(macOS)
                    if let image = NSImage(data: data) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    #endif
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "photo.fill")
                                .foregroundColor(.gray)
                        )
                }
                Text(knobs.wrappedValue.background.customImageData == nil
                     ? "Select Custom Background"
                     : "Change Custom Background")
                Spacer()
            }
        }
    }

    // MARK: - Gradient mode

    private var gradientSection: some View {
        Section {
            ColorPickerRow(label: "Top Color",
                           token: knobs.background.gradient.topColor)
            ColorPickerRow(label: "Bottom Color",
                           token: knobs.background.gradient.bottomColor)
            VStack(alignment: .leading) {
                Text("Top Opacity: \(knobs.wrappedValue.background.gradient.topOpacity, specifier: "%.2f")")
                Slider(value: knobs.background.gradient.topOpacity,
                       in: 0...1)
            }
            VStack(alignment: .leading) {
                Text("Bottom Opacity: \(knobs.wrappedValue.background.gradient.bottomOpacity, specifier: "%.2f")")
                Slider(value: knobs.background.gradient.bottomOpacity,
                       in: 0...1)
            }
        } header: {
            Text("Gradient")
        } footer: {
            Text("The gradient stretches from top to bottom of the screen on every condition.")
        }
    }

    // MARK: - Dynamic accent mode

    private var dynamicAccentSection: some View {
        Section {
            ColorPickerRow(label: "Tint",
                           token: knobs.background.dynamicTint)
        } header: {
            Text("Dynamic Accent")
        } footer: {
            Text("The shipped preset image is multiplied with this tint. Try warm tones at dusk.")
        }
    }

    // MARK: - Per-condition

    private var perConditionSection: some View {
        Section {
            ForEach(PerConditionBackgroundEditor.knownConditions, id: \.self) { condition in
                Button {
                    perConditionEditorTarget = condition
                } label: {
                    HStack {
                        Text(conditionLabel(condition))
                        Spacer()
                        if let entry = knobs.wrappedValue.background.perCondition[condition] {
                            if entry.imageData != nil {
                                Image(systemName: "photo")
                            } else if entry.gradientOverride != nil {
                                Image(systemName: "rectangle.gradient.horizontal")
                            } else {
                                Image(systemName: "circle.dotted")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Image(systemName: "circle.dotted")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Per-Condition Overrides")
        } footer: {
            Text("Override the mode for individual conditions. Empty entries fall through to the global mode.")
        }
    }

    private func conditionLabel(_ raw: String) -> String {
        raw.replacingOccurrences(of: "-", with: " ").capitalized
    }

    // MARK: - Overlay

    private var overlaySection: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Overlay Strength: \(knobs.wrappedValue.background.overlayOpacity, specifier: "%.2f")")
                Slider(value: knobs.background.overlayOpacity,
                       in: 0...0.7)
            }
        } header: {
            Text("Dark Overlay")
        } footer: {
            Text("Strength of the dark scrim on top of the background. Improves contrast for the text below.")
        }
    }

    // MARK: - Time of day

    private var timeOfDaySection: some View {
        Section {
            Picker("Rule", selection: knobs.background.timeOfDayRule) {
                Text("None").tag(TimeOfDayRule.none)
                Text("Dawn / Day / Dusk / Night").tag(TimeOfDayRule.dawnDayDuskNight)
                Text("Hour Range").tag(TimeOfDayRule.hourRange)
            }
        } header: {
            Text("Time of Day")
        } footer: {
            Text(timeOfDayFooterText(for: knobs.wrappedValue.background.timeOfDayRule))
        }
    }

    private func timeOfDayFooterText(for rule: TimeOfDayRule) -> String {
        switch rule {
        case .none:
            return "Always use the condition's preset image."
        case .dawnDayDuskNight:
            return "Dawn and dusk show a warm image; night shows a darker image. Requires sunrise/sunset data."
        case .hourRange:
            return "Reserved for a future 'switch at X o'clock' rule."
        }
    }

    // MARK: - Paywall (locked)

    private var paywallForm: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "wand.and.stars")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 72)
                        .foregroundColor(.accentColor)
                        .padding(.top, 12)
                    Text("Unlock Background Customisation")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                    Text("Change the background image, set a gradient, tint the preset, swap images by condition, switch by time of day, and tune the dark overlay.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Section {
                Button {
                    Task { await storeManager.purchaseCustomBackground() }
                } label: {
                    HStack {
                        if storeManager.purchaseInProgress {
                            ProgressView()
                                .padding(.trailing, 6)
                        }
                        Text(storeManager.purchaseInProgress
                             ? "Processing…"
                             : purchaseButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(storeManager.purchaseInProgress)
                Button("Restore Purchase") {
                    Task { await storeManager.restorePurchases() }
                }
            } footer: {
                Text("The free experience — the shipped preset image with the default dark overlay — is available to every user. Customisation is unlocked by a single in-app purchase.")
            }
        }
    }

    private var purchaseButtonTitle: String {
        if let product = storeManager.products.first {
            return "Unlock for \(product.displayPrice)"
        }
        return "Unlock Background Customisation"
    }

    // MARK: - Image handling

    private func handleImagePicked(_ image: PlatformImage) {
        let data: Data?
        #if os(iOS)
        data = image.jpegData(compressionQuality: 0.7)
        #elseif os(macOS)
        if let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff) {
            data = bitmap.representation(using: .jpeg, properties: [:])
        } else {
            data = nil
        }
        #endif
        guard let raw = data else { return }
        let capped = BackgroundImageReencoder.capAt200KB(raw)
        registry.set(\.background.customImageData, capped)
        registry.set(\.background.useCustom, true)
    }
}

// MARK: - Per-condition editor

struct PerConditionEditor: View {
    let condition: String
    @Binding var spec: PerConditionBackground
    @Environment(\.dismiss) private var dismiss
    @State private var showingImagePicker = false

    var body: some View {
        NavigationStack {
            Form {
                imageSection
                gradientSection
            }
            .navigationTitle(condition.replacingOccurrences(of: "-", with: " ").capitalized)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(image: Binding(
                    get: { nil },
                    set: { newImage in
                        guard let newImage = newImage else { return }
                        if let data = compressForStorage(newImage) {
                            spec.imageData = BackgroundImageReencoder.capAt200KB(data)
                        }
                    }
                ), onImageSelected: { _ in })
            }
        }
    }

    private var imageSection: some View {
        Section {
            Toggle("Custom image", isOn: Binding(
                get: { spec.imageData != nil },
                set: { newValue in
                    if !newValue { spec.imageData = nil }
                    else if spec.imageData == nil { showingImagePicker = true }
                }
            ))
            if let data = spec.imageData {
                #if os(iOS)
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                }
                #elseif os(macOS)
                if let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                }
                #endif
            }
        }
    }

    @ViewBuilder
    private var gradientSection: some View {
        if let grad = Binding($spec.gradientOverride) {
            Section {
                Toggle("Custom gradient", isOn: Binding(
                    get: { spec.gradientOverride != nil },
                    set: { newValue in
                        if newValue && spec.gradientOverride == nil {
                            spec.gradientOverride = GradientSpec()
                        } else if !newValue {
                            spec.gradientOverride = nil
                        }
                    }
                ))
                ColorPickerRow(label: "Top Color", token: grad.topColor)
                ColorPickerRow(label: "Bottom Color", token: grad.bottomColor)
                VStack(alignment: .leading) {
                    Text("Top Opacity: \(grad.topOpacity.wrappedValue, specifier: "%.2f")")
                    Slider(value: grad.topOpacity, in: 0...1)
                }
                VStack(alignment: .leading) {
                    Text("Bottom Opacity: \(grad.bottomOpacity.wrappedValue, specifier: "%.2f")")
                    Slider(value: grad.bottomOpacity, in: 0...1)
                }
            }
        } else {
            Section {
                Toggle("Custom gradient", isOn: Binding(
                    get: { false },
                    set: { newValue in
                        if newValue { spec.gradientOverride = GradientSpec() }
                    }
                ))
            }
        }
    }

    private func compressForStorage(_ image: PlatformImage) -> Data? {
        #if os(iOS)
        return image.jpegData(compressionQuality: 0.7)
        #elseif os(macOS)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [:])
        #endif
    }
}

extension PerConditionBackgroundEditor {
    static let knownConditions: [String] = [
        "sunny", "cloudy", "rainy", "snowy", "thunder",
        "foggy", "windy", "default"
    ]
}

enum PerConditionBackgroundEditor {}

// MARK: - Color picker row

struct ColorPickerRow: View {
    let label: LocalizedStringKey
    @Binding var token: ColourToken
    @State private var preset: NamedColourPreset = .blue
    @State private var customHex: String = ""

    enum NamedColourPreset: String, CaseIterable, Identifiable {
        case blue, purple, pink, red, orange, yellow,
             green, teal, cyan, indigo, mint, brown,
             system, primary, secondary, surface, black, white
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                Rectangle()
                    .fill(token.color)
                    .frame(width: 24, height: 24)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray))
            }
            Picker("Preset", selection: $preset) {
                ForEach(NamedColourPreset.allCases) { p in
                    Text(p.rawValue.capitalized).tag(p)
                }
            }
            .onChange(of: preset) { newValue in
                token = .named(newValue.rawValue)
            }
            HStack {
                Text("Hex")
                    .foregroundColor(.secondary)
                TextField("#RRGGBB", text: $customHex)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
                    .onSubmit { applyHex() }
                Button("Apply") { applyHex() }
                    .disabled(customHex.isEmpty)
            }
        }
    }

    private func applyHex() {
        let trimmed = customHex.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        token = .hex(trimmed.hasPrefix("#") ? trimmed : "#" + trimmed)
    }
}

// MARK: - Per-condition key (Identifiable wrapper)

private struct PerConditionKey: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - Platform image alias

#if os(iOS)
typealias PlatformImage = UIImage
#elseif os(macOS)
typealias PlatformImage = NSImage
#endif

// MARK: - Image size cap (plan §4.5 risk mitigation)

/// Re-encode a JPEG until it fits in `maxBytes`. Falls back to the
/// last attempt if the target can't be hit. Keeps the App Group
/// profile size in check even with very large user-supplied photos.
enum BackgroundImageReencoder {
    static let maxBytes: Int = 200 * 1024

    static func capAt200KB(_ data: Data) -> Data {
        guard data.count > maxBytes else { return data }
        #if os(iOS)
        guard let image = UIImage(data: data) else { return data }
        var quality: CGFloat = 0.7
        var attempt = image.jpegData(compressionQuality: quality)
        while let bytes = attempt, bytes.count > maxBytes, quality > 0.1 {
            quality -= 0.1
            attempt = image.jpegData(compressionQuality: quality)
        }
        return attempt ?? data
        #elseif os(macOS)
        guard let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return data }
        var quality: CGFloat = 0.7
        var attempt: Data? = bitmap.representation(
            using: .jpeg, properties: [.compressionFactor: quality])
        while let bytes = attempt, bytes.count > maxBytes, quality > 0.1 {
            quality -= 0.1
            attempt = bitmap.representation(
                using: .jpeg, properties: [.compressionFactor: quality])
        }
        return attempt ?? data
        #endif
    }
}

// MARK: - Previews

struct BackgroundSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundSettingsView()
            .environmentObject(StoreManager.shared)
    }
}

// MARK: - BackgroundModeRow (Phase 2 — per-row lock UI)

struct BackgroundModeRow: View {
    let mode: BackgroundMode
    let isSelected: Bool
    let requiredProductID: String?
    let isOwned: (String) -> Bool
    let onTapOwned: () -> Void
    let onTapLocked: (String) -> Void

    private var isLocked: Bool {
        guard let pid = requiredProductID else { return false }
        return !isOwned(pid)
    }

    var body: some View {
        Button {
            if isLocked, let pid = requiredProductID {
                onTapLocked(pid)
            } else {
                onTapOwned()
            }
        } label: {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(mode.displayName)
                            .font(.body)
                            .foregroundColor(.primary)
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .imageScale(.small)
                                .foregroundStyle(.orange)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(subtitle(for: mode, locked: isLocked))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mode.displayName)
        .accessibilityValue(isSelected ? "Selected" : (isLocked ? "Locked" : "Available"))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch mode {
        case .preset:
            swatch(colors: [.blue.opacity(0.4), .gray.opacity(0.6)])
        case .customImage:
            swatch(colors: [.green.opacity(0.4), .teal.opacity(0.6)], system: "photo.fill")
        case .gradient:
            swatch(colors: [.purple.opacity(0.4), .pink.opacity(0.6)])
        case .dynamicAccent:
            swatch(colors: [.orange.opacity(0.4), .yellow.opacity(0.6)])
        case .aurora:
            swatch(colors: [
                Color(red: 0.36, green: 0.75, blue: 0.74),
                Color(red: 0.04, green: 0.11, blue: 0.23)
            ])
        }
    }

    private func swatch(colors: [Color], system: String? = nil) -> some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if let system = system {
                Image(systemName: system)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
    }

    private func subtitle(for mode: BackgroundMode, locked: Bool) -> String {
        if locked, let pid = requiredProductID,
           let product = CosmeticCatalog.product(id: pid) {
            return String(
                format: "Tap to buy %@ — $%.2f",
                product.displayName,
                Double(product.priceCents) / 100.0
            )
        }
        switch mode {
        case .preset: return "Shipped backgrounds for each condition."
        case .customImage: return "Your own photo."
        case .gradient: return "Two-stop vertical gradient."
        case .dynamicAccent: return "Preset tinted by your accent colour."
        case .aurora: return "Aurora-themed backgrounds that auto-pick the right image for the current weather."
        }
    }
}

extension BackgroundMode {
    var displayName: String {
        switch self {
        case .preset:          return "Preset"
        case .customImage:     return "Custom Image"
        case .gradient:        return "Gradient"
        case .dynamicAccent:   return "Dynamic Accent"
        case .aurora:          return "Aurora Backgrounds"
        }
    }
}

/// Identifiable wrapper used to drive the locked-cosmetics
/// sheet off a `String?` (the product ID).
struct LockedProductID: Identifiable {
    let value: String
    var id: String { value }
}
