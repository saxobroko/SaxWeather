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
import SwiftUI
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

    /// User-saved profiles (named, mutable, deletable). The five
    /// [`BuiltInProfile`](SaxWeather/SaxWeather/Models/CustomisationProfile.swift:73)s
    /// are not stored here — they're factory-built on demand. This
    /// list only contains profiles the user has explicitly saved
    /// via `saveCurrentAs(name:)` or imported via `importProfile(from:)`.
    /// Phase 7 — wired into the Settings UI's `ProfileSwitcherView`.
    @Published private(set) var savedProfiles: [CustomisationProfile] = []

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
    /// Filename inside the App Group container holding the saved-
    /// profile index (an array of `CustomisationProfile`s).
    private static let savedProfilesFilename = "saved-profiles.json"

    #if DEBUG
    /// File-system watcher that powers hot-reload.
    private var hotReloadSource: DispatchSourceFileSystemObject?
    #endif

    // MARK: - Init

    /// Production init.
    ///
    /// Boot order:
    ///   1. Try the App Group profile file (`current.saxtheme`).
    ///      If it exists, load + migrate and use it directly.
    ///   2. Otherwise, seed a fresh `KnobStorage` from any values
    ///      the user already customised via the legacy `@AppStorage`
    ///      UI (first launch post-Phase-2 deploy).
    ///   3. Write the resulting knobs through to `UserDefaults`
    ///      so any `@AppStorage` reads see consistent values from
    ///      the very first frame.
    ///   4. Persist the seeded profile so subsequent launches
    ///      skip step 2.
    private init() {
        if let loaded = Self.loadFromDisk() {
            self.profile = loaded
            // Re-bridge in case UserDefaults drifted (e.g. a user
            // edited via the Settings app or an external tool).
            ProfileToAppStorageBridge.bridge(loaded.knobs)
        } else {
            let seeded = ProfileToAppStorageBridge.readFromAppStorage()
            var fresh = CustomisationProfile(
                name: "Default",
                builtIn: .default,
                knobs: seeded
            )
            fresh.schemaVersion = ProfileMigrator.currentSchemaVersion
            self.profile = fresh
            // Write through so @AppStorage views see consistent
            // values on the first frame.
            ProfileToAppStorageBridge.bridge(fresh.knobs)
            // Persist so step 2 doesn't repeat on next launch.
            persist()
        }
        recomputeHash()
        loadSavedProfiles()
        setupHotReload()
    }

    /// Test-only init. Starts fresh from `initial`, no disk I/O, no
    /// hot-reload watcher. Use this in unit tests to avoid singleton
    /// leakage across test cases.
    init(testProfile initial: CustomisationProfile = .makeDefault()) {
        self.profile = initial
        self.savedProfiles = []
        recomputeHash()
    }

    /// Test-only init that seeds a pre-populated saved-profiles
    /// list. Used by unit tests for the saved-profile CRUD methods.
    init(testProfile initial: CustomisationProfile, savedProfiles: [CustomisationProfile]) {
        self.profile = initial
        self.savedProfiles = savedProfiles
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
        // Write through to UserDefaults so every existing
        // `@AppStorage` view continues to reflect the new profile.
        ProfileToAppStorageBridge.bridge(profile.knobs)
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
        // Write the single changed knob (and its siblings, for
        // simplicity) to UserDefaults so existing `@AppStorage`
        // views see the new value on the next render pass.
        ProfileToAppStorageBridge.bridge(profile.knobs)
        reloadWidgets()
    }

    /// Read a single knob via a key path.
    func get<Value>(_ keyPath: KeyPath<KnobStorage, Value>) -> Value {
        profile.knobs[keyPath: keyPath]
    }

    /// A two-way `Binding` to the active `KnobStorage`. Use
    /// `$registry.knobsBinding.background.mode` in SwiftUI views
    /// to bind pickers, sliders, and toggles to a single knob —
    /// `setKnobs(_:)` runs on every write so the change
    /// persists, bumps the hash, and reloads widgets.
    ///
    /// Why a custom binding instead of binding to `profile`
    /// directly? `profile` is `@Published private(set)` so the
    /// setter is private (all writes must funnel through the
    /// registry to keep the persistence + widget-reload
    /// invariants).
    var knobsBinding: Binding<KnobStorage> {
        Binding(
            get: { self.profile.knobs },
            set: { self.setKnobs($0) }
        )
    }

    /// Replace the whole `KnobStorage`. Bumps the profile
    /// timestamp, persists, bridges to `UserDefaults`, and
    /// reloads widgets. The sibling of `set(_:_:)` for callers
    /// that already hold a complete `KnobStorage` (e.g. SwiftUI
    /// bindings).
    func setKnobs(_ newKnobs: KnobStorage) {
        var newProfile = profile
        guard newProfile.knobs != newKnobs else { return }
        newProfile.knobs = newKnobs
        newProfile.updatedAt = Date()
        profile = newProfile
        recomputeHash()
        persist()
        ProfileToAppStorageBridge.bridge(profile.knobs)
        reloadWidgets()
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

    // MARK: - Saved profiles (Phase 7)

    /// Save the active profile under a new name. The saved profile
    /// appears in `savedProfiles` and is persisted to the App
    /// Group so it survives relaunches. If a saved profile with
    /// the same name already exists, it's overwritten (same UUID
    /// is preserved so the user doesn't see a duplicate row).
    func saveCurrentAs(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var snapshot = profile
        snapshot.name = trimmed
        snapshot.id = savedProfiles.first(where: { $0.name == trimmed })?.id ?? UUID()
        if let idx = savedProfiles.firstIndex(where: { $0.name == trimmed }) {
            savedProfiles[idx] = snapshot
        } else {
            savedProfiles.append(snapshot)
        }
        persistSavedProfiles()
    }

    /// Delete a saved profile by ID. No-op if the profile isn't
    /// in the list.
    func deleteSavedProfile(id: UUID) {
        savedProfiles.removeAll { $0.id == id }
        persistSavedProfiles()
    }

    /// Rename a saved profile. No-op if the profile isn't in the
    /// list. If `newName` collides with an existing saved profile,
    /// the rename is rejected (no silent overwrite).
    @discardableResult
    func renameSavedProfile(id: UUID, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let idx = savedProfiles.firstIndex(where: { $0.id == id }) else {
            return false
        }
        if savedProfiles.contains(where: { $0.name == trimmed && $0.id != id }) {
            return false
        }
        savedProfiles[idx].name = trimmed
        persistSavedProfiles()
        return true
    }

    /// Apply a saved profile by ID. No-op if not found.
    func applySavedProfile(id: UUID) {
        guard let saved = savedProfiles.first(where: { $0.id == id }) else { return }
        apply(saved)
    }

    // MARK: - Saved-profile persistence

    /// URL of the saved-profiles JSON file inside the App Group, or
    /// `nil` if the container isn't available.
    private var savedProfilesURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)?
            .appendingPathComponent(Self.savedProfilesFilename)
    }

    /// Load saved profiles from disk on init.
    private func loadSavedProfiles() {
        guard let url = savedProfilesURL,
              let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let profiles = try? decoder.decode([CustomisationProfile].self, from: data) {
            self.savedProfiles = profiles
        }
    }

    /// Persist the current `savedProfiles` array to disk.
    private func persistSavedProfiles() {
        guard let url = savedProfilesURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(savedProfiles)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("⚠️ CustomisationRegistry: failed to persist saved profiles — \(error)")
            #endif
        }
    }

    // MARK: - Knob catalogue (Phase 7 — Settings search)

    /// Every knob the registry knows about, for the Settings
    /// search UI. New knob = one new descriptor here. The search
    /// matches against `searchTokens` (case-insensitive).
    var allKnobs: [KnobDescriptor] {
        KnobDescriptor.catalogue
    }

    /// Subset of `allKnobs` whose `searchTokens` contain the query
    /// (case-insensitive). Empty query returns everything.
    func searchKnobs(_ query: String) -> [KnobDescriptor] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allKnobs }
        let lower = trimmed.lowercased()
        return allKnobs.filter { descriptor in
            descriptor.searchTokens.contains { $0.lowercased().contains(lower) }
        }
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
