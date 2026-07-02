# SaxWeather — Cosmetic-Only Monetization Plan

> **Status:** Draft v2 — revised after user decisions on 5 open questions
> **Author target:** Architect / single-developer SwiftUI on iOS/macOS
> **Premise:** Add a paid-cosmetics catalog on top of the existing customisation engine and StoreKit plumbing. **No real feature may be paywalled. No ads. Ever.** Cosmetics are an optional, voluntary way for users to support development and personalise the app.

---

## 0. How to read this plan

This plan is **additive**. It does not propose removing, gating, or downgrading anything that already exists. Every existing customisation knob in [`SaxWeather/Models/ProfileSpecs.swift`](SaxWeather/Models/ProfileSpecs.swift:1) stays free. Every existing IAP (`CustomBackground50c`) stays. The Tip Jar stays. The leaderboard stays.

What this plan adds:

1. A **paid-cosmetics catalog** — 24 distinct items organised into 8 packs.
2. A **Cosmetics Store** UI, separate from the Tip Jar.
3. A small **entitlement layer** that links StoreKit product IDs to cosmetic items.
4. A **preview-on-actual-forecast** flow so users can try before they buy.
5. **Ethical guardrails** — no dark patterns, no fake urgency, no status-symbol pressure.
6. A **Supporter Pack** — a single one-time IAP that unlocks every current and every future cosmetic, always available, never expires.

---

## 1. Guiding Principles

These are non-negotiable. Every design decision in this plan must satisfy all of them.

### 1.1 Hard constraints (reaffirmed)

1. **No real feature may be paywalled.** Every current and future functional feature — units, forecast window, hourly chart, alerts, leaderboard, multiple locations, API keys, refresh cadence, accessibility settings — remains fully accessible to free users.
2. **No ads of any kind.** No banner, no interstitial, no "sponsored weather", no "promoted location", no SDKs that phone home for ad attribution.

### 1.2 Ethical-pricing principles

3. **Purchases persist across reinstalls via Apple ID.** StoreKit 2's `Transaction.currentEntitlements` is the source of truth; we never rely solely on a local flag.
4. **No subscriptions required.** Every cosmetic — including the **Supporter Pack** — is a one-time non-consumable IAP. There are no recurring subscriptions of any kind.
5. **No dark patterns.** No fake countdowns, no "Only 3 left!", no "Unlock" framing for cosmetics, no fake discounts, no "Are you sure you want to miss out?" copy.
6. **Supporter-friendly pricing tiers.** Micro ($0.99–$1.99), Standard ($2.99–$4.99), Premium ($6.99–$9.99), Bundle ($14.99+). **No individual item above $19.99. The Supporter Pack is $24.99 — the single, explicit exception, because it unlocks every current and every future cosmetic, including any new premium items, forever.**
7. **Free tier must feel complete, not crippled.** The shipped app, with zero purchases, must look and feel like a finished product. Cosmetics are *additions*, not *unlocks*.
8. **No status-symbol pressure.** A small "Supporter" badge in Settings is the only acknowledgement of ownership. No leaderboard flair that creates social comparison, no public profile that exposes what others have bought.
9. **Accessibility is not a cosmetic.** Every paid cosmetic must respect Dynamic Type, Reduce Motion, Increase Contrast, and VoiceOver. Free accessible equivalents are always available.
10. **Regional pricing is Apple's job.** We set US tier prices; App Store handles purchasing-power parity. We do not run our own regional pricing logic.
11. **Refunds are Apple's job.** We do not gate refunds behind a flow. We surface the standard `Transaction.refundRequestSheet` if a user asks.
12. **No Family Sharing on any product.** All non-consumable cosmetics — including the Supporter Pack — are configured with `familyShareable = false` in [`SaxWeather/SaxWeather/configuration.storekit`](SaxWeather/configuration.storekit:1) and in App Store Connect. Restoration works on the same Apple ID only. Cosmetics are personal taste — sharing them across a household adds complexity for very little benefit and creates awkward UX when family members want different looks. This matches the existing configuration of `CustomBackground50c` and every Tip Jar product.

---

## 2. Audit Summary of Existing Cosmetic Surface

### 2.1 What is already cosmetically customisable for free

The customisation engine ([`plans/INFINITE_CUSTOMISATION_PLAN.md`](plans/INFINITE_CUSTOMISATION_PLAN.md)) already exposes a substantial free cosmetic surface:

| Category | Free knobs (already shipped) |
|---|---|
| **Accent colour** | 13 named colours via [`AccentColorHelper.swift`](SaxWeather/AccentColorHelper.swift:11) + arbitrary RGB/hex via [`Helpers/ColourToken.swift`](SaxWeather/Helpers/ColourToken.swift:1) |
| **Palette** | 5-colour palette (bg, surface, text, muted, danger) |
| **Card style** | `.glass`, `.solid`, `.outline`, `.neumorphic` |
| **Corner radius** | 0–28 pt slider |
| **Typography** | `.system`, `.rounded`, `.serif`, `.mono` |
| **Font scale** | 0.75×–1.5× |
| **Bold text** | on/off |
| **Increase contrast** | on/off |
| **Colour scheme** | system / light / dark |
| **Card opacity** | 0.4–1.0 |
| **Background mode** | preset / custom image / gradient / dynamic accent |
| **Per-condition backgrounds** | user-supplied JPEG per weather condition |
| **Time-of-day background rule** | dawn/day/dusk/night or hour range |
| **Background overlay opacity** | 0–0.7 |
| **Lottie animation set** | bundled / bundled-static / custom |
| **Per-condition Lottie overrides** | user-supplied JSON per condition |
| **Lottie playback speed** | 0.25×–2.0× |
| **Lottie loop mode** | loop / play once |
| **Weather icon style** | multicolor / monochrome / outline |
| **SF Symbol variant** | automatic / filled / outline |
| **Icon size multiplier** | 0.7×–1.6× |
| **Display mode** | Summary / Detailed |
| **Home section order** | drag-reorder |
| **Hidden home sections** | per-section hide |
| **Forecast days** | 3 / 5 / 7 / 10 / 14 |
| **Hourly hours** | 12 / 24 / 48 |
| **Card density** | compact / regular / relaxed |
| **Hourly chart type** | line / bar / area / gradient |
| **Hourly card style** | compact / detailed |
| **Daily card style** | row / grid / bars |
| **Chart axes** | on/off |
| **Precipitation overlay** | on/off |
| **Sun arc** | on/off |
| **Moon phase** | on/off |
| **Widget style (small/medium/large)** | classic / minimal / icon / graph, etc. |
| **Widget background** | transparent / system / vignette / user image |
| **Widget accent** | follows app or override |
| **Widget tap action** | open app / refresh |
| **Haptic intensity** | light / medium / heavy |
| **Haptic on selection** | on/off |
| **Taptic on refresh** | on/off |
| **Refresh sound** | on/off |
| **Weather alert sounds** | on/off |
| **Quiet hours** | start/end hour |
| **Custom location nicknames** | per-saved-location |
| **Custom metric labels** | per-metric |
| **Terminology set** | system / feels-like / apparent / japanese |
| **Language override** | nil = system, or any supported locale |

That's **~50 free cosmetic knobs** already. The paid catalog must not duplicate any of these — it must *extend* the surface into places the free engine doesn't reach.

### 2.2 Cosmetic gaps — places where the app currently offers no customisation that *could* become a paid cosmetic

These are the gaps the paid catalog fills. Each gap is a place where the app currently has a single shipped look and no way to change it.

| Gap | What it is today | Why it's a good cosmetic |
|---|---|---|
| **App icon** | Single shipped `AppIcon.appiconset` | iOS supports `alternateIconName`; users love personalising their home screen |
| **Widget background image** | Solid colour from `WidgetBackground.colorset` | Widgets are the most visible surface; a custom image sells |
| **Per-condition weather background images** | 8 shipped Unsplash JPEGs in `Assets.xcassets/weather_background_*.imageset` | Cohesive themed sets (Aurora, Neon, Seasonal) feel collectable |
| **Lottie animation set** | 10 shipped Lottie files | Curated themed animation sets (Aurora, Neon, Seasonal) feel collectable |
| **Accent palette presets** | 13 named colours + arbitrary RGB/hex | Curated designer palettes (Sunset, Forest, Cyberpunk) feel collectable |
| **Weather-condition icon style** | SF Symbols only | Custom illustrated icon sets (Hand-drawn, Pixel, Neon) feel collectable |
| **Typography family** | 4 system families | Designer font sets (Editorial, Mono Code, Handwritten) feel collectable |
| **Haptic patterns** | 3 intensities of the system haptic | Custom Core Haptics patterns (Rain, Wind, Thunder) feel collectable |
| **Hourly chart style** | 4 chart types | Themed chart skins (Aurora gradient, Neon glow, Newspaper print) feel collectable |
| **Onboarding illustrations** | Single shipped set | Themed onboarding illustration sets feel collectable |
| **Empty-state illustrations** | Single shipped set | Themed empty-state sets feel collectable |
| **Leaderboard rank badge** | Tier name only (no visual flair) | Cosmetic badge frames around the existing tier name — purely visual, no gameplay effect |
| **Severe-weather alert card** | Severity-coloured card with system icon | Themed alert card designs (Newspaper, Sci-Fi, Minimal) feel collectable |
| **Seasonal/event themes** | None | Halloween, Christmas, Pride, Autumn — each available during its defined annual window, kept forever after purchase |
| **Custom refresh sound** | System default | Curated sound packs (Chime, Nature, Synth) feel collectable |
| **Custom pull-to-refresh animation** | System spinner | Custom Lottie pull-to-refresh animations feel collectable |
| **Settings app icon (in iOS Settings.app)** | Default | iOS 18+ supports tinted app icons; a curated set feels collectable |
| **Lock-screen widget style** | Single shipped | Themed lock-screen widget faces feel collectable |

These 18 gaps map to the 24 paid items in §3.

---

## 3. Proposed Paid Cosmetic Catalog

**24 distinct cosmetic items** organised into **8 packs**. Every item is a one-time non-consumable IAP. Prices are US tier prices; App Store handles regional pricing. **Family Sharing is not offered on any product.**

### 3.1 Pack: Aurora (4 items)

A cohesive northern-lights-themed set. Greens, teals, deep purples, soft glows.

| # | Name & concept | What it changes visually | Asset / format | Price tier | Product ID | Integration point | Widget parity | Why it stays a cosmetic |
|---|---|---|---|---|---|---|---|---|
| 1 | **Aurora Backgrounds** | Replaces the 8 shipped `weather_background_*.imageset` JPEGs with aurora-themed equivalents (clear-day = green sky, rainy = teal sheets, snowy = purple haze, etc.) | 8 JPEGs (≤ 200 KB each) in a new `aurora_background_*.imageset` set | Standard $3.99 | `com.saxweather.cosmetic.aurora.backgrounds` | `BackgroundResolver` — add `case .aurora` to `BackgroundMode` | ✅ Widget reads the same `Assets.xcassets` | Purely visual; same data, different photo |
| 2 | **Aurora Lottie Animations** | Replaces the 10 shipped Lottie files with aurora-themed equivalents (clear-day = flowing green ribbons, snowy = falling purple particles, etc.) | 10 Lottie JSON files in `Lottie Animations/Aurora/` | Standard $3.99 | `com.saxweather.cosmetic.aurora.lottie` | [`Services/AnimationRegistry.swift`](SaxWeather/Services/AnimationRegistry.swift:1) — add `lottieSet: .aurora` to `IconographySpec` | ❌ Widgets don't render Lottie (memory budget); widget falls back to the aurora background image | Purely visual; same condition mapping, different animation |
| 3 | **Aurora Accent Palette** | A 5-colour palette preset (bg = deep navy, surface = teal, text = mint, muted = lavender, danger = coral) | A `Palette` struct value | Micro $1.99 | `com.saxweather.cosmetic.aurora.palette` | [`Models/ProfileSpecs.swift`](SaxWeather/Models/ProfileSpecs.swift:55) — `Palette` already supports this | ✅ Widget reads palette via `WidgetSharedConfig` | Purely visual; same knobs, different default values |
| 4 | **Aurora Hourly Chart Skin** | Replaces the hourly chart's gradient/line colours with aurora-themed ones (green→teal→purple gradient) | A `ChartSkin` struct value (new) | Micro $1.99 | `com.saxweather.cosmetic.aurora.chart` | [`ForecastView.swift`](SaxWeather/ForecastView.swift:1) — chart rendering reads `chartSkin` | ❌ Widgets don't render the hourly chart | Purely visual; same data, different colours |

### 3.2 Pack: Neon (4 items)

A cyberpunk/synthwave-themed set. Hot pinks, electric blues, scanlines.

| # | Name & concept | What it changes visually | Asset / format | Price tier | Product ID | Integration point | Widget parity | Why it stays a cosmetic |
|---|---|---|---|---|---|---|---|---|
| 5 | **Neon Backgrounds** | 8 synthwave-themed background JPEGs (sunset grids, neon city skylines, etc.) | 8 JPEGs in `neon_background_*.imageset` | Standard $3.99 | `com.saxweather.cosmetic.neon.backgrounds` | `BackgroundResolver` — `case .neon` | ✅ | Purely visual |
| 6 | **Neon Lottie Animations** | 10 synthwave-themed Lottie animations (glitchy rain, pixel snow, etc.) | 10 Lottie JSON files | Standard $3.99 | `com.saxweather.cosmetic.neon.lottie` | `AnimationRegistry` — `lottieSet: .neon` | ❌ | Purely visual |
| 7 | **Neon Accent Palette** | Hot pink + electric blue + cyan palette | `Palette` struct value | Micro $1.99 | `com.saxweather.cosmetic.neon.palette` | `Palette` | ✅ | Purely visual |
| 8 | **Neon Weather Icons** | Custom illustrated weather-condition icons in a neon style (replaces SF Symbols) | 11 SF Symbol substitutes (PNG/SVG) + a `WeatherIconStyle.neon` case | Standard $2.99 | `com.saxweather.cosmetic.neon.icons` | [`Services/AnimationRegistry.swift`](SaxWeather/Services/AnimationRegistry.swift:86) — `symbolName(for:)` returns the neon asset name when owned | ✅ Widget reads via `WidgetSharedConfig` | Purely visual; same condition mapping, different glyph |

### 3.3 Pack: Seasonal (4 items)

Time-of-year-themed sets. Each is a one-time IAP, **only purchasable during a defined annual window** (see §3.11 "Seasonal Availability Model"), but **owned forever after purchase**. Once a user has bought a seasonal pack, they can equip it year-round — there is no auto-unequip at season end.

| # | Name & concept | What it changes visually | Asset / format | Price tier | Product ID | Integration point | Widget parity | Why it stays a cosmetic |
|---|---|---|---|---|---|---|---|---|
| 9 | **Halloween Pack** | Spooky backgrounds (foggy = haunted forest, rainy = blood moon, thunder = lightning over a graveyard), Halloween Lottie animations, jack-o'-lantern weather icons, Halloween accent palette | 8 JPEGs + 10 Lottie + 11 icons + 1 palette | Premium $6.99 | `com.saxweather.cosmetic.seasonal.halloween` | All four integration points above | ✅ for backgrounds + palette + icons; ❌ for Lottie | Purely visual |
| 10 | **Christmas Pack** | Snowy cabin backgrounds, snowflake Lottie animations, candy-cane weather icons, red/green palette | 8 JPEGs + 10 Lottie + 11 icons + 1 palette | Premium $6.99 | `com.saxweather.cosmetic.seasonal.christmas` | All four | ✅ / ❌ split | Purely visual |
| 11 | **Pride Pack** | Rainbow-flag-inspired backgrounds, rainbow Lottie animations, rainbow weather icons, rainbow palette. **Treated as a normal seasonal cosmetic — same as Halloween, Christmas, etc. — with no charity hook.** | 8 JPEGs + 10 Lottie + 11 icons + 1 palette | Premium $6.99 | `com.saxweather.cosmetic.seasonal.pride` | All four | ✅ / ❌ split | Purely visual |
| 12 | **Autumn Pack** | Warm-toned forest backgrounds, falling-leaf Lottie animations, pumpkin-spice weather icons, burnt-orange palette | 8 JPEGs + 10 Lottie + 11 icons + 1 palette | Premium $6.99 | `com.saxweather.cosmetic.seasonal.autumn` | All four | ✅ / ❌ split | Purely visual |

**Note on the Pride Pack.** Earlier drafts of this plan considered donating proceeds from the Pride Pack to a chosen LGBTQ+ charity. After review, that idea has been shelved for v1. The Pride Pack ships as a purely visual seasonal cosmetic — no donation mechanism, no App Store Connect report-based donations, no backend required. If we ever revisit charity integration in a future version, it will be designed as a separate, opt-in flow and not bundled with a paid cosmetic.

**Note on the seasonal pack lineup.** v1 ships four seasonal packs: Halloween, Christmas, Pride, Autumn. The earlier draft listed Lunar New Year as #11; it has been replaced by Pride to keep the lineup aligned with the user's seasonal set (Halloween, Christmas, Pride, Autumn).

### 3.4 Pack: Typography (3 items)

Designer font sets that go beyond the 4 system families already free.

| # | Name & concept | What it changes visually | Asset / format | Price tier | Product ID | Integration point | Widget parity | Why it stays a cosmetic |
|---|---|---|---|---|---|---|---|---|
| 13 | **Editorial Font Set** | A serif/transitional font family for headlines + a clean sans for body. Adds 2 new cases to `TypographyFamily` | 2 `.ttf` or `.otf` files registered in `Info.plist` (`UIAppFonts`) | Standard $2.99 | `com.saxweather.cosmetic.font.editorial` | [`Models/ProfileSpecs.swift`](SaxWeather/Models/ProfileSpecs.swift:49) — extend `TypographyFamily` enum | ✅ Widget reads via `WidgetSharedConfig` | Purely visual; same text, different glyphs |
| 14 | **Mono Code Font Set** | A developer-style monospace family for the entire app | 1 `.ttf` file | Micro $1.99 | `com.saxweather.cosmetic.font.mono` | `TypographyFamily` | ✅ | Purely visual |
| 15 | **Handwritten Font Set** | A casual handwritten family for a friendlier feel | 1 `.ttf` file | Micro $1.99 | `com.saxweather.cosmetic.font.handwritten` | `TypographyFamily` | ✅ | Purely visual |

### 3.5 Pack: Haptics & Sound (3 items)

Custom haptic patterns and refresh sounds.

| # | Name & concept | What it changes visually | Asset / format | Price tier | Product ID | Integration point | Widget parity | Why it stays a cosmetic |
|---|---|---|---|---|---|---|---|---|
| 16 | **Rain Haptic Pack** | A custom Core Haptics pattern that mimics raindrops (light taps at random intervals) for the existing `hapticOnSelection` and `tapticOnRefresh` knobs | A `.ahap` Core Haptics pattern file | Micro $1.99 | `com.saxweather.cosmetic.haptic.rain` | [`Helpers/HapticFeedbackHelper.swift`](SaxWeather/Helpers/HapticFeedbackHelper.swift:1) — add `playCustomPattern(named:)` | ❌ Widgets don't fire haptics | Purely tactile; no functional change |
| 17 | **Wind Haptic Pack** | A continuous-breeze Core Haptics pattern | A `.ahap` file | Micro $1.99 | `com.saxweather.cosmetic.haptic.wind` | `HapticFeedbackHelper` | ❌ | Purely tactile |
| 18 | **Synth Refresh Sound Pack** | 3 short synth tones (major, minor, pentatonic) for the existing `refreshSound` knob | 3 `.caf` audio files | Micro $1.99 | `com.saxweather.cosmetic.sound.synth` | `BehaviourSpec.refreshSound` playback path | ❌ Widgets don't play sounds | Purely auditory |

### 3.6 Pack: Widgets (2 items)

Widget-specific cosmetics that don't apply to the main app.

| # | Name & concept | What it changes visually | Asset / format | Price tier | Product ID | Integration point | Widget parity | Why it stays a cosmetic |
|---|---|---|---|---|---|---|---|---|
| 19 | **Widget Background Images** | 6 curated background images for the widget (aurora, neon, sunset, forest, ocean, monochrome) | 6 JPEGs in `SaxWeatherWidget/Assets.xcassets/widget_bg_*.imageset` | Standard $2.99 | `com.saxweather.cosmetic.widget.backgrounds` | [`SaxWeatherWidget/SaxWeatherWidget.swift`](SaxWeather/SaxWeatherWidget/SaxWeatherWidget.swift:1) — `WidgetBackground.userImage` already exists; add a `userImagePack` enum | ✅ Widget-only | Purely visual |
| 20 | **Widget Theme Skins** | 4 cohesive widget themes (Classic, Glass, Newspaper, Terminal) that change the widget's typography, accent, and chrome | A `WidgetTheme` struct value (new) | Standard $3.99 | `com.saxweather.cosmetic.widget.themes` | `WidgetSpec` — add `theme: WidgetTheme` | ✅ Widget-only | Purely visual |

### 3.7 Pack: App Icon (2 items)

| # | Name & concept | What it changes visually | Asset / format | Price tier | Product ID | Integration point | Widget parity | Why it stays a cosmetic |
|---|---|---|---|---|---|---|---|---|
| 21 | **App Icon Pack: Minimal** | 4 minimalist app icons (line-art weather glyphs on solid backgrounds) | 4 `AppIcon-*.appiconset` directories | Standard $2.99 | `com.saxweather.cosmetic.appicon.minimal` | `UIApplication.shared.setAlternateIconName(_:)` | ❌ App icons are app-only | Purely visual; iOS handles the home-screen swap |
| 22 | **App Icon Pack: Illustrated** | 4 illustrated app icons (hand-drawn weather scenes) | 4 `AppIcon-*.appiconset` directories | Standard $2.99 | `com.saxweather.cosmetic.appicon.illustrated` | Same | ❌ | Purely visual |

### 3.8 Pack: Supporter (2 items)

The "thank you" tier. These are the only items that surface any acknowledgement of ownership. Both are `familyShareable: false`.

| # | Name & concept | What it changes visually | Asset / format | Price tier | Product ID | Integration point | Widget parity | Why it stays a cosmetic |
|---|---|---|---|---|---|---|---|---|
| 23 | **Supporter Badge** | A small "☕ Supporter" badge in Settings (next to the version number). **No public visibility, no leaderboard effect, no social comparison.** | A `Bool` entitlement flag | Micro $0.99 | `com.saxweather.cosmetic.supporter.badge` | [`SettingsView.swift`](SaxWeather/SettingsView.swift:836) — `aboutSection` | ❌ | Purely visual; private acknowledgement only |
| 24 | **Supporter Pack** | **Unlocks every current and every future cosmetic** added to the app, permanently. Not "may include" — **will include**. New cosmetics added in future versions are automatically owned by Supporter Pack holders. Single one-time IAP, always available, never expires. | A `Bool` entitlement flag that grants all other product IDs | Premium $24.99, `familyShareable: false` | `com.saxweather.cosmetic.supporter.pack` | `EntitlementStore` — short-circuits all ownership checks | ✅ for everything that has widget parity | Purely a bundle; no functional change |

**Naming options for #24.** Primary recommendation: **Supporter Pack**. Alternatives to consider:

- **Lifetime Library** — emphasises "every current + every future"
- **All-Access Pass** — emphasises scope, slightly more casual
- **Patron Pack** — slightly more upscale tone

Pick one before Phase 5 ships; the choice should match the app's voice. **Supporter Pack** is recommended because it pairs naturally with the existing Supporter Badge (#23) and reinforces the "help fund the app you love" framing.

**Marketing copy.** "Buy once, get every cosmetic — now and forever. Help fund the app you love."

**No "limited founders" framing.** This pack is always available, always the same price, never goes away, and never sells out.

### 3.9 Catalog summary

| Pack | Items | Price range | Notes |
|---|---|---|---|
| Aurora | 4 | $1.99–$3.99 | Cohesive theme; good "first pack" |
| Neon | 4 | $1.99–$3.99 | Cohesive theme; appeals to a different aesthetic |
| Seasonal | 4 | $6.99 each | Only purchasable during seasonal window (§3.11); kept forever after |
| Typography | 3 | $1.99–$2.99 | Font licensing is the constraint |
| Haptics & Sound | 3 | $1.99 each | Tactile/auditory only |
| Widgets | 2 | $2.99–$3.99 | Widget-only |
| App Icon | 2 | $2.99 each | iOS handles the swap |
| Supporter | 2 | $0.99–$24.99 | Supporter Pack is the bundle |
| **Total** | **24** | **$0.99–$24.99** | **Price ceiling: $19.99 except the Supporter Pack at $24.99. Family Sharing: not offered on any product.** |

### 3.10 Bundles (separate from the Supporter Pack)

| Bundle | Contents | Price | Product ID |
|---|---|---|---|
| **Starter Pack** | Aurora Backgrounds + Aurora Lottie + Aurora Palette + Mono Code Font | $7.99 (save ~$4) | `com.saxweather.cosmetic.bundle.starter` |
| **Mega Pack: Aurora** | All 4 Aurora items | $7.99 (save ~$2) | `com.saxweather.cosmetic.bundle.aurora` |
| **Mega Pack: Neon** | All 4 Neon items | $7.99 (save ~$2) | `com.saxweather.cosmetic.bundle.neon` |
| **Mega Pack: Seasonal** | All 4 Seasonal items | $19.99 (save ~$8) | `com.saxweather.cosmetic.bundle.seasonal` |

**Supporter Pack supersedes bundles, not stacks with them.** A user who owns the Supporter Pack is treated as owning the Starter Pack, every Mega Pack, and every individual cosmetic — the same `owns(_:)` short-circuit in §4.1 returns `true` for any of them. They do not receive a refund of a bundle purchased earlier, but they cannot accidentally double-buy: the bundle tile in the store renders as "Owned" for Supporter Pack holders.

### 3.11 Seasonal Availability Model

This sub-section defines how the four seasonal packs (Halloween, Christmas, Pride, Autumn) are sold and equipped. The model has four parts: a fixed annual **purchase window**, **permanent ownership**, **free equip behaviour**, and the **StoreKit configuration** mechanism that makes it work.

#### 3.11.1 Purchase window

Each seasonal pack has a defined availability window. Outside the window:

- The product is **not offered by the App Store** (Apple's storefront gates the purchase).
- The in-app store tile shows **"Returns [date]"** or **"Out of season"** with the price greyed out.
- The product is **not hidden** — users can still see it, browse its preview, and add it to their App Store wishlist. They just can't buy it.

**Seasonal Calendar (proposed windows for v1):**

| Pack | Window (inclusive) | Length | Notes |
|---|---|---|---|
| Halloween | **Oct 1 – Nov 5** | ~5 weeks | Lands before the holiday; stays through Halloween week |
| Christmas | **Dec 1 – Jan 7** | ~5 weeks | Covers Advent + Christmas + New Year |
| Pride | **Jun 1 – Jul 7** | ~5 weeks | Covers Pride Month + early July |
| Autumn | **Sep 1 – Nov 30** | ~13 weeks | Longest window; covers the shoulder season where no other pack is active |

Windows are defined per-pack and may be adjusted in `CosmeticCatalog` config (e.g. extending Autumn a week into December one year). Each shipped v1 window above is deliberate: each pack gets roughly a month on sale, and the long Autumn window covers the "shoulder season" where no other pack is active. Total non-overlap is best-effort, not strict — the four windows are intentionally non-overlapping by design.

#### 3.11.2 Ownership permanence

Once purchased, the user owns the pack **forever**. The pack is a StoreKit non-consumable IAP — `Transaction.currentEntitlements` will keep returning it for the lifetime of the user's Apple ID. **Restoration always works on the same Apple ID.** Re-downloading the app, switching devices within the same Apple ID, and reinstalling after a factory reset all restore the pack automatically.

#### 3.11.3 Equip behaviour (no auto-unequip)

The cosmetic is a **normal cosmetic in the customisation picker**. The user can equip and unequip it freely, year-round. **There is no auto-unequip at season end.** A user who bought the Christmas Pack in December 2026 can still have the Christmas Lottie animation playing in July 2027 — that's their choice, and it's part of the "collect" model: you collect the pack during its window, you own the look, you keep using it whenever you like.

This also applies to widgets: a user who equipped Halloween on their widget does not have to re-equip every October.

#### 3.11.4 Widget parity

The same model applies in widget config (see §5.5). The widget configuration intent lists all four seasonal packs, each with a lock icon if unowned; tapping a locked item opens the in-app store to that pack's detail page via deep link. Equipping a seasonal pack on a widget is permanent (until the user changes it) — no auto-unequip.

#### 3.11.5 StoreKit configuration (the actual mechanism)

This is **a configuration concern, not a code concern.** The seasonal product is implemented by:

1. **Listing the product ID in [`SaxWeather/SaxWeather/configuration.storekit`](SaxWeather/configuration.storekit:1) year-round.** The product must always be declared so StoreKit and `Product.products(for:)` recognise it. Removing it seasonally would break restoration for users who already own it.
2. **Toggling availability in App Store Connect.** Each seasonal product is configured with a "Cleared for Sale" date range. Outside the window, Apple does not offer the product for purchase. Users who have already bought it are unaffected — non-consumable entitlements survive "out of stock" periods.
3. **Telling the in-app store when the window is active.** `CosmeticCatalog` exposes each seasonal pack's window as a static `availabilityWindow: DateInterval?` field. The Cosmetics Store view reads this to decide whether to render "Buy $6.99" or "Returns [date]" / "Out of season" on the tile.
4. **No code is required to disable the product** when the window closes — Apple does it for us. **The build shipped to the App Store can be the same binary year-round.**

This pattern mirrors how Apple Arcade titles handle seasonal content drops: the same binary sits on the store all year; the storefront gates purchases on a calendar.

#### 3.11.6 Marketing copy (no fake urgency)

The user explicitly does **not** want "Limited time only!" framing. Use honest copy:

| ❌ Never write | ✅ Write instead |
|---|---|
| "Limited time only!" | "Available until November 5" (only when in-window and the date is genuinely informative) |
| "Don't miss Halloween!" | "Get the Halloween Pack — returns next year on October 1" (out-of-season copy) |
| "Hurry — sale ends soon!" | (omit; no fake urgency) |
| "Last chance!" | (omit) |
| "Exclusive drop!" | (omit; nothing is exclusive) |

**In-season tile copy:** "Buy $6.99" (preferred) or "Available until November 5" (optional — only show if the window is short enough that the date adds value).

**Out-of-season tile copy:** "Out of season" or "Returns October 1". The price is greyed out and the "Buy" button is replaced with the returns-date label.

---

## 4. StoreKit / Architecture Plan

### 4.1 Refactor of [`SaxWeather/StoreManager.swift`](SaxWeather/StoreManager.swift:1)

The current `StoreManager` is hard-coded to a single product (`CustomBackground50c`) with a `customBackgroundUnlocked: Bool`. It needs to become a generic catalog loader with an entitlement set.

**New shape:**

```swift
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    /// Every product the app sells, loaded from `configuration.storekit`.
    /// Keyed by product ID for O(1) lookup.
    @Published private(set) var products: [String: Product] = [:]

    /// Every product ID the user owns (verified via StoreKit).
    /// Includes the Supporter Pack — see `owns(_:)` for the short-circuit.
    @Published private(set) var ownedProductIDs: Set<String> = []

    @Published var purchaseInProgress: String? = nil  // product ID, or nil
    @Published var purchaseError: String? = nil

    /// True if the user owns the given product, OR owns the Supporter Pack.
    /// This is the single short-circuit that turns the Supporter Pack into
    /// "unlock everything". One line; do not duplicate elsewhere.
    func owns(_ productID: String) -> Bool {
        ownedProductIDs.contains(productID)
            || ownedProductIDs.contains(CosmeticProductID.supporterPack)
    }

    /// Load all products declared in `configuration.storekit`.
    func loadProducts() async

    /// Refresh `ownedProductIDs` from `Transaction.currentEntitlements`.
    func refreshEntitlements() async

    /// Purchase a product by ID. Handles success / cancel / pending / unverified.
    func purchase(productID: String) async -> Bool

    /// Trigger `AppStore.sync()` and refresh entitlements.
    func restorePurchases() async
}
```

**Key changes from the current implementation:**

1. **Generic product loading.** `Product.products(for:)` is called with the full list of cosmetic product IDs (a static constant in `CosmeticCatalog`), not a single hard-coded ID.
2. **Entitlement set, not a single bool.** `ownedProductIDs: Set<String>` replaces `customBackgroundUnlocked: Bool`. The existing `customBackgroundUnlocked` becomes a computed property: `customBackgroundUnlocked = owns("CustomBackground50c")`.
3. **Supporter Pack short-circuit.** `owns(_:)` returns `true` if the user owns the Supporter Pack, so individual ownership checks don't need to special-case it. This single line is what makes the Supporter Pack's "every current + every future" promise enforceable in code.
4. **Per-product purchase state.** `purchaseInProgress: String?` lets the UI show a spinner on the specific tile being purchased, not a global "purchasing…" overlay.
5. **Transaction listener stays.** The `for await result in StoreKit.Transaction.updates` loop stays; it just updates `ownedProductIDs` instead of a single bool.

### 4.2 Extending [`SaxWeather/Services/CustomisationRegistry.swift`](SaxWeather/Services/CustomisationRegistry.swift:1) and [`BuiltInProfiles.swift`](SaxWeather/Services/BuiltInProfiles.swift:1)

The registry already knows about every cosmetic knob. We add a thin layer that knows which knobs are *paid*.

**New file: `SaxWeather/Services/CosmeticCatalog.swift`**

```swift
/// One paid cosmetic item in the catalog.
struct CosmeticItem: Identifiable, Hashable, Codable {
    let id: String                  // StoreKit product ID, e.g. "com.saxweather.cosmetic.aurora.backgrounds"
    let displayName: String         // "Aurora Backgrounds"
    let packID: String              // "aurora"
    let category: CosmeticCategory  // .backgrounds, .lottie, .palette, .icons, .font, .haptic, .sound, .widget, .appIcon, .supporter
    let summary: String             // One-line description
    let symbolName: String          // SF Symbol for the tile
    let previewImageName: String?   // Asset name for the preview thumbnail
    let widgetParity: Bool          // Does this apply to widgets too?
    let tier: PriceTier             // .micro, .standard, .premium, .bundle
    let availabilityWindow: DateInterval?  // nil for non-seasonal; set for the 4 seasonal packs
}

enum CosmeticCategory: String, Codable, CaseIterable {
    case backgrounds, lottie, palette, icons, font, haptic, sound
    case widget, appIcon, supporter
}

enum PriceTier: String, Codable {
    case micro, standard, premium, bundle
}

/// The full catalog. Static — declared in code, not fetched from a server.
enum CosmeticCatalog {
    static let all: [CosmeticItem] = [
        // Aurora
        .init(id: "com.saxweather.cosmetic.aurora.backgrounds", ...),
        .init(id: "com.saxweather.cosmetic.aurora.lottie", ...),
        .init(id: "com.saxweather.cosmetic.aurora.palette", ...),
        .init(id: "com.saxweather.cosmetic.aurora.chart", ...),
        // ... 20 more
    ]

    static func item(for productID: String) -> CosmeticItem? {
        all.first { $0.id == productID }
    }

    static func items(in packID: String) -> [CosmeticItem] {
        all.filter { $0.packID == packID }
    }
}
```

**How the registry uses it:**

The registry doesn't need to know about StoreKit directly. It exposes a single read-only helper:

```swift
extension CustomisationRegistry {
    /// True if the user can apply the given cosmetic item.
    /// Reads from `StoreManager.shared.owns(_:)`.
    func canApply(_ item: CosmeticItem) -> Bool {
        StoreManager.shared.owns(item.id)
    }
}
```

**How individual knobs learn they're paid:**

We extend [`SaxWeather/Services/KnobDescriptor.swift`](SaxWeather/Services/KnobDescriptor.swift:74) with a new helper, parallel to the existing `requiresCustomBackgroundIAP`:

```swift
extension KnobDescriptor {
    /// The StoreKit product ID that unlocks this knob, if any.
    /// `nil` for free knobs.
    var requiredProductID: String? {
        switch id {
        case "backgroundMode" where /* aurora or neon selected */:
            return "com.saxweather.cosmetic.aurora.backgrounds"
        // ... etc
        default: return nil
        }
    }
}
```

But this gets messy fast. **Cleaner approach:** the *value* of a knob carries the product ID, not the knob descriptor. For example, `BackgroundMode` gets new cases:

```swift
enum BackgroundMode: String, Codable, CaseIterable, Hashable {
    case preset, customImage, gradient, dynamicAccent
    case aurora, neon  // paid
    case halloween, christmas, pride, autumn  // paid, seasonal
}
```

And a single helper resolves "is this mode paid?":

```swift
extension BackgroundMode {
    var requiredProductID: String? {
        switch self {
        case .aurora:     return "com.saxweather.cosmetic.aurora.backgrounds"
        case .neon:       return "com.saxweather.cosmetic.neon.backgrounds"
        case .halloween:  return "com.saxweather.cosmetic.seasonal.halloween"
        case .christmas:  return "com.saxweather.cosmetic.seasonal.christmas"
        case .pride:      return "com.saxweather.cosmetic.seasonal.pride"
        case .autumn:     return "com.saxweather.cosmetic.seasonal.autumn"
        default:          return nil
        }
    }

    var availabilityWindow: DateInterval? {
        switch self {
        case .halloween:  return DateInterval(start: ..., end: ...) // Oct 1 – Nov 5
        case .christmas:  return DateInterval(start: ..., end: ...) // Dec 1 – Jan 7
        case .pride:      return DateInterval(start: ..., end: ...) // Jun 1 – Jul 7
        case .autumn:     return DateInterval(start: ..., end: ...) // Sep 1 – Nov 30
        default:          return nil
        }
    }
}
```

This pattern repeats for `LottieAnimationSet`, `WeatherIconStyle`, `TypographyFamily`, `Palette` (via a `palettePreset` enum), `WidgetBackground`, etc. **Every paid option carries its own product ID and (if seasonal) its own availability window.** The UI checks `StoreManager.shared.owns(mode.requiredProductID ?? "")` before allowing the selection.

### 4.3 `OwnedCosmetics` / `EntitlementStore` design

**No new persistence layer needed.** StoreKit 2's `Transaction.currentEntitlements` is the source of truth. We mirror it into a `@Published Set<String>` on `StoreManager` for fast UI checks.

**Why no UserDefaults mirror?** Because StoreKit already persists across reinstalls via Apple ID. A local mirror would just be a cache that can drift. We *do* keep a transient in-memory cache (`ownedProductIDs`) for the lifetime of the app process.

**Why no CloudKit?** Because StoreKit already syncs across the user's devices via Apple ID. Adding CloudKit would duplicate that and create conflict-resolution headaches. The only thing CloudKit would buy us is "see what I bought on a device that hasn't restored yet" — which is a rare edge case not worth the complexity.

**Receipt validation:** StoreKit 2's `VerificationResult<Transaction>` is the validation. We only act on `.verified` transactions. `.unverified` transactions are logged in DEBUG and ignored.

**Supporter Pack enforcement.** The single short-circuit in `owns(_:)` (§4.1) is what implements the "every current + every future" promise. When a new cosmetic is added in a future version:

1. The new product ID is added to `CosmeticCatalog.all` and to `configuration.storekit` (with `familyShareable: false`).
2. No `owns(_:)` change is required — the short-circuit already returns `true` for the new product ID, because it returns `true` for every product ID when `supporterPack` is owned.
3. A user who owns the Supporter Pack sees the new cosmetic as "Owned" in the store and can equip it immediately.

This is the one place in the codebase where "future-proofing" happens at the entitlement layer rather than the data layer.

### 4.4 Restore-purchases UX flow

1. **Automatic on launch.** `StoreManager.init()` calls `refreshEntitlements()` which iterates `Transaction.currentEntitlements`. No user action needed.
2. **Manual restore button.** In the Cosmetics Store's "My Cosmetics" tab, a "Restore Purchases" button calls `restorePurchases()` which calls `AppStore.sync()` then `refreshEntitlements()`.
3. **Settings entry point.** A "Restore Purchases" row in Settings → Support section, for users who can't find the button in the store.

**Note on seasonal packs and restore.** A user who buys the Halloween Pack in October and reinstalls in March will see Halloween as "Out of season" in the store (no Buy button), but it remains in `ownedProductIDs` and the user can still equip it year-round. Restoration never loses entitlements, even when the product is off-sale.

### 4.5 Refund / family-sharing considerations

- **Refunds:** Apple's standard flow. If a user requests a refund via `Transaction.refundRequestSheet`, we don't need to do anything — StoreKit handles it. We *do* listen for `.revoked` transactions in the `Transaction.updates` loop and remove the product ID from `ownedProductIDs`.
- **No Family Sharing.** Every cosmetic product — including the Supporter Pack and every bundle — has `familyShareable: false` in `configuration.storekit` and in App Store Connect. **Restoration works on the same Apple ID only.** If a user signs in on a new device with a different Apple ID, none of their cosmetics carry over. This is the documented behaviour and matches the existing configuration of `CustomBackground50c` and every Tip Jar product in [`SaxWeather/SaxWeather/configuration.storekit`](SaxWeather/configuration.storekit:1).
- **Account changes:** If the user signs out of their Apple ID, `Transaction.currentEntitlements` returns empty. We don't try to detect this; we just re-render with no owned cosmetics. The user can sign back in and tap "Restore Purchases".

### 4.6 Server-side requirements

**None.** StoreKit + Apple ID handles everything. No backend, no receipt-validation server, no CloudKit. This is a deliberate choice:

- **Lower operational cost.** No server to run, monitor, or secure.
- **Better privacy.** No user data leaves the device except the anonymous StoreKit transaction.
- **Simpler compliance.** No GDPR/CCPA server-side concerns.
- **Trade-off:** No cross-device sync beyond what Apple ID already provides. If a user buys on iPhone and opens the app on iPad for the first time before iCloud syncs the receipt, they won't see the cosmetic until they tap "Restore Purchases". This is acceptable — it's how every other StoreKit-only app works.

---

## 5. UI / UX Surfaces

### 5.1 The Cosmetics Store view

A new view, separate from [`SaxWeather/TipJarView.swift`](SaxWeather/TipJarView.swift:1). Lives at `SaxWeather/Views/Cosmetics/CosmeticsStoreView.swift`.

**Structure:**

```
CosmeticsStoreView
├── Header
│   ├── Title: "Cosmetics"
│   ├── Subtitle: "Personalise SaxWeather. Every cosmetic is optional."
│   └── "Restore Purchases" button (top-right)
├── Featured carousel (horizontal scroll)
│   └── 3-4 highlighted items (e.g. "Aurora Pack — 4 items, $7.99")
├── Category grid (vertical scroll)
│   ├── Section: Backgrounds
│   │   └── Tile × N (Aurora, Neon, Halloween, Christmas, Pride, Autumn, …)
│   ├── Section: Animations
│   │   └── Tile × N
│   ├── Section: Accent Palettes
│   │   └── Tile × N
│   ├── Section: Weather Icons
│   │   └── Tile × N
│   ├── Section: Typography
│   │   └── Tile × N
│   ├── Section: Haptics & Sound
│   │   └── Tile × N
│   ├── Section: Widgets
│   │   └── Tile × N
│   ├── Section: App Icons
│   │   └── Tile × N
│   └── Section: Supporter
│       └── Tile × N (Supporter Badge, Supporter Pack)
└── Footer
    └── "All cosmetics are optional. SaxWeather is fully functional without any purchase."
```

**Tile states:**

| State | Visual | Tap action |
|---|---|---|
| **Owned** | Green checkmark badge, "Owned" label, no price | Opens preview / "Apply" |
| **Buy** | Price label, "Buy" button | Opens pack detail sheet |
| **Out of season** | Greyed-out price, "Returns [date]" label, no Buy button | Opens preview (free preview still allowed) |
| **Preview** | "Preview" button (no price) | Applies to a temporary preview profile for 30 seconds |

**Pack detail sheet:**

```
PackDetailSheet (e.g. "Aurora Pack")
├── Hero image (the pack's signature visual)
├── Title + summary
├── "What's included" list (4 items with thumbnails)
├── Price + "Buy Pack" button (or "Owned" if already purchased, or "Out of season" if seasonal & off-window)
├── "Preview Pack" button (applies all 4 items to a preview profile)
└── Footer: "This pack changes only visuals. No features are affected."
```

### 5.2 Entry point in [`SaxWeather/SettingsView.swift`](SaxWeather/SettingsView.swift:1)

Add a new row in the existing settings tree, between "Switch Profile" and "Backup & Restore":

```swift
Button {
    showingCosmeticsStore = true
} label: {
    HStack {
        Label("Cosmetics Store", systemImage: "paintpalette.fill")
        Spacer()
        if ownedCount > 0 {
            Text("\(ownedCount) owned")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

The icon is `paintpalette.fill` (distinct from `paintbrush.fill` used for Appearance). The label is "Cosmetics Store" (not "Buy Cosmetics" or "Unlock More" — neutral framing).

### 5.3 Preview-on-actual-forecast flow

The killer feature. When a user taps "Preview" on a cosmetic tile:

1. **Snapshot the current profile.** `let snapshot = CustomisationRegistry.shared.profile`.
2. **Apply the cosmetic to a temporary preview profile.** Create a new `CustomisationProfile` with the cosmetic's knobs overridden, apply it.
3. **Show a banner.** A non-dismissible banner at the top of the home screen: "Previewing Aurora Backgrounds — [Buy $3.99] [Restore Previous]". The banner has a 30-second auto-restore timer.
4. **User navigates the app normally.** They see the cosmetic on their actual forecast, not a mock.
5. **Restore.** Tapping "Restore Previous" or waiting 30 seconds restores the snapshot.

This is implemented as a new `PreviewProfileManager` (singleton, `@MainActor`):

```swift
@MainActor
final class PreviewProfileManager: ObservableObject {
    @Published private(set) var isPreviewing: Bool = false
    @Published private(set) var previewingItem: CosmeticItem? = nil
    private var snapshot: CustomisationProfile? = nil
    private var restoreTask: Task<Void, Never>? = nil

    func startPreview(of item: CosmeticItem) {
        snapshot = CustomisationRegistry.shared.profile
        // Apply the cosmetic's knobs to a copy of the profile
        var preview = snapshot!
        applyCosmetic(item, to: &preview.knobs)
        CustomisationRegistry.shared.apply(preview)
        previewingItem = item
        isPreviewing = true
        restoreTask = Task {
            try? await Task.sleep(for: .seconds(30))
            if !Task.isCancelled { await self.restore() }
        }
    }

    func restore() {
        guard let snapshot = snapshot else { return }
        CustomisationRegistry.shared.apply(snapshot)
        restoreTask?.cancel()
        isPreviewing = false
        previewingItem = nil
        self.snapshot = nil
    }
}
```

The banner is a new view modifier on `ContentView`:

```swift
.overlay(alignment: .top) {
    if previewManager.isPreviewing, let item = previewManager.previewingItem {
        PreviewBanner(item: item, onBuy: { ... }, onRestore: { previewManager.restore() })
    }
}
```

**Preview is allowed even when a seasonal pack is out of window.** Users can preview Halloween in July without buying it; the preview just won't have a "Buy" button until October 1.

### 5.4 Subtle "Thank you" treatment

For users who own **any** paid cosmetic, a small "☕ Supporter" badge appears next to the version number in Settings → About.

The badge is **not** shown:
- On the home screen
- In the widget
- In the leaderboard
- Anywhere visible to other users
- In the App Store listing

This is deliberate. The badge is a private acknowledgement, not a status symbol.

**Supporter Pack holders.** Because the Supporter Pack's `owns(_:)` short-circuit returns `true` for every cosmetic, a Supporter Pack holder automatically counts as "owns any paid cosmetic" and gets the badge for free.

### 5.5 Widgets: Widget Theme picker (locked tiles shown)

The widget configuration intent ([`SaxWeather/SaxWeatherWidget/AppIntent.swift`](SaxWeather/SaxWeatherWidget/AppIntent.swift:1)) gets a new parameter:

```swift
struct SelectWidgetThemeIntent: WidgetConfigurationIntent {
    @Parameter(title: "Theme") var theme: WidgetThemeEntity?
}
```

Where `WidgetThemeEntity` is an `AppEntity` that lists:
- **System** (free, default)
- **Glass** (free, uses the existing glass material)
- **Newspaper** (paid, requires `com.saxweather.cosmetic.widget.themes`)
- **Terminal** (paid, requires `com.saxweather.cosmetic.widget.themes`)
- **Aurora** (paid, requires `com.saxweather.cosmetic.widget.themes`)

**Locked items are shown, not hidden.** The widget configuration intent lists **all** widget themes — including unowned ones — each with a small **lock icon overlay** if the user doesn't own it. Tapping a locked item opens the in-app store at that item's detail page via a deep link. This mirrors the main app's UX and avoids the surprise of items "missing" from the picker.

The same pattern applies to seasonal cosmetic choices made from a widget intent (e.g. a future intent that lets the user pick a background pack for their widget): unowned items appear with a lock icon and deep-link to the store. Out-of-season packs are visible in the picker too, with the same "Returns [date]" copy the in-app store uses.

**Implementation requirement.** Showing locked tiles requires a URL scheme that opens the store to a specific cosmetic detail. The URL scheme must be:

- Registered in [`SaxWeather/SaxWeather/Info.plist`](SaxWeather/Info.plist:1) under `CFBundleURLTypes` — proposed scheme: `saxweather://cosmetic/<productID>`.
- Handled by [`SaxWeather/SaxWeather/SaxWeatherApp.swift`](SaxWeather/SaxWeatherApp.swift:1) — the app routes the URL to `CosmeticsStoreView` with a "focus this item" parameter, which scrolls to and highlights the tile.

This is a small amount of plumbing (≈20 lines of code in the widget extension + a URL handler in `SaxWeatherApp`), but it must be done before any locked-tile UX ships. **Plan for it in Phase 2 (the foundation for Widgets) rather than leaving it for a later phase.**

If a user manages to select a paid theme they don't own (e.g. via a stale widget configuration from an earlier install), the widget falls back to System with a small "Unlock" affordance that opens the app to the Cosmetics Store.

---

## 6. Ethical / Trust Considerations

### 6.1 Localised copy guidelines

All store copy must follow these rules. No exceptions.

| ❌ Never write | ✅ Write instead |
|---|---|
| "Limited time only!" | (omit; cosmetics are permanent once owned) or "Available until November 5" (seasonal in-window only) |
| "Only 3 left!" | (omit; digital goods are unlimited) |
| "Unlock Aurora Backgrounds" | "Get Aurora Backgrounds" |
| "Don't miss out!" | (omit) |
| "50% OFF — Today Only!" | (omit; no fake discounts) |
| "Exclusive!" | (omit; nothing is exclusive) |
| "Premium" (as a value claim) | "Premium tier" (as a price tier) |
| "You won't believe how this looks!" | (omit; let the preview speak) |
| "Founders only" | (omit; we have no Founders tier — the equivalent is the always-available Supporter Pack) |

**Tone:** Calm, factual, friendly. The store copy reads like a museum gift shop, not a casino.

### 6.2 Accessibility

Every paid cosmetic must:

1. **Respect Dynamic Type.** All text in previews and pack detail sheets must scale with the user's preferred content size category.
2. **Respect Reduce Motion.** All Lottie animations must have a static fallback. The existing `disableWeatherAnimations` and `reduceMotion` knobs already handle this — paid Lottie sets must honour them.
3. **Respect Increase Contrast.** All preview thumbnails must have sufficient contrast. The pack detail sheet must pass WCAG AA contrast.
4. **Provide VoiceOver labels.** Every tile, button, and preview image must have a meaningful `accessibilityLabel`.
5. **Provide free accessible equivalents.** For every paid cosmetic, there must be a free alternative that achieves a similar visual effect:
   - Paid background image → free custom-image background (user-supplied)
   - Paid Lottie animation → free SF Symbol fallback (already exists)
   - Paid palette → free arbitrary RGB/hex colour (already exists)
   - Paid font → free system font family (already exists)
   - Paid haptic pattern → free system haptic intensity (already exists)
   - Paid weather icon → free SF Symbol (already exists)

### 6.3 Regional pricing

We set US tier prices only. App Store handles purchasing-power parity automatically. We do **not**:

- Run our own regional pricing logic
- Offer regional discounts outside App Store's system
- Use price as a manipulative lever (e.g. "lower price in developing countries to drive volume")

We **do**:

- Set US prices that are reasonable for each tier
- Let App Store's "equivalent tier" pricing handle the rest
- Monitor conversion rates by region in App Store Connect (aggregate, anonymous)

---

## 7. Pricing & Bundle Strategy

### 7.1 Per-item pricing

See §3 for the full table. Summary:

| Tier | Price range | Items |
|---|---|---|
| Micro | $0.99–$1.99 | Supporter Badge, Mono Code Font, Handwritten Font, Rain Haptics, Wind Haptics, Synth Sounds, Aurora Palette, Aurora Chart, Neon Palette |
| Standard | $2.99–$4.99 | Aurora Backgrounds, Aurora Lottie, Neon Backgrounds, Neon Lottie, Neon Icons, Editorial Font, Widget Backgrounds, Widget Themes, App Icon Packs |
| Premium | $6.99–$9.99 | Seasonal Packs (4) |
| Bundle | $7.99–$19.99 | Starter Pack ($7.99), Mega Pack: Aurora ($7.99), Mega Pack: Neon ($7.99), Mega Pack: Seasonal ($19.99) |
| **Supporter Pack** | **$24.99** | **Single SKU; unlocks every current and every future cosmetic** |

**Price ceiling:** **$19.99 for any individual item or bundle, with the explicit, documented exception of the Supporter Pack at $24.99.** The previous $19.99 ceiling has been lifted for this single SKU because the Supporter Pack's promise — "every current + every future" — is a meaningfully bigger commitment than any single pack.

**Family Sharing:** not offered on any tier.

### 7.2 Starter Pack

**$7.99** — Aurora Backgrounds + Aurora Lottie + Aurora Palette + Mono Code Font. Saves ~$4 vs. buying individually. Designed as the "I want to try cosmetics but I'm not sure" entry point.

### 7.3 Mega Packs

- **Mega Pack: Aurora** — $7.99 (all 4 Aurora items, save ~$2)
- **Mega Pack: Neon** — $7.99 (all 4 Neon items, save ~$2)
- **Mega Pack: Seasonal** — $19.99 (all 4 Seasonal items, save ~$8)

### 7.4 Supporter Pack

**$24.99, `familyShareable: false`, always available, never seasonal.** Unlocks every current cosmetic and **every future cosmetic** added to the app, permanently. Labelled:

> "Buy once, get every cosmetic — now and forever. Help fund the app you love."

This is **not** a hedged promise. The Supporter Pack is a firm commitment: any new cosmetic added in a future version is automatically included. The only way we could ever remove this commitment is to (a) introduce a separate product line (e.g. "Pro Cosmetics") that is **not** included in the Supporter Pack, or (b) version the catalog with a clear "added after v1.x" cutoff. **Neither is in scope for v1.**

**Family Sharing:** Off (see §1.2 and §4.5). The single purchase covers the buyer's devices only — same Apple ID, no household sharing.

**Supersedes bundles.** A user who owns the Supporter Pack is treated as owning the Starter Pack, every Mega Pack, and every individual cosmetic. This is enforced by the `owns(_:)` short-circuit in [`SaxWeather/SaxWeather/StoreManager.swift`](SaxWeather/SaxWeather/StoreManager.swift:267) — a one-line change that does not need to be repeated in the UI layer.

**Why $24.99 (justified).** The previous $19.99 ceiling was self-imposed for individual packs. The Supporter Pack breaks that ceiling because it carries an explicit, unhedged promise of "every future cosmetic". Pricing it at $19.99 would understate that commitment; pricing it at $29.99 would feel like a stretch for an indie weather app. $24.99 sits in the "premium one-time IAP" tier alongside Things 3's iPhone upgrade and similar indie commitments, and aligns with the user's instruction to lift the ceiling for this single SKU.

**Naming.** Primary recommendation: **Supporter Pack**. Alternatives considered: **Lifetime Library**, **All-Access Pass**, **Patron Pack**. Pick one before Phase 5 ships. (§3.8 has the full rationale.)

### 7.5 Explicit recommendation against subscriptions

**We recommend against a subscription model for cosmetics.** Rationale:

1. **Trust.** Subscriptions create churn anxiety. Users who feel "locked in" to a subscription resent it. Cosmetics are a one-time joy; subscriptions are a recurring cost.
2. **App Store favour.** Apple has publicly stated they prefer one-time IAPs over subscriptions for non-content apps. Subscriptions face stricter review.
3. **No churn.** A subscription requires constant re-engagement ("are you still getting value?"). A one-time IAP is a single moment of delight.
4. **Simpler accounting.** No MRR to track, no churn rate to worry about, no dunning.
5. **Aligns with the app's ethos.** SaxWeather is "free, ad-free, no tracking". A subscription feels at odds with that ethos. A one-time IAP feels like a tip jar with extra steps.

If we ever need recurring revenue, the Tip Jar (consumable) is the right mechanism, not a cosmetics subscription.

---

## 8. Implementation Phasing

Five phases. Each is independently shippable. Each unblocks the next.

### 8.1 Phase 1 — Foundation + 3 items

**Goal:** Prove the architecture with a minimal catalog.

**Cosmetics shipped:**
- Aurora Backgrounds ($3.99)
- Aurora Palette ($1.99)
- Supporter Badge ($0.99)

**Engineering work:**
- Refactor `StoreManager` to support multiple products (§4.1)
- Add `CosmeticCatalog` and `CosmeticItem` (§4.2)
- Add `BackgroundMode.aurora` case + `requiredProductID` helper
- Add `Palette` preset enum (or extend `Palette` with a `preset: PalettePreset?` field)
- Add `PreviewProfileManager` (§5.3)
- Add `CosmeticsStoreView` with Featured + Category grid (§5.1)
- Add Settings entry point (§5.2)
- Add "Supporter" badge to Settings → About (§5.4)
- Update `configuration.storekit` with the 3 new product IDs (all `familyShareable: false`)

**Asset work:**
- 8 aurora-themed background JPEGs (≤ 200 KB each)
- 1 aurora palette (5 colour tokens)
- 1 supporter badge SF Symbol (or text)

**Marketing/ASO angle:**
- "SaxWeather now has a Cosmetics Store — make it yours."
- App Store screenshot update showing Aurora Backgrounds

**Effort:** M

### 8.2 Phase 2 — Aurora Pack complete + Neon Pack + Widget foundation

**Goal:** Ship the first two cohesive packs, plus the widget-side foundation (URL scheme + locked-tile scaffolding) that Phase 3 needs.

**Cosmetics shipped:**
- Aurora Lottie ($3.99)
- Aurora Hourly Chart Skin ($1.99)
- Neon Backgrounds ($3.99)
- Neon Lottie ($3.99)
- Neon Palette ($1.99)
- Neon Weather Icons ($2.99)
- Starter Pack bundle ($7.99)
- Mega Pack: Aurora bundle ($7.99)
- Mega Pack: Neon bundle ($7.99)

**Engineering work:**
- Add `LottieAnimationSet.aurora` and `.neon` cases
- Add `WeatherIconStyle.neon` case + neon icon assets
- Add `ChartSkin` enum + `ForecastSpec.chartSkin` field
- Add bundle product IDs to `configuration.storekit` (all `familyShareable: false`)
- Add "Preview Pack" button to pack detail sheet
- **Register `saxweather://cosmetic/<productID>` URL scheme** in `Info.plist`
- **Handle deep links in `SaxWeatherApp`** to route to a specific cosmetic detail
- Add `WidgetThemeEntity` to widget extension (locked-tile UX scaffolded but not yet visible — widget themes ship in Phase 3)

**Asset work:**
- 10 aurora Lottie animations
- 10 neon Lottie animations
- 11 neon weather icons (PNG/SVG)
- 1 aurora chart skin (gradient definition)
- 1 neon palette

**Marketing/ASO angle:**
- "Two new packs: Aurora and Neon. Pick your vibe."
- Featured carousel in the store

**Effort:** L

### 8.3 Phase 3 — Halloween Pack + Widgets (theme skins)

**Goal:** Ship the first seasonal pack (Halloween) ahead of October, plus widget themes that can be locked/unlocked. **The build for this phase is submitted to the App Store with the seasonal product configured in `configuration.storekit`, but the product is enabled in App Store Connect only during the Oct 1 – Nov 5 window.** Outside the window, the in-app store tile shows "Returns October 1" with the price greyed out — but the binary itself does not change.

**Cosmetics shipped:**
- Halloween Pack ($6.99) — **first seasonal pack** (window Oct 1 – Nov 5)
- Widget Background Images ($2.99)
- Widget Theme Skins ($3.99)

**Engineering work:**
- Add `LottieAnimationSet.halloween` case
- Add `BackgroundMode.halloween` case + `requiredProductID` + `availabilityWindow` helpers (§4.2)
- Add `WeatherIconStyle.halloween` case + icon assets
- Add Halloween palette preset
- Add `WidgetBackground.userImagePack` enum
- Add `WidgetTheme` enum + `WidgetSpec.theme` field
- Wire up `SelectWidgetThemeIntent` to show **locked-tile UX** (lock icon on unowned themes, deep-links to store via the URL scheme from Phase 2)
- Add `com.saxweather.cosmetic.seasonal.halloween` product ID to `configuration.storekit` (year-round, `familyShareable: false`)
- Configure the Halloween product in **App Store Connect** with availability window Oct 1 – Nov 5
- Add `CosmeticCatalog.availabilityWindow` for Halloween
- Out-of-season tile UI ("Returns October 1" copy + greyed-out price)

**Asset work:**
- 8 Halloween background JPEGs
- 10 Halloween Lottie animations
- 11 Halloween weather icons
- 1 Halloween palette
- 6 widget background JPEGs
- 1 Widget Theme Skins thumbnail

**Marketing/ASO angle:**
- "Get into the spirit" copy for Halloween (only during the window — no in-app push outside the window)
- Push notification (opt-in) when the Halloween Pack goes on sale (Oct 1)
- App Store screenshot showing widget themes

**Effort:** L

### 8.4 Phase 4 — Remaining Seasonal Packs + App Icons + Typography + Haptics & Sound

**Goal:** Complete the seasonal lineup and ship the rest of the visual surface (app icons, fonts, haptics, sound).

**Cosmetics shipped:**
- Christmas Pack ($6.99) — window Dec 1 – Jan 7
- Pride Pack ($6.99) — window Jun 1 – Jul 7 (no charity hook — see §3.3 note)
- Autumn Pack ($6.99) — window Sep 1 – Nov 30
- App Icon Pack: Minimal ($2.99)
- App Icon Pack: Illustrated ($2.99)
- Editorial Font Set ($2.99)
- Mono Code Font Set ($1.99)
- Handwritten Font Set ($1.99)
- Rain Haptic Pack ($1.99)
- Wind Haptic Pack ($1.99)
- Synth Refresh Sound Pack ($1.99)
- Mega Pack: Seasonal bundle ($19.99)

**Engineering work:**
- Add `LottieAnimationSet.christmas`, `.pride`, `.autumn` cases
- Add corresponding `BackgroundMode`, `WeatherIconStyle`, palette presets (each with `requiredProductID` + `availabilityWindow`)
- Add `UIApplication.shared.setAlternateIconName(_:)` integration
- Extend `TypographyFamily` with 3 new cases
- Register fonts in `Info.plist` (`UIAppFonts`)
- Add Core Haptics pattern playback to `HapticFeedbackHelper`
- Add custom sound playback to refresh-sound path
- Add the three new seasonal product IDs to `configuration.storekit` (year-round, `familyShareable: false`)
- Configure each seasonal product in **App Store Connect** with its respective window

**Asset work:**
- 8 backgrounds × 3 packs = 24 JPEGs
- 10 Lottie × 3 packs = 30 Lottie animations
- 11 icons × 3 packs = 33 weather icons
- 3 palettes
- 8 app icons (1024×1024 each, all required sizes)
- 4 font files (`.ttf` or `.otf`) — **font licensing is the constraint here**
- 2 `.ahap` Core Haptics pattern files
- 3 `.caf` audio files

**Marketing/ASO angle:**
- Seasonal push notifications (opt-in) for each new pack on its sale date
- "Personalise your home screen" copy for App Icon Packs
- Font pack launch: editor-style promo screenshots

**Effort:** L

### 8.5 Phase 5 — Supporter Pack + polish

**Goal:** The always-available bundle that unlocks every current and every future cosmetic, plus final polish.

**Cosmetics shipped:**
- **Supporter Pack ($24.99, `familyShareable: false`)** — unlocks every current and every future cosmetic

**Engineering work:**
- Add `com.saxweather.cosmetic.supporter.pack` product ID to `configuration.storekit`
- Update `StoreManager.owns(_:)` to short-circuit on `.supporterPack` (the one-line change in §4.1)
- Add "Supporter Pack" tile to Supporter section
- Add "Buy once, get every cosmetic — now and forever. Help fund the app you love." copy on the Supporter Pack detail sheet
- Confirm Supporter Pack holders automatically receive the "Supporter" badge in Settings → About (§5.4)
- Confirm `CosmeticCatalog.all` returns `isOwned = true` for every cosmetic when Supporter Pack is owned (verify with a unit test that adds a new mock cosmetic and confirms it shows as owned for a Supporter Pack holder — this is the "future-proof" acceptance test)
- Add "Restore Purchases" button to Settings → Support
- Final pass on accessibility audit
- Final pass on App Store review checklist
- Confirm all seasonal product IDs are still listed in `configuration.storekit` (they should be — they live there year-round)

**Asset work:**
- 1 Supporter Pack hero image
- 1 Supporter Pack tile thumbnail

**Marketing/ASO angle:**
- "Support development and unlock every cosmetic — now and forever."
- No "Founders" framing; honest "always-available" copy
- Email existing supporters (with consent) about the Supporter Pack

**Effort:** S

---

## 9. Risks & Open Questions

### 9.1 Apple App Store review risk areas

**Guideline 3.1.1 — In-App Purchase:**
- We must not mention prices outside the IAP sheet (no "Only $3.99!" in the store description).
- We must not direct users to external purchase mechanisms.
- We must use StoreKit's `Product.displayPrice` for all price display, not hard-coded strings.

**Guideline 3.1.5 — Developer Code of Conduct:**
- No manipulative urgency ("Limited time!", "Only 3 left!").
- No dark patterns (pre-checked boxes, hidden opt-outs).
- Clear disclosure of what each purchase includes.

**Guideline 5.2.1 — General App Review:**
- The Supporter Pack's "every current and every future cosmetic" promise must be accurate. If we add a Pro Cosmetics line in a later version, we must clearly disclose that those new cosmetics are *not* included in the original Supporter Pack.

**Mitigation:** Submit each phase to TestFlight early. The seasonal pack windows should be tested on a sandbox account before App Store submission.

### 9.2 Widget extension size limit impact

Widget extensions have a ~30 MB memory budget. Bundled assets count against this.

**Mitigation:**
- Widget background images are ≤ 100 KB each (6 images = ≤ 600 KB total).
- Widget Lottie animations are **not** bundled in the widget extension. The widget always uses the shipped `Assets.xcassets` backgrounds, just retinted by the active palette.
- Widget theme skins are pure code (no assets).

### 9.3 Asset pipeline / Lottie authoring workflow

We need a repeatable process for creating Lottie animations.

**Recommendation:**
- **Tool:** LottieFiles + After Effects, or Rive (for newer animations).
- **Authoring guidelines:** Max 60 fps, max 200 layers, max 500 KB per JSON file, transparent background, loop seamlessly.
- **Review:** Every Lottie must be reviewed on-device before shipping. Lottie previews in browsers are not representative.
- **Versioning:** Lottie JSON files are committed to the repo. No runtime download.

### 9.4 Font licensing

Custom fonts require a licence. We must:

- Use fonts with permissive licences (SIL Open Font Licence, Apache 2.0) **or**
- Purchase commercial licences for each font we ship
- Include the licence file in the app bundle
- Credit the font designer in the Attribution settings

**Recommendation:** Start with SIL OFL fonts (Google Fonts has many). Avoid commercial fonts unless the licence is clear.

### 9.5 Closed decisions and remaining questions

The five open questions from draft v1 are now closed by user decisions:

| # | Original question | Resolution |
|---|---|---|
| 1 | Pride Pack charity: which charity, donation mechanism? | **Closed.** No charity integration in v1. Pride Pack is a normal seasonal cosmetic. |
| 2 | Seasonal pack availability: year-round or in-season only? | **Closed.** In-season only, with a defined annual window per pack (§3.11). Once bought, owned forever. |
| 3 | Founders Pack future cosmetics clause: hedge or commit? | **Closed.** Commit. **Supporter Pack at $24.99 unlocks every current and every future cosmetic — no hedge.** |
| 4 | Family Sharing scope: Founders-only, or all packs? | **Closed.** **No Family Sharing on any product** (§1.2, §4.5). |
| 5 | Refund policy: own button, or Apple only? | **Closed.** Apple only. Surface `Transaction.refundRequestSheet` if asked. |

**Two new questions surfaced by the revised plan:**

1. **Supporter Pack name.** Primary recommendation is **"Supporter Pack"**. Alternatives: **"Lifetime Library"**, **"All-Access Pass"**, **"Patron Pack"**. Confirm before Phase 5 ships. *(See §3.8 for the full rationale.)*
2. **Should the "Supporter" badge eligibility include Supporter Pack owners automatically?** The Supporter Badge (#23, $0.99) is a separate purchase. Owners of the Supporter Pack auto-own the Supporter Badge via the `owns(_:)` short-circuit — but they paid $24.99 vs. $0.99, and might reasonably expect the badge to "feel" earned, not bundled. Recommendation: **yes, include it** — the pack's promise is "every cosmetic", and the badge is one of them. Confirm or override before Phase 5.

(Removed from v1: the open questions about Pride Pack charity, seasonal availability, Founders Pack clause, Family Sharing scope, and refund policy — all decided.)

---

## 10. Success Metrics (non-invasive)

### 10.1 Soft KPIs

We track these via StoreKit 2's built-in analytics and App Store Connect. **No third-party analytics SDK. No tracking pixels. No fingerprinting.**

| Metric | Source | What it tells us |
|---|---|---|
| `productView` impressions | StoreKit 2 `ProductView` events (iOS 17+) | How many users see each cosmetic tile |
| Conversion rate | StoreKit 2 purchase events | What % of viewers buy |
| Top sellers | App Store Connect sales report | Which items resonate |
| Restore rate | `AppStore.sync()` calls | How many users need to manually restore |
| Refund rate | App Store Connect refund report | Quality signal — high refund rate = misleading copy |
| Supporter Pack attach rate | App Store Connect | What % of buyers also buy the Supporter Pack |
| Seasonal pack purchase window distribution | App Store Connect (date-of-purchase) | Are users buying at the start, middle, or end of the window? |

### 10.2 Explicit non-goals

We **do not** track:

- User identity (no Apple ID association)
- Device fingerprinting
- Cross-app tracking
- In-app behaviour (which tiles were tapped, how long the preview was shown)
- Geographic distribution beyond App Store Connect's aggregate regional sales report
- A/B testing of store copy or pricing

### 10.3 Aggregate and anonymous

All metrics are aggregate. We cannot answer "did user X buy the Aurora Pack?" — only "how many Aurora Packs were sold this month?". This is a deliberate privacy stance that aligns with the app's "no tracking" ethos.

---

## 11. Glossary

- **Cosmetic** — A purely visual change to the app. No functional effect.
- **Pack** — A themed collection of cosmetics sold together or individually.
- **Supporter Pack** — The $24.99 bundle that unlocks every current and every future cosmetic, permanently. Replaces the previously planned "Founders Pack".
- **Supporter Badge** — A small private acknowledgement in Settings for users who own any paid cosmetic.
- **Entitlement** — A StoreKit product ID the user owns. Stored in `Transaction.currentEntitlements`.
- **Preview** — A temporary application of a cosmetic to the user's actual forecast, with a 30-second auto-restore.
- **Seasonal window** — The defined annual date range during which a seasonal pack can be purchased. Outside the window, the pack is not offered by the App Store. (§3.11)
- **Family Sharing** — Not offered on any SaxWeather cosmetic. All products are `familyShareable: false` in App Store Connect.

---

## 12. Acceptance criteria

This plan is "done" when **all** of the following hold:

- [ ] `StoreManager` supports loading and purchasing any number of products.
- [ ] `CosmeticCatalog` declares all 24 items with their product IDs, prices, and integration points.
- [ ] Every paid cosmetic has a free accessible equivalent.
- [ ] The Cosmetics Store view renders Featured + Category grid + Pack detail + Owned/Buy/Preview/Out-of-season states.
- [ ] Preview-on-actual-forecast works for every cosmetic, including out-of-season seasonal packs.
- [ ] **The Supporter Pack short-circuits all ownership checks** (replaces the Founders Pack).
- [ ] **The Supporter Pack promise of "every future cosmetic" is honoured** — verified by a unit test that adds a new mock cosmetic to the catalog and confirms it shows as owned for a Supporter Pack holder.
- [ ] **Family Sharing is `false` for every cosmetic product** — verified by inspecting `configuration.storekit` and App Store Connect.
- [ ] **Seasonal packs are only purchasable during their defined windows** — verified by inspecting App Store Connect availability settings for each product.
- [ ] **Outside the seasonal window, the in-app tile shows "Returns [date]" or "Out of season"** with the price greyed out and the Buy button replaced.
- [ ] **Outside the seasonal window, no auto-unequip occurs** — a user who equipped Halloween Lottie in November can keep using it in February.
- [ ] **Widget configuration intent shows all themes (owned and unowned) with a lock icon on unowned ones** — verified by setting up a fresh install and inspecting the intent.
- [ ] **Tapping a locked widget tile deep-links to the in-app store** via the registered `saxweather://` URL scheme.
- [ ] Restore Purchases works on a fresh install.
- [ ] No real feature is paywalled (verified by a test that confirms every existing `@AppStorage` knob is still settable without any purchase).
- [ ] No ads are served (verified by a grep for ad SDKs and a review of the network traffic).
- [ ] All paid cosmetics respect Dynamic Type, Reduce Motion, Increase Contrast, and VoiceOver.
- [ ] App Store review passes for each phase.
- [ ] No third-party analytics SDK is added.
- [ ] The "Supporter" badge is the only acknowledgement of ownership, and it's private.

If any of these boxes is unchecked, we are not done.
