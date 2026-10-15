import SwiftUI

struct AddPlaceSheet: View {
    @ObservedObject var viewModel: PlacesViewModel
    let onClose: () -> Void

    @State private var name = ""
    @State private var category: PlaceCategory = .other
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var useCurrentLocation = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    FTTextField(title: "Tên địa điểm", placeholder: "VD: Phở 24 Nguyễn Huệ", icon: "mappin.fill", text: $name)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                } header: {
                    Text(verbatim: L10n.tr("places.form.info"))
                }

                Section {
                    Picker(selection: $category) {
                        ForEach(PlaceCategory.allCases) { category in
                            Label {
                                Text(verbatim: category.displayName)
                            } icon: {
                                Image(systemName: category.iconName)
                            }.tag(category)
                        }
                    } label: {
                        Text(verbatim: L10n.tr("places.form.category"))
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(verbatim: L10n.tr("places.form.category"))
                }

                Section {
                    Toggle(isOn: $useCurrentLocation) {
                        Text(verbatim: L10n.tr("places.form.use_current_location"))
                    }
                        .tint(FTColors.primary)
                        .onChange(of: useCurrentLocation) { use in
                            if use { fillCurrentLocation() }
                        }

                    if !useCurrentLocation {
                        coordinateField("Vĩ độ:", placeholder: "10.7769", text: $latitude)
                        coordinateField("Kinh độ:", placeholder: "106.7009", text: $longitude)
                    } else if viewModel.currentLocation == nil {
                        Text(verbatim: L10n.tr("places.form.current_location_unavailable"))
                            .font(FTFont.caption())
                            .foregroundColor(FTColors.warning)
                    }
                } header: {
                    Text(verbatim: L10n.tr("places.form.location"))
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label {
                            Text(verbatim: L10n.message(error))
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                        }
                            .foregroundColor(FTColors.danger)
                            .font(FTFont.caption())
                    }
                }
            }
            .navigationTitle(Text(verbatim: L10n.tr("places.form.add_title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.tr("common.cancel"), action: onClose)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.tr("common.save"), action: save)
                        .disabled(viewModel.isAdding || name.isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: fillCurrentLocation)
    }

    private func coordinateField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            AppLocalizedText(label)
                .font(FTFont.caption())
                .foregroundColor(FTColors.textSecondary)
            TextField(placeholder, text: text)
                .keyboardType(.numbersAndPunctuation)
        }
    }

    private func fillCurrentLocation() {
        guard let point = viewModel.currentLocation else { return }
        latitude = String(point.latitude)
        longitude = String(point.longitude)
    }

    private func save() {
        let location: GeoPoint?
        if useCurrentLocation {
            location = viewModel.currentLocation
        } else if let lat = Double(latitude.replacingOccurrences(of: ",", with: ".")),
                  let lon = Double(longitude.replacingOccurrences(of: ",", with: ".")) {
            location = GeoPoint(latitude: lat, longitude: lon)
        } else {
            location = nil
        }

        guard let location else {
            viewModel.errorMessage = "Vui lòng nhập tọa độ hợp lệ."
            return
        }

        Task {
            if await viewModel.add(name: name, category: category, location: location) {
                onClose()
            }
        }
    }
}
