//
//  ChartPaletteStore.swift
//  SaxWeather
//
//  Part B — Aurora Chart Skin reactivity fix.
//
//  `ChartPalette` is a free function (not reactive). The chart
//  skin is stored in `ForecastSpec.chartSkin`. When the user
//  previews the Aurora Chart Skin, the chart skin changes but
//  views that use it don't always re-render because:
//
//    1. The `chartPaletteColors` computed property in
//       `HourlyForecastView` is only called inside
//       `ForEach(hourlyData)`, not directly in the view body.
//       SwiftUI may not re-evaluate the computed property when
//       the profile changes.
//    2. The view body has a `let _ = registry.profile` hack to
//       force re-evaluation, but this is fragile.
//
//  This store wraps the chart palette in an `ObservableObject`
//  so views can observe it via `@EnvironmentObject` /
//  `@ObservedObject`. When the profile's chart skin changes
//  or the user's entitlements change, the store re-resolves
//  and notifies observers.
//
//  The store observes both `CustomisationRegistry.shared` and
//  `StoreManager.shared` via Combine and updates its
//  `@Published var activeColors` when either changes.
//
//  Threading: `@MainActor` — every state mutation and
//  observation happens on the main actor, matching the
//  existing `CustomisationRegistry` isolation.
//

import SwiftUI
import Combine

/// Reactive wrapper around the active chart palette. Views
/// observe this store (via `@EnvironmentObject` or
/// `@ObservedObject`) and re-render when the chart skin or
/// entitlements change.
///
/// The store is the single source of truth for "what chart
/// colours should be rendered right now". It observes
/// `CustomisationRegistry.shared` (for the profile's chart
/// skin) and `StoreManager.shared` (for the user's
/// entitlements) and updates its `@Published var activeColors`
/// when either changes.
@MainActor
final class ChartPaletteStore: ObservableObject {

    /// The currently active chart skin (after gating by
    /// ownership). Published so views that observe this store
    /// re-render when it changes.
    @Published private(set) var activeSkin: ChartSkin

    /// The five-colour gradient for the active skin. Published
    /// so views that observe this store re-render when it
    /// changes.
    @Published private(set) var activeColors: [Color]

    /// The registry this store observes. Held weakly so the
    /// store doesn't keep the registry alive.
    private weak var registry: CustomisationRegistry?

    /// The store manager this store observes. Held weakly so
    /// the store doesn't keep the store manager alive.
    private weak var storeManager: StoreManager?

    /// Combine cancellables for the registry and store manager
    /// observations.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    /// Standard init. Observes `registry` (defaults to
    /// `.shared`) and `storeManager` (defaults to `.shared`)
    /// and updates `activeSkin` / `activeColors` when either
    /// changes.
    ///
    /// - Parameters:
    ///   - registry: the registry to observe. Defaults to
    ///     `CustomisationRegistry.shared`. Tests inject a
    ///     test-only registry.
    ///   - storeManager: the store manager to observe.
    ///     Defaults to `StoreManager.shared`. Tests inject a
    ///     test-only store manager.
    init(
        registry: CustomisationRegistry = .shared,
        storeManager: StoreManager = .shared
    ) {
        self.registry = registry
        self.storeManager = storeManager

        // Resolve the initial active skin and colours.
        let preferred = registry.profile.knobs.forecast.chartSkin
        let initialSkin = ChartPalette.resolveActiveSkin(
            preferredSkin: preferred,
            isOwned: { storeManager.owns($0) }
        )
        self.activeSkin = initialSkin
        self.activeColors = initialSkin.colors

        // Observe the registry's profile and update when the
        // chart skin changes. `registry.$profile` is the
        // `@Published` wrapper for `profile`; we map it to the
        // chart skin and remove duplicates so we only fire
        // when the chart skin actually changes.
        registry.$profile
            .map { $0.knobs.forecast.chartSkin }
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.recomputeColors()
            }
            .store(in: &cancellables)

        // Observe the store manager's `objectWillChange` and
        // recompute colours when entitlements change. We use
        // `objectWillChange` because `StoreManager` doesn't
        // expose a `@Published` property for ownership
        // changes (it delegates to `EntitlementStore`). The
        // `DispatchQueue.main.async` defers the recompute to
        // the next runloop tick so the entitlement change has
        // time to propagate.
        storeManager.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.recomputeColors()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Resolution

    /// Recompute the active skin and colours from the current
    /// profile + entitlement state. Called when either changes.
    private func recomputeColors() {
        guard let registry = registry,
              let storeManager = storeManager else { return }
        let preferred = registry.profile.knobs.forecast.chartSkin
        let newSkin = ChartPalette.resolveActiveSkin(
            preferredSkin: preferred,
            isOwned: { storeManager.owns($0) }
        )
        if newSkin != activeSkin {
            activeSkin = newSkin
            activeColors = newSkin.colors
        }
    }
}