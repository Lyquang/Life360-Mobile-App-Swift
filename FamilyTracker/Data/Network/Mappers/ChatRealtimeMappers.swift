import Foundation

extension ChatMessageDTO {
    func toDomain() -> ChatMessage {
        ChatMessage(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            type: ChatMessageType(rawValue: type) ?? .text,
            content: content ?? "",
            attachment: attachment.map {
                ChatAttachment(url: $0.url, width: $0.width, height: $0.height, mimeType: $0.mimeType)
            },
            createdAt: ISO8601.date(from: createdAt) ?? Date()
        )
    }
}

extension ConversationDTO {
    func toDomain() -> Conversation {
        Conversation(
            id: id,
            type: ConversationType(rawValue: type) ?? .group,
            groupId: groupId,
            name: name,
            avatarUrl: avatarUrl,
            members: (members ?? []).map {
                ConversationMember(id: $0.id, name: $0.name, avatar: $0.avatar, isOnline: $0.isOnline ?? false)
            },
            lastMessage: lastMessage?.toDomain(),
            lastMessageAt: ISO8601.date(from: lastMessageAt),
            unreadCount: unreadCount ?? 0
        )
    }
}

extension LocationUpdateDTO {
    func toDomain() -> MemberLocation {
        MemberLocation(
            id: userId,
            name: name,
            latitude: latitude,
            longitude: longitude,
            batteryLevel: batteryLevel.map { Int($0) },
            timestamp: timestamp,
            durationAtLocation: durationAtLocation.map { Int($0) },
            durationSince: durationSince,
            durationFormatted: durationFormatted
        )
    }
}

extension SOSAlertDTO {
    func toDomain() -> SOSAlert {
        SOSAlert(userId: userId, name: name, message: message, latitude: latitude, longitude: longitude,
                 groupId: groupId, groupName: groupName, timestamp: timestamp)
    }
}

extension StayAlertDTO {
    func toDomain() -> LocationStayAlert {
        LocationStayAlert(
            userId: userId, name: name, latitude: latitude, longitude: longitude,
            durationMinutes: Int(durationMinutes), durationFormatted: durationFormatted,
            durationSince: durationSince, groupId: groupId, groupName: groupName,
            message: message, timestamp: timestamp
        )
    }
}

extension TypingDTO {
    func toDomain() -> TypingEvent {
        TypingEvent(conversationId: conversationId, userId: userId, name: name, isTyping: isTyping)
    }
}
