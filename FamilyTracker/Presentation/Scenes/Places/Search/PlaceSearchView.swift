import SwiftUI

struct PlaceSearchView: View {
    @ObservedObject var viewModel: PlaceSearchViewModel
    let onClose: () -> Void
    let onSelect: (PlaceSearchResult) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField(L10n.tr("search.field.placeholder"),
                          text: Binding(get: { viewModel.query }, set: viewModel.updateQuery))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                    .onSubmit { focused = false; viewModel.submit() }
                    .accessibilityIdentifier("search.field")
                if !viewModel.query.isEmpty {
                    Button { viewModel.updateQuery(""); focused = true } label: {
                        Image(systemName: "xmark.circle.fill").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(L10n.tr("search.action.clear_query"))
                }
                Button(L10n.tr("common.cancel"), action: onClose)
                    .font(FTFont.subheadline())
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(L10n.tr("search.action.close"))
                    .accessibilityIdentifier("search.close")
            }
            .padding(.horizontal, FTSpacing.md)
            .frame(minHeight: 52)

            List {
                if viewModel.historyFailed {
                    Text(verbatim: L10n.tr("search.error.history"))
                        .font(.footnote).foregroundColor(FTColors.warning)
                        .accessibilityIdentifier("search.history_error")
                }
                if let key = viewModel.failureKey {
                    Section {
                        Text(verbatim: L10n.tr(key)).foregroundColor(FTColors.danger)
                        if viewModel.canRetry {
                            Button(L10n.tr("search.action.retry"), action: viewModel.retry)
                                .accessibilityIdentifier("search.retry")
                        }
                    }
                }
                if viewModel.isLoading {
                    ProgressView { Text(verbatim: L10n.tr("search.state.loading")) }
                        .accessibilityIdentifier("search.loading")
                }
                if PlaceSearchQuery.trimmed(viewModel.query).isEmpty {
                    discovery
                    if !viewModel.recent.isEmpty {
                        Section {
                            ForEach(viewModel.recent) { item in
                                Button { focused = false; viewModel.chooseRecent(item) } label: {
                                    Label { Text(verbatim: item.query) } icon: {
                                        Image(systemName: "clock")
                                    }
                                }
                                .swipeActions {
                                    Button(role: .destructive) { viewModel.removeRecent(item) } label: {
                                        Text(verbatim: L10n.tr("search.action.delete"))
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive) { viewModel.removeRecent(item) } label: {
                                        Text(verbatim: L10n.tr("search.action.delete"))
                                    }
                                }
                            }
                            Button(L10n.tr("search.action.clear_all"), role: .destructive,
                                   action: viewModel.clearHistory)
                                .accessibilityIdentifier("search.clear_history")
                        } header: {
                            Text(verbatim: L10n.tr("search.section.recent"))
                        }
                    }
                } else if viewModel.didSearch {
                    if !viewModel.results.isEmpty {
                        Section {
                            ForEach(viewModel.results) { item in
                                Button { focused = false; onSelect(item) } label: {
                                    placeRow(title: item.name, subtitle: item.address, symbol: "mappin.circle.fill")
                                }
                            }
                        } header: { Text(verbatim: L10n.tr("search.section.results")) }
                    } else if !viewModel.isLoading && viewModel.failure == nil {
                        Text(verbatim: L10n.tr("search.state.empty"))
                            .accessibilityIdentifier("search.empty")
                    }
                } else if !viewModel.suggestions.isEmpty {
                    Section {
                        ForEach(viewModel.suggestions) { item in
                            Button { focused = false; viewModel.chooseSuggestion(item) } label: {
                                placeRow(title: item.title, subtitle: item.subtitle, symbol: "magnifyingglass")
                            }
                        }
                    } header: { Text(verbatim: L10n.tr("search.section.suggestions")) }
                } else if !viewModel.isLoading && viewModel.failure == nil {
                    Text(verbatim: L10n.tr("search.state.hint"))
                        .foregroundColor(FTColors.textSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(FTColors.background)
        .toolbar(.hidden, for: .navigationBar)
        .task { focused = true }
    }

    private var discovery: some View {
        Section {
            Text(verbatim: L10n.tr("search.state.hint"))
                .font(.footnote).foregroundColor(FTColors.textSecondary)
            nearbyButton("search.nearby.cafe", symbol: "cup.and.saucer")
            nearbyButton("search.nearby.restaurant", symbol: "fork.knife")
        }
    }

    private func nearbyButton(_ key: String, symbol: String) -> some View {
        Button {
            focused = false
            viewModel.updateQuery(L10n.tr(key))
            viewModel.submit()
        } label: {
            Label { Text(verbatim: L10n.tr(key)) } icon: { Image(systemName: symbol) }
        }
    }

    private func placeRow(title: String, subtitle: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: FTSpacing.sm) {
            Image(systemName: symbol).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title).foregroundColor(FTColors.textPrimary)
                if !subtitle.isEmpty {
                    Text(verbatim: subtitle).font(.footnote).foregroundColor(FTColors.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
