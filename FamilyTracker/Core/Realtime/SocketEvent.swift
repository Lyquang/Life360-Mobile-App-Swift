import Foundation

enum SocketEvent {
    // Client → Server
    static let updateLocation  = "update_location"
    static let sosAlert        = "sos_alert"
    static let chatTyping      = "chat:typing"
    static let chatSendMessage = "chat:send_message"
    static let journeyWatch = "journey:watch"
    static let journeyUnwatch = "journey:unwatch"

    // Server → Client
    static let sessionReady        = "session:ready"
    static let locationUpdate      = "location_update"
    static let sosAlertReceive     = "sos_alert"
    static let sosUpdated          = "sos:updated"
    static let sosConfirmed        = "sos_confirmed"
    static let memberOnline        = "member_online"
    static let memberOffline       = "member_offline"
    static let locationStayAlert   = "location_stay_alert"
    static let chatNewMessage      = "chat:new_message"
    static let chatReadReceipt     = "chat:read_receipt"
    static let chatConversationUpdated = "chat:conversation_updated"
    static let journeyTrailDelta = "journey:trail_delta"
    static let journeyTrailReset = "journey:trail_reset"
    static let journeyTrailClosed = "journey:trail_closed"
    static let error               = "error"
}
