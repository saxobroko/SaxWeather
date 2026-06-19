//
//  CustomisationRegistry.swift
//  SaxWeather
//
//  Single source of truth for every customisation knob in
//  SaxWeather. Loads the active profile from the shared App Group
//  on launch, persists on every mutation, and (in DEBUG builds)
//  watches `current.saxtheme` on disk and hot-reloads when the
//  file changes — so editing the JSON in any text editor live
//  updates the running app.
//
//  Public API contract (see `plans/INFINITE_CUSTOMISATION_PLAN.md`
//  §2.3):
//
//      let registry = CustomisationRegistry.shared
//      registry.apply(BuiltInProfile.powerUser.profile)
//      registry.set(\.data.unitSystem, "Imperial")
//      let unit: String = registry.get(\.data.unitSystem)
//      registry.resetTo(.minimalist)
//      let url = try registry.exportProfile()
//      try registry.importProfile(from: url)
//
//  All mutation goes through the registry; existing `@AppStorage`
//  reads keep working unchanged until Phase 2 wires the bridge.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class CustomisationRegistry: ObservableObject {
    /// Process-wide singleton. The first access from the main actor
    /// initialises the registry (loading from disk or falling back
    /// to the default profile).
    static let shared = CustomisationRegistry()

    /// The currently active profile. Mutating this directly is
    /// discouraged — use `apply(_:)` or `set(_:_:)` instead so the
    /// registry can persist + bump `versionToken`.
    @Published private(set) var profile: CustomisationProfile

    /// Bumped whenever the *shape* of the profile changes (a
    /// section added, a section removed, a profile swap). Cheap
    /// value tweaks (toggles, sliders) propagate via
    /// `objectWillChange` only and leave `versionToken` alone, so
    /// views that depend on layout structure don't re-render on
    /// every knob tweak.
    @Published private(set) var versionToken: Int = 0

    /// Stable hash of the current knob values. The widget reads
    /// this to decide whether its cached theme is stale.
    private(set) var profileHash: Int = 0

    // MARK: - Storage

    /// App Group ID shared with the widget extension. Same value
    /// used by `WidgetSyncService`.
    private static let appGroupID = "group.com.saxobroko.SaxWeather"
    /// Filename inside the App Group container holding the active
    /// profile as JSON.
    private static let activeProfileFilename = "current.saxtheme"

    #if DEBUG
    /// File-system watcher that powers hot-reload.
    private var hotReloadSource: DispatchSourceFileSystemObject?
    #endif

    // MARK: - Init

    /// Production init. Loads the persisted profile (or falls back
    /// to the default) and (in DEBUG) wires a file-system watcher.
    private init() {
        self.profile = Self.loadFromDisk() ?? CustomisationProfile.makeDefault()
        recomputeHash()
        setupHotReload()
    }

    /// Test-only init. Starts fresh from `initial`, no disk I/O, no
    /// hot-reload watcher. Use this in unit tests to avoid singleton
    /// leakage across test cases.
    init(testProfile initial: CustomisationProfile = .makeDefault()) {
        self.profile = initial
        recomputeHash()
    }

    // MARK: - Apply

    /// Replace the entire active profile. Bumps `versionToken` (the
    /// shape can change) and persists. Also asks WidgetKit to
    /// reload its timelines so the widget picks up the new theme.
    func apply(_ newProfile: CustomisationProfile) {
        var normalised = newProfile
        normalised.updatedAt = Date()
        normalised.schemaVersion = ProfileMigrator.currentSchemaVersion
        profile = normalised
        versionToken &+= 1
        recomputeHash()
        persist()
        reloadWidgets()
    }

    /// Convenience: switch to a built-in preset.
    func resetTo(_ builtIn: BuiltInProfile) {
        apply(builtIn.profile)
    }

    // MARK: - Set / Get

    /// Mutate a single knob via a writable key path. No-op if the
    /// value is unchanged. Cheap — does NOT bump `versionToken`.
    ///
    /// Example: `registry.set(\.data.unitSystem, "Imperial")`.
    func set<Value: Equatable>(
        _ keyPath: WritableKeyPath<KnobStorage, Value>,
        _ value: Value
    ) {
        var newKnobs = profile.knobs
        guard newKnobs[keyPath: keyPath] != value else { return }
        newKnobs[keyPath: keyPath] = value
        var newProfile = profile
        newProfile.knobs = newKnobs
        newProfile.updatedAt = Date()
        profile = newProfile
        recomputeHash()
        persist()
        reloadWidgets()
    }

    /// Read a single knob via a key path.
    func get<Value>(_ keyPath: KeyPath<KnobStorage, Value>) -> Value {
        profile.knobs[keyPath: keyPath]
    }

    // MARK: - Profile I/O

    /// Absolute URL of the active profile file inside the App Group
    /// container, or `nil` if the container isn't available (e.g.
    /// running outside a signed app context, or in a unit test).
    var profileFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)?
            .appendingPathComponent(Self.activeProfileFilename)
    }

    /// Write the active profile to a `.saxtheme` file in the user's
    /// Documents directory and return the URL. Caller can hand this
    /// to `ShareLink` or `UIActivityViewController` for export.
    func exportProfile() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)

        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let stamp = Self.exportDateFormatter.string(from: Date())
        let safeName = profile.name.fileSystemSafe
        let url = documents.appendingPathComponent("\(safeName)-\(stamp).saxtheme")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Read a `.saxtheme` file from disk, migrate it forward, and
    /// apply it. Throws if the file is unreadable or unparseable.
    func importProfile(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let imported = try ProfileMigrator.migrate(data)
        apply(imported)
    }

    // MARK: - Hot reload (DEBUG)

    /// Re-read `current.saxtheme` from disk and apply it. Used by
    /// the file-system watcher and from the Theme Editor card in
    /// `LottieDebugView`.
    func reloadFromDisk() {
        guard let loaded = Self.loadFromDisk() else { return }
        profile = loaded
        versionToken &+= 1
        recomputeHash()
    }

    // MARK: - Private

    /// Returns the parsed profile from disk, or `nil` if the file
    /// doesn't exist or can't be migrated. Failures here are silent
    /// by design — first-launch should silently fall back to the
    /// default profile.
    private static func loadFromDisk() -> CustomisationProfile? {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(activeProfileFilename,
                                    isDirectory: false),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? ProfileMigrator.migrate(data)
    }

    private func persist() {
        guard let url = profileFileURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profile)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("⚠️ CustomisationRegistry: failed to persist profile — \(error)")
            #endif
        }
    }

    private func recomputeHash() {
        var hasher = Hasher()
        hasher.combine(profile.knobs)
        profileHash = hasher.finalize()
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private static let exportDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Hot reload wiring

    private func setupHotReload() {
        #if DEBUG
        guard let url = profileFileURL else { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            // Brief debounce — editors fire `write` multiple times
            // per save.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.reloadFromDisk()
            }
        }
        source.resume()
        hotReloadSource = source
        #endif
    }
}

// MARK: - String sanitiser

private extension String {
    /// Coerce to a filename-safe form: alphanumerics, `-`, `_`.
    /// Used when naming `.saxtheme` exports.
    var fileSystemSafe: String {
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-_"))
        let scalars = unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(scalars))
        return result.isEmpty ? "Profile" : result
    }
}
