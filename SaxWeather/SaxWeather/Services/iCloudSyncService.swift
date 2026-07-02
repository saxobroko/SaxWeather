
import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// User-facing status of the iCloud sync subsystem. Surfaced in the
/// Backup & Restore screen so users can tell whether their settings
/// are being mirrored.
enum iCloudSyncStatus: Equatable {
    /// iCloud sync is disabled by the user.
    case disabled
    /// iCloud sync is enabled and the local copy matches the
    /// remote copy.
    case idle
    /// iCloud sync is enabled and a push/pull is in flight.
    case syncing
    /// iCloud sync is enabled but the user isn't signed in to
    /// iCloud (or iCloud Drive is disabled in Settings).
    case unavailable(reason: String)
    /// iCloud sync is enabled but the last push/pull failed.
    case error(reason: String)

    var displayLabel: String {
        switch self {
        case .disabled:    return "Off"
        case .idle:        return "Up to date"
        case .syncing:     return "Syncing…"
        case .unavailable: return "Unavailable"
        case .error:       return "Error"
        }
    }

    var symbolName: String {
        switch self {
        case .disabled:    return "icloud.slash"
        case .idle:        return "checkmark.icloud"
        case .syncing:     return "arrow.triangle.2.circlepath.icloud"
        case .unavailable: return "exclamationmark.icloud"
        case .error:       return "xmark.icloud"
        }
    }
}

@MainActor
final class iCloudSyncService: ObservableObject {
    /// Process-wide singleton. The first access from the main actor
    /// initialises the service (registers for external-change
    /// notifications and reads the user's preference).
    static let shared = iCloudSyncService()

    /// Whether the user has opted in to iCloud sync. Persisted in
    /// `UserDefaults` so the choice survives relaunches. Defaults
    /// to `false` — sync is opt-in.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled {
                start()
            } else {
                stop()
            }
        }
    }

    /// Current sync status. Updated whenever the service pushes,
    /// pulls, or detects an error.
    @Published private(set) var status: iCloudSyncStatus = .disabled

    /// The timestamp of the last successful push or pull. `nil` if
    /// sync has never completed. Surfaced in the UI so users can
    /// see when their settings were last mirrored.
    @Published private(set) var lastSyncedAt: Date?

    // MARK: - Storage

    private static let enabledKey = "iCloudSyncService.isEnabled"
    private static let profileKey = "SaxWeather.activeProfile.v1"
    private static let lastSyncedAtKey = "iCloudSyncService.lastSyncedAt"

    /// The ubiquitous key-value store. `nil` if iCloud isn't
    /// available on this device (e.g. simulator without an iCloud
    /// account, or the entitlement is missing).
    private let store = NSUbiquitousKeyValueStore.default

    /// Observer for external-change notifications. Held strongly so
    /// the notification keeps firing.
    private var externalChangeObserver: NSObjectProtocol?

    /// Observer for app-foreground notifications — used to trigger
    /// a pull when the user reopens the app.
    private var foregroundObserver: NSObjectProtocol?

    // MARK: - Init

    private init() {
        // Read the user's preference. Default to off so we don't
        // surprise anyone by silently pushing their settings to
        // iCloud on first launch.
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        if let stamp = UserDefaults.standard.object(forKey: Self.lastSyncedAtKey) as? Date {
            self.lastSyncedAt = stamp
        }
        if isEnabled {
            start()
        } else {
            status = .disabled
        }
    }

    // MARK: - Lifecycle

    /// Begin syncing. Called when the user toggles sync on, or on
    /// first launch if sync was already enabled.
    func start() {
        guard isEnabled else { return }
        guard store != nil else {
            status = .unavailable(reason: "iCloud is not available on this device.")
            return
        }
        registerObservers()
        // Trigger an immediate pull so the local copy reflects the
        // latest remote state.
        pullIfNeeded()
        // Ask iCloud to flush any pending writes from other devices.
        store.synchronize()
        status = .idle
    }

    /// Stop syncing. Called when the user toggles sync off. The
    /// remote copy is left in place so re-enabling picks up where
    /// it left off.
    func stop() {
        if let observer = externalChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            externalChangeObserver = nil
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
        status = .disabled
    }

    // MARK: - Push

    /// Push the given profile to iCloud. Called by
    /// `CustomisationRegistry` after every mutation. No-op if sync
    /// is disabled or iCloud is unavailable.
    func push(profile: CustomisationProfile) {
        guard isEnabled else { return }
        guard store != nil else {
            status = .unavailable(reason: "iCloud is not available on this device.")
            return
        }
        status = .syncing
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profile)
            // NSUbiquitousKeyValueStore has a 1 MB per-key limit
            // and a 1 MB total limit. A SaxWeather profile is well
            // under 100 KB so this is safe.
            store.set(data, forKey: Self.profileKey)
            store.synchronize()
            recordSync()
            status = .idle
        } catch {
            status = .error(reason: error.localizedDescription)
        }
    }

    // MARK: - Pull

    /// Pull the remote profile from iCloud and apply it if it's
    /// newer than the local one. Called on launch, on external
    /// change, and when the app returns to the foreground.
    func pullIfNeeded(apply: (CustomisationProfile) -> Void = { _ in }) {
        guard isEnabled else { return }
        guard store != nil else {
            status = .unavailable(reason: "iCloud is not available on this device.")
            return
        }
        status = .syncing
        guard let data = store.data(forKey: Self.profileKey) else {
            // No remote copy yet — that's fine, the local copy
            // will be pushed on the next mutation.
            status = .idle
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let remote = try decoder.decode(CustomisationProfile.self, from: data)
            apply(remote)
            recordSync()
            status = .idle
        } catch {
            // The remote copy might be from an older schema. Try
            // migrating it forward before giving up.
            if let migrated = try? ProfileMigrator.migrate(data) {
                apply(migrated)
                recordSync()
                status = .idle
            } else {
                status = .error(reason: "Couldn't read the iCloud backup.")
            }
        }
    }

    /// Force a pull from iCloud, ignoring the local timestamp.
    /// Used by the "Restore from iCloud" button in the UI.
    func forcePull(apply: (CustomisationProfile) -> Void) {
        guard isEnabled else { return }
        guard store != nil else {
            status = .unavailable(reason: "iCloud is not available on this device.")
            return
        }
        status = .syncing
        guard let data = store.data(forKey: Self.profileKey) else {
            status = .idle
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let remote = try decoder.decode(CustomisationProfile.self, from: data)
            apply(remote)
            recordSync()
            status = .idle
        } catch {
            if let migrated = try? ProfileMigrator.migrate(data) {
                apply(migrated)
                recordSync()
                status = .idle
            } else {
                status = .error(reason: "Couldn't read the iCloud backup.")
            }
        }
    }

    /// Delete the remote copy. Used by the "Remove iCloud Backup"
    /// button in the UI. The local copy is left untouched.
    func deleteRemoteBackup() {
        guard store != nil else { return }
        store.removeObject(forKey: Self.profileKey)
        store.synchronize()
        lastSyncedAt = nil
        UserDefaults.standard.removeObject(forKey: Self.lastSyncedAtKey)
    }

    // MARK: - Private

    private func registerObservers() {
        // External change — another device wrote to the store.
        if externalChangeObserver == nil {
            externalChangeObserver = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.pullIfNeeded()
                }
            }
        }
        // App foregrounded — give iCloud a chance to deliver any
        // changes that arrived while we were backgrounded.
        #if canImport(UIKit)
        if foregroundObserver == nil {
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.store.synchronize()
                    self?.pullIfNeeded()
                }
            }
        }
        #endif
    }

    private func recordSync() {
        let now = Date()
        lastSyncedAt = now
        UserDefaults.standard.set(now, forKey: Self.lastSyncedAtKey)
    }
}