// MARK: - PlacesView.swift
// Favorite places of the selected group.

import SwiftUI

struct PlacesView: View {
    @ObservedObject var viewModel: PlacesViewModel
    let onAddPlace: () -> Void

    @State private var selectedCategory: PlaceCategory?

    var body: some View {
        ZStack {
            FTColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if !viewModel.groups.isEmpty {
                    groupPicker
                }

                categoryFilter

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Đang tải địa điểm...")
                        .progressViewStyle(CircularProgressViewStyle(tint: FTColors.primary))
                    Spacer()
                } else if filteredPlaces.isEmpty {
                    Spacer()
                    FTEmptyView(
                        icon: "star.slash",
                        title: "Chưa có địa điểm",
                        subtitle: "Thêm địa điểm yêu thích để nhóm cùng lưu lại những nơi đáng nhớ",
                        actionTitle: viewModel.selectedGroupId != nil ? "Thêm địa điểm" : nil,
                        action: onAddPlace
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: FTSpacing.sm) {
                            ForEach(filteredPlaces) { place in
                                PlaceCard(place: place) { viewModel.focus(on: place) }
                            }
                        }
                        .padding(FTSpacing.md)
                    }
                    .refreshable { await viewModel.reloadPlaces() }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.groups.isEmpty { await viewModel.loadGroups() }
        }
        .ftSuccessToast($viewModel.successMessage)
        .ftErrorAlert($viewModel.loadErrorMessage)
    }

    private var filteredPlaces: [FavoritePlace] {
        viewModel.places(for: selectedCategory)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Địa điểm yêu thích")
                    .font(FTFont.title2())
                    .foregroundColor(FTColors.textPrimary)
                Text("\(viewModel.places.count) địa điểm")
                    .font(FTFont.caption())
                    .foregroundColor(FTColors.textSecondary)
            }

            Spacer()

            if viewModel.selectedGroupId != nil {
                Button(action: onAddPlace) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(FTColors.primaryGradient)
                        .clipShape(Circle())
                        .shadow(color: FTColors.primary.opacity(0.4), radius: 8)
                }
            }
        }
        .padding(.horizontal, FTSpacing.md)
        .padding(.top, FTSpacing.md)
        .padding(.bottom, FTSpacing.sm)
    }

    private var groupPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                ForEach(viewModel.groups) { group in
                    let isSelected = viewModel.selectedGroupId == group.id
                    Button {
                        Task { await viewModel.selectGroup(group.id) }
                    } label: {
                        Text(group.name)
                            .font(FTFont.caption())
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundColor(isSelected ? .white : FTColors.textSecondary)
                            .padding(.horizontal, FTSpacing.md)
                            .padding(.vertical, 8)
                            .background(isSelected ? FTColors.primary : FTColors.surface)
                            .cornerRadius(FTRadius.full)
                    }
                }
            }
            .padding(.horizontal, FTSpacing.md)
            .padding(.vertical, FTSpacing.sm)
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                categoryChip(label: "Tất cả", icon: "star.fill", isSelected: selectedCategory == nil, color: FTColors.primary) {
                    selectedCategory = nil
                }
                ForEach(PlaceCategory.allCases) { category in
                    categoryChip(
                        label: category.displayName,
                        icon: category.iconName,
                        isSelected: selectedCategory == category,
                        color: category.color
                    ) {
                        selectedCategory = category == selectedCategory ? nil : category
                    }
                }
            }
            .padding(.horizontal, FTSpacing.md)
            .padding(.vertical, FTSpacing.sm)
        }
    }

    private func categoryChip(label: String, icon: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(FTFont.caption())
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .white : FTColors.textSecondary)
            .padding(.horizontal, FTSpacing.sm)
            .padding(.vertical, 6)
            .background(isSelected ? color : FTColors.surface)
            .cornerRadius(FTRadius.full)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct PlaceCard: View {
    let place: FavoritePlace
    let onTap: () -> Void

    var body: some View {
        let color = place.category.color
        Button(action: onTap) {
            HStack(spacing: FTSpacing.md) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: place.category.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(FTFont.subheadline())
                        .foregroundColor(FTColors.textPrimary)

                    Text(place.category.displayName)
                        .font(FTFont.caption())
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.12))
                        .cornerRadius(FTRadius.full)

                    if let lat = place.latitude, let lon = place.longitude {
                        Text("Lat: \(String(format: "%.4f", lat)), Lon: \(String(format: "%.4f", lon))")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(FTColors.textTertiary)
                    }
                }

                Spacer()

                if let addedBy = place.addedBy {
                    MemberAvatarView(name: addedBy.name, size: .small, isOnline: false, batteryLevel: nil)
                }
            }
            .padding(FTSpacing.md)
            .ftCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}
