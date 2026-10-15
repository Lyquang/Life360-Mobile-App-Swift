import Foundation

enum MediaKind: String, Codable, Sendable {
    case image
    case voice
}

enum MediaUploadPolicy {
    static let imageMimeType = "image/jpeg"
    static let imageExtension = "jpg"
    static let voiceMimeType = "audio/mp4"
    static let voiceExtension = "m4a"
    static let maxImageBytes = 10 * 1024 * 1024
    static let maxVoiceBytes = 25 * 1024 * 1024
    static let maxVoiceDuration: TimeInterval = 900
    static let ticketLifetime: TimeInterval = 300
    static let maxCaptionLength = 2_000
    static let validBlurHashLength = 6...100
    static let validImageDimension = 1...20_000

    static func mimeType(for kind: MediaKind) -> String {
        kind == .image ? imageMimeType : voiceMimeType
    }

    static func fileExtension(for kind: MediaKind) -> String {
        kind == .image ? imageExtension : voiceExtension
    }

    static func maxBytes(for kind: MediaKind) -> Int {
        kind == .image ? maxImageBytes : maxVoiceBytes
    }
}

struct MediaUploadTicket: Sendable {
    let uploadURL: URL
    let method: String
    let headers: [String: String]
    let key: String
    let publicURL: URL
    let expiresIn: Int
    let expiresAt: Date
}

enum MediaUploadError: Error, Equatable {
    case invalidMedia(String)
    case ticketExpired
    case fileSizeMismatch(expected: Int, actual: Int)
    case backend(status: Int, code: String?, message: String)
    case uploadFailed(status: Int?, retryable: Bool)
    case serviceUnavailable
    case forbidden
    case refreshUnavailable
    case socketRejected(message: String)
    case acknowledgementTimeout

}
