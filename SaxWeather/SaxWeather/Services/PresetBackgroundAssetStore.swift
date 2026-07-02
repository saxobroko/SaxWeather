
import Foundation
import Combine

/// On-demand cache for shipped preset weather backgrounds.
/// `default` stays in the app bundle; every other condition
/// is downloaded from the CDN on first use.
@MainActor
final class PresetBackgroundAssetStore: ObservableObject {

    static let shared = PresetBackgroundAssetStore()

    /// Bundled locally — the fallback on first launch.
    static let bundledCondition = "default"

    /// Remote JPEG conditions (everything except `default`).
    static let remoteConditions: [String] = [
        "cloudy", "foggy", "rainy", "snowy", "thunder", "windy"
    ]

    @Published private(set) var downloadingConditions: Set<String> = []
    @Published private(set) var downloadedConditions: Set<String> = []

    private let fileManager = FileManager.default
    private let session: URLSession
    private var inFlightTasks: [String: Task<Void, Never>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
        refreshDownloadedSet()
    }

    func usesBundledAsset(forCondition condition: String) -> Bool {
        normalizedCondition(condition) == Self.bundledCondition
    }

    func normalizedCondition(_ condition: String) -> String {
        let lower = condition.lowercased()
        switch lower {
        case "sunny", "clear-day", "default", "night", "clear-night":
            return Self.bundledCondition
        case "partly-cloudy", "partly-cloudy-day", "partly-cloudy-night", "partly cloudy":
            return "cloudy"
        case "thunderstorm", "storm":
            return "thunder"
        default:
            return lower
        }
    }

    func remoteURL(forCondition condition: String) -> URL {
        let key = normalizedCondition(condition)
        return RemoteAssetCDN.remoteURL(
            category: .backgrounds,
            filename: "\(key).jpg"
        )
    }

    func localURL(forCondition condition: String) -> URL {
        let key = normalizedCondition(condition)
        return cacheDirectory.appendingPathComponent("\(key).jpg")
    }

    func isDownloaded(condition: String) -> Bool {
        let key = normalizedCondition(condition)
        guard key != Self.bundledCondition else { return true }
        return fileManager.fileExists(atPath: localURL(forCondition: key).path)
    }

    func localImageData(forCondition condition: String) -> Data? {
        let key = normalizedCondition(condition)
        guard key != Self.bundledCondition else { return nil }
        let url = localURL(forCondition: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    func download(condition: String) async throws {
        let key = normalizedCondition(condition)
        guard key != Self.bundledCondition else { return }
        if isDownloaded(condition: key) { return }

        if let existing = inFlightTasks[key] {
            await existing.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performDownload(condition: key)
        }
        inFlightTasks[key] = task
        await task.value
        inFlightTasks[key] = nil
    }

    func prefetchAllRemote() async {
        await withTaskGroup(of: Void.self) { group in
            for condition in Self.remoteConditions {
                group.addTask { [weak self] in
                    try? await self?.download(condition: condition)
                }
            }
        }
    }

    private var cacheDirectory: URL {
        let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let dir = base
            .appendingPathComponent("BundledAssets", isDirectory: true)
            .appendingPathComponent("backgrounds", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func refreshDownloadedSet() {
        downloadedConditions = Set(
            Self.remoteConditions.filter { isDownloaded(condition: $0) }
        )
    }

    private func performDownload(condition: String) async {
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
        } catch {
            #if DEBUG
            print("⚠️ Preset background download failed for \(condition): \(error)")
            #endif
        }
    }
}
