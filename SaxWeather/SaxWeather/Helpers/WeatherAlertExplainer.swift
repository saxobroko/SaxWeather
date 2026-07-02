//
//  WeatherAlertExplainer.swift
//  SaxWeather
//
//  Uses Apple's on-device Foundation Models (iOS 26+) to rewrite official
//  weather warnings in plain, easy-to-understand language.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum WeatherAlertExplainer {

    enum ExplainerError: LocalizedError {
        case unavailable
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Plain-language explanations aren't available on this device."
            case .emptyResponse:
                return "Couldn't generate an explanation. Please try again."
            }
        }
    }

    /// True when Apple Intelligence is enabled and the on-device model is ready.
    static var isSupported: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
        }
        #endif
        return false
    }

    static func summariseAll(alerts: [WeatherAlert]) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                throw ExplainerError.unavailable
            }
            guard !alerts.isEmpty else { throw ExplainerError.emptyResponse }

            let session = LanguageModelSession(instructions: Self.overviewInstructions)
            let response = try await session.respond(to: Self.buildOverviewPrompt(alerts: alerts))
            let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { throw ExplainerError.emptyResponse }
            return content
        }
        #endif
        throw ExplainerError.unavailable
    }

    static func explain(title: String, affectedArea: String?, details: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                throw ExplainerError.unavailable
            }

            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(
                to: Self.buildPrompt(title: title, affectedArea: affectedArea, details: details)
            )
            let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { throw ExplainerError.emptyResponse }
            return content
        }
        #endif
        throw ExplainerError.unavailable
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static var instructions: String {
        """
        You explain official weather warnings in plain, calm language for the \
        general public. In a few short sentences, cover: what is happening, who \
        or where is affected, the main risks, and what people should do to stay \
        safe. Use simple words and a reassuring but clear tone. Only use \
        information from the warning provided — never invent specifics such as \
        times, places, or measurements. Keep the whole explanation under 120 words.
        """
    }
    #endif

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static var overviewInstructions: String {
        """
        You brief the general public on the current weather warnings for their \
        area in plain, calm language. Give a short overview: how many warnings \
        there are, which are the most serious, and the key things people should \
        watch out for or do. Use simple words and lead with the most important \
        risk. Only use information from the warnings provided — never invent \
        specifics. Keep the whole summary under 130 words.
        """
    }
    #endif

    private static func buildOverviewPrompt(alerts: [WeatherAlert]) -> String {
        var prompt = "Summarise these current weather warnings in plain language.\n"
        for (index, alert) in alerts.enumerated() {
            prompt += "\n\(index + 1). \(alert.type)"
            prompt += " (severity: \(alert.severity.rawValue))"
            if let area = alert.affectedArea, !area.isEmpty {
                prompt += "\n   Affected area: \(area)"
            }
            let detail = alert.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if !detail.isEmpty, detail != alert.type {
                prompt += "\n   Details: \(detail)"
            }
        }
        return prompt
    }

    private static func buildPrompt(title: String, affectedArea: String?, details: String) -> String {
        var prompt = "Explain this weather warning in plain language.\n\nTitle: \(title)\n"
        if let affectedArea, !affectedArea.isEmpty {
            prompt += "Affected area: \(affectedArea)\n"
        }
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDetails.isEmpty {
            prompt += "\nWarning details:\n\(trimmedDetails)"
        }
        return prompt
    }
}
