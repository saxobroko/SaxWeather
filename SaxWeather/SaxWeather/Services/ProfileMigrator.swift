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

import Foundation

enum ProfileMigrator {
    /// The schema version this binary understands. Bump this every
    /// time a knob is renamed, removed, or its *meaning* changes
    /// in a way older files can't represent.
    static let currentSchemaVersion: Int = 1

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
        default:
            // Future versions: add `case 2: …` etc. above this.
            break
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
