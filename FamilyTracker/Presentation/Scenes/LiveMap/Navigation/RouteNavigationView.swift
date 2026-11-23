import SwiftUI

struct RouteNavigationView: View {
    @ObservedObject var viewModel: RouteNavigationViewModel
    let onStart: () -> Void
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                HStack {
                    Text(L10n.tr("route.title")).font(FTFont.headline())
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.tr("route.action.close"))
                }
                if !viewModel.privateLocationEnabled {
                    Text(L10n.tr("route.state.consent")).font(FTFont.body())
                    Button(action: viewModel.enablePrivateLocation) {
                        Text(L10n.tr("route.action.enable_location"))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                } else if viewModel.active {
                    HStack(spacing: FTSpacing.md) {
                        if let remainingSeconds = viewModel.remainingSeconds {
                            Text(L10n.tr("route.option.duration", Int(ceil(remainingSeconds / 60))))
                                .font(FTFont.headline())
                        }
                        if let remainingMeters = viewModel.remainingMeters {
                            Text(L10n.tr("route.option.distance", (remainingMeters / 1000).formatted(
                                .number.precision(.fractionLength(1)))))
                                .font(FTFont.footnote())
                        }
                        Spacer(minLength: 0)
                        Button(action: viewModel.toggleVoice) {
                            Image(systemName: viewModel.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(L10n.tr(viewModel.voiceEnabled
                                                      ? "route.action.mute" : "route.action.unmute"))
                    }
                    if viewModel.offline {
                        Label(L10n.tr("route.state.offline"), systemImage: "wifi.slash")
                            .foregroundColor(FTColors.warning)
                    }
                    if viewModel.hasUnverifiedSegment { otherWarning }
                    Button(action: onClose) {
                        Text(L10n.tr("route.action.end")).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Picker(L10n.tr("route.mode.title"), selection: Binding(
                        get: { viewModel.mode }, set: { viewModel.setMode($0) })) {
                        ForEach(RouteTravelMode.allCases, id: \.self) { mode in
                            Text(L10n.tr(modeKey(mode))).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(L10n.tr("route.mode.title"))

                    if viewModel.loading { ProgressView(L10n.tr("route.state.loading")) }
                    ForEach(viewModel.routes) { route in
                        Button { viewModel.select(route.id) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(L10n.tr("route.option.duration",
                                                 Int(ceil(route.durationSeconds / 60))))
                                    Text(L10n.tr("route.option.distance",
                                                 (route.distanceMeters / 1000).formatted(
                                                    .number.precision(.fractionLength(1)))))
                                        .font(FTFont.footnote())
                                    Text(route.trafficAvailable
                                         ? L10n.tr("route.traffic.reported")
                                         : L10n.tr("route.traffic.unavailable"))
                                        .font(FTFont.caption())
                                }
                                Spacer()
                                if route.id == viewModel.selectedID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .accessibilityLabel(L10n.tr("route.option.selected"))
                                }
                            }
                            .padding(FTSpacing.md)
                            .background(FTColors.card, in: RoundedRectangle(cornerRadius: FTRadius.md))
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                    if viewModel.hasUnverifiedSegment { otherWarning }
                    if viewModel.selectedRoute != nil {
                        Button(action: onStart) {
                            Text(L10n.tr("route.action.start")).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button(action: viewModel.refresh) {
                        Text(L10n.tr("route.action.retry")).frame(minHeight: 44)
                    }
                }
                if let key = viewModel.noticeKey {
                    Text(L10n.tr(key))
                        .font(FTFont.footnote())
                        .foregroundColor(FTColors.warning)
                        .accessibilityLabel(L10n.tr(key))
                }
                if !viewModel.active {
                    Text(L10n.tr("route.provider")).font(FTFont.caption())
                        .foregroundColor(FTColors.textSecondary)
                }
            }
            .padding(FTSpacing.md)
        }
        .background(FTColors.background, in: RoundedRectangle(cornerRadius: FTRadius.xl))
    }

    private var otherWarning: some View {
        Label(L10n.tr("route.warning.other"), systemImage: "exclamationmark.triangle")
            .font(FTFont.footnote())
            .foregroundColor(FTColors.warning)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func modeKey(_ mode: RouteTravelMode) -> String {
        switch mode {
        case .motorcycle: return "route.mode.motorcycle"
        case .car: return "route.mode.car"
        case .walking: return "route.mode.walking"
        }
    }
}

struct RouteManeuverBanner: View {
    @ObservedObject var viewModel: RouteNavigationViewModel

    var body: some View {
        HStack(alignment: .center, spacing: FTSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .bold))
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                if let meters = viewModel.distanceToNextManeuver {
                    Text(L10n.tr("route.step.distance", Int(ceil(meters))))
                        .font(FTFont.footnote())
                }
                Text(instruction).font(FTFont.headline())
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(FTSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FTColors.background, in: RoundedRectangle(cornerRadius: FTRadius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.tr("route.a11y.next_step") + ": " + instruction)
    }

    private var instruction: String {
        guard let next = viewModel.nextStep else { return L10n.tr("route.state.next_unknown") }
        return NavigationSpeechService.message(for: next.code) ?? L10n.tr("route.state.next_unknown")
    }

    private var symbol: String {
        guard let code = viewModel.nextStep?.code else { return "location.north.fill" }
        if code.contains("LEFT") { return "arrow.turn.up.left" }
        if code.contains("RIGHT") { return "arrow.turn.up.right" }
        if code.contains("UTURN") { return "arrow.uturn.backward" }
        if code.hasPrefix("ARRIVE") { return "mappin.circle.fill" }
        return "arrow.up"
    }
}
