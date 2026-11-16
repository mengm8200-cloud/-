import UIKit

/// Identifies an image kept in backend storage.
enum MediaRef: Hashable {
    /// Path inside the public "avatars" bucket.
    case avatar(String)
    /// Path inside the private "chat-media" bucket.
    case chat(String)
    /// Path inside the private "post-media" bucket.
    case post(String)

    fileprivate var cacheKey: String {
        switch self {
        case .avatar(let path): return "avatars_" + path.replacingOccurrences(of: "/", with: "_")
        case .chat(let path): return "chat_" + path.replacingOccurrences(of: "/", with: "_")
        case .post(let path): return "post_" + path.replacingOccurrences(of: "/", with: "_")
        }
    }
}

/// Loads storage images with a memory cache in front of a disk cache.
final class ImageStore {
    static let shared = ImageStore()

    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL

    private init() {
        memory.countLimit = 300
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func cached(_ ref: MediaRef) -> UIImage? {
        memory.object(forKey: ref.cacheKey as NSString)
    }

    func image(for ref: MediaRef) async throws -> UIImage {
        if let hit = cached(ref) {
            return hit
        }
        let file = directory.appendingPathComponent(ref.cacheKey)
        if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
            memory.setObject(image, forKey: ref.cacheKey as NSString)
            return image
        }

        let data: Data
        switch ref {
        case .avatar(let path):
            let url = Backend.shared.publicURL(bucket: "avatars", path: path)
            data = try await URLSession.shared.data(from: url).0
        case .chat(let path):
            data = try await Backend.shared.download(bucket: "chat-media", path: path)
        case .post(let path):
            data = try await Backend.shared.download(bucket: "post-media", path: path)
        }
        guard let image = UIImage(data: data) else {
            throw BackendError(status: 0, code: "image", message: "图片无法显示")
        }
        store(image, data: data, for: ref)
        return image
    }

    /// Primes the caches, for example with a picture the user just uploaded.
    func store(_ image: UIImage, data: Data, for ref: MediaRef) {
        memory.setObject(image, forKey: ref.cacheKey as NSString)
        try? data.write(to: directory.appendingPathComponent(ref.cacheKey), options: .atomic)
    }
}

enum ImagePrep {
    /// Scales a picked photo down and re-encodes it as JPEG so uploads stay small.
    static func jpeg(from data: Data, maxDimension: CGFloat, quality: CGFloat = 0.8) -> (image: UIImage, data: Data)? {
        guard let source = UIImage(data: data) else { return nil }
        let longest = max(source.size.width, source.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let target = CGSize(
            width: max(1, (source.size.width * scale).rounded()),
            height: max(1, (source.size.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            source.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let encoded = resized.jpegData(compressionQuality: quality) else { return nil }
        return (resized, encoded)
    }
}
