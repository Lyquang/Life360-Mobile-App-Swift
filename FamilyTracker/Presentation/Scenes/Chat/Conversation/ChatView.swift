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
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.start() }
        .onDisappear { viewModel.stopTyping() }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.sendPhoto(data)
                }
                photoItem = nil
            }
        }
        .ftErrorAlert($viewModel.errorMessage)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: FTSpacing.sm) {
                    if viewModel.hasMore {
                        Button("Tải tin nhắn cũ hơn") { Task { await viewModel.loadOlder() } }
                            .font(FTFont.caption())
                            .padding(.top, FTSpacing.sm)
                    }
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message, isMine: viewModel.isMine(message))
                            .id(message.id)
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

            TextField("Nhắn tin…", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, FTSpacing.sm)
                .padding(.vertical, 8)
                .background(FTColors.surface)
                .cornerRadius(FTRadius.lg)
                .onChange(of: viewModel.draft) { _ in viewModel.draftChanged() }

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
}

struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool

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
                Text(DisplayFormat.time(message.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(FTColors.textTertiary)
            }
            if !isMine { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if message.type == .image, let url = message.attachment.flatMap({ URL(string: $0.url) }) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView().frame(width: 180, height: 140)
            }
            .frame(maxWidth: 220)
            .cornerRadius(FTRadius.md)
            if !message.content.isEmpty { textBubble }
        } else {
            textBubble
        }
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
