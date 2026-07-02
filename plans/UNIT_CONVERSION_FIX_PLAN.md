# Unit Conversion Audit & Fix Plan

> **Created:** 2026-06-16
> **Scope:** SaxWeather / SaxWeatherWidget / SaxWeatherApp
> **Status:** 🔴 In Progress (analysis complete, fixes pending)

---

## Executive Summary

After auditing all four weather data sources (WeatherKit, Open-Meteo, Weather Underground, OpenWeatherMap) and every display/widget pipeline, I found **5 real bugs** and **2 structural risks** that cause incorrect numbers and inconsistent units across the app. The "UK" unit system (°C + mph + hPa) is **silently broken** — it's effectively the same as "Metric" today.

The root cause is that the [`Weather`](SaxWeather/SaxWeather/Weather.swift) model assumes "Metric" means **km/h for wind** internally, but two of the four data sources (Weather Underground PWS and OpenWeatherMap) return wind in **m/s** when their metric/standard unit is requested. They are written into the model as if they were already in km/h, so all derived values (feels-like, display, widget) are wrong by a factor of 3.6.

---

## 1. Reference: What Each API Returns in "Metric"

| API | URL param used | Temperature | Wind | Wind gust | Pressure |
|---|---|---|---|---|---|
| **WeatherKit** | n/a (system) | °C | **m/s** (converted to km/h in code ✅) | **m/s** (converted to km/h in code ✅) | hPa |
| **Open-Meteo** | default | °C | **km/h** ✅ | **km/h** ✅ | hPa |
| **Weather Underground** | `units=m` | °C | **m/s** ❌ stored as km/h | **m/s** ❌ stored as km/h | hPa |
| **OpenWeatherMap** | `units=metric` | °C | **m/s** ❌ stored as km/h | **m/s** ❌ stored as km/h | hPa |

The model treats `windSpeed` in Metric mode as **km/h** ([`convertUnits`](SaxWeather/SaxWeather/Weather.swift:286) does `* 0.621371` = km/h → mph), so two of four sources are wrong.

---

## 2. Bugs Found

### 🔴 Bug 1 — Weather Underground wind stored in m/s, model expects km/h
**File:** [`SaxWeather/SaxWeather/Weather.swift:229`](SaxWeather/SaxWeather/Weather.swift:229) and `:234`

```swift
self.windSpeed = wuObservation?.metric.windSpeed ?? owmCurrent?.wind_speed ?? openMeteoResponse?.current?.wind_speed_10m
self.windGust  = wuObservation?.metric.windGust  ?? owmCurrent?.wind_gust  ?? openMeteoResponse?.current?.wind_gusts_10m
```

WU's `units=m` returns `metric.windSpeed` and `metric.windGust` in **m/s**. The fallback chain writes the **m/s** value into `windSpeed`, which the rest of the app treats as **km/h**. Everything downstream (feels-like, widget, summary text) is off by 3.6×.

**Symptom:** WU shows 11 km/h when the station is actually reporting 40 km/h. In Imperial mode, the "convert km/h to mph" step *amplifies* the error: 11 m/s × 0.621371 ≈ 6.8 mph shown for a 25 mph wind.

### 🔴 Bug 2 — OpenWeatherMap wind stored in m/s, model expects km/h
**File:** [`SaxWeather/SaxWeather/WeatherService.swift:718-720`](SaxWeather/SaxWeather/WeatherService.swift:718)

```swift
wind_speed: currentWeather.wind.speed,
wind_gust:  currentWeather.wind.gust ?? 0,
```

OWM with `units=metric` returns wind in **m/s**. Same downstream effect as Bug 1.

**Symptom:** Identical to Bug 1, but only when the OWM provider is selected.

### 🔴 Bug 3 — `convertUnits(from: "Metric", to: "UK")` is a silent no-op
**File:** [`SaxWeather/SaxWeather/Weather.swift:278-344`](SaxWeather/SaxWeather/Weather.swift:278)

The switch over `from`/`to` only handles `("Metric", "Imperial")` and `("Imperial", "Metric")`. The "UK" target is **never matched**, so:

- Temperature stays in °C ✅ (correct for UK)
- Wind stays in km/h ❌ (UK wants mph)
- Pressure stays in hPa ✅ (correct for UK)

In practice, choosing "UK" produces a hybrid that displays °C + km/h + hPa — i.e. the same as "Metric" with misleading labels in some places.

**Caller:** [`WeatherService.swift:505`](SaxWeather/SaxWeather/WeatherService.swift:505), `:545`](SaxWeather/SaxWeather/WeatherService.swift:545), and [`WeatherService+WeatherKit.swift:46`](SaxWeather/SaxWeather/WeatherService+WeatherKit.swift:46) all do `if unitSystem != "Metric" { convertUnits(from: "Metric", to: unitSystem) }` — they expect "UK" to be handled.

### 🔴 Bug 4 — Widget UK wind conversion uses the wrong factor
**File:** [`SaxWeather/SaxWeather/SaxWeatherApp.swift:263-265`](SaxWeather/SaxWeather/SaxWeatherApp.swift:263) (background station refresh)

```swift
} else if unitSystem == "UK" {
    windSpeed = windSpeed * 0.621371   // <-- BUG
}
```

`observation.metric.windSpeed` is **m/s**, not km/h. Multiplying by 0.621371 (km/h → mph) gives a value that is 0.621371 × 2.23694 ≈ 1.39× too high in mph, *and* mixes units.

**Correct:** `windSpeed * 2.23694` (m/s → mph).

### 🔴 Bug 5 — Widget hourly WeatherKit path has the same UK bug shape, but is correct
**File:** [`SaxWeather/SaxWeatherWidget/SaxWeatherWidget.swift:530-534`](SaxWeather/SaxWeatherWidget/SaxWeatherWidget.swift:530)

```swift
var windSpeed = hour.wind.speed.value * 3.6   // m/s → km/h
if unitSystem == "Imperial" {
    windSpeed = windSpeed * 0.621371           // km/h → mph  ✅
} else if unitSystem == "UK" {
    windSpeed = windSpeed * 0.621371           // km/h → mph  ✅
}
```

This one is actually correct because the code first converts to km/h (`* 3.6`), so `* 0.621371` is a valid km/h → mph step. No change needed.

### 🟡 Risk 1 — UI labels don't know about "UK"
**File:** [`SaxWeather/SaxWeather/ContentView.swift:564-572`](SaxWeather/SaxWeather/ContentView.swift:564)

```swift
private var temperatureUnit: String { unitSystem == "Metric" ? "°C" : "°F" }
private var speedUnit:         String { unitSystem == "Metric" ? "km/h" : "mph" }
private var pressureUnit:      String { unitSystem == "Metric" ? "hPa" : "inHg" }
```

With "UK" selected, these render as `°F` / `mph` / `inHg`, which is wrong — the model now (after Fix 3) stores °C / mph / hPa. The labels must be aware of three states.

The same tri-state issue exists in [`ForecastView.swift:533`](SaxWeather/SaxWeather/ForecastView.swift:533) and [`HourlyForecastView.swift:269`](SaxWeather/SaxWeather/HourlyForecastView.swift:269):

```swift
let windUnit = weatherService.unitSystem == "Metric" ? "km/h" : "mph"
```

### 🟡 Risk 2 — `convertUnits` runs in the wrong direction
**File:** [`SaxWeather/SaxWeather/Weather.swift:193-213`](SaxWeather/SaxWeather/Weather.swift:193) (`ensureMetricAndCalculateFeelsLike`)

```swift
if currentUnit == "Imperial" {
    tempInCelsius = (temperature - 32) * 5/9
    windInMetersPerSecond = windSpeed * 0.44704 // mph to m/s
}
```

This treats `windSpeed` as **mph** when unit is Imperial (correct) and as **m/s** when unit is Metric/UK (also correct, because in Metric/UK the value was m/s at the API and not yet converted). After Fix 1+2 the model always has km/h in Metric/UK, so this branch must change to:

```swift
} else if currentUnit == "UK" {
    windInMetersPerSecond = windSpeed * 0.27778 // mph to m/s
}
// default ("Metric"): windSpeed is km/h → divide by 3.6
```

This logic was actually masking Bug 1/Bug 2: the `Apparent Temperature` formula (the default branch) was using a wind value ~3.6× too small, and so the "feels like" was wrong too — but only by a small amount because the wind coefficient in Australian Apparent Temp is just `-0.70` per m/s.

---

## 3. Fix Plan

### Phase 1 — Single source of truth
**New file:** [`SaxWeather/SaxWeather/Helpers/UnitConverter.swift`](SaxWeather/SaxWeather/Helpers/)

Centralizes every conversion the app performs. All other code references this enum/struct so the next developer can audit conversions in one place.

```swift
enum UnitConverter {
    static func mpsToKmh(_ v: Double) -> Double { v * 3.6 }
    static func kmhToMph(_ v: Double) -> Double { v * 0.621371 }
    static func mpsToMph(_ v: Double) -> Double { v * 2.23694 }
    static func celsiusToF(_ c: Double) -> Double { c * 9/5 + 32 }
    static func fToCelsius(_ f: Double) -> Double { (f - 32) * 5/9 }
    static func hPaToInHg(_ v: Double) -> Double { v * 0.02953 }
    static func inHgToHPa(_ v: Double) -> Double { v * 33.8639 }

    /// Label / unit-symbol helpers used by the UI.
    enum UnitSystem: String, CaseIterable {
        case metric   = "Metric"
        case imperial = "Imperial"
        case uk       = "UK"
        var temperatureLabel: String { self == .imperial ? "°F" : "°C" }
        var speedLabel:         String { self == .imperial ? "mph" : (self == .uk ? "mph" : "km/h") }
        var pressureLabel:      String { self == .imperial ? "inHg" : "hPa" }
    }
}
```

### Phase 2 — Fix the WU/OWM unit assignment
**File:** [`SaxWeather/SaxWeather/Weather.swift:228-234`](SaxWeather/SaxWeather/Weather.swift:228)

Convert wind/gust from m/s → km/h for WU and OWM at the point of assignment so the rest of the system can assume km/h in Metric/UK:

```swift
// Weather Underground returns wind in m/s with `units=m`
let wuWindKmh  = (wuObservation?.metric.windSpeed ?? 0) * 3.6
let wuGustKmh  = (wuObservation?.metric.windGust  ?? 0) * 3.6
// OpenWeatherMap returns wind in m/s with `units=metric`
let owmWindKmh = (owmCurrent?.wind_speed ?? 0) * 3.6
let owmGustKmh = (owmCurrent?.wind_gust  ?? 0) * 3.6
// Open-Meteo is already km/h
let omWindKmh  = openMeteoResponse?.current?.wind_speed_10m ?? 0
let omGustKmh  = openMeteoResponse?.current?.wind_gusts_10m ?? 0
self.windSpeed = wuObservation != nil ? wuWindKmh : (owmCurrent != nil ? owmWindKmh : (omWindKmh != 0 ? omWindKmh : nil))
self.windGust  = wuObservation != nil ? wuGustKmh : (owmCurrent != nil ? owmGustKmh : (omGustKmh != 0 ? omGustKmh : nil))
```

(Cleaner with explicit `if/else if` chain.)

### Phase 3 — Add `("Metric", "UK")` and `("Imperial", "UK")` cases
**File:** [`SaxWeather/SaxWeather/Weather.swift:278-344`](SaxWeather/SaxWeather/Weather.swift:278)

UK = °C + mph + hPa. From Metric: convert wind km/h → mph. From Imperial: convert temp °F → °C (keep pressure, keep mph). Also add the reverse directions and the UK → Metric / UK → Imperial paths for completeness, since the user can change unit system at runtime.

### Phase 4 — Fix `ensureMetricAndCalculateFeelsLike`
**File:** [`SaxWeather/SaxWeather/Weather.swift:193-213`](SaxWeather/SaxWeather/Weather.swift:193)

Use `UnitConverter` to normalize wind to m/s based on `currentUnit`, not just `Imperial`.

### Phase 5 — Fix widget UK wind conversion
**File:** [`SaxWeather/SaxWeather/SaxWeatherApp.swift:263`](SaxWeather/SaxWeather/SaxWeatherApp.swift:263)

```swift
} else if unitSystem == "UK" {
    windSpeed = windSpeed * 2.23694   // m/s → mph (observation.metric.windSpeed is m/s)
}
```

### Phase 6 — Update UI unit labels to handle UK
- [`ContentView.swift:564-572`](SaxWeather/SaxWeather/ContentView.swift:564) — use `UnitSystem` tri-state
- [`ForecastView.swift:533`](SaxWeather/SaxWeather/ForecastView.swift:533) — same
- [`HourlyForecastView.swift:269`](SaxWeather/SaxWeather/HourlyForecastView.swift:269) — same
- [`DetailedForecastSheet.swift:131`](SaxWeather/SaxWeather/DetailedForecastSheet.swift:131) — same

### Phase 7 — Verify
1. Build the project (Cmd+B) to confirm no compilation errors
2. Quick spot-check: with each provider (WeatherKit, Open-Meteo, WU, OWM) and each unit system (Metric, Imperial, UK), confirm:
   - WU Metric wind = what the station reports in m/s × 3.6
   - OWM Metric wind = what OWM returns × 3.6
   - UK always shows °C / mph / hPa
   - Imperial always shows °F / mph / inHg

---

## 4. Affected Files

| File | Reason |
|---|---|
| `SaxWeather/SaxWeather/Weather.swift` | WU/OWM wind assignment, `convertUnits`, `ensureMetricAndCalculateFeelsLike` |
| `SaxWeather/SaxWeather/WeatherService.swift` | (no change needed — uses `convertUnits` which is fixed) |
| `SaxWeather/SaxWeather/WeatherService+OpenMeteo.swift` | (no change — Open-Meteo is km/h) |
| `SaxWeather/SaxWeather/WeatherService+WeatherKit.swift` | (no change — already correct, uses `convertUnits`) |
| `SaxWeather/SaxWeather/Weather+WeatherKit.swift` | (no change — already converts m/s → km/h) |
| `SaxWeather/SaxWeather/SaxWeatherApp.swift` | Widget UK wind conversion |
| `SaxWeather/SaxWeather/ContentView.swift` | UK-aware unit labels |
| `SaxWeather/SaxWeather/ForecastView.swift` | UK-aware unit labels |
| `SaxWeather/SaxWeather/HourlyForecastView.swift` | UK-aware unit labels |
| `SaxWeather/SaxWeather/DetailedForecastSheet.swift` | UK-aware unit labels |
| `SaxWeather/SaxWeather/Helpers/UnitConverter.swift` | **NEW** — single source of truth |
