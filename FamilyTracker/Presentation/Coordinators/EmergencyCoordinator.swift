import SwiftUI

@MainActor
final class EmergencyCoordinator: ObservableObject {
    struct Route: Identifiable { let id: String }
    @Published var isConfirmingSOS = false
    @Published var route: Route?
    @Published var incomingID: String?
    let viewModel: SOSViewModel
    let currentUserID: String
    var onShowLocation: ((String, GeoPoint?, Date?) -> Void)?
    private var shownIDs: Set<String> = []
    private var shownOrder: [String] = []

    init(container: AppContainer, currentUser: User) {
        currentUserID = currentUser.id
        viewModel = SOSViewModel(session: container.sosSession, lifecycle: container.sosIntentLifecycle,
                                 location: container.sosLocation, repository: container.sosRepository,
                                 identity: { [weak session = container.session] in session?.locationSessionIdentity })
        viewModel.onOpenIncident = { [weak self] id in self?.open(id) }
    }

    func stop() {
        viewModel.stop()
        route = nil
        incomingID = nil
        shownIDs.removeAll()
        shownOrder.removeAll()
    }
    func requestSOS() {
        if let existing = viewModel.session.incidents.values.first(where: { $0.ownerId == currentUserID && $0.status == .active }) {
            open(existing.id)
        } else { isConfirmingSOS = true }
    }
    func open(_ id: String) { incomingID = nil; route = Route(id: id) }
    @discardableResult
    func presentIncoming(_ id: String) -> Bool {
        if let incident = viewModel.session.details[id]?.incident, incident.status != .active { return false }
        if viewModel.session.detailErrors[id] == .forbidden || viewModel.session.detailErrors[id] == .notFound {
            return false
        }
        guard shownIDs.insert(id).inserted else { return false }
        shownOrder.append(id)
        if shownOrder.count > 512 { shownIDs.remove(shownOrder.removeFirst()) }
        incomingID = id
        return true
    }
    func showLocation(_ userID: String, fallback: GeoPoint?, recordedAt: Date?) {
        route = nil
        onShowLocation?(userID, fallback, recordedAt)
    }
}

struct EmergencyPresentation: ViewModifier {
    @ObservedObject var coordinator: EmergencyCoordinator
    @ObservedObject private var viewModel: SOSViewModel

    init(coordinator: EmergencyCoordinator) {
        self.coordinator = coordinator
        self.viewModel = coordinator.viewModel
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if viewModel.busy {
                    ZStack {
                        Color.black.opacity(0.18).ignoresSafeArea()
                        ProgressView(L10n.tr("sos.new.sending"))
                            .padding().background(FTColors.card).cornerRadius(FTRadius.md)
                    }
                }
            }
            .overlay(alignment: .top) {
                if let id = coordinator.incomingID {
                    Button { coordinator.open(id) } label: {
                        Label(L10n.tr("sos.new.alert"), systemImage: "exclamationmark.triangle.fill")
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(FTColors.dangerGradient).cornerRadius(FTRadius.lg)
                    }.padding(FTSpacing.md)
                }
            }
            .confirmationDialog(L10n.tr("sos.confirm.title"), isPresented: $coordinator.isConfirmingSOS,
                                titleVisibility: .visible) {
                if viewModel.pending != nil {
                    Button(L10n.tr("sos.new.resume"), role: .destructive) { viewModel.send(includeLocation: false) }
                } else {
                    Button(L10n.tr("sos.new.with_location"), role: .destructive) { viewModel.send(includeLocation: true) }
                    Button(L10n.tr("sos.new.without_location"), role: .destructive) { viewModel.send(includeLocation: false) }
                }
                Button(L10n.tr("common.cancel"), role: .cancel) {}
            } message: {
                Text(verbatim: L10n.tr(viewModel.pending == nil ? "sos.confirm.message" : "sos.new.resume_message"))
            }
            .alert(L10n.tr("sos.new.location_failed"), isPresented: $viewModel.showLocationFallback) {
                Button(L10n.tr("sos.new.without_location")) { viewModel.send(includeLocation: false) }
                Button(L10n.tr("common.cancel"), role: .cancel) {}
            } message: { Text(verbatim: L10n.tr("sos.new.location_failed_message")) }
            .ftErrorAlert($viewModel.errorMessage)
            .sheet(item: $coordinator.route) { route in
                SOSDetailView(id: route.id, currentUserID: coordinator.currentUserID,
                              viewModel: viewModel, onLocation: coordinator.showLocation)
            }
    }
}
