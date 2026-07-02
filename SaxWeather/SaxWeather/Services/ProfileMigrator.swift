
import Foundation

enum ProfileMigrator {
    static let currentSchemaVersion: Int = 3

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
            migrateAuroraModesToSinglePreset(in: &dict)
        default:
            // Future versions: add `case 4: …` etc. above this.
            break
        }
    }

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
