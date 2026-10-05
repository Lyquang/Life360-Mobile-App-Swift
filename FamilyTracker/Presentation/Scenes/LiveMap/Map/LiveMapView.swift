// MARK: - LiveMapView.swift
// Full-screen map with realtime member positions. Navigation/SOS are delegated to MapCoordinator.

import SwiftUI
import MapKit

struct LiveMapView: View {
    @ObservedObject var viewModel: LiveMapViewModel
    let coordinator: MapCoordinator

    @State private var showMemberList = false
    @State private var selectedMember: MemberLocation?

    var body: some View {
        ZStack(alignment: .top) {
            Map(
                coordinateRegion: $viewModel.mapRegion,
                showsUserLocation: true,
                userTrackingMode: .constant(viewModel.isTrackingUser ? .follow : .none),
                annotationItems: viewModel.memberLocations
            ) { member in
                MapAnnotation(coordinate: member.coordinate) {
                    Button {
                        withAnimation(.spring()) {
                            selectedMember = member
                            viewModel.centerOnMember(member)
                        }
                    } label: {
                        MapMemberPin(memberLocation: member, isCurrentUser: member.id == viewModel.currentUserId)
                    }
                }
            }
            .ignoresSafeArea()

            LinearGradient(colors: [Color.black.opacity(0.5), Color.clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
                .ignoresSafeArea()

            header

            controls

            if let member = selectedMember {
                VStack {
                    Spacer()
                    MemberInfoCard(
                        member: member,
                        onDismiss: { selectedMember = nil },
                        onNavigate: { viewModel.centerOnMember(member) },
                        onShowJourney: { coordinator.showJourney(of: member) }
                    )
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if showMemberList {
                memberList
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.start() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FamilyTracker")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isConnected ? FTColors.accent : FTColors.danger)
                        .frame(width: 6, height: 6)
                    Text(viewModel.isConnected ? "Đang kết nối" : "Offline")
                        .font(FTFont.caption())
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            Button {
                withAnimation(.spring()) { showMemberList.toggle() }
            } label: {
                HStack(spacing: FTSpacing.xs) {
                    Image(systemName: "person.2.fill")
                    Text("\(viewModel.memberLocations.count)")
                        .font(FTFont.subheadline())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(FTRadius.full)
            }
        }
        .padding(.horizontal, FTSpacing.md)
        .padding(.top, 55)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: FTSpacing.sm) {
            Spacer()

            mapControlButton(
                icon: viewModel.isTrackingUser ? "location.fill" : "location",
                color: viewModel.isTrackingUser ? FTColors.primary : FTColors.textSecondary,
                action: viewModel.centerOnUser
            )

            mapControlButton(icon: "sos", color: FTColors.danger, action: coordinator.requestSOS)
        }
        .padding(.trailing, FTSpacing.md)
        .padding(.bottom, 120)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func mapControlButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Member list overlay

    private var memberList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Thành viên trực tuyến")
                    .font(FTFont.headline())
                Spacer()
                Button {
                    withAnimation { showMemberList = false }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(FTColors.textSecondary)
                }
            }
            .padding(FTSpacing.md)

            if viewModel.memberLocations.isEmpty {
                Text("Không có thành viên nào đang trực tuyến")
                    .font(FTFont.subheadline())
                    .foregroundColor(FTColors.textSecondary)
                    .padding(FTSpacing.xl)
            } else {
                ForEach(viewModel.memberLocations) { member in
                    Button {
                        selectedMember = member
                        viewModel.centerOnMember(member)
                        withAnimation { showMemberList = false }
                    } label: {
                        HStack(spacing: FTSpacing.md) {
                            MemberAvatarView(name: member.name, size: .medium, isOnline: true, batteryLevel: member.batteryLevel)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .font(FTFont.subheadline())
                                    .foregroundColor(FTColors.textPrimary)
                                Text("Cập nhật lúc \(DisplayFormat.time(iso: member.timestamp))")
                                    .font(FTFont.caption())
                                    .foregroundColor(FTColors.textSecondary)
                            }

                            Spacer()

                            if let battery = member.batteryLevel {
                                BatteryIndicatorView(level: battery)
                            }
                        }
                        .padding(.horizontal, FTSpacing.md)
                        .padding(.vertical, FTSpacing.sm)
                    }
                    Divider().padding(.leading, 72)
                }
            }
        }
        .background(FTColors.card)
        .cornerRadius(FTRadius.xl)
        .shadow(color: Color.black.opacity(0.2), radius: 20)
        .padding(.horizontal, FTSpacing.md)
        .padding(.top, 100)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
