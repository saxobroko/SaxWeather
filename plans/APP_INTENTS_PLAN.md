# App Intents Implementation Plan

## Overview
This plan outlines the steps to integrate the modern `AppIntents` framework into SaxWeather. This will allow users to interact with the app via Siri, the Shortcuts app, and prepare the app for the upcoming iOS 27 Siri 2.0 (Gemini-powered) capabilities.

## Phase 1: Core App Intents Definition
Define the fundamental actions users can take via Siri or Shortcuts.

1. **Create `GetWeatherIntent`**
   - **Purpose:** Fetch and return the current weather for a specific location.
   - **Parameters:** `location` (Optional, defaults to current location).
   - **Result:** Returns a rich dialog (`ProvidesDialog`) and a custom snippet view showing the weather summary.

2. **Create `ShowForecastIntent`**
   - **Purpose:** Open the app directly to the detailed forecast for a specific location.
   - **Parameters:** `location` (Required).
   - **Result:** Opens the app and navigates to the specified location's forecast.

## Phase 2: Entity Resolution
To allow users to select locations, we need to define an `AppEntity`.

1. **Create `LocationEntity`**
   - Conforms to `AppEntity`.
   - Represents a saved location in the user's list.
   - Implement `EntityQuery` to allow Siri/Shortcuts to search and resolve locations from `SavedLocationsManager`.

## Phase 3: App Shortcuts Provider
Expose the intents to the system automatically without requiring the user to manually create shortcuts.

1. **Create `SaxWeatherShortcutsProvider`**
   - Conforms to `AppShortcutsProvider`.
   - Define `AppShortcut` instances for the intents created in Phase 1.
   - Example phrases:
     - "Get the weather in \(.applicationName)"
     - "Show forecast for \(\.$location) in \(.applicationName)"
   - Define a shortcut tile color and icon.

## Phase 4: Widget Configuration Update
Update the existing placeholder widget intent to use the new `LocationEntity`.

1. **Update `ConfigurationAppIntent` (in `SaxWeatherWidget/AppIntent.swift`)**
   - Remove the placeholder `favoriteEmoji` parameter.
   - Add a `location` parameter of type `LocationEntity?`.
   - Update the widget timeline provider to fetch weather for the selected entity, falling back to the current location if nil.

## Phase 5: UI and Navigation Integration
Ensure the app can handle being opened by an intent.

1. **Update `SaxWeatherApp.swift` / `ContentView.swift`**
   - Handle deep linking or navigation state changes triggered by `ShowForecastIntent` (e.g., using `NavigationStack` and `navigationDestination`).

## Phase 6: Testing & Refinement
1. Test intents via the Shortcuts app.
2. Test voice commands with Siri.
3. Verify widget configuration UI shows the list of saved locations correctly.
