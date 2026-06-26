//
//  ColourTokenStore.swift
//  SaxWeather
//
//  Part B — Aurora Palette reactivity fix.
//
//  `ColourToken` is a plain enum (not reactive). The palette is
//  stored in `VisualSpec.palette` (a struct). When the user
//  previews the Aurora Palette, the palette changes but views
//  that use it don't always re-render because:
//
//    1. The palette is only used in `.solid` and `.outline`
//       card styles (the default `.glass` style uses
//       `Material.ultraThin` etc. and ignores the palette).
//    2. Views that read the palette directly from the registry
//       may not observe the registry's `@Published` property
//       correctly (e.g. computed properties called inside
//       `ForEach` may not trigger re-renders).
//
//  This store wraps the palette in an `ObservableObject` so
//  views can observe it via `@EnvironmentObject` /
//  `@ObservedObject`. When the profile's palette changes, the
//  store re-resolves and notifies observers.
//
//  The store observes `CustomisationRegistry.shared` via
//  Combine and updates its `@Published var palette` when the
//  profile changes. Views that observe this store will
//  re-render automatically.
//
//  Threading: `@MainActor` — every state mutation and
//  observation happens on the main actor, matching the
//  existing `CustomisationRegistry` isolation.
//

import SwiftUI
import Combine

/// Reactive wrapper around the active `Palette`. Views observe
/// this store (via `@EnvironmentObject` or `@ObservedObject`)
/// and re-render when the palette changes.
///
/// The store is the single source of truth for "what palette
/// is currently active". It observes `CustomisationRegistry.shared`
/// and updates its `@Published var palette` when the profile's
/// palette changes.
@MainActor
final class ColourTokenStore: ObservableObject {

    /// The currently active palette. Published so views that
    /// observe this store re-render when it changes.
    @Published private(set) var palette: Palette

    /// The registry this store observes. Held weakly so the
    /// store doesn't keep the registry alive.
    private weak var registry: CustomisationRegistry?

    /// Combine cancellables for the registry observation.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    /// Standard init. Observes `registry` (defaults to
    /// `.shared`) and updates `palette` when the profile
    /// changes.
    ///
    /// - Parameter registry: the registry to observe. Defaults
    ///   to `CustomisationRegistry.shared`. Tests inject a
    ///   test-only registry.
    init(registry: CustomisationRegistry = .shared) {
        self.registry = registry
        self.palette = registry.profile.knobs.visual.palette

        // Observe the registry's profile and update when the
        // palette changes. `registry.$profile` is the
        // `@Published` wrapper for `profile`; we map it to the
        // palette and remove duplicates so we only fire when
        // the palette actually changes.
        registry.$profile
            .map { $0.knobs.visual.palette }
            .removeDuplicates()
            .sink { [weak self] newPalette in
                self?.palette = newPalette
            }
            .store(in: &cancellables)
    }

    // MARK: - Resolution

    /// Resolve a `ColourToken` to a SwiftUI `Color` using the
    /// current palette. The optional `colorScheme` lets
    /// `.named("system")` resolve to the right semantic colour
    /// in light vs dark mode.
    ///
    /// This is a convenience wrapper around `ColourToken.color(for:)`
    /// so views can call `store.color(for: token)` instead of
    /// `token.color(for: colorScheme)`.
    func color(for token: ColourToken, colorScheme: ColorScheme = .light) -> Color {
        token.color(for: colorScheme)
    }

    /// Convenience for SwiftUI views that don't care about
    /// colour scheme (most cards, lists, etc.).
    func color(for token: ColourToken) -> Color {
        token.color
    }
}