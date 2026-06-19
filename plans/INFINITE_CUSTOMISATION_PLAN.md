# SaxWeather — "Infinitely Customisable" Architecture Plan

> **Status:** Draft v1 — for review and execution in code mode
> **Author target:** Architect / single-developer SwiftUI on iOS/macOS
> **Premise:** Build on top of the existing app, do not rewrite it. Every existing `@AppStorage` key, view modifier, and surface is an opportunity for leverage, not a target for replacement.

---

## 0. Why this plan exists (and what "infinite" really means)

SaxWeather already exposes dozens of customisation knobs through scattered `@AppStorage` keys (`accentColor`, `unitSystem`, `forecastDays`, `displayMode`, `useCustomBackground`, `customTextSizeMultiplier`, `reduceMotion`, `disableWeatherAnimations`, `increaseContrast`, `boldText`, `enhancedVoiceOverLabels`, `speakWeatherAlerts`, `enableHapticFeedback`, …) plus per-screen user actions (image picker for backgrounds, accent picker, text-size slider, motion toggles, etc.).

What it does **not** have:

1. A single, declarative, **versioned** model that captures *all* of those knobs at once.
2. A way to **export / import / share** a complete customisation set (a "theme").
3. A way to **reorder or hide** home-screen sections without rebuilding the view.
4. A way for the **widget** to honour per-widget variants (compact vs. rich, alternate colour, alternate icon set).
5. A way to **hot-reload** customisations during development.
6. A **typed registry** that gives the Settings UI a uniform way to enumerate, group, search and reset every knob.

"Infinite" here does not mean literally unbounded — it means *bounded by a schema, extensible by users, not by code changes*. Adding a knob = registering it in one place; removing or renaming a knob = bumping a schema version and the engine migrates old profiles.

### The leverage map (where we already do this work)

| Existing asset | File | How we leverage it |
|---|---|---|
| Accent picker | [`AccentColorHelper.swift`](SaxWeather/SaxWeather/AccentColorHelper.swift:11) | Replace hardcoded 10-color enum with a `CustomColour` token that defaults to the existing palette but also accepts RGB/hex. |
| Background settings | [`BackgroundSettingsView.swift`](SaxWeather/SaxWeather/BackgroundSettingsView.swift:146) + [`BackgroundView.swift`](SaxWeather/SaxWeather/BackgroundView.swift:16) | Add per-condition photos, gradient stacks, and "by-time-of-day" rules. |
| Lottie animation helper | [`WeatherAnimationHelper.swift`](SaxWeather/SaxWeather/WeatherAnimationHelper.swift:11) | Insert a registry hook so the lookup is overridable from a `CustomisationProfile`. |
| LottieView motion gate | [`LottieView.swift`](SaxWeather/SaxWeather/LottieView.swift:31) | Already reads `disableWeatherAnimations` + `reduceMotion` — drive it from the registry. |
| Text-size / contrast / motion modifiers | [`AccessibilityModifiers.swift`](SaxWeather/SaxWeather/AccessibilityModifiers.swift:11) | All use `@AppStorage` — same pattern, just bound through the registry. |
| Display mode switch | [`ContentView.swift:266`](SaxWeather/SaxWeather/ContentView.swift:266) (`displayMode == "Detailed"`) | Promote `"Summary"` / `"Detailed"` to an enum so we can extend with `Compact`, `PowerUser`, etc. |
| Forecast day count | [`SettingsView.swift:65`](SaxWeather/SaxWeather/SettingsView.swift:65) (3/5/7/10/14) | Keep the option set; lift into the registry as `forecastDayWindow`. |
| Forecast section order | [`DetailedWeatherView.swift:11`](SaxWeather/SaxWeather/DetailedWeatherView.swift:11) | Sections are hardcoded — wrap them in a registry-driven `ForEach`. |
| Unit labels | [`ContentView.swift:564`](SaxWeather/SaxWeather/ContentView.swift:564), [`ForecastView.swift:533`](SaxWeather/SaxWeather/ForecastView.swift:533), [`HourlyForecastView.swift:269`](SaxWeather/SaxWeather/HourlyForecastView.swift:269), [`DetailedForecastSheet.swift:131`](SaxWeather/SaxWeather/DetailedForecastSheet.swift:131) | Already tri-state (Metric/Imperial/UK) after [`plans/UNIT_CONVERSION_FIX_PLAN.md`](plans/UNIT_CONVERSION_FIX_PLAN.md) — funnel through one source. |
| Widget host→widget sync | [`WidgetSyncService.swift`](SaxWeather/SaxWeather/WidgetSyncService.swift:42) + [`WidgetSharedConfig.swift`](SaxWeather/SaxWeatherWidget/WidgetSharedConfig.swift:18) | Extend `Keys` with a `currentProfileID` + `cachedProfileHash` so the widget can subscribe to a theme without re-encoding the whole payload. |
| Lottie debug | [`LottieDebugView.swift`](SaxWeather/SaxWeather/LottieDebugView.swift:390) | Add a "Theme Editor" debug card that exposes hot-reload. |
| Onboarding | [`OnboardingView.swift`](SaxWeather/SaxWeather/OnboardingView.swift:33) | Add a "Pick a starting vibe" step before the Ready page (see [`plans/onboarding_overhaul_plan.md`](plans/onboarding_overhaul_plan.md) — already has a CustomizationStep at index 6). |
| Saved locations | [`SavedLocation.swift`](SaxWeather/SaxWeather/SavedLocation.swift) + [`SavedLocationsManager.swift`](SaxWeather/SaxWeather/SavedLocationsManager.swift:5) | Each saved location can carry an **override profile** (e.g. "make Melbourne a dark style, Melbourne-Office the bright one"). |
| Lottie animation assets | [`Lottie Animations/`](SaxWeather/SaxWeather/Lottie%20Animations/) (10 files) + [`Assets.xcassets/weather_background_*.imageset`](SaxWeather/SaxWeather/Assets.xcassets/) (8 imagesets) | Stable, named; the registry can override the mapping table without changing assets. |

---

## 1. Customisation Dimensions Inventory

The full surface we want every user (and our own debug menu) to be able to tweak. Each row is one **knob** the registry knows about. Grouped by category.

### 1.1 Visual — Colours & Typography

| ID | Knob | Type | Default | Where it currently lives |
|---|---|---|---|---|
| `accentColor` | Accent colour | `ColourToken` (named + RGB fallback) | `.blue` | [`AccentColorHelper.swift:13`](SaxWeather/SaxWeather/AccentColorHelper.swift:13) — extend |
| `palette` | Full palette (bg/surface/text/muted/danger) | `Palette` struct of 5 `ColourToken`s | System semantic colours | **new** |
| `cardStyle` | Card material | `enum: .glass, .solid, .outline, .neumorphic` | `.glass` on iOS 26+, `.solid` otherwise | implicit via `if #available(iOS 26.2, *)` in [`DetailedWeatherView.swift:196`](SaxWeather/SaxWeather/DetailedWeatherView.swift:196) |
| `cornerRadius` | Card corner radius | `Double` (0…28) | 16 | hardcoded `RoundedRectangle(cornerRadius: 16)` scattered |
| `fontScale` | Global text scale | `Double` (0.75…1.5) | 1.0 | [`AccessibilitySettingsView.swift:106`](SaxWeather/SaxWeather/AccessibilitySettingsView.swift:106) |
| `boldText` | Force-bold body text | `Bool` | `false` | [`AccessibilitySettingsView.swift:169`](SaxWeather/SaxWeather/AccessibilitySettingsView.swift:169) |
| `useSystemTextSize` | Respect Dynamic Type | `Bool` | `true` | [`AccessibilitySettingsView.swift:84`](SaxWeather/SaxWeather/AccessibilitySettingsView.swift:84) |
| `typography` | Font family override (rounded/serif/mono) | `enum: .system, .rounded, .serif, .mono` | `.system` | hardcoded `.system(...design: .rounded)` in [`ContentView.swift:394`](SaxWeather/SaxWeather/ContentView.swift:394) |
| `increaseContrast` | High-contrast outline on text | `Bool` | `false` | [`AccessibilitySettingsView.swift:154`](SaxWeather/SaxWeather/AccessibilitySettingsView.swift:154) |
| `colorScheme` | App-wide scheme | `enum: .system, .light, .dark` | `.system` | [`SettingsView.swift:64`](SaxWeather/SaxWeather/SettingsView.swift:64) |
| `cardOpacity` | Card translucency | `Double` (0.4…1.0) | 0.6 | implicit via `.opacity(0.6)` |

### 1.2 Visual — Background

| ID | Knob | Type | Default |
|---|---|---|---|
| `backgroundMode` | Background strategy | `enum: .preset, .customImage, .gradient, .dynamicAccent` | `.preset` |
| `backgroundUseCustom` | Toggle custom image | `Bool` | `true` |
| `customBackgroundData` | Image data (JPEG) | `Data?` | `nil` |
| `backgroundGradient` | Top + bottom colours for `.gradient` | `GradientStop` tuple | accent → bg |
| `backgroundDynamicTint` | Tint of `.dynamicAccent` backgrounds | `ColourToken` | accent |
| `backgroundPerCondition` | Per-condition overrides | `[String: BackgroundSpec]` | empty (uses shipped imagesets) |
| `backgroundTimeOfDayRule` | Switch background by time | `enum: .none, .dawnDayDuskNight, .hourRange` | `.none` |
| `backgroundOverlayOpacity` | Dark overlay strength | `Double` (0…0.7) | 0.28 (matches [`ContentView.swift:263`](SaxWeather/SaxWeather/ContentView.swift:263)) |

### 1.3 Visual — Iconography & Animations

| ID | Knob | Type | Default |
|---|---|---|---|
| `lottieAnimationSet` | Which animation set to use | `enum: .bundled, .bundledStatic, .custom` | `.bundled` |
| `lottieOverrideMap` | Per-condition → custom JSON filename | `[String: String]` | `{}` |
| `lottiePlaybackSpeed` | Speed multiplier | `Double` (0.25…2.0) | 1.0 |
| `lottieLoopMode` | Loop / play once | `enum: .loop, .playOnce` | `.loop` |
| `disableWeatherAnimations` | Force static icons | `Bool` | `false` |
| `weatherIconStyle` | Icon style | `enum: .multicolor, .monochrome, .outline` | `.multicolor` |
| `symbolSet` | SF Symbol variant override | `enum: .automatic, .filled, .outline` | `.filled` |

### 1.4 Visual — Layout & Density

| ID | Knob | Type | Default |
|---|---|---|---|
| `displayMode` | Home layout | `enum: .summary, .detailed, .compact, .power` | `.summary` |
| `homeSectionOrder` | Section IDs in user-chosen order | `[HomeSectionID]` | `[.hero, .current, .hourly, .daily, .details, .extended]` |
| `hiddenHomeSections` | Sections to hide | `Set<HomeSectionID>` | `[]` |
| `forecastDays` | Forecast window | `Int` (3/5/7/10/14) | 7 |
| `hourlyHours` | Hourly window | `Int` (12/24/48) | 24 |
| `cardDensity` | Spacing | `enum: .compact, .regular, .relaxed` | `.regular` |
| `showHamburgerMenu` | Show the floating location button | `Bool` | `true` |

### 1.5 Data — Units, Precision, Sources

| ID | Knob | Type | Default |
|---|---|---|---|
| `unitSystem` | Unit set | `enum: .metric, .imperial, .uk` | `.metric` |
| `temperaturePrecision` | Decimal places | `Int` (0…2) | 1 |
| `windPrecision` | Decimal places | `Int` (0…1) | 0 |
| `pressurePrecision` | Decimal places | `Int` (0…2) | 0 |
| `preferredDataSource` | Preferred primary source | `enum: .auto, .weatherKit, .openMeteo, .weatherUnderground, .openWeatherMap` | `.auto` |
| `useOpenMeteoAsDefault` | Use Open-Meteo as the default | `Bool` | `false` |
| `disableAPIKeys` | Don't use any keyed provider | `Bool` | `false` |
| `stationID` / `wuApiKey` / `owmApiKey` | Existing credentials | `String` | n/a — handled separately, **not** in theme |
| `refreshCadence` | Pull-to-refresh throttle | `enum: .aggressive, .normal, .batterySaver` | `.normal` |
| `backgroundRefreshEnabled` | Background refresh on/off | `Bool` | `true` |

### 1.6 Data — Displayed Fields

| ID | Knob | Type | Default |
|---|---|---|---|
| `visibleMetrics` | Which cards on the detail screen | `Set<MetricID>` | all |
| `hourlyMetrics` | What to show in hourly items | `Set<HourlyMetricID>` | `{temp, precip, wind}` |
| `extendedCardsEnabled` | AQI / UV / Pollen / Sun-Moon cards | `Set<ExtendedCardID>` | `{aqi, uv, sun}` |
| `showLocationLabel` | Always show "Weather for X" | `Bool` | `true` |

### 1.7 Behaviour — Interactions

| ID | Knob | Type | Default |
|---|---|---|---|
| `enableHapticFeedback` | Toggle haptics | `Bool` | `true` |
| `hapticIntensity` | Strength | `enum: .light, .medium, .heavy` | `.medium` |
| `pullToRefresh` | Allow pull-to-refresh | `Bool` | `true` (iOS limitation note already in [`AccessibilitySettingsView.swift:218`](SaxWeather/SaxWeather/AccessibilitySettingsView.swift:218)) |
| `tapDayToExpand` | Tap a daily card → detailed sheet | `Bool` | `true` |
| `longPressToCustomise` | Long-press any section → "Customise" | `Bool` | `true` |
| `confirmDestructive` | Confirm before resetting a profile | `Bool` | `true` |

### 1.8 Behaviour — Sound & Notifications

| ID | Knob | Type | Default |
|---|---|---|---|
| `weatherAlertSounds` | Play sound for severe alerts | `Bool` | `true` |
| `speakWeatherAlerts` | VoiceOver auto-speak alerts | `Bool` | `true` |
| `quietHours` | Mute alerts during range | `TimeRange?` | `nil` |
| `refreshSound` | Tick when refresh completes | `Bool` | `false` |

### 1.9 Accessibility

| ID | Knob | Type | Default |
|---|---|---|---|
| `reduceMotion` | OS-level motion reduction override | `Bool` | follows system |
| `reduceMotionForce` | Always-on reduce motion regardless of OS | `Bool` | `false` |
| `enhancedVoiceOverLabels` | Verbose screen-reader hints | `Bool` | `true` |
| `hapticOnSelection` | Haptic on picker change | `Bool` | `true` |
| `tapticOnRefresh` | Haptic on refresh | `Bool` | `true` |
| `highContrastOutline` | Outlines around text | `Bool` | `false` (same as `increaseContrast`) |

### 1.10 Content — Language & Terminology

| ID | Knob | Type | Default |
|---|---|---|---|
| `language` | App language override | `String?` (nil = follows system) | `nil` |
| `terminologySet` | "Feels like" vs "Apparent" vs "体感" | `enum` mapped to `Localizable.xcstrings` keys | `.system` |
| `locationNicknames` | Per-saved-location custom label | `[UUID: String]` | `{}` |
| `customLabels` | User-defined metric labels | `[MetricID: String]` | `{}` |

### 1.11 Power-User & Integrations

| ID | Knob | Type | Default |
|---|---|---|---|
| `experimentalFlags` | Per-flag toggles | `Set<ExperimentalFlag>` | `[]` |
| `shortcutName` | Custom Shortcuts phrase | `String?` | `nil` |
| `urlSchemePrefix` | Reserved for future use | reserved | n/a |
| `widgetRefreshPolicy` | `.frequent / .normal / .batterySaver` | `enum` | `.normal` |
| `shareThemeOnExport` | Strip credentials before share | `Bool` | `true` |
| `debugOverlay` | Show FPS / version badge | `Bool` | `false` |

### 1.12 Widget — Per-Widget Variants

| ID | Knob | Type | Default |
|---|---|---|---|
| `widgetStyle.small` | Small widget visual | `enum: .classic, .minimal, .icon, .graph` | `.classic` |
| `widgetStyle.medium` | Medium widget composition | `enum: .hero+forecast, .hero+hourly, .graph` | `.hero+forecast` |
| `widgetStyle.large` | Large widget composition | `enum: .full, .table, .chart` | `.full` |
| `widgetBackground` | Widget chrome | `enum: .transparent, .system, .vignette, .userImage` | `.system` |
| `widgetAccentSource` | `.followApp, .override(ColourToken)` | enum | `.followApp` |
| `widgetTapAction` | `.openApp, .refresh, .openLocation(UUID)` | enum | `.openApp` |

### 1.13 Forecast Presentation

| ID | Knob | Type | Default |
|---|---|---|---|
| `hourlyChartType` | `.line, .bar, .area, .gradient` | enum | `.line` |
| `hourlyCardStyle` | `.compact, .detailed` | enum | `.compact` |
| `dailyCardStyle` | `.row, .grid, .bars` | enum | `.row` |
| `precipitationOverlay` | Show precip bars on hourly | `Bool` | `true` |
| `showSunArc` | Sunrise/sunset arc visual | `Bool` | `true` |
| `showMoonPhase` | Moon icon on hero | `Bool` | `true` |
| `chartAxes` | Show axes on chart | `Bool` | `false` |

---

## 2. Customisation Engine Architecture

### 2.1 The `CustomisationProfile` model

```swift
struct CustomisationProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String                  // "Default", "Power User", "Aussie Summer"
    var builtIn: BuiltInProfile        // .default, .minimalist, .powerUser, .accessibility
    var createdAt: Date
    var updatedAt: Date
    var schemaVersion: Int             // bumped when new knobs appear
    var knobs: KnobStorage             // discriminated-union-style key/value
}
```

`KnobStorage` is **not** a single `Codable` dictionary — each top-level group from §1 gets its own strongly-typed struct (`Visual`, `Background`, `Iconography`, `Layout`, `Data`, `Behaviour`, `Accessibility`, `Content`, `PowerUser`, `Widget`, `Forecast`). The whole thing serialises as a single `.saxtheme` JSON document, but reading/writing a single knob is type-safe.

```swift
struct KnobStorage: Codable, Equatable {
    var visual        : VisualSpec         = .init()
    var background    : BackgroundSpec     = .init()
    var iconography   : IconographySpec    = .init()
    var layout        : LayoutSpec         = .init()
    var data          : DataSpec           = .init()
    var behaviour     : BehaviourSpec      = .init()
    var accessibility : AccessibilitySpec  = .init()
    var content       : ContentSpec        = .init()
    var powerUser     : PowerUserSpec      = .init()
    var widget        : WidgetSpec         = .init()
    var forecast      : ForecastSpec       = .init()
}
```

### 2.2 Built-in profiles (always available, never deleted)

| ID | Profile | Key differences from default |
|---|---|---|
| `default` | **Default** | Ships with current app behaviour |
| `minimalist` | **Minimalist** | `.summary`, no animations, no Lottie, 3-day forecast, no extended cards, large text |
| `powerUser` | **Power User** | `.detailed`, 14-day forecast, 48-hour hourly, all metrics shown, AQI/pollen/sun/moon on, hourly chart `.area` |
| `accessibility` | **Accessibility** | Bold text, increase contrast, reduce motion, large font, enhanced VO labels, larger card spacing |
| `batterySaver` | **Battery Saver** | Reduce motion, less-frequent refresh, `.compact` hourly, no Lottie, dim background overlay |

A new `init` from one of these is one line: `var p = BuiltInProfile.minimalist.profile`.

### 2.3 The `CustomisationRegistry`

A single source of truth that knows:

- Every knob's **default value**, **range**, **enum cases**, **description**, and which group it belongs to.
- How to **decode / encode / migrate** old profiles when new knobs are added.
- How to **publish** changes so any SwiftUI view re-renders.
- How to **search** by name / group / keyword for the new Settings UI search bar.

```swift
@MainActor
final class CustomisationRegistry: ObservableObject {
    static let shared = CustomisationRegistry()

    @Published private(set) var profile: CustomisationProfile
    private(set) var profileHash: Int                 // recomputed on every write

    // Apply a whole profile (with animation hook for Settings preview).
    func apply(_ profile: CustomisationProfile, animated: Bool = true)

    // Apply a single knob, decoded into the right group by a stable key path.
    func set<Value: Equatable>(_ keyPath: WritableKeyPath<KnobStorage, Value>, _ value: Value)

    // Read.
    func get<Value>(_ keyPath: KeyPath<KnobStorage, Value>) -> Value

    // Enumerate for the Settings UI.
    var allKnobs: [KnobDescriptor] { get }            // grouped, searchable
    func searchKnobs(_ query: String) -> [KnobDescriptor]

    // Profile I/O.
    func exportProfile() throws -> URL                 // .saxtheme file
    func importProfile(from url: URL) throws
    func resetTo(_ builtIn: BuiltInProfile)

    // Hot-reload (DEBUG only).
    func reloadFromDisk()
    var profileFileURL: URL { get }                   // ~/Library/Application Support/SaxWeather/current.saxtheme
}
```

**Reactive propagation:** the registry is `@Published`. We push it through SwiftUI two ways:

1. **`@StateObject var registry = CustomisationRegistry.shared`** at the root, propagated via `.environmentObject`.
2. An **Environment key** that surfaces the `CustomisationRegistry` so deeply-nested views can grab it without prop-drilling (mirrors the existing `popupState` pattern in [`ContentView.swift:23`](SaxWeather/SaxWeather/ContentView.swift:23)).

### 2.4 Declarative `LayoutSpec`

`LayoutSpec.homeSectionOrder` and `LayoutSpec.hiddenHomeSections` together describe the home screen. A new `HomeSectionRenderer` consumes them:

```swift
struct HomeSectionRenderer<Service: WeatherServiceProtocol>: View {
    @EnvironmentObject var registry: CustomisationRegistry
    @ObservedObject var service: Service
    var body: some View {
        // For each ID in registry.profile.knobs.layout.homeSectionOrder,
        // build the matching subview. Hidden sections are skipped.
        ForEach(registry.profile.knobs.layout.homeSectionOrder, id: \.self) { id in
            if !registry.profile.knobs.layout.hiddenHomeSections.contains(id) {
                homeSection(for: id)
            }
        }
    }
}
```

`homeSection(for:)` is a switch over the `HomeSectionID` enum — same code that already lives in [`DetailedWeatherView.swift`](SaxWeather/SaxWeather/DetailedWeatherView.swift:11) and [`ContentView.swift`](SaxWeather/SaxWeather/ContentView.swift:104), just lifted out of hardcoded order.

The **preview pane** in the new Settings UI uses the same renderer with a small mocked `WeatherService`, so as the user toggles a knob the preview updates live.

### 2.5 Persistence

Three layers:

| Layer | Where | Format | Lifetime |
|---|---|---|---|
| L0 — Hot prefs | `@AppStorage` keys (existing ones) | UserDefaults (standard + App Group) | Permanent; the registry **writes through** to keep them so existing view code keeps working |
| L1 — Active profile | App Group `current.saxtheme` | Codable JSON | Permanent; what the registry reads on launch |
| L2 — Saved profiles | App Group `profiles/<uuid>.saxtheme` | Codable JSON | Permanent; user can have many, switch via Settings |

The **App Group** is the same `group.com.saxobroko.SaxWeather` already used by [`WidgetSyncService`](SaxWeather/SaxWeather/WidgetSyncService.swift:96). The widget reads `current.saxtheme` (or just the relevant keys — see §2.7) to honour the theme without a host-app push.

### 2.6 Reactive propagation through SwiftUI

```mermaid
flowchart LR
    A[User toggles a knob in Settings] --> B[CustomisationRegistry.set]
    B --> C[KnobStorage diff]
    C --> D[Persists to App Group current.saxtheme]
    C --> E[@Published profile change]
    E --> F[All .environmentObject(CustomisationRegistry) views re-render]
    E --> G[PreferenceKey propagates to deeply nested views]
    D --> H[WidgetSyncService bumps widgetDataVersion]
    H --> I[Widget reloads + applies theme subset]
```

Two propagation paths so we don't pay a full-view re-render for every tweak:

- **Cheap toggles** (booleans, enums): `@Published profile` triggers `objectWillChange`, views that read the registry re-evaluate.
- **Expensive restructurings** (section reorders): a `versionToken: Int` on the registry changes; views that read `versionToken` only re-evaluate when the section structure actually moved.

### 2.7 Widget-side theme application

The widget already reads shared defaults via [`WidgetSharedConfig.swift`](SaxWeather/SaxWeatherWidget/WidgetSharedConfig.swift:18). Extend `Keys` with:

```swift
static let activeProfileHash = "activeProfileHash"
static let cachedProfileHash = "cachedProfileHash"
static let profileSubsetJSON  = "profileSubsetJSON"
```

The host computes a **minimal subset** of the active profile (colour tokens, animation set, layout density, widget style) and writes it as JSON. The widget reads it, deserialises, and applies. If the host's `activeProfileHash` differs from the widget's `cachedProfileHash`, the widget reloads its theme before rendering.

### 2.8 Schema migration

```swift
enum ProfileMigrator {
    static let currentSchemaVersion: Int = 1
    static func migrate(_ data: Data) throws -> CustomisationProfile {
        // 1. Decode as a generic JSON object.
        // 2. Read schemaVersion.
        // 3. Run per-version migrations (add defaults for new fields, rename old ones).
        // 4. Re-encode with currentSchemaVersion.
    }
}
```

Every new knob = bump `currentSchemaVersion` + add a migration that backfills the new field with its default. Old `.saxtheme` files users shared a year ago still load.

### 2.9 Import / Export as `.saxtheme`

- **Format:** JSON. Extension `.saxtheme`. UTI: `com.saxobroko.saxtheme`.
- **Naming:** `<profile-name>-<yyyyMMdd>.saxtheme`. Sanitised.
- **Sanitisation:** unless the user un-checks `shareThemeOnExport`, the export **strips** credentials (`wuApiKey`, `owmApiKey`, `stationID`) and personal location coordinates. This is enforced in `CustomisationRegistry.exportProfile()`.
- **Sharing:** `ShareLink(item: profileFileURL)` from Settings, plus `UIActivityViewController` on iOS. AirDrop picks it up automatically via UTI.
- **Import:** `fileImporter` modifier, validated by `ProfileMigrator`, previewable in a sheet before the user confirms "Apply".

### 2.10 Hot-reload for development

In DEBUG builds, `CustomisationRegistry` watches the `current.saxtheme` file via `DispatchSource.makeFileSystemObjectSource`. Editing the JSON on disk and saving causes the live app to re-apply. The debug menu's "Theme Editor" view in [`LottieDebugView.swift`](SaxWeather/SaxWeather/LottieDebugView.swift:390) gets a new card that:

- Shows the active profile as editable JSON.
- "Reveal in Finder" button → opens the file in Finder so devs can edit with any text editor.
- "Reset" + "Reload" buttons.

### 2.11 Shortcuts / URL schemes / App Intents

- **Shortcuts:** add a `SaxThemeIntent` (`AppIntent`) with parameters `profileName: String` and `applyToAllDevices: Bool`. Returns immediately.
- **URL scheme:** `saxweather://theme/apply?id=<uuid>` and `saxweather://theme/preview?id=<uuid>`.
- **App Intents for widget configuration:** the existing [`AppIntent.swift`](SaxWeather/SaxWeatherWidget/AppIntent.swift:11) stub becomes a real `ConfigurationAppIntent` with a `themeID: AppEntity` parameter — picked from the user's saved profiles.

---

## 3. Settings UI Architecture

### 3.1 Top-level layout

```
SettingsView
├── Search bar (filters every section)
├── Profile bar (active profile + switcher)
├── "Preview" pane (always-visible HomeSectionRenderer)
│   └── Live mini-render of the home screen using mocked data
├── Sections (lazy, grouped by category)
│   ├── Visual — Colours & Typography
│   ├── Visual — Background
│   ├── Visual — Iconography & Animations
│   ├── Layout & Density
│   ├── Forecast Presentation
│   ├── Data — Units & Sources
│   ├── Data — Displayed Fields
│   ├── Behaviour — Interactions
│   ├── Behaviour — Sound & Notifications
│   ├── Accessibility
│   ├── Content — Language & Terminology
│   ├── Power User & Integrations
│   ├── Widget — Per-Widget Variants
│   └── (existing) Saved Locations, Weather Data, Tip Jar, About, Attribution
├── Profile actions
│   ├── Save current as new profile…
│   ├── Switch profile…
│   ├── Import .saxtheme…
│   └── Export current…
```

The existing `SettingsView` (2512 lines) is **extended**, not rewritten: keep all current sections (`Locations`, `Weather Data`, `Preferences`, `Appearance`, `Accessibility`, `TipJar`, `About`, `Attribution`) as-is, **add** the new sections. Move the existing `BackgroundSettingsButton` call into the new "Background" section.

### 3.2 Live preview pane

A persistent pane at the top of `SettingsView` that renders a `HomeSectionRenderer` against a stubbed `WeatherService`. Every knob change updates the preview **animated**, so the user sees their theme land. The preview is sized like an iPhone (≈ 360 × 720 logical pts) and centred; the rest of Settings scrolls behind it.

Implementation note: the stub service is a `MockWeatherService` shipped with the project — it implements the same `WeatherServiceProtocol` interface and returns fixture data from the existing `WeatherForecast.DailyForecast` sample builder in [`DetailedForecastSheet.swift:313`](SaxWeather/SaxWeather/DetailedForecastSheet.swift:313).

### 3.3 Search

`searchable(text: $query)` modifier. The query is matched against `KnobDescriptor.searchTokens` — a per-knob list of keywords the registry generates from the knob's `id`, `displayName`, `group`, and aliases (e.g. "color" / "colour", "temperature", "wind").

### 3.4 "Customise this" long-press

A single shared helper:

```swift
extension View {
    func customisableSection() -> some View {
        modifier(CustomisableSectionModifier())
    }
}
```

When `registry.profile.knobs.behaviour.longPressToCustomise` is `true`, a long-press on any marked section presents a popover anchored to that section listing the **knobs that affect only that section**. This is the fastest possible customisation path: long-press the hourly card → "Show 48 hours / Use bar chart / Show precipitation overlay". Tapping a row navigates to (or expands inline) the right knob.

### 3.5 Onboarding-time style picker

Add a new step between the existing CustomizationStep (`OnboardingView.swift:104`) and the APIKeysStep (`OnboardingView.swift:106`):

| # | Title |
|---|---|
| 7 | **Pick a starting vibe** (new) — three big illustrated cards: Default / Minimalist / Power User. "Choose later" defaults to Default. |
| 8 | **Optional: API Keys** (existing) |
| 9 | **You're All Set!** (existing) |

The `OnboardingProgressIndicator`'s `totalSteps` constant in [`OnboardingView.swift:45`](SaxWeather/SaxWeather/OnboardingView.swift:45) bumps from 8 → 9. The new step sets `registry.apply(BuiltInProfile.minimalist.profile)` (or whichever was picked) so the user's choice is immediate.

### 3.6 Reset / preset actions

A `ProfileActionsSection` at the bottom of `SettingsView`:

- "Reset to Default"
- "Switch to Minimalist / Power User / Accessibility / Battery Saver"
- "Save current as new profile…" → `TextField` for a name → stored under a fresh UUID
- "Manage profiles…" → list of saved profiles with rename / duplicate / delete

---

## 4. Implementation Roadmap

8 phases. Each is independently shippable, each is testable on its own, each unblocks the next.

| # | Phase | Outcome | New files | Edited files | Complexity |
|---|---|---|---|---|---|
| 1 | Foundation: the `CustomisationProfile` model & registry | Single source of truth exists, defaults match current behaviour | `Models/CustomisationProfile.swift`, `Models/ProfileSpecs.swift`, `Services/CustomisationRegistry.swift` | `SaxWeatherApp.swift` (inject registry) | **M** |
| 2 | Bridge to existing `@AppStorage` keys | Existing views still work unchanged, registry writes through to UserDefaults | `Services/ProfileToAppStorageBridge.swift` | Every `@AppStorage` call site stays the same; we add a `subscribe()` method | **S** |
| 3 | iOS-26-aware theming primitives | Customisable palette, card style, corner radius, font scale, opacity | `Helpers/ColourToken.swift`, `Helpers/ScaledFont.swift`, `ViewModifiers/StyledCard.swift` | `DetailedWeatherView.swift`, `ForecastView.swift`, `DetailedForecastSheet.swift`, `WeatherDetailsView` (wherever cards are) | **M** |
| 4 | Layout engine + `HomeSectionRenderer` | Reorderable / hideable home-screen sections, widget-friendly preview | `Views/HomeSectionRenderer.swift`, `Views/Sections/*` | `ContentView.swift`, `DetailedWeatherView.swift` | **L** |
| 5 | Background engine | Per-condition, gradient, dynamic accent, time-of-day rules | `Views/Backgrounds/*` | `BackgroundView.swift`, `BackgroundSettingsView.swift` | **M** |
| 6 | Iconography & animation engine | Lottie overrides, animation speed, custom JSON per condition, symbol variants | `Services/AnimationRegistry.swift`, `Views/ConditionIcon.swift` | `LottieView.swift`, `WeatherAnimationHelper.swift`, `WeatherConditionView.swift`, all `LottieView(name:)` callers | **M** |
| 7 | Settings UI rebuild | Search, preview, profile switcher, import/export, "Customise this" | `Views/Settings/*` (split into many files), `Views/Settings/ProfileImporterView.swift` | `SettingsView.swift` (slimmed), `LottieDebugView.swift` (add Theme Editor card) | **L** |
| 8 | Widget parity, App Intents, Shortcuts, sharing | Widget honours theme, configurable via AppIntent, Shortcuts support, `.saxtheme` share via `ShareLink` + AirDrop | `Services/WidgetThemeBridge.swift`, `SaxWeatherWidget/AppIntent.swift` (real), `Intents/SaxThemeIntent.swift` | `WidgetSharedConfig.swift`, `SaxWeatherWidget.swift`, `Info.plist` (UTI), `SaxWeather.entitlements` (associated domains for `saxweather://`) | **L** |

### 4.1 Phase 1 — Foundation

**Files**

- **NEW** `SaxWeather/SaxWeather/Models/CustomisationProfile.swift` — the type described in §2.1, plus `KnobStorage` and the 11 group structs.
- **NEW** `SaxWeather/SaxWeather/Models/ProfileSpecs.swift` — `VisualSpec`, `BackgroundSpec`, …, `ForecastSpec`. Every property is `@Published`-able through the parent `KnobStorage`. Defaults match the existing `@AppStorage` defaults.
- **NEW** `SaxWeather/SaxWeather/Services/CustomisationRegistry.swift` — `@MainActor` `ObservableObject`, `apply`, `set`, `get`, `searchKnobs`, profile I/O, hot-reload watcher.
- **EDIT** `SaxWeather/SaxWeather/SaxWeatherApp.swift:412` — inject `CustomisationRegistry.shared` as `@StateObject`, pass via `.environmentObject` to `ContentView`. The existing `WeatherService` & `storeManager` injection stays.

**Acceptance criteria**

- The app launches with **identical** behaviour to today (every default matches the existing `@AppStorage` defaults).
- A unit test (`SaxWeatherTests/CustomisationRegistryTests.swift`) verifies that round-tripping a profile through `Codable` + `ProfileMigrator` produces an equal profile.
- `CustomisationRegistry.shared.profile` exposes a `KnobStorage` whose every field matches the corresponding `@AppStorage` default.

**Risks**

- Default-value drift: every default must be lifted from the exact existing `@AppStorage` initialiser. Easy to miss. Mitigation: write a single `DefaultsFromCurrentAppStorage` helper that returns the `KnobStorage` initialised from the live `UserDefaults` (where set), falling back to the registered default. Use this in `init()` of the registry.

**Complexity: M**

### 4.2 Phase 2 — Bridge to existing `@AppStorage`

**Why:** we don't want to rewrite every view in Phase 1. The bridge lets the registry **write through** to `@AppStorage` so existing call-sites continue to read from `UserDefaults` while the registry becomes the single mutation path.

**Files**

- **NEW** `SaxWeather/SaxWeather/Services/ProfileToAppStorageBridge.swift` — single `bridge(_: KnobStorage) -> Void` that writes every knob to its corresponding `@AppStorage` key. Includes a reverse direction `readFromAppStorage() -> KnobStorage` for migration of users with existing settings.
- **EDIT** Settings surfaces (`SettingsView.swift:18-30` and `AccessibilitySettingsView.swift:12-28`) — replace direct `@AppStorage` writes with `registry.set(\.keyPath, newValue)`. Reads stay as `@AppStorage` until each view is migrated to read from the registry.

**Acceptance criteria**

- Toggling `unitSystem` in the existing `SettingsView` updates the registry, the App Group `current.saxtheme`, **and** the `unitSystem` `@AppStorage` key (verified by reading back `UserDefaults.standard.string(forKey: "unitSystem")` in a test).
- A widget reload triggered by `WidgetCenter.shared.reloadAllTimelines()` reads the new unit (verified by inspecting the App Group key).

**Risks**

- Two-way sync bugs (registry → AppStorage → bridge → registry). Mitigation: the registry is the **only** writer; `@AppStorage` views become read-only paths until they're migrated. Add `dispatchPrecondition(condition: .onMainActor)` in the bridge.

**Complexity: S**

### 4.3 Phase 3 — Theming primitives

**Files**

- **NEW** `SaxWeather/SaxWeather/Helpers/ColourToken.swift` — `ColourToken` enum: `.named(String)`, `.rgb(r,g,b,a)`, `.hex(String)`. Codable, hashable, convertible to `Color`.
- **NEW** `SaxWeather/SaxWeather/Helpers/ScaledFont.swift` — wraps `Font` with the registry's `fontScale` and `typography` and `boldText`.
- **NEW** `SaxWeather/SaxWeather/Views/StyledCard.swift` — view modifier that takes the registry and applies `cardStyle`, `cornerRadius`, `cardOpacity`, palette colours, and `palette.background`.
- **EDIT** `SaxWeather/SaxWeather/DetailedWeatherView.swift:196` (`heroSection`), `:323` (`hourlyForecastSection`), `:402` (`WeatherCard`), `:500` (`WindCard`) — replace hardcoded glass / solid backgrounds with `StyledCard`.
- **EDIT** `SaxWeather/SaxWeather/ForecastView.swift:174`, `DetailedForecastSheet.swift:241`, `Views/ExtendedWeatherDetailViews.swift` — same migration.

**Acceptance criteria**

- Toggling `cardStyle` in the registry live-switches every card between `.glass` / `.solid` / `.outline` / `.neumorphic` (visual inspection).
- `cornerRadius` slider visibly rounds / squares cards.
- The fallback path (`iOS < 26.2`) is preserved — `StyledCard` checks `#available` internally and downgrades.

**Risks**

- iOS 26 glass effect performance under heavy lists. Mitigation: gate glass to `WidgetFamily`-aware contexts; for `List` rows use `.thinMaterial`, only the hero card gets full glass.

**Complexity: M**

### 4.4 Phase 4 — Layout engine

**Files**

- **NEW** `SaxWeather/SaxWeather/Views/HomeSectionRenderer.swift` — the renderer described in §2.4.
- **NEW** `SaxWeather/SaxWeather/Views/Sections/HeroSection.swift`, `CurrentSection.swift`, `HourlySection.swift`, `DailySection.swift`, `DetailsSection.swift`, `ExtendedSection.swift` — one file per section, each conforms to `HomeSection`.
- **EDIT** `SaxWeather/SaxWeather/ContentView.swift:259` (`mainWeatherView`) — replace the inline `contentLayer` body with `HomeSectionRenderer(weatherService: weatherService)`.
- **EDIT** `SaxWeather/SaxWeather/DetailedWeatherView.swift` — keep for backwards compatibility (the `displayMode == "Detailed"` path), but route the body through the same renderer.

**Acceptance criteria**

- Toggling `displayMode` in the registry live-switches between `.summary` / `.detailed` / `.compact` / `.power`.
- Drag-reorder UI in Settings → Layout changes `homeSectionOrder` and the home screen re-orders without a relaunch.
- Hiding `extendedSection` removes the AQI / pollen / sun-moon cards across the app.

**Risks**

- Section re-renders may cause layout jumps. Mitigation: use `.animation(.spring, value: registry.versionToken)` only at the renderer root.

**Complexity: L**

### 4.5 Phase 5 — Background engine

**Files**

- **NEW** `SaxWeather/SaxWeather/Views/Backgrounds/BackgroundStrategy.swift` — discriminated union over `.preset`, `.customImage(Data)`, `.gradient(GradientStop, GradientStop)`, `.dynamicAccent(ColourToken)`.
- **NEW** `SaxWeather/SaxWeather/Views/Backgrounds/BackgroundResolver.swift` — given `currentBackgroundCondition` (string already in use at [`ContentView.swift:325`](SaxWeather/SaxWeather/ContentView.swift:325)) + `Date()` + `registry.profile`, returns a `BackgroundStrategy`.
- **EDIT** `SaxWeather/SaxWeather/BackgroundView.swift:16` — accept a `BackgroundStrategy` instead of a condition string; render based on strategy.
- **EDIT** `SaxWeather/SaxWeather/BackgroundSettingsView.swift` — add UI for the new modes (gradient pickers, per-condition photo library).

**Acceptance criteria**

- Setting `.gradient` displays a vertical gradient using `accent` and `palette.surface` across all conditions.
- Setting `.dynamicAccent` tints the existing preset image with the current accent.
- `backgroundTimeOfDayRule = .dawnDayDuskNight` automatically swaps to a darker preset between sunset and sunrise (verified by forcing the system clock).

**Risks**

- Per-condition photo library balloons `App Group` size. Mitigation: store thumbnails (≤ 200 KB JPEG) and re-encode on import.

**Complexity: M**

### 4.6 Phase 6 — Iconography & animation engine

**Files**

- **NEW** `SaxWeather/SaxWeather/Services/AnimationRegistry.swift` — wraps `WeatherAnimationHelper.animationNameFromCode(...)` with override logic from `registry.profile.knobs.iconography.lottieOverrideMap`.
- **NEW** `SaxWeather/SaxWeather/Views/ConditionIcon.swift` — single entry point for "give me the icon for condition X at night Y at size Z" that the renderer uses. Picks between Lottie / SF Symbol / custom symbol.
- **EDIT** `SaxWeather/SaxWeather/LottieView.swift:64` — read playback speed and loop mode from the registry. Honour `lottiePlaybackSpeed`.
- **EDIT** `SaxWeather/SaxWeather/WeatherAnimationHelper.swift` — `animationName(for:isNight:)` becomes a thin wrapper around `AnimationRegistry.shared.name(for:isNight:)`.
- **EDIT** Every `LottieView(name:)` call site (`ContentView.swift:378/382`, `DetailedForecastSheet.swift:66`, `ForecastView.swift:279`, `DetailedWeatherView.swift:201/290`, `WeatherConditionView.swift:24`, `WeatherAnimationView.swift:20`) — migrate to `ConditionIcon(condition: ..., isNight: ..., size: ...)`.

**Acceptance criteria**

- Changing `lottiePlaybackSpeed` to 0.5 visibly slows every animation.
- Loading a custom JSON via `lottieOverrideMap[condition: "clear-day"] = "my-clear-day.json"` (shipped with the bundle as an example) shows the custom animation in the hero card and forecast hourly items.

**Risks**

- Lottie animations being expensive to parse on the main thread. Mitigation: parse on first appearance, cache in `LottieParser` (already exists).

**Complexity: M**

### 4.7 Phase 7 — Settings UI rebuild

**Files**

- **NEW** `SaxWeather/SaxWeather/Views/Settings/SettingsHomeView.swift` — top-level container with search, preview, profile bar.
- **NEW** `SaxWeather/SaxWeather/Views/Settings/SettingsPreviewPane.swift` — the live preview pane.
- **NEW** `SaxWeather/SaxWeather/Views/Settings/Sections/VisualSection.swift`, `BackgroundSection.swift`, `IconographySection.swift`, `LayoutSection.swift`, `ForecastSection.swift`, `DataSection.swift`, `FieldsSection.swift`, `BehaviourSection.swift`, `SoundSection.swift`, `AccessibilitySection.swift` (re-uses existing view), `ContentSection.swift`, `PowerUserSection.swift`, `WidgetSection.swift`, `ProfileActionsSection.swift`.
- **NEW** `SaxWeather/SaxWeather/Views/Settings/ProfileSwitcherView.swift` — list of built-in + user profiles.
- **NEW** `SaxWeather/SaxWeather/Views/Settings/ProfileImporterView.swift` — `.fileImporter` + preview + apply.
- **NEW** `SaxWeather/SaxWeather/Views/Settings/CustomisableSection.swift` — the `customisableSection()` modifier.
- **EDIT** `SaxWeather/SaxWeather/SettingsView.swift` — keep the entry point and the existing tabs (`Locations`, `Weather Data`, `Preferences`, `Appearance`, `Accessibility`, `Tip Jar`, `About`, `Attribution`) as nested `NavigationLink`s. Replace the iOS root with `SettingsHomeView(weatherService: storeManager:)` that internally navigates to these.
- **EDIT** `SaxWeather/SaxWeather/LottieDebugView.swift:390` — add a **Theme Editor** card: JSON editor + Reveal in Finder + Reload + Reset.

**Acceptance criteria**

- The Settings root renders search + preview + sections; existing `NavigationLink` destinations still work.
- Typing "color" into the search bar surfaces all colour-related knobs across categories.
- Export → file written to disk → AirDrop to another device → import on the second device produces an identical profile (minus credentials).

**Risks**

- Performance of the live preview during scroll. Mitigation: render the preview at a fixed logical size, throttle to 30 fps with `.drawingGroup()` if needed.

**Complexity: L**

### 4.8 Phase 8 — Widget, Intents, Shortcuts, Sharing

**Files**

- **NEW** `SaxWeather/SaxWeather/Services/WidgetThemeBridge.swift` — `hostProfile` → `WidgetThemeSubset` (colour tokens, animation set, layout density, widget style). Writes `WidgetSharedConfig.Keys.profileSubsetJSON` and bumps `widgetDataVersion` via existing `WidgetSyncService`.
- **EDIT** `SaxWeather/SaxWeatherWidget/WidgetSharedConfig.swift` — add `activeProfileHash`, `cachedProfileHash`, `profileSubsetJSON` keys.
- **EDIT** `SaxWeather/SaxWeatherWidget/SaxWeatherWidget.swift` — read the subset, apply colour/typography/layout/widget-style changes per family. Per-family views (`small`, `medium`, `large`) switch on `widgetStyle.<family>`.
- **REWRITE** `SaxWeather/SaxWeatherWidget/AppIntent.swift` — real `ConfigurationAppIntent` with `themeID: ThemeEntity` parameter. `ThemeEntity` is an `AppEntity` backed by `CustomisationRegistry`'s saved profiles.
- **NEW** `SaxWeather/SaxWeather/Intents/SaxThemeIntent.swift` — `AppIntent` for Shortcuts: "Set SaxWeather Theme", parameters `themeName`, `applyToAllDevices`. Available on iOS 16+ via `AppShortcutsProvider`.
- **EDIT** `SaxWeather/SaxWeather/Info.plist` — add `UTExportedTypeDeclarations` for `com.saxobroko.saxtheme`, `CFBundleTypeRole = Viewer`, and `CFBundleURLTypes` for `saxweather://`.
- **EDIT** `SaxWeather/SaxWeather/SaxWeather.entitlements` — add associated-domains entitlement if we want Universal Links (optional, defer to v1).
- **EDIT** `SaxWeather/SaxWeather/SettingsView.swift` (or wherever the Share button lives) — `ShareLink(item: profileFileURL)`.

**Acceptance criteria**

- Adding a widget and choosing a non-default theme via the widget configuration intent applies that theme to the widget.
- Saving a custom theme on device A → opening Shortcuts → running "Set SaxWeather Theme: Power User" → the widget immediately switches.
- Importing a `.saxtheme` file via AirDrop opens the app to a preview screen.

**Risks**

- Widget memory budget (~30 MB). Mitigation: profile subset is a tiny JSON (< 2 KB). No image assets live in the widget process — it always uses the shipped `Assets.xcassets` for backgrounds, just retinted.
- App Review: `.saxtheme` UTI + `LSItemContentTypes` needs to be declared correctly to enable AirDrop. Mitigation: test in TestFlight early.

**Complexity: L**

---

## 5. Risks, Trade-offs, and Open Questions

### 5.1 What "infinite" really means

"Infinite customisation" is a marketing claim. In practice it means:

1. **Bounded by a schema.** Every knob is registered. New knob = code change. Power users hit the schema edge — that's where the JSON editor in debug mode + "experimental flags" + import/export step in. The JSON editor is the escape hatch.
2. **Extensible in spirit.** The schema is small. Most users will touch 5-10 knobs. Power users will touch 50. Developers will read the JSON.
3. **Not literally infinite.** There is no "user uploads their own Lottie file that the app interprets" — that's a sandboxed runtime, not a customisation system. If we want that, it needs WebKit + a JS bundle interpreter, which is a separate product.

### 5.2 Performance

- **Widget**: already budget-stretched. Mitigation: only colour tokens, animation set name, and layout density cross the process boundary. Images always come from `Assets.xcassets`. See §2.7.
- **Home screen re-renders**: a single `@Published` change at the root can re-render the whole tab. Mitigation: §2.6 — split propagation into cheap (per-property) and structural (per-token-version) paths.
- **Background photos**: large user photos can blow the memory budget. Mitigation: re-encode to ≤ 200 KB JPEG on import; cache decoded `UIImage` once.

### 5.3 App Store review

- **Custom URLs / URL schemes**: harmless, but UTI declarations (`com.saxobroko.saxtheme`) must be correct for AirDrop to surface the app as a target. Verify in TestFlight before submission.
- **Importing arbitrary JSON**: not a sandboxing risk because we never execute it. The decoder is `JSONDecoder` with a strict schema. Migrations reject unknown future versions with a clear error.
- **App Intents**: Apple's review team has been strict about Shortcuts integrations. Keep the parameter list short and obvious.

### 5.4 CloudKit schema migration

Currently no `CustomisationProfile` is in CloudKit (the leaderboard is). If we choose to sync profiles via iCloud in a later phase:

- Each profile gets a `CKRecord` of type `CustomisationProfile`.
- `schemaVersion` becomes a CloudKit record field.
- Migration: any consumer that reads a `CustomisationProfile` must call `ProfileMigrator.migrate(...)` first.
- Conflict resolution: last-writer-wins on `updatedAt`. Profiles don't conflict meaningfully because knobs are commutative at the granularity users touch.

This is **out of scope for v1** — keep profiles local + App Group + ShareLink. CloudKit sync is a follow-up.

### 5.5 Backwards compatibility

- Existing `@AppStorage` keys must keep working. Every Phase ≥ 2 keeps the `@AppStorage` reads live; Phase 2 adds write-through from the registry. Users who never open the new Settings UI see **zero** behaviour change.
- Existing Lottie animation assets are unchanged.
- The widget extension keeps its existing `WidgetSharedConfig.Keys` and adds new ones.

### 5.6 Open questions to resolve before Phase 7

1. **Do we want a paid "Theme Store"?** Out of scope, but the UTI + import/export plumbing is half the work. Decide before Phase 8.
2. **Should `SavedLocation` carry an override profile?** Strong UX case (e.g. "Melbourne = Dark, Office = Bright"). Trivially additive — one optional field. Recommend **yes**, defer to Phase 7.
3. **Should we ship a "Designer" curated profile pack?** Bundled `.saxtheme` files in the app. Recommend deferring to post-v1 — first prove the engine works.
4. **Should the Settings preview pane be optional?** Power users on small phones may want to hide it. Recommend **yes**, with a single toggle `showSettingsPreview` (which is itself a knob — meta, but allowed).

### 5.7 When to ship

| Phase | Suggested version | Reason |
|---|---|---|
| 1 | v1.5 | Invisible to users; sets up the model. Safe. |
| 2 | v1.5 | Also invisible; just plumbing. |
| 3 | v1.6 | First user-visible theming changes. Pair with a release-note blurb. |
| 4 | v1.6 | Layout engine. Pair with Phase 3. |
| 5 | v1.7 | Background engine. User-facing "wow" moment. |
| 6 | v1.7 | Iconography engine. Pair with Phase 5. |
| 7 | v1.8 | New Settings UI. Major UX change — ship with a "What's new" sheet. |
| 8 | v1.9 | Widget parity, sharing. Marketing-friendly feature. |

---

## 6. Glossary

- **Knob** — one customisable setting, registered in `KnobStorage`.
- **Profile** — a complete named `CustomisationProfile` (= one set of knob values).
- **Built-in profile** — one of the five non-deletable profiles (§2.2).
- **Schema version** — `currentSchemaVersion` in `ProfileMigrator`, bumped when knobs are added or renamed.
- **`.saxtheme`** — the file format for export/import of profiles.
- **Registry** — `CustomisationRegistry.shared`, the singleton runtime.
- **Section** — one block of the home screen (Hero / Current / Hourly / Daily / Details / Extended), identified by `HomeSectionID`.

---

## 7. Acceptance for "infinite"

This plan delivers "infinitely customisable" if and only if **all** of the following hold at v1.9:

- [ ] Every row in §1 has a registered knob.
- [ ] Every row in §1 can be changed via the Settings UI without code changes.
- [ ] A profile can be exported to a `.saxtheme` file, shared via AirDrop, imported on a second device, and applied — verified end-to-end.
- [ ] The widget honours the active theme (colour tokens + animation set + layout density + per-family style).
- [ ] An exported profile, after a schema-version bump (e.g. via adding a new knob), still loads on a build that ships the new schema (via `ProfileMigrator`).
- [ ] A new developer can add a new knob in **one place** (a `ProfileSpecs.swift` field + a `KnobDescriptor` entry) and have it surface automatically in Settings, search, and the import/export pipeline.

If any of those six boxes is unchecked, we are not done.
