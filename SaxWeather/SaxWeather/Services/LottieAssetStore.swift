
import Foundation
import Combine

/// On-demand cache for weather Lottie animations served from
/// the CDN as `.lottie` (dotLottie) files.
@MainActor
final class LottieAssetStore: ObservableObject {

    static let shared = LottieAssetStore()

    static let animationNames: [String] = [
        "clear-day", "clear-night",
        "partly-cloudy", "partly-cloudy-night",
        "cloudy", "foggy", "rainy",
        "snowy", "snowy-day", "snowy-night",
        "thunderstorm"
    ]

    @Published private(set) var downloadingNames: Set<String> = []
    @Published private(set) var downloadedNames: Set<String> = []

    private let fileManager = FileManager.default
    private let session: URLSession
    private var inFlightTasks: [String: Task<Void, Never>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
        refreshDownloadedSet()
    }

    func remoteURL(forName name: String) -> URL {
        RemoteAssetCDN.remoteURL(category: .lottie, filename: "\(name).lottie")
    }

    func localURL(forName name: String) -> URL {
        cacheDirectory.appendingPathComponent("\(name).lottie")
    }

    func isDownloaded(name: String) -> Bool {
        fileManager.fileExists(atPath: localURL(forName: name).path)
    }

    func download(name: String) async throws {
        if isDownloaded(name: name) { return }

        if let existing = inFlightTasks[name] {
            await existing.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performDownload(name: name)
        }
        inFlightTasks[name] = task
        await task.value
        inFlightTasks[name] = nil
    }

    func prefetchAll() async {
        await withTaskGroup(of: Void.self) { group in
            for name in Self.animationNames {
                group.addTask { [weak self] in
                    try? await self?.download(name: name)
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
            .appendingPathComponent("lottie", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func refreshDownloadedSet() {
        downloadedNames = Set(
            Self.animationNames.filter { isDownloaded(name: $0) }
        )
    }

    private func performDownload(name: String) async {
        downloadingNames.insert(name)
        defer {
            downloadingNames.remove(name)
            refreshDownloadedSet()
        }

        let destination = localURL(forName: name)
        let source = remoteURL(forName: name)

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
            print("⚠️ Lottie download failed for \(name): \(error)")
            #endif
        }
    }
}
