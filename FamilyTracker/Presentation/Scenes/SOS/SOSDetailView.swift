import SwiftUI

struct SOSDetailView: View {
    let id: String
    let currentUserID: String
    @ObservedObject var viewModel: SOSViewModel
    @ObservedObject private var session: SOSSessionController
    let onLocation: (String, GeoPoint?, Date?) -> Void
    @Environment(\.dismiss) private var dismiss

    init(id: String, currentUserID: String, viewModel: SOSViewModel,
         onLocation: @escaping (String, GeoPoint?, Date?) -> Void) {
        self.id = id
        self.currentUserID = currentUserID
        self.viewModel = viewModel
        self.session = viewModel.session
        self.onLocation = onLocation
    }

    var body: some View {
        NavigationStack {
            Group {
                if let detail = session.details[id] {
                    content(detail)
                } else if session.refreshing.contains(id) {
                    ProgressView(L10n.tr("sos.new.loading"))
                } else {
                    VStack(spacing: FTSpacing.md) {
                        Text(verbatim: L10n.tr("sos.new.detail_unavailable"))
                        Button(L10n.tr("sos.new.retry")) { Task { await session.refreshDetail(id: id) } }
                            .frame(minHeight: 44)
                    }.padding()
                }
            }
            .navigationTitle(Text(verbatim: L10n.tr("sos.new.detail_title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.close")) { dismiss() }
                }
            }
            .task { await session.refreshDetail(id: id) }
            .ftErrorAlert($viewModel.errorMessage)
            .onDisappear { viewModel.suspend() }
        }
    }

    private func content(_ detail: SOSDetail) -> some View {
        let incident = detail.incident
        return ScrollView {
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.title).foregroundColor(FTColors.danger)
                    VStack(alignment: .leading) {
                        Text(verbatim: L10n.tr("sos.new.detail_title")).font(.headline)
                        Text(verbatim: status(incident.status)).foregroundColor(FTColors.textSecondary)
                    }
                    Spacer()
                }
                if !incident.message.isEmpty { Text(incident.message).font(.body) }
                if incident.ownerId != currentUserID || incident.location != nil {
                    Button {
                        let fallback = incident.location.map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) }
                        onLocation(incident.ownerId, fallback, incident.location?.recordedAt)
                    } label: {
                        Label(L10n.tr("sos.alert.view_map"), systemImage: "location.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.bordered)
                }
                Text(verbatim: L10n.tr("sos.new.helpers")).font(.headline)
                if detail.responders.isEmpty {
                    Text(verbatim: L10n.tr("sos.new.no_helpers")).foregroundColor(FTColors.textSecondary)
                } else {
                    ForEach(detail.responders) { responder in
                        Label(responder.name ?? L10n.tr("sos.new.unknown_person"), systemImage: "person.crop.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
                if detail.hasMore {
                    Button(L10n.tr("sos.new.more")) { Task { await session.loadMoreResponders(id: id) } }
                        .disabled(session.loadingResponders.contains(id)).frame(minHeight: 44)
                }
                if incident.status == .active {
                    if incident.ownerId == currentUserID {
                        Button(L10n.tr("sos.new.safe")) { viewModel.close(id, status: .resolved) }
                            .buttonStyle(.borderedProminent).frame(maxWidth: .infinity, minHeight: 44)
                        Button(L10n.tr("sos.new.cancel"), role: .destructive) { viewModel.close(id, status: .cancelled) }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        if detail.responders.contains(where: { $0.responderId == currentUserID }) {
                            Label(L10n.tr("sos.new.coming_confirmed"), systemImage: "checkmark.circle.fill")
                                .foregroundColor(FTColors.primary).frame(minHeight: 44)
                        } else {
                            Button(L10n.tr("sos.new.coming")) { viewModel.respond(to: id) }
                                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
                if viewModel.busy || session.awaitingRefresh.contains(id) {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(FTSpacing.md)
            .disabled(viewModel.busy || session.awaitingRefresh.contains(id))
        }
    }

    private func status(_ status: SOSStatus) -> String {
        switch status {
        case .active: return L10n.tr("sos.new.active")
        case .resolved: return L10n.tr("sos.new.resolved")
        case .cancelled: return L10n.tr("sos.new.cancelled")
        case .expired, .unknown: return L10n.tr("sos.new.closed")
        }
    }
}
