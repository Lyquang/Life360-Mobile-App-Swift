import Foundation

enum MessageDeliveryState: Equatable { case sent, sending(Double), failed(String), uncertain }

enum PendingMedia {
    case image(raw: Data, prepared: ImageAttachmentInput?, publicURL: String?, caption: String?)
    case voice(input: VoiceAttachmentInput, publicURL: String?)
    var publicURL: String? {
        switch self { case .image(_, _, let url, _), .voice(_, let url): return url }
    }
}

struct ChatMessageItem: Identifiable {
    let id: String
    var message: ChatMessage
    var delivery: MessageDeliveryState
    var previewData: Data?
    var pending: PendingMedia?
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessageItem] = []
    @Published private(set) var hasMore = false
    @Published private(set) var isLoading = true
    @Published private(set) var isSending = false
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var typingNames: [String] = []
    @Published var draft = ""
    @Published var errorMessage: String?

    let conversationId: String
    let title: String
    let emptyGreetingName: String?
    let currentUserId: String
    let playback = VoicePlaybackController()

    private let fetchMessages: FetchMessagesUseCase
    private let sendText: SendTextMessageUseCase
    private let prepareImage: PrepareImageUseCase
    private let uploadImage: UploadImageUseCase
    private let sendImage: SendImageMessageUseCase
    private let uploadVoice: UploadVoiceUseCase
    private let sendVoice: SendVoiceMessageUseCase
    private let markRead: MarkConversationReadUseCase
    private let observeNewMessages: ObserveNewMessagesUseCase
    private let observeTyping: ObserveTypingUseCase
    private let sendTyping: SendTypingUseCase
    private let recorder: AudioRecorderService
    private let onForbidden: () -> Void
    private var nextBefore: String?
    private var tasks: [Task<Void, Never>] = []
    private var mediaTasks: [String: Task<Void, Never>] = [:]
    private var typingResetTask: Task<Void, Never>?
    private var isTypingSent = false
    private var typers: [String: String] = [:]

    init(conversationId: String, title: String, emptyGreetingName: String? = nil, currentUserId: String,
         fetchMessages: FetchMessagesUseCase, sendText: SendTextMessageUseCase,
         prepareImage: PrepareImageUseCase, uploadImage: UploadImageUseCase,
         sendImage: SendImageMessageUseCase, uploadVoice: UploadVoiceUseCase,
         sendVoice: SendVoiceMessageUseCase, markRead: MarkConversationReadUseCase,
         observeNewMessages: ObserveNewMessagesUseCase, observeTyping: ObserveTypingUseCase,
         sendTyping: SendTypingUseCase, recorder: AudioRecorderService,
         onForbidden: @escaping () -> Void) {
        self.conversationId = conversationId; self.title = title
        self.emptyGreetingName = emptyGreetingName; self.currentUserId = currentUserId
        self.fetchMessages = fetchMessages; self.sendText = sendText
        self.prepareImage = prepareImage; self.uploadImage = uploadImage; self.sendImage = sendImage
        self.uploadVoice = uploadVoice; self.sendVoice = sendVoice; self.markRead = markRead
        self.observeNewMessages = observeNewMessages; self.observeTyping = observeTyping
        self.sendTyping = sendTyping; self.recorder = recorder; self.onForbidden = onForbidden
    }

    deinit { tasks.forEach { $0.cancel() }; mediaTasks.values.forEach { $0.cancel() }; typingResetTask?.cancel() }
    func isMine(_ message: ChatMessage) -> Bool { message.senderId == currentUserId }

    func start() async {
        if tasks.isEmpty {
            let messageStream = observeNewMessages(), typingStream = observeTyping(), recordingEvents = recorder.events
            tasks.append(Task { [weak self] in for await value in messageStream { self?.receive(value) } })
            tasks.append(Task { [weak self] in for await value in typingStream { self?.receive(value) } })
            tasks.append(Task { [weak self] in
                for await event in recordingEvents {
                    guard let self else { return }
                    switch event {
                    case .elapsed(let value): self.recordingDuration = value
                    case .reachedLimit(let input): self.finishRecording(input)
                    case .interrupted:
                        self.isRecording = false; self.recordingDuration = 0
                        self.errorMessage = "Ghi âm đã dừng do phiên âm thanh bị gián đoạn."
                    }
                }
            })
        }
        await loadInitial()
    }

    func loadInitial() async {
        isLoading = true; defer { isLoading = false }
        do {
            let page = try await fetchMessages(conversationId: conversationId)
            messages = page.messages.map(sentItem); hasMore = page.hasMore; nextBefore = page.nextBefore
            await markRead(conversationId: conversationId, messageId: messages.last?.message.id)
        } catch { errorMessage = error.localizedDescription }
    }

    func loadOlder() async {
        guard hasMore, !isLoading, let before = nextBefore else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let page = try await fetchMessages(conversationId: conversationId, before: before)
            let known = Set(messages.map(\.message.id))
            messages.insert(contentsOf: page.messages.filter { !known.contains($0.id) }.map(sentItem), at: 0)
            hasMore = page.hasMore; nextBefore = page.nextBefore
        } catch { errorMessage = error.localizedDescription }
    }

    func send() async {
        let text = draft
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSending else { return }
        isSending = true; draft = ""; stopTyping(); defer { isSending = false }
        do { receive(try await sendText(text, conversationId: conversationId)) }
        catch { draft = text; errorMessage = error.localizedDescription }
    }

    func sendPhoto(_ data: Data) {
        let id = "local-\(UUID().uuidString)"
        messages.append(pendingItem(id: id, type: .image, preview: data,
            pending: .image(raw: data, prepared: nil, publicURL: nil, caption: normalizedCaption)))
        runMediaTask(id: id)
    }

    func toggleRecording() {
        if isRecording {
            do { finishRecording(try recorder.stop()) } catch { failRecording(error) }
        } else {
            Task { [weak self] in
                do { try await self?.recorder.start(); self?.isRecording = true; self?.recordingDuration = 0 }
                catch { self?.failRecording(error) }
            }
        }
    }

    func cancelRecording() { recorder.cancel(); isRecording = false; recordingDuration = 0 }
    func cancelUpload(id: String) {
        mediaTasks[id]?.cancel(); mediaTasks[id] = nil
        if case .voice(let input, _)? = messages.first(where: { $0.id == id })?.pending { cleanup(input) }
        removeItem(id)
    }
    func retry(id: String) {
        guard mediaTasks[id] == nil, messages.first(where: { $0.id == id })?.pending != nil else { return }
        runMediaTask(id: id)
    }

    func draftChanged() {
        guard !draft.isEmpty else { stopTyping(); return }
        if !isTypingSent { isTypingSent = true; sendTyping(conversationId: conversationId, isTyping: true) }
        typingResetTask?.cancel()
        typingResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }; self?.stopTyping()
        }
    }

    func stopTyping() {
        typingResetTask?.cancel(); guard isTypingSent else { return }
        isTypingSent = false; sendTyping(conversationId: conversationId, isTyping: false)
    }

    private var normalizedCaption: String? {
        let value = String(draft.prefix(MediaUploadPolicy.maxCaptionLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func finishRecording(_ input: VoiceAttachmentInput) {
        isRecording = false; recordingDuration = 0
        let id = "local-\(UUID().uuidString)"
        messages.append(pendingItem(id: id, type: .voice, preview: nil,
                                    pending: .voice(input: input, publicURL: nil)))
        runMediaTask(id: id)
    }

    private func failRecording(_ error: Error) {
        recorder.cancel(); isRecording = false; recordingDuration = 0; errorMessage = error.localizedDescription
    }

    private func runMediaTask(id: String) {
        update(id) { $0.delivery = .sending(0) }
        let task = Task { [weak self] in
            guard let self else { return }; defer { self.mediaTasks[id] = nil }
            do { try await self.performMediaSend(id: id) }
            catch is CancellationError { self.removeItem(id) }
            catch let error as MediaUploadError where error == .acknowledgementTimeout { await self.reconcile(id: id) }
            catch let error as MediaUploadError where error == .forbidden {
                self.update(id) { $0.delivery = .failed(error.localizedDescription) }; self.onForbidden()
            } catch { self.update(id) { $0.delivery = .failed(error.localizedDescription) } }
        }
        mediaTasks[id] = task
    }

    private func performMediaSend(id: String) async throws {
        guard let pending = messages.first(where: { $0.id == id })?.pending else { return }
        switch pending {
        case .image(let raw, let existing, let oldURL, let caption):
            let image: ImageAttachmentInput
            if let existing { image = existing } else { image = try await prepareImage(raw) }
            let url: String
            if let oldURL { url = oldURL }
            else {
                url = try await uploadImage(image, conversationId: conversationId) { [weak self] value in
                    Task { @MainActor in self?.update(id) { $0.delivery = .sending(value) } }
                }
            }
            update(id) { $0.pending = .image(raw: raw, prepared: image, publicURL: url, caption: caption) }
            if let found = try await findExisting(publicURL: url) { replace(id, with: found); return }
            replace(id, with: try await sendImage(image: image, publicURL: url, caption: caption,
                                                  conversationId: conversationId))
        case .voice(let input, let oldURL):
            let url: String
            if let oldURL { url = oldURL }
            else {
                url = try await uploadVoice(input, conversationId: conversationId) { [weak self] value in
                    Task { @MainActor in self?.update(id) { $0.delivery = .sending(value) } }
                }
            }
            update(id) { $0.pending = .voice(input: input, publicURL: url) }
            if let found = try await findExisting(publicURL: url) { replace(id, with: found); cleanup(input); return }
            replace(id, with: try await sendVoice(voice: input, publicURL: url, conversationId: conversationId)); cleanup(input)
        }
    }

    private func reconcile(id: String) async {
        guard let url = messages.first(where: { $0.id == id })?.pending?.publicURL else { return }
        do {
            if let found = try await findExisting(publicURL: url) { replace(id, with: found) }
            else { update(id) { $0.delivery = .uncertain } }
        } catch { update(id) { $0.delivery = .uncertain } }
    }

    private func findExisting(publicURL: String) async throws -> ChatMessage? {
        let page = try await fetchMessages(conversationId: conversationId)
        return page.messages.first {
            $0.senderId == currentUserId && mediaURL(of: $0) == publicURL
        }
    }

    private func receive(_ message: ChatMessage) {
        guard message.conversationId == conversationId else { return }
        if let url = mediaURL(of: message), let index = messages.firstIndex(where: {
            $0.pending?.publicURL == url && $0.message.senderId == currentUserId
        }) { messages[index] = sentItem(message) }
        else if !messages.contains(where: { $0.message.id == message.id }) { messages.append(sentItem(message)) }
        typers[message.senderId] = nil; typingNames = Array(typers.values)
        if !isMine(message) { Task { await markRead(conversationId: conversationId, messageId: message.id) } }
    }

    private func receive(_ event: TypingEvent) {
        guard event.conversationId == conversationId, event.userId != currentUserId else { return }
        typers[event.userId] = event.isTyping ? (event.name ?? L10n.tr("common.person.unknown")) : nil
        typingNames = Array(typers.values)
    }

    private func sentItem(_ message: ChatMessage) -> ChatMessageItem {
        ChatMessageItem(id: message.id, message: message, delivery: .sent, previewData: nil, pending: nil)
    }

    private func pendingItem(id: String, type: ChatMessageType, preview: Data?, pending: PendingMedia) -> ChatMessageItem {
        let message = ChatMessage(id: id, conversationId: conversationId, senderId: currentUserId,
            senderName: nil, type: type, content: "", attachment: nil, mediaUrl: nil,
            duration: nil, fileSize: nil, mimeType: nil, createdAt: Date())
        return ChatMessageItem(id: id, message: message, delivery: .sending(0), previewData: preview, pending: pending)
    }

    private func mediaURL(of message: ChatMessage) -> String? { message.attachment?.url ?? message.mediaUrl }
    private func update(_ id: String, _ change: (inout ChatMessageItem) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }; change(&messages[index])
    }
    private func replace(_ id: String, with message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }; messages[index] = sentItem(message)
    }
    private func removeItem(_ id: String) { messages.removeAll { $0.id == id } }
    private func cleanup(_ input: VoiceAttachmentInput) { try? FileManager.default.removeItem(at: input.fileURL) }
}
