import os

/// Fixed names only; never attach location, identity, URL or message metadata.
enum PerformanceSignposts {
    enum Operation {
        case composeApp
        case restoreSession
        case loadJourney
        case loadChats
        case uploadMedia
        case deliverLocationFix
    }

    private static let signposter = OSSignposter(subsystem: "com.familytracker.app", category: "performance")

    static func begin(_ operation: Operation) -> OSSignpostIntervalState {
        let id = signposter.makeSignpostID()
        switch operation {
        case .composeApp: return signposter.beginInterval("ComposeApp", id: id)
        case .restoreSession: return signposter.beginInterval("RestoreSession", id: id)
        case .loadJourney: return signposter.beginInterval("LoadJourney", id: id)
        case .loadChats: return signposter.beginInterval("LoadChats", id: id)
        case .uploadMedia: return signposter.beginInterval("UploadMedia", id: id)
        case .deliverLocationFix: return signposter.beginInterval("DeliverLocationFix", id: id)
        }
    }

    static func end(_ operation: Operation, _ state: OSSignpostIntervalState) {
        switch operation {
        case .composeApp: signposter.endInterval("ComposeApp", state)
        case .restoreSession: signposter.endInterval("RestoreSession", state)
        case .loadJourney: signposter.endInterval("LoadJourney", state)
        case .loadChats: signposter.endInterval("LoadChats", state)
        case .uploadMedia: signposter.endInterval("UploadMedia", state)
        case .deliverLocationFix: signposter.endInterval("DeliverLocationFix", state)
        }
    }
}
