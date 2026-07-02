//
//  ProfileMigrator.swift
//  SaxWeather
//
//  Loads `.saxtheme` JSON data of any supported `schemaVersion`
//  and migrates it forward to `currentSchemaVersion`. Adding a new
//  knob follows a two-step recipe:
//
//    1. Bump `ProfileMigrator.currentSchemaVersion`.
//    2. Add a `case` to `applyMigration(version:to:)` that
//       back-fills the new field with its default in the
//       generic-JSON layer.
//
//  Note: purely additive changes (a new optional knob with a
//  default) don't need a migration — Swift's `Codable` fills the
//  default automatically. Only renames and removals do.
//
//  Phase 4 — Aurora Backgrounds single-preset refactor.
//  The 8 specific `BackgroundMode` cases (`.auroraSunny`,
//  `.auroraCloudy`, etc.) were removed and replaced with a
//  single `.aurora` case. The resolver now picks the right
//  Aurora image based on the current weather condition.
//  Profiles saved with the old `.aurora*` modes are migrated
//  to `.aurora`.
//

import Foundation

enum ProfileMigrator {
    /// The schema version this binary understands. Bump this every
    /// time a knob is renamed, removed, or its *meaning* changes
    /// in a way older files can't represent.
    ///
    /// ## Version history
    ///
    /// - **1** — initial schema. Eleven spec structs, ~50 knobs.
    /// - **2** — "Infinitely customisable" expansion.
    ///   * Surfaced ~25 existing-but-undocumented knobs as
    ///     `KnobDescriptor`s so they show up in the Settings
    ///     search.
    ///   * Added new knobs for swipe-to-switch-location, hero
    ///     layout density, hourly card size, daily card density,
    ///     and two experimental flags.
    ///   * Purely additive — every old `.saxtheme` still decodes
    ///     via Swift's `Codable` defaults. This migration case is
    ///     here for documentation and so future renames have a
    ///     place to grow.
    /// - **3** — Aurora Backgrounds single-preset refactor.
    ///   * Removed the 8 specific `BackgroundMode` cases
    ///     (`.auroraSunny`, `.auroraCloudy`, etc.) and replaced
    ///     them with a single `.aurora` case.
    ///   * The resolver now picks the right Aurora image based
    ///     on the current weather condition.
    ///   * Profiles saved with the old `.aurora*` modes are
    ///     migrated to `.aurora`.
    static let currentSchemaVersion: Int = 3

    /// Decode + migrate + return the up-to-date profile.
    /// Throws `ProfileMigratorError.invalidFormat` if the data
    /// isn't a JSON object, or `.unsupportedVersion(_)` if the
    /// on-disk version is newer than this binary supports.
    static func migrate(_ data: Data) throws -> CustomisationProfile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Phase A: parse as a generic JSON object so we can inspect
        // (and possibly mutate) `schemaVersion` independently of the
        // typed struct.
        let raw = try JSONSerialization.jsonObject(with: data)
        guard var dict = raw as? [String: Any] else {
            throw ProfileMigratorError.invalidFormat
        }

        let rawVersion = (dict["schemaVersion"] as? Int) ?? 0

        // Phase B: run migrations from `rawVersion + 1` upward.
        guard rawVersion <= currentSchemaVersion else {
            throw ProfileMigratorError.unsupportedVersion(rawVersion)
        }
        if rawVersion < currentSchemaVersion {
            for v in (rawVersion + 1)...currentSchemaVersion {
                applyMigration(version: v, to: &dict)
            }
            dict["schemaVersion"] = currentSchemaVersion
        }

        // Phase C: re-encode and decode into the typed model.
        let migratedData = try JSONSerialization.data(withJSONObject: dict)
        var profile = try decoder.decode(CustomisationProfile.self, from: migratedData)
        // Always trust the binary's version stamp over whatever came
        // in from disk, in case the re-encode round-trip lost it.
        profile.schemaVersion = currentSchemaVersion
        return profile
    }

    /// Per-version transformations. Keep each case idempotent so
    /// re-running migrations against already-migrated data is safe.
    private static func applyMigration(version: Int, to dict: inout [String: Any]) {
        switch version {
        case 1:
            // Initial schema. No migrations needed; every field has
            // a default in its struct definition, and Swift's
            // `Codable` synthesis fills them in automatically.
            break
        case 2:
            // v2 is purely additive — every new knob has a default
            // in its struct definition, so Swift's `Codable` synthesis
            // fills them in automatically when the file is re-decoded
            // after we bump the schemaVersion stamp. Nothing to do
            // here beyond bump; the case is kept so the migration
            // table has an obvious place to grow when a v3 renames a
            // field.
            break
        case 3:
            // Phase 4 — Aurora Backgrounds single-preset refactor.
            // The 8 specific `BackgroundMode` cases (`.auroraSunny`,
            // `.auroraCloudy`, etc.) were removed and replaced with
            // a single `.aurora` case. Profiles saved with the old
            // `.aurora*` modes are migrated to `.aurora`.
            migrateAuroraModesToSinglePreset(in: &dict)
        default:
            // Future versions: add `case 4: …` etc. above this.
            break
        }
    }

    /// Phase 4 migration — map any `.aurora*` `BackgroundMode`
    /// to the single `.aurora` case. The resolver picks the
    /// right Aurora image based on the current weather
    /// condition, so the user-visible behaviour is identical.
    private static func migrateAuroraModesToSinglePreset(in dict: inout [String: Any]) {
        guard var knobs = dict["knobs"] as? [String: Any] else { return }
        guard var background = knobs["background"] as? [String: Any] else { return }
        guard let mode = background["mode"] as? String else { return }

        // Map any `.aurora*` mode to `.aurora`.
        if mode.hasPrefix("aurora") {
            background["mode"] = "aurora"
            knobs["background"] = background
            dict["knobs"] = knobs
        }
    }
}

enum ProfileMigratorError: LocalizedError, Equatable {
    case invalidFormat
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid .saxtheme file format."
        case .unsupportedVersion(let v):
            return "Unsupported profile version: \(v). Update SaxWeather to load this theme."
        }
    }
}
