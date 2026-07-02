
import SwiftUI
import Combine

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