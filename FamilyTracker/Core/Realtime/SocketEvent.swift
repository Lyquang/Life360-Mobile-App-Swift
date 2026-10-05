import Foundation

enum SocketEvent {
    // Client → Server
    static let updateLocation  = "update_location"
    static let sosAlert        = "sos_alert"
    static let chatTyping      = "chat:typing"

    // Server → Client
    static let sessionReady        = "session:ready"
    static let locationUpdate      = "location_update"
    static let sosAlertReceive     = "sos_alert"
    static let sosConfirmed        = "sos_confirmed"
    static let memberOnline        = "member_online"
    static let memberOffline       = "member_offline"
    static let locationStayAlert   = "location_stay_alert"
    static let chatNewMessage      = "chat:new_message"
    static let chatReadReceipt     = "chat:read_receipt"
    static let chatConversationUpdated = "chat:conversation_updated"
    static let error               = "error"
}
