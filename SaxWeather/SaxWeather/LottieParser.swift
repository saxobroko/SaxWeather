//
//  LottieParser.swift
//  SaxWeather
//

import Foundation
import Lottie
import SwiftUI

@MainActor
enum LottieParser {
    static func cachedFilePath(for name: String) -> String? {
        for candidate in candidateNames(for: name) {
            let path = LottieAssetStore.shared.localURL(forName: candidate).path
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    static func loadAnimation(named name: String) -> LottieAnimation? {
        for candidate in candidateNames(for: name) {
            if let animation = loadJSONFromCache(named: candidate) {
                return animation
            }
        }

        #if DEBUG
        print("❌ Failed to load animation: \(name)")
        #endif
        return nil
    }

    static func makeAnimationView(
        named name: String,
        loopMode: LottieLoopMode,
        speed: CGFloat,
        onFailure: @escaping () -> Void
    ) -> LottieAnimationView {
        guard let path = cachedFilePath(for: name) else {
            onFailure()
            return LottieAnimationView()
        }

        return LottieAnimationView(
            dotLottieFilePath: path,
            configuration: .shared
        ) { view, error in
            if error != nil {
                onFailure()
                return
            }
            view.contentMode = .scaleAspectFit
            view.loopMode = loopMode
            view.animationSpeed = speed
            view.play()
        }
    }

    private static func candidateNames(for name: String) -> [String] {
        var names = [name]
        let alternate = name.contains("-")
            ? name.replacingOccurrences(of: "-", with: "_")
            : name.replacingOccurrences(of: "_", with: "-")
        if alternate != name {
            names.append(alternate)
        }
        return names
    }

    private static func loadJSONFromCache(named name: String) -> LottieAnimation? {
        let jsonPath = LottieAssetStore.shared.localURL(forName: name)
            .deletingPathExtension()
            .appendingPathExtension("json")
            .path
        guard FileManager.default.fileExists(atPath: jsonPath) else { return nil }
        return LottieAnimation.filepath(jsonPath)
    }
}
