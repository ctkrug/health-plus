import SwiftUI
import UIKit

/// Local profile data that isn't auth identity: the user's @username handle and a profile photo.
/// The photo is stored as a downscaled JPEG in the App Group container (so a widget could reuse it).
/// Everything is on-device — no backend (see the accounts decision in the project history).
@Observable
final class ProfileStore {
    var username: String {
        didSet { UserDefaults.standard.set(username, forKey: Self.usernameKey) }
    }
    private(set) var image: UIImage?

    private static let usernameKey = "profileUsername"
    private static let appGroup = "group.com.ctkrug.healthplus"

    private var imageURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)?
            .appendingPathComponent("profile.jpg")
    }

    init() {
        username = UserDefaults.standard.string(forKey: Self.usernameKey) ?? ""
        if let url = imageURL, let data = try? Data(contentsOf: url) {
            image = UIImage(data: data)
        }
    }

    var hasPhoto: Bool { image != nil }

    /// Set (or clear, with nil) the profile photo from raw image data picked by the user.
    func setImage(data: Data?) {
        guard let url = imageURL else { return }
        if let data, let picked = UIImage(data: data)?.downscaled(maxDimension: 512) {
            image = picked
            try? picked.jpegData(compressionQuality: 0.85)?.write(to: url, options: .atomic)
        } else {
            image = nil
            try? FileManager.default.removeItem(at: url)
        }
    }

    func removePhoto() { setImage(data: nil) }
}

private extension UIImage {
    /// Aspect-fit downscale so avatars stay small on disk and in memory.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
