import UIKit

/// BlurHash encoder (https://blurha.sh). Works on a 32x32 thumbnail, which is plenty for a placeholder.
enum BlurHashEncoder {
    static let fallback = "L6PZfSi_.AyE_3t7t7R**0o#DgR4"

    private static let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~")

    static func encode(_ image: UIImage, componentsX: Int = 4, componentsY: Int = 3) -> String? {
        guard let cgImage = image.cgImage, (1...9).contains(componentsX), (1...9).contains(componentsY) else { return nil }

        let width = 32
        let height = 32
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var factors: [(Float, Float, Float)] = []
        for j in 0..<componentsY {
            for i in 0..<componentsX {
                let normalisation: Float = (i == 0 && j == 0) ? 1 : 2
                var r: Float = 0, g: Float = 0, b: Float = 0
                for y in 0..<height {
                    for x in 0..<width {
                        let basis = normalisation
                            * cos(Float.pi * Float(i) * Float(x) / Float(width))
                            * cos(Float.pi * Float(j) * Float(y) / Float(height))
                        let index = y * bytesPerRow + x * 4
                        r += basis * sRGBToLinear(pixels[index])
                        g += basis * sRGBToLinear(pixels[index + 1])
                        b += basis * sRGBToLinear(pixels[index + 2])
                    }
                }
                let scale = 1 / Float(width * height)
                factors.append((r * scale, g * scale, b * scale))
            }
        }

        let dc = factors[0]
        let ac = factors.dropFirst()

        var hash = encode83((componentsX - 1) + (componentsY - 1) * 9, length: 1)

        let maximumValue: Float
        if !ac.isEmpty {
            let actualMax = ac.map { max(abs($0.0), abs($0.1), abs($0.2)) }.max() ?? 0
            let quantisedMax = Int(max(0, min(82, floor(actualMax * 166 - 0.5))))
            maximumValue = Float(quantisedMax + 1) / 166
            hash += encode83(quantisedMax, length: 1)
        } else {
            maximumValue = 1
            hash += encode83(0, length: 1)
        }

        hash += encode83(encodeDC(dc), length: 4)
        for factor in ac {
            hash += encode83(encodeAC(factor, maximumValue: maximumValue), length: 2)
        }
        return hash
    }

    private static func encodeDC(_ value: (Float, Float, Float)) -> Int {
        (linearToSRGB(value.0) << 16) + (linearToSRGB(value.1) << 8) + linearToSRGB(value.2)
    }

    private static func encodeAC(_ value: (Float, Float, Float), maximumValue: Float) -> Int {
        func quantise(_ v: Float) -> Int {
            Int(max(0, min(18, floor(signPow(v / maximumValue, 0.5) * 9 + 9.5))))
        }
        return quantise(value.0) * 19 * 19 + quantise(value.1) * 19 + quantise(value.2)
    }

    private static func encode83(_ value: Int, length: Int) -> String {
        var result = ""
        for i in 1...length {
            let divisor = Int(pow(83, Double(length - i)))
            result.append(characters[(value / divisor) % 83])
        }
        return result
    }

    private static func sRGBToLinear(_ value: UInt8) -> Float {
        let v = Float(value) / 255
        return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    private static func linearToSRGB(_ value: Float) -> Int {
        let v = max(0, min(1, value))
        return v <= 0.0031308 ? Int(v * 12.92 * 255 + 0.5) : Int((1.055 * pow(v, 1 / 2.4) - 0.055) * 255 + 0.5)
    }

    private static func signPow(_ value: Float, _ exponent: Float) -> Float {
        copysign(pow(abs(value), exponent), value)
    }
}
