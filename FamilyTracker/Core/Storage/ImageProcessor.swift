import UIKit

struct ProcessedImage {
    let data: Data
    let width: Int
    let height: Int
    let mimeType: String
    let blurhash: String
}

enum ImageProcessingError: LocalizedError {
    case invalidImage

    var errorDescription: String? { L10n.tr("media.error.image_unreadable") }
}

/// Downscales + JPEG-compresses before upload and computes the blurhash placeholder.
struct ImageProcessor {
    var maxDimension: CGFloat = 1600
    var compressionQuality: CGFloat = 0.8

    func process(_ data: Data) throws -> ProcessedImage {
        guard let image = UIImage(data: data) else { throw ImageProcessingError.invalidImage }
        let resized = resize(image)
        var jpeg: Data?
        for quality in [compressionQuality, 0.7, 0.6, 0.5, 0.4] {
            jpeg = resized.jpegData(compressionQuality: quality)
            if let jpeg, jpeg.count <= MediaUploadPolicy.maxImageBytes { break }
        }
        guard let jpeg else { throw ImageProcessingError.invalidImage }
        guard jpeg.count <= MediaUploadPolicy.maxImageBytes else {
            throw MediaUploadError.invalidMedia("media.error.image_too_large")
        }
        let pixelWidth = Int(resized.size.width * resized.scale)
        let pixelHeight = Int(resized.size.height * resized.scale)
        let blurhash = BlurHashEncoder.encode(resized) ?? BlurHashEncoder.fallback

        guard MediaUploadPolicy.validImageDimension.contains(pixelWidth),
              MediaUploadPolicy.validImageDimension.contains(pixelHeight),
              MediaUploadPolicy.validBlurHashLength.contains(blurhash.count) else {
            throw MediaUploadError.invalidMedia("media.error.invalid_image_metadata")
        }

        return ProcessedImage(data: jpeg, width: pixelWidth, height: pixelHeight, mimeType: "image/jpeg", blurhash: blurhash)
    }

    private func resize(_ image: UIImage) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let ratio = maxDimension / longest
        let target = CGSize(width: (size.width * ratio).rounded(), height: (size.height * ratio).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
