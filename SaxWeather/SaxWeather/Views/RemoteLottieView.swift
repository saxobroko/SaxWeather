import SwiftUI
import Lottie

/// Wraps `LottieView` with CDN download + a single refresh when
/// this animation's cache file becomes available.
struct RemoteLottieView: View {
    let name: String
    var loopMode: LottieLoopMode = .loop
    @Binding var loadingFailed: Bool

    @State private var refreshToken = UUID()
    @State private var loadedName: String?

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

    var body: some View {
        LottieView(name: name, loopMode: loopMode, loadingFailed: $loadingFailed)
            .id("\(name)-\(refreshToken)")
            .task(id: name) {
                let store = LottieAssetStore.shared
                if loadedName == name, store.isDownloaded(name: name) {
                    return
                }
                if store.isDownloaded(name: name) {
                    loadedName = name
                    refreshToken = UUID()
                    return
                }
                try? await store.download(name: name)
                if store.isDownloaded(name: name) {
                    loadedName = name
                    refreshToken = UUID()
                }
            }
    }
}
