import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    var name: String
    var loopMode: LottieLoopMode = .loop
    @Binding var loadingFailed: Bool
    
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
        // Nothing to update
    }
}
