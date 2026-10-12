import SwiftUI
import PhotosUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var photoItem: PhotosPickerItem?

    init(viewModel: @autoclosure @escaping () -> ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if !viewModel.typingNames.isEmpty {
                Text("\(viewModel.typingNames.joined(separator: ", ")) đang nhập…")
                    .font(FTFont.caption())
                    .foregroundColor(FTColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, FTSpacing.md)
                    .padding(.bottom, 4)
            }
            inputBar
        }
        .navigationTitle(viewModel.title.isEmpty ? Text("Tin nhắn") : Text(verbatim: viewModel.title))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.start() }
        .onDisappear { viewModel.stopTyping() }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.sendPhoto(data)
                }
                photoItem = nil
            }
        }
        .ftErrorAlert($viewModel.errorMessage)
    }

    private var messageList: some View {
        Group {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ProgressView("Đang tải tin nhắn...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.messages.isEmpty {
                emptyConversation
            } else {
                populatedMessageList
            }
        }
    }

    private var emptyConversation: some View {
        VStack(spacing: FTSpacing.sm) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 32))
                .foregroundColor(FTColors.primary)
            if let name = viewModel.emptyGreetingName {
                Text(verbatim: L10n.format("Hãy gửi lời chào đến %@", name))
                    .font(FTFont.body())
                    .foregroundColor(FTColors.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Chưa có tin nhắn")
                    .font(FTFont.body())
                    .foregroundColor(FTColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(FTSpacing.xl)
    }

    private var populatedMessageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: FTSpacing.sm) {
                    if viewModel.hasMore {
                        Button("Tải tin nhắn cũ hơn") { Task { await viewModel.loadOlder() } }
                            .font(FTFont.caption())
                            .padding(.top, FTSpacing.sm)
                    }
                    ForEach(viewModel.messages) { item in
                        MessageBubble(item: item, isMine: viewModel.isMine(item.message), playback: viewModel.playback,
                                      onRetry: { viewModel.retry(id: item.id) },
                                      onCancel: { viewModel.cancelUpload(id: item.id) })
                            .id(item.id)
                    }
                }
                .padding(FTSpacing.md)
            }
            .onChange(of: viewModel.messages.last?.id) { id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: FTSpacing.sm) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundColor(FTColors.primary)
            }
            .disabled(viewModel.isSending)

            Button(action: viewModel.toggleRecording) {
                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.isRecording ? .red : FTColors.primary)
            }
            .accessibilityLabel(L10n.text(viewModel.isRecording ? "Dừng ghi âm" : "Ghi âm"))

            if viewModel.isRecording {
                Text(verbatim: L10n.format("Đang ghi %@", duration(viewModel.recordingDuration)))
                    .font(FTFont.body())
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: viewModel.cancelRecording) { Image(systemName: "xmark.circle") }
                    .accessibilityLabel(L10n.text("Hủy ghi âm"))
            } else {
                TextField("Nhắn tin…", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, FTSpacing.sm)
                .padding(.vertical, 8)
                .background(FTColors.surface)
                .cornerRadius(FTRadius.lg)
                .onChange(of: viewModel.draft) { _ in viewModel.draftChanged() }
            }

            Button {
                Task { await viewModel.send() }
            } label: {
                if viewModel.isSending {
                    ProgressView()
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(FTColors.primary)
                }
            }
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(FTSpacing.sm)
        .background(FTColors.card)
    }

    private func duration(_ value: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(value) / 60, Int(value) % 60)
    }
}

struct MessageBubble: View {
    let item: ChatMessageItem
    let isMine: Bool
    @ObservedObject var playback: VoicePlaybackController
    let onRetry: () -> Void
    let onCancel: () -> Void

    private var message: ChatMessage { item.message }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if !isMine, let sender = message.senderName {
                    Text(sender)
                        .font(FTFont.caption())
                        .foregroundColor(FTColors.textSecondary)
                }
                content
                deliveryState
                Text(DisplayFormat.time(message.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(FTColors.textTertiary)
            }
            if !isMine { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if message.type == .image {
            if let data = item.previewData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: 220).cornerRadius(FTRadius.md)
            } else if let attachment = message.attachment, let url = URL(string: attachment.url) {
                CachedMediaImage(url: url, blurhash: attachment.blurhash)
                    .aspectRatio(imageRatio(attachment), contentMode: .fit)
                    .frame(maxWidth: 220).cornerRadius(FTRadius.md)
            }
            if !message.content.isEmpty { textBubble }
        } else if message.type == .voice {
            voiceBubble
        } else {
            textBubble
        }
    }

    private var voiceBubble: some View {
        HStack(spacing: FTSpacing.sm) {
            Button {
                if let value = message.mediaUrl, let url = URL(string: value) { playback.toggle(url: url) }
            } label: {
                Image(systemName: playback.activeURL?.absoluteString == message.mediaUrl && playback.isPlaying
                      ? "pause.fill" : "play.fill")
            }
            ProgressView(value: playback.activeURL?.absoluteString == message.mediaUrl ? playback.progress : 0)
                .frame(width: 100)
            Text(duration(message.duration ?? 0)).font(FTFont.caption())
        }
        .padding(FTSpacing.sm)
        .background(isMine ? FTColors.primary.opacity(0.16) : FTColors.surface)
        .cornerRadius(FTRadius.lg)
    }

    @ViewBuilder private var deliveryState: some View {
        switch item.delivery {
        case .sent: EmptyView()
        case .sending(let value):
            HStack(spacing: 6) {
                ProgressView(value: value).frame(width: 70)
                Button(action: onCancel) { Image(systemName: "xmark.circle") }
            }.font(FTFont.caption())
        case .failed(let message):
            Button(action: onRetry) { Label(message, systemImage: "arrow.clockwise") }
                .font(FTFont.caption()).foregroundColor(.red)
        case .uncertain:
            Button(action: onRetry) { Label("Chưa xác nhận - kiểm tra và gửi lại", systemImage: "questionmark.circle") }
                .font(FTFont.caption()).foregroundColor(.orange)
        }
    }

    private func imageRatio(_ attachment: ChatAttachment) -> CGFloat {
        guard let width = attachment.width, let height = attachment.height, height > 0 else { return 4 / 3 }
        return CGFloat(width) / CGFloat(height)
    }

    private func duration(_ value: TimeInterval) -> String {
        String(format: "%d:%02d", Int(value) / 60, Int(value) % 60)
    }

    private var textBubble: some View {
        Text(message.content)
            .font(FTFont.body())
            .foregroundColor(isMine ? .white : FTColors.textPrimary)
            .padding(.horizontal, FTSpacing.md)
            .padding(.vertical, FTSpacing.sm)
            .background(isMine ? FTColors.primary : FTColors.surface)
            .cornerRadius(FTRadius.lg)
    }
}
