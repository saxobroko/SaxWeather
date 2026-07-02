
import Foundation
import Combine

/// On-demand download and disk cache for paywalled cosmetic
/// image assets served from `weather.saxobroko.com`.
@MainActor
final class CosmeticAssetStore: ObservableObject {

    static let shared = CosmeticAssetStore()

    static let auroraBaseURL = RemoteAssetCDN.url(path: "assets/aurora/")
    static let auroraProductID = BackgroundResolver.auroraBackgroundsProductID

    /// Every Aurora background condition key the resolver can
    /// request. Matches the filenames on the CDN.
    static let auroraConditions: [String] = [
        "sunny", "cloudy", "foggy", "rainy",
        "snowy", "thunder", "windy", "default"
    ]

    @Published private(set) var downloadingConditions: Set<String> = []
    @Published private(set) var downloadedConditions: Set<String> = []

    private let fileManager = FileManager.default
    private let session: URLSession
    private var previewOnlyConditions: Set<String> = []
    private var inFlightTasks: [String: Task<Void, Never>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
        refreshDownloadedSet()
        observePurchaseAndPreviewNotifications()
    }

    // MARK: - Public API

    func conditionKey(forWeatherCondition condition: String) -> String {
        let assetName = BackgroundResolver.auroraAssetName(forCondition: condition)
        let prefix = "weather_background_aurora_"
        guard assetName.hasPrefix(prefix) else { return "default" }
        return String(assetName.dropFirst(prefix.count))
    }

    func remoteURL(forCondition condition: String) -> URL {
        Self.auroraBaseURL.appendingPathComponent("\(condition).jpg")
    }

    func localURL(forCondition condition: String) -> URL {
        cacheDirectory.appendingPathComponent("\(condition).jpg")
    }

    func isDownloaded(condition: String) -> Bool {
        fileManager.fileExists(atPath: localURL(forCondition: condition).path)
    }

    func localImageData(forCondition condition: String) -> Data? {
        let url = localURL(forCondition: condition)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Download a single Aurora background. Idempotent when the
    /// file is already on disk.
    func download(condition: String, previewOnly: Bool = false) async throws {
        if isDownloaded(condition: condition) {
            if previewOnly {
                previewOnlyConditions.insert(condition)
            }
            return
        }

        if let existing = inFlightTasks[condition] {
            await existing.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performDownload(condition: condition, previewOnly: previewOnly)
        }
        inFlightTasks[condition] = task
        await task.value
        inFlightTasks[condition] = nil
    }

    /// Prefetch every Aurora background after purchase.
    func downloadAll(previewOnly: Bool = false) async {
        await withTaskGroup(of: Void.self) { group in
            for condition in Self.auroraConditions {
                group.addTask { [weak self] in
                    try? await self?.download(condition: condition, previewOnly: previewOnly)
                }
            }
        }
    }

    /// Download the conditions needed for a timed preview.
    func downloadForPreview(conditions: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for condition in conditions {
                group.addTask { [weak self] in
                    try? await self?.download(condition: condition, previewOnly: true)
                }
            }
        }
    }

    /// Remove preview downloads when the user did not purchase.
    func purgePreviewDownloads(unlessOwned isOwned: () -> Bool) {
        guard !isOwned() else {
            previewOnlyConditions.removeAll()
            return
        }
        for condition in previewOnlyConditions {
            let url = localURL(forCondition: condition)
            try? fileManager.removeItem(at: url)
            downloadedConditions.remove(condition)
        }
        previewOnlyConditions.removeAll()
    }

    func promotePreviewDownloadsToPermanent() {
        previewOnlyConditions.removeAll()
    }

    // MARK: - Notifications

    private func observePurchaseAndPreviewNotifications() {
        NotificationCenter.default.addObserver(
            forName: StoreManager.cosmeticPurchaseCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let productID = notification.userInfo?["productID"] as? String
            Task { @MainActor in
                self.handlePurchase(productID: productID)
            }
        }

        NotificationCenter.default.addObserver(
            forName: PreviewProfileManager.previewExpiredNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.purgePreviewDownloads(unlessOwned: {
                    StoreManager.shared.owns(Self.auroraProductID)
                })
            }
        }
    }

    private func handlePurchase(productID: String?) {
        guard let productID else { return }
        guard Self.unlocksAuroraBackgrounds(productID: productID) else { return }
        promotePreviewDownloadsToPermanent()
        Task {
            await downloadAll(previewOnly: false)
        }
    }

    static func unlocksAuroraBackgrounds(productID: String) -> Bool {
        productID == auroraProductID
            || productID == CosmeticCatalog.supporterPackID
            || productID == "com.saxweather.cosmetic.bundle.mega.aurora"
    }

    // MARK: - Internals

    private var cacheDirectory: URL {
        let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let dir = base
            .appendingPathComponent("CosmeticAssets", isDirectory: true)
            .appendingPathComponent("aurora", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func refreshDownloadedSet() {
        downloadedConditions = Set(
            Self.auroraConditions.filter { isDownloaded(condition: $0) }
        )
    }

    private func performDownload(condition: String, previewOnly: Bool) async {
        downloadingConditions.insert(condition)
        defer {
            downloadingConditions.remove(condition)
            refreshDownloadedSet()
        }

        let destination = localURL(forCondition: condition)
        let source = remoteURL(forCondition: condition)

        do {
            let (tempURL, response) = try await session.download(from: source)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return
            }
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: tempURL, to: destination)
            if previewOnly {
                previewOnlyConditions.insert(condition)
            }
        } catch {
            #if DEBUG
            print("⚠️ Aurora asset download failed for \(condition): \(error)")
            #endif
        }
    }
}
