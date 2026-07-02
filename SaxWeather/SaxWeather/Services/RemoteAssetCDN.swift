
import Foundation

/// Shared CDN paths for on-demand assets served from
/// `weather.saxobroko.com`.
enum RemoteAssetCDN {
    static let origin = URL(string: "https://weather.saxobroko.com")!

    static func url(path: String) -> URL {
        origin.appendingPathComponent(path)
    }

    enum Category: String {
        case aurora = "assets/aurora"
        case backgrounds = "assets/backgrounds"
        case lottie = "assets/lottie"
    }

    static func remoteURL(category: Category, filename: String) -> URL {
        url(path: "\(category.rawValue)/\(filename)")
    }
}
