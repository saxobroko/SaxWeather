
import SwiftUI
import Combine

enum PreviewDestination: Equatable {
    /// The main Weather tab — the cosmetic affects the
    /// background image or the whole-app palette. Used for
    /// `.backgrounds` and `.palette`.
    case mainWeather
    /// The Forecast tab — the cosmetic affects the hourly
    /// chart skin. Used for `.chart`.
    case forecast
}

/// The live-preview coordinator. Lives at the `ContentView`
/// level as a `@StateObject` so the navigation logic and the
/// countdown overlay can both observe it.
@MainActor
final class CosmeticPreviewCoordinator: ObservableObject {

    /// The active preview destination, or `nil` when no
    /// preview is running. `ContentView` observes this to
    /// switch tabs.
    @Published private(set) var presentedDestination: PreviewDestination?

    @Published var reopenProductID: String?

    /// The display name of the product currently being
    /// previewed, used by the countdown overlay. `nil` when
    /// no preview is running.
    @Published private(set) var previewingProductName: String?

    @Published private(set) var snapshotProfile: CustomisationProfile?

    // MARK: - Init

    init() {}

    // MARK: - Destination routing

    static func destination(for kind: CosmeticKind) -> PreviewDestination? {
        switch kind {
        case .backgrounds, .palette:
            return .mainWeather
        case .chart:
            return .forecast
        case .badge, .supporterPack, .bundle,
             .icons, .font, .haptic, .sound,
             .widgetTheme, .appIcon:
            return nil
        }
    }

    /// `true` when a preview is currently driving navigation.
    var hasActivePreview: Bool {
        presentedDestination != nil
    }

    // MARK: - Lifecycle

    func startPreview(
        of product: CosmeticProduct,
        originalProfile: CustomisationProfile
    ) {
        presentedDestination = Self.destination(for: product.productKind)
        previewingProductName = product.displayName
        snapshotProfile = originalProfile
    }

    func endPreview(reopenForProductID productID: String? = nil) {
        presentedDestination = nil
        previewingProductName = nil
        snapshotProfile = nil
        if let productID = productID {
            reopenProductID = productID
        }
    }
}