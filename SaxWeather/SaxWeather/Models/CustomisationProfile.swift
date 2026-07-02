//
//  CustomisationProfile.swift
//  SaxWeather
//
//  "Infinitely customisable" foundation — Phase 1.
//
//  A `CustomisationProfile` is a named, versioned bundle of every
//  customisation knob in the app. This file defines the top-level
//  type, the `BuiltInProfile` enum (the five non-deletable presets),
//  and `KnobStorage` which groups the eleven typed spec structs.
//
//  See `plans/INFINITE_CUSTOMISATION_PLAN.md` for the full design.
//

import Foundation

/// A versioned, Codable snapshot of every customisation knob in
/// the app. Profiles are the unit users save, switch between,
/// export, and share as `.saxtheme` files.
///
/// Every property has a sensible default so a freshly-constructed
/// `KnobStorage()` reproduces the app's shipped behaviour exactly
/// (matches the existing `@AppStorage` defaults throughout the
/// codebase).
struct CustomisationProfile: Codable, Hashable, Identifiable {
    /// Stable identifier. Preserved across edits; new UUIDs only
    /// happen on "Save as new profile…".
    var id: UUID
    /// Human-readable name shown in the profile switcher and used
    /// as the prefix of exported `.saxtheme` filenames.
    var name: String
    /// Which built-in preset this profile derives from. Used to
    /// seed the "Reset to preset" action.
    var builtIn: BuiltInProfile
    var createdAt: Date
    var updatedAt: Date
    /// Bumped whenever a knob is added or renamed.
    /// `ProfileMigrator` reads this and back-fills defaults for
    /// older profiles so `.saxtheme` files always load.
    var schemaVersion: Int
    /// The actual bag of knobs. See `KnobStorage` and the eleven
    /// spec structs in `ProfileSpecs.swift`.
    var knobs: KnobStorage

    init(
        id: UUID = UUID(),
        name: String,
        builtIn: BuiltInProfile,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        schemaVersion: Int = ProfileMigrator.currentSchemaVersion,
        knobs: KnobStorage = KnobStorage()
    ) {
        self.id = id
        self.name = name
        self.builtIn = builtIn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
        self.knobs = knobs
    }

    /// Factory for the runtime "Default" profile. Always uses the
    /// registry's current schema version so the version stamp is
    /// never stale on first launch.
    static func makeDefault() -> CustomisationProfile {
        CustomisationProfile(name: "Default", builtIn: .default)
    }
}

/// The five non-deletable starter profiles. Every other profile a
/// user creates derives from one of these via "Save as…".
enum BuiltInProfile: String, Codable, CaseIterable, Identifiable, Hashable {
    case `default`
    case minimalist
    case powerUser
    case accessibility
    case batterySaver

    var id: String { rawValue }

    /// User-facing name. Localisable in a future phase.
    var displayName: String {
        switch self {
        case .default:       return "Default"
        case .minimalist:    return "Minimalist"
        case .powerUser:     return "Power User"
        case .accessibility: return "Accessibility"
        case .batterySaver:  return "Battery Saver"
        }
    }

    /// The `CustomisationProfile` that represents this preset.
    /// Built fresh on each access; the registry assigns its own
    /// `id`/`createdAt` when applying.
    var profile: CustomisationProfile {
        BuiltInProfiles.profile(for: self)
    }
}

/// Container for every customisation knob, grouped by category.
/// Each group is a strongly-typed struct so reading or writing a
/// single knob is type-safe, even though the whole bundle
/// serialises as one `.saxtheme` JSON document.
///
/// New group? Add it here, define the spec struct in
/// `ProfileSpecs.swift`, and bump `ProfileMigrator.currentSchemaVersion`
/// if you need a migration for older profiles.
struct KnobStorage: Codable, Hashable {
    var visual        : VisualSpec         = .init()
    var background    : BackgroundSpec     = .init()
    var iconography   : IconographySpec    = .init()
    var layout        : LayoutSpec         = .init()
    var data          : DataSpec           = .init()
    var behaviour     : BehaviourSpec      = .init()
    var accessibility : AccessibilitySpec  = .init()
    var content       : ContentSpec        = .init()
    var powerUser     : PowerUserSpec      = .init()
    var widget        : WidgetSpec         = .init()
    var forecast      : ForecastSpec       = .init()
}
