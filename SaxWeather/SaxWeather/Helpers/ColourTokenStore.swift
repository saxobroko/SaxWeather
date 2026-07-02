
import SwiftUI
import Combine

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

    func color(for token: ColourToken, colorScheme: ColorScheme = .light) -> Color {
        token.color(for: colorScheme)
    }

    /// Convenience for SwiftUI views that don't care about
    /// colour scheme (most cards, lists, etc.).
    func color(for token: ColourToken) -> Color {
        token.color
    }
}