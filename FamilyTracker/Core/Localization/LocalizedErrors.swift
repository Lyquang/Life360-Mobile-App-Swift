import Foundation

extension DomainError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .validation: return L10n.tr("error.invalid_data")
        case .unauthorized: return L10n.tr("error.session_expired")
        case .forbidden: return L10n.tr("error.forbidden")
        case .network: return L10n.tr("error.network_unavailable")
        case .server: return L10n.tr("error.request_failed")
        case .decoding: return L10n.tr("error.invalid_response")
        case .unknown: return L10n.tr("error.request_failed")
        }
    }
}

extension MediaUploadError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidMedia(let key): return L10n.tr(key)
        case .ticketExpired: return L10n.tr("media.error.ticket_expired")
        case .fileSizeMismatch: return L10n.tr("media.error.invalid_file_size")
        case .backend(let status, let code, _):
            if code == "VALIDATION_ERROR" || code == "BAD_REQUEST" { return L10n.tr("error.invalid_data") }
            if code == "UNAUTHORIZED" || status == 401 { return L10n.tr("error.session_expired") }
            if code == "FORBIDDEN" || status == 403 { return L10n.tr("error.forbidden") }
            if code == "SERVICE_UNAVAILABLE" || status == 503 { return L10n.tr("error.service_unavailable") }
            return L10n.tr("error.request_failed")
        case .uploadFailed: return L10n.tr("media.error.upload_failed")
        case .serviceUnavailable: return L10n.tr("error.service_unavailable")
        case .forbidden: return L10n.tr("error.forbidden")
        case .refreshUnavailable: return L10n.tr("error.session_expired")
        case .socketRejected: return L10n.tr("chat.error.send_failed")
        case .acknowledgementTimeout: return L10n.tr("media.error.acknowledgement_unknown")
        }
    }
}
