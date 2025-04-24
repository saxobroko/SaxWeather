import Foundation
import Lottie

class AnimationCache {
    static let shared = AnimationCache()
    private var cache: [String: LottieAnimation] = [:]
    private let queue = DispatchQueue(label: "com.saxweather.animationcache", qos: .userInitiated)
    
    private init() {}
    
    func getAnimation(named name: String) -> LottieAnimation? {
        return queue.sync {
            return cache[name]
        }
    }
    
    func setAnimation(_ animation: LottieAnimation, for name: String) {
        queue.async {
            self.cache[name] = animation
        }
    }
    
    func clearCache() {
        queue.async {
            self.cache.removeAll()
        }
    }
    
    func preloadAnimations() {
        let animations = [
            "clear-day", "clear-night", "partly-cloudy", "partly-cloudy-night",
            "cloudy", "rainy", "thunderstorm", "foggy"
        ]
        
        for animationName in animations {
            if let animation = LottieParser.loadAnimation(named: animationName) {
                setAnimation(animation, for: animationName)
            }
        }
    }
} 