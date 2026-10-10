import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var viewModel: NotificationSettingsViewModel
    @Environment(\.scenePhase) private var scenePhase
    let onOpenSettings: () -> Void
    let onClose: () -> Void

    init(viewModel: @autoclosure @escaping () -> NotificationSettingsViewModel,
         onOpenSettings: @escaping () -> Void, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onOpenSettings = onOpenSettings
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Cho phép thông báo", isOn: binding(\.enabled))
                        .accessibilityIdentifier("notifications.master")
                    Toggle("Thông báo tin nhắn mới", isOn: binding(\.messages))
                        .disabled(!viewModel.preferences.enabled)
                    Toggle("Cảnh báo khẩn cấp SOS", isOn: binding(\.sos))
                        .disabled(!viewModel.preferences.enabled)
                }
                Section("Quyền thông báo iOS") {
                    switch viewModel.permission {
                    case .notDetermined:
                        Button("Cấp quyền thông báo") { Task { await viewModel.requestPermission() } }
                            .disabled(viewModel.isRequesting || !viewModel.preferences.enabled)
                    case .denied:
                        Text("Thông báo đang bị tắt trong Cài đặt iPhone.")
                        Button("Mở Cài đặt iPhone", action: onOpenSettings)
                    case .authorized:
                        Label("Đã cấp quyền", systemImage: "checkmark.circle")
                        Button("Mở Cài đặt iPhone", action: onOpenSettings)
                    case .provisional:
                        Text("Thông báo đang được gửi im lặng.")
                        Button("Mở Cài đặt iPhone", action: onOpenSettings)
                    }
                }
                Section("Dịch vụ thông báo") {
                    Label("Cài đặt đã lưu trên thiết bị", systemImage: "iphone")
                    Text("Push từ máy chủ chưa được cấu hình.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Thông báo")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Xong", action: onClose) }
            }
        }
        .task { await viewModel.refresh() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await viewModel.refresh() } }
        }
        .ftErrorAlert($viewModel.errorMessage)
    }

    private func binding(_ key: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(get: { viewModel.preferences[keyPath: key] }, set: { viewModel.set(key, $0) })
    }
}
