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

    var errorDescription: String? { "Không đọc được ảnh." }
}

/// Downscales + JPEG-compresses before upload and computes the blurhash placeholder.
struct ImageProcessor {
    var maxDimension: CGFloat = 1600
    var compressionQuality: CGFloat = 0.8

    func process(_ data: Data) throws -> ProcessedImage {
        guard let image = UIImage(data: data) else { throw ImageProcessingError.invalidImage }
        let resized = resize(image)
        guard let jpeg = resized.jpegData(compressionQuality: compressionQuality) else {
            throw ImageProcessingError.invalidImage
        }
        let pixelWidth = Int(resized.size.width * resized.scale)
        let pixelHeight = Int(resized.size.height * resized.scale)
        let blurhash = BlurHashEncoder.encode(resized) ?? BlurHashEncoder.fallback

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
