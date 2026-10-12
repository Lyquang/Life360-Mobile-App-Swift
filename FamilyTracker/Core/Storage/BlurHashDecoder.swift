import UIKit

enum BlurHashDecoder {
    private static let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~")

    static func image(from hash: String, width: Int = 32, height: Int = 24) -> UIImage? {
        let characters = Array(hash)
        guard characters.count >= 6, let size = decode(characters, 0, 1) else { return nil }
        let componentsX = size % 9 + 1, componentsY = size / 9 + 1
        guard characters.count == 4 + 2 * componentsX * componentsY,
              let maximumValue = decode(characters, 1, 2),
              let dc = decode(characters, 2, 6) else { return nil }
        let maximum = (Float(maximumValue) + 1) / 166
        var colors = [SIMD3<Float>]()
        colors.append(SIMD3(srgbToLinear(dc >> 16), srgbToLinear((dc >> 8) & 255), srgbToLinear(dc & 255)))
        for index in 1..<(componentsX * componentsY) {
            guard let value = decode(characters, 4 + index * 2, 6 + index * 2) else { return nil }
            colors.append(SIMD3(
                signedPower(Float(value / (19 * 19)) - 9) * maximum,
                signedPower(Float((value / 19) % 19) - 9) * maximum,
                signedPower(Float(value % 19) - 9) * maximum
            ))
        }

        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                var color = SIMD3<Float>(repeating: 0)
                for j in 0..<componentsY {
                    for i in 0..<componentsX {
                        let basis = cos(Float.pi * Float(x) * Float(i) / Float(width))
                            * cos(Float.pi * Float(y) * Float(j) / Float(height))
                        color += colors[i + j * componentsX] * basis
                    }
                }
                let offset = 4 * (x + y * width)
                pixels[offset] = linearToSrgb(color.x)
                pixels[offset + 1] = linearToSrgb(color.y)
                pixels[offset + 2] = linearToSrgb(color.z)
            }
        }
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data), let cgImage = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        ) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func decode(_ characters: [Character], _ start: Int, _ end: Int) -> Int? {
        guard start >= 0, end <= characters.count, start < end else { return nil }
        var value = 0
        for character in characters[start..<end] {
            guard let index = alphabet.firstIndex(of: character) else { return nil }
            value = value * 83 + index
        }
        return value
    }

    private static func signedPower(_ value: Float) -> Float {
        copysign(pow(abs(value) / 9, 2), value)
    }

    private static func srgbToLinear(_ value: Int) -> Float {
        let color = Float(value) / 255
        return color <= 0.04045 ? color / 12.92 : pow((color + 0.055) / 1.055, 2.4)
    }

    private static func linearToSrgb(_ value: Float) -> UInt8 {
        let color = max(0, min(1, value))
        let result = color <= 0.0031308 ? color * 12.92 : 1.055 * pow(color, 1 / 2.4) - 0.055
        return UInt8(max(0, min(255, Int(result * 255 + 0.5))))
    }
}
