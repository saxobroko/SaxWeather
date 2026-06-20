import SwiftUI
import Lottie

#if os(iOS)
import UIKit

struct LottieView: UIViewRepresentable {
    var name: String
    var loopMode: LottieLoopMode = .loop
    @Binding var loadingFailed: Bool
    @AppStorage("disableWeatherAnimations") private var disableWeatherAnimations = false
    @AppStorage("reduceMotion") private var reduceMotion = false
    // Phase 6 — playback speed is bridged from
    // `IconographySpec.lottiePlaybackSpeed` via
    // `ProfileToAppStorageBridge`. Default 1.0 matches the
    // registry default so existing call sites see no change.
    @AppStorage("lottiePlaybackSpeed") private var lottiePlaybackSpeed: Double = 1.0

    init(name: String, loopMode: LottieLoopMode = .loop) {
        self.name = name
        self.loopMode = loopMode
        self._loadingFailed = .constant(false)
    }

    init(name: String, loopMode: LottieLoopMode = .loop, loadingFailed: Binding<Bool>) {
        self.name = name
        self.loopMode = loopMode
        self._loadingFailed = loadingFailed
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.tag = 999 // Tag to identify our container
        
        // If animations are disabled, show a static weather icon instead
        if disableWeatherAnimations || reduceMotion {
            print("🎨 LottieView: Showing static icon for \(name) (animations disabled: \(disableWeatherAnimations), reduce motion: \(reduceMotion))")
            let iconView = UIImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.contentMode = .scaleAspectFit
            iconView.tintColor = .label
            
            // Map animation name to SF Symbol
            let symbolName = weatherSymbolForAnimation(name)
            iconView.image = UIImage(systemName: symbolName)
            
            containerView.addSubview(iconView)
            
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
                iconView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
            ])
            
            return containerView
        }
        
        print("🎬 LottieView: Showing animated icon for \(name)")
        
        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        ])
        
        // Use our custom parser to load the animation
        if let animation = LottieParser.loadAnimation(named: name) {
            animationView.animation = animation
            animationView.contentMode = .scaleAspectFit
            animationView.loopMode = loopMode
            // Phase 6 — honour `IconographySpec.lottiePlaybackSpeed`
            // (bridged to UserDefaults via `ProfileToAppStorageBridge`).
            animationView.animationSpeed = CGFloat(lottiePlaybackSpeed)
            animationView.play()
        } else {
            // Animation failed to load
            DispatchQueue.main.async {
                self.loadingFailed = true
            }

            // Show error indicator
            let label = UILabel()
            label.text = "❌"
            label.font = UIFont.systemFont(ofSize: 40)
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(label)

            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
            ])
        }

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Check if settings have changed and we need to recreate the view
        let hasSubviews = !uiView.subviews.isEmpty
        let isCurrentlyStatic = hasSubviews && uiView.subviews.first is UIImageView
        let shouldBeStatic = disableWeatherAnimations || reduceMotion
        
        // If the state changed (static <-> animated), recreate the view
        if isCurrentlyStatic != shouldBeStatic {
            print("🔄 LottieView: Settings changed, recreating view (static: \(shouldBeStatic))")
            
            // Remove all subviews
            uiView.subviews.forEach { $0.removeFromSuperview() }
            
            if shouldBeStatic {
                // Create static icon
                let iconView = UIImageView()
                iconView.translatesAutoresizingMaskIntoConstraints = false
                iconView.contentMode = .scaleAspectFit
                iconView.tintColor = .label
                
                let symbolName = weatherSymbolForAnimation(name)
                iconView.image = UIImage(systemName: symbolName)
                
                uiView.addSubview(iconView)
                
                NSLayoutConstraint.activate([
                    iconView.widthAnchor.constraint(equalTo: uiView.widthAnchor),
                    iconView.heightAnchor.constraint(equalTo: uiView.heightAnchor)
                ])
            } else {
                // Create animated view
                let animationView = LottieAnimationView()
                animationView.translatesAutoresizingMaskIntoConstraints = false
                uiView.addSubview(animationView)
                
                NSLayoutConstraint.activate([
                    animationView.widthAnchor.constraint(equalTo: uiView.widthAnchor),
                    animationView.heightAnchor.constraint(equalTo: uiView.heightAnchor)
                ])
                
                if let animation = LottieParser.loadAnimation(named: name) {
                    animationView.animation = animation
                    animationView.contentMode = .scaleAspectFit
                    animationView.loopMode = loopMode
                    // Phase 6 — honour `IconographySpec.lottiePlaybackSpeed`.
                    animationView.animationSpeed = CGFloat(lottiePlaybackSpeed)
                    animationView.play()
                }
            }
        }
    }

    private func weatherSymbolForAnimation(_ animationName: String) -> String {
        let name = animationName.lowercased()
        switch name {
        case "clear-day": return "sun.max.fill"
        case "clear-night": return "moon.stars.fill"
        case "partly-cloudy", "partly-cloudy-night": return "cloud.sun.fill"
        case "cloudy": return "cloud.fill"
        case "foggy": return "cloud.fog.fill"
        case "rainy": return "cloud.rain.fill"
        case "snowy": return "cloud.snow.fill"
        case "thunderstorm": return "cloud.bolt.fill"
        default: return "cloud.sun.fill"
        }
    }
}
#endif

#if os(macOS)
import AppKit

struct LottieView: NSViewRepresentable {
    var name: String
    var loopMode: LottieLoopMode = .loop
    @Binding var loadingFailed: Bool
    @AppStorage("disableWeatherAnimations") private var disableWeatherAnimations = false
    @AppStorage("reduceMotion") private var reduceMotion = false
    // Phase 6 — playback speed is bridged from
    // `IconographySpec.lottiePlaybackSpeed` via
    // `ProfileToAppStorageBridge`. Default 1.0 matches the
    // registry default so existing call sites see no change.
    @AppStorage("lottiePlaybackSpeed") private var lottiePlaybackSpeed: Double = 1.0

    init(name: String, loopMode: LottieLoopMode = .loop) {
        self.name = name
        self.loopMode = loopMode
        self._loadingFailed = .constant(false)
    }

    init(name: String, loopMode: LottieLoopMode = .loop, loadingFailed: Binding<Bool>) {
        self.name = name
        self.loopMode = loopMode
        self._loadingFailed = loadingFailed
    }
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        
        // If animations are disabled, show a static weather icon instead
        if disableWeatherAnimations || reduceMotion {
            print("🎨 LottieView (macOS): Showing static icon for \(name) (animations disabled: \(disableWeatherAnimations), reduce motion: \(reduceMotion))")
            let iconView = NSImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.imageScaling = .scaleProportionallyUpOrDown
            
            // Map animation name to SF Symbol
            let symbolName = weatherSymbolForAnimation(name)
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: name) {
                iconView.image = image
            }
            
            containerView.addSubview(iconView)
            
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
                iconView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
            ])
            
            return containerView
        }
        
        print("🎬 LottieView (macOS): Showing animated icon for \(name)")
        
        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        ])
        
        if let animation = LottieParser.loadAnimation(named: name) {
            animationView.animation = animation
            animationView.loopMode = loopMode
            // Phase 6 — honour `IconographySpec.lottiePlaybackSpeed`.
            animationView.animationSpeed = CGFloat(lottiePlaybackSpeed)
            animationView.play()
        } else {
            loadingFailed = true
        }
        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Check if settings have changed and we need to recreate the view
        let hasSubviews = !nsView.subviews.isEmpty
        let isCurrentlyStatic = hasSubviews && nsView.subviews.first is NSImageView
        let shouldBeStatic = disableWeatherAnimations || reduceMotion
        
        // If the state changed (static <-> animated), recreate the view
        if isCurrentlyStatic != shouldBeStatic {
            print("🔄 LottieView (macOS): Settings changed, recreating view (static: \(shouldBeStatic))")
            
            // Remove all subviews
            nsView.subviews.forEach { $0.removeFromSuperview() }
            
            if shouldBeStatic {
                // Create static icon
                let iconView = NSImageView()
                iconView.translatesAutoresizingMaskIntoConstraints = false
                iconView.imageScaling = .scaleProportionallyUpOrDown
                
                let symbolName = weatherSymbolForAnimation(name)
                if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: name) {
                    iconView.image = image
                }
                
                nsView.addSubview(iconView)
                
                NSLayoutConstraint.activate([
                    iconView.widthAnchor.constraint(equalTo: nsView.widthAnchor),
                    iconView.heightAnchor.constraint(equalTo: nsView.heightAnchor)
                ])
            } else {
                // Create animated view
                let animationView = LottieAnimationView()
                animationView.translatesAutoresizingMaskIntoConstraints = false
                nsView.addSubview(animationView)
                
                NSLayoutConstraint.activate([
                    animationView.widthAnchor.constraint(equalTo: nsView.widthAnchor),
                    animationView.heightAnchor.constraint(equalTo: nsView.heightAnchor)
                ])
                
                if let animation = LottieParser.loadAnimation(named: name) {
                    animationView.animation = animation
                    animationView.loopMode = loopMode
                    // Phase 6 — honour `IconographySpec.lottiePlaybackSpeed`.
                    animationView.animationSpeed = CGFloat(lottiePlaybackSpeed)
                    animationView.play()
                }
            }
        }
    }

    private func weatherSymbolForAnimation(_ animationName: String) -> String {
        let name = animationName.lowercased()
        switch name {
        case "clear-day": return "sun.max.fill"
        case "clear-night": return "moon.stars.fill"
        case "partly-cloudy", "partly-cloudy-night": return "cloud.sun.fill"
        case "cloudy": return "cloud.fill"
        case "foggy": return "cloud.fog.fill"
        case "rainy": return "cloud.rain.fill"
        case "snowy": return "cloud.snow.fill"
        case "thunderstorm": return "cloud.bolt.fill"
        default: return "cloud.sun.fill"
        }
    }
}
#endif
