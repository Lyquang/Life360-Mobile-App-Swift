import Foundation

enum SOSPendingState: String, Codable, Sendable {
    case ready, uncertain
}

/// A pending SOS belongs to one account and keeps its original request unchanged.
struct SOSPendingIntent: Codable, Equatable, Sendable {
    let ownerID: String
    let intent: SOSCreationIntent
    var state: SOSPendingState
    var attemptCount: Int
    var notBefore: Date?
}

enum SOSRetryDecision: Equatable, Sendable {
    case retry(delay: TimeInterval, notBefore: Date)
    case deferUntil(Date)
    case stop(notBefore: Date?)
}

/// Pure policy: callers supply the clock and random value so retries are testable.
enum SOSRetryPolicy {
    static let maximumAttempts = 3
    static let maximumForegroundWait: TimeInterval = 60

    static func decide(failure: SOSFailure, attempts: Int, now: Date, jitter: Double) -> SOSRetryDecision {
        guard now.timeIntervalSinceReferenceDate.isFinite, attempts >= 1 else { return .stop(notBefore: nil) }
        let random = jitter.isFinite ? min(1, max(0, jitter)) : 0
        let backoff = min(30, pow(2, Double(min(attempts - 1, 5))))
        let extra = random * min(backoff, 5)
        let delay: TimeInterval
        switch failure {
        case .rateLimited(let header):
            if let header, let seconds = TimeInterval(header.trimmingCharacters(in: .whitespacesAndNewlines)),
               seconds.isFinite, seconds >= 0 {
                delay = seconds + extra
            } else { delay = backoff + extra }
        case .network, .server:
            delay = backoff + extra
        default:
            return .stop(notBefore: nil)
        }
        // Extremely large deadlines must stop this run rather than retry before the header.
        let deadlineSeconds = now.timeIntervalSinceReferenceDate + delay
        guard deadlineSeconds.isFinite else {
            return .stop(notBefore: Date(timeIntervalSinceReferenceDate: .greatestFiniteMagnitude))
        }
        let deadline = Date(timeIntervalSinceReferenceDate: deadlineSeconds)
        if attempts >= maximumAttempts { return .stop(notBefore: deadline) }
        if delay > maximumForegroundWait { return .deferUntil(deadline) }
        return .retry(delay: delay, notBefore: deadline)
    }
}
