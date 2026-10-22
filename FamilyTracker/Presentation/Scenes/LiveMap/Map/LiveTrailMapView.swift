import MapKit
import SwiftUI

struct LiveTrailMapView: UIViewRepresentable {
    let region: MKCoordinateRegion
    let trackingUser: Bool
    let showsUserLocation: Bool
    let currentUserId: String
    let members: [MemberLocation]
    let drawing: TrailDrawing
    let bottomInset: CGFloat
    let onSelectMember: (MemberLocation) -> Void
    let onUserMoved: () -> Void

    func makeCoordinator() -> Renderer { Renderer() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.showsUserLocation = showsUserLocation
        map.delegate = context.coordinator
        context.coordinator.map = map
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.update(region: region, trackingUser: trackingUser,
                                   currentUserId: currentUserId, members: members,
                                   drawing: drawing, bottomInset: bottomInset, onSelectMember: onSelectMember,
                                   onUserMoved: onUserMoved)
    }

    static func dismantleUIView(_ map: MKMapView, coordinator: Renderer) {
        coordinator.detach()
        map.delegate = nil
    }

    final class MemberAnnotation: NSObject, MKAnnotation {
        let id: String
        var member: MemberLocation
        var host: UIHostingController<MapMemberPin>?
        @objc dynamic var coordinate: CLLocationCoordinate2D

        init(_ member: MemberLocation) {
            id = member.id
            self.member = member
            coordinate = member.point.coordinate
        }
    }

    final class TrailAnnotation: NSObject, MKAnnotation {
        let id: String
        let symbol: String
        let title: String?
        @objc dynamic var coordinate: CLLocationCoordinate2D

        init(id: String, point: GeoPoint, symbol: String, title: String) {
            self.id = id
            self.symbol = symbol
            self.title = title
            coordinate = point.coordinate
        }
    }

    @MainActor
    final class Renderer: NSObject, MKMapViewDelegate {
        weak var map: MKMapView?
        private struct LineRecord {
            let points: [GeoPoint]
            let style: TrailDrawing.Style
            let overlays: [MKPolyline]
        }
        private var lines = [String: LineRecord]()
        private var roles = [ObjectIdentifier: (TrailDrawing.Style, Bool)]()
        private var members = [String: MemberAnnotation]()
        private var endpoints = [String: TrailAnnotation]()
        private var lastRegion: MKCoordinateRegion?
        private var lastBottomInset: CGFloat?
        private var isMovingProgrammatically = false
        private var currentUserId = ""
        private var onSelectMember: ((MemberLocation) -> Void)?
        private var onUserMoved: (() -> Void)?

        func update(region: MKCoordinateRegion, trackingUser: Bool, currentUserId: String,
                    members: [MemberLocation], drawing: TrailDrawing, bottomInset: CGFloat,
                    onSelectMember: @escaping (MemberLocation) -> Void,
                    onUserMoved: @escaping () -> Void) {
            guard let map else { return }
            self.currentUserId = currentUserId
            self.onSelectMember = onSelectMember
            self.onUserMoved = onUserMoved
            if let old = lastRegion {
                if abs(old.center.latitude - region.center.latitude) > 0.000001 ||
                    abs(old.center.longitude - region.center.longitude) > 0.000001 ||
                    abs(old.span.latitudeDelta - region.span.latitudeDelta) > 0.000001 ||
                    lastBottomInset != bottomInset {
                    isMovingProgrammatically = true
                    moveCamera(region, bottomInset: bottomInset, on: map)
                }
            } else {
                isMovingProgrammatically = true
                moveCamera(region, bottomInset: bottomInset, on: map)
            }
            lastRegion = region
            lastBottomInset = bottomInset
            map.userTrackingMode = trackingUser ? .follow : .none
            syncMembers(members, on: map)
            syncTrail(drawing, on: map)
        }

        private func moveCamera(_ region: MKCoordinateRegion, bottomInset: CGFloat, on map: MKMapView) {
            guard bottomInset > 0,
                  let bounds = RouteBounds(points: [
                    GeoPoint(latitude: region.center.latitude - region.span.latitudeDelta / 2,
                             longitude: region.center.longitude - region.span.longitudeDelta / 2),
                    GeoPoint(latitude: region.center.latitude + region.span.latitudeDelta / 2,
                             longitude: region.center.longitude + region.span.longitudeDelta / 2)
                  ]) else {
                map.setRegion(region, animated: false)
                return
            }
            map.setVisibleMapRect(RouteMapGeometry.visibleRect(for: bounds),
                                  edgePadding: UIEdgeInsets(top: 24, left: 24,
                                                            bottom: bottomInset + 24, right: 24),
                                  animated: false)
        }

        func detach() {
            if let map {
                map.removeOverlays(map.overlays)
                map.removeAnnotations(Array(members.values) + Array(endpoints.values))
            }
            lines.removeAll()
            roles.removeAll()
            members.removeAll()
            endpoints.removeAll()
            onSelectMember = nil
            onUserMoved = nil
            map = nil
        }

        private func syncMembers(_ latest: [MemberLocation], on map: MKMapView) {
            let ids = Set(latest.map(\.id))
            for id in members.keys.filter({ !ids.contains($0) }) {
                if let marker = members.removeValue(forKey: id) { map.removeAnnotation(marker) }
            }
            for member in latest {
                if let marker = members[member.id] {
                    let changed = marker.member.name != member.name ||
                        marker.member.batteryLevel != member.batteryLevel
                    marker.member = member
                    marker.coordinate = member.point.coordinate
                    if changed, let view = map.view(for: marker) {
                        setMemberContent(view, member: member)
                    }
                } else {
                    let marker = MemberAnnotation(member)
                    members[member.id] = marker
                    map.addAnnotation(marker)
                }
            }
        }

        private func syncTrail(_ drawing: TrailDrawing, on map: MKMapView) {
            let ids = Set(drawing.lines.map(\.id))
            for id in lines.keys.filter({ !ids.contains($0) }) { removeLine(id, from: map) }
            for line in drawing.lines where line.points.count >= 2 {
                if let old = lines[line.id], old.points == line.points,
                   old.style == line.style { continue }
                removeLine(line.id, from: map)
                var coordinates = line.points.map(\.coordinate)
                let count = line.style == .matched ? 2 : 1
                let overlays = (0..<count).map { _ in MKPolyline(coordinates: &coordinates, count: coordinates.count) }
                lines[line.id] = LineRecord(points: line.points, style: line.style, overlays: overlays)
                for (index, overlay) in overlays.enumerated() {
                    roles[ObjectIdentifier(overlay)] = (line.style, index == 0 && count == 2)
                    map.addOverlay(overlay, level: .aboveRoads)
                }
            }
            let desired: [(String, GeoPoint, String, String)] = {
                guard let first = drawing.fixes.first else { return [] }
                if let last = drawing.fixes.last, last != first {
                    return [("start", first, "circle.fill", L10n.tr("history.tag.start")),
                            ("end", last, "flag.fill", L10n.tr("history.tag.latest"))]
                }
                return [("start", first, "mappin.circle.fill", L10n.tr("history.tag.start"))]
            }()
            let wanted = Set(desired.map(\.0))
            for id in endpoints.keys.filter({ !wanted.contains($0) }) {
                if let marker = endpoints.removeValue(forKey: id) { map.removeAnnotation(marker) }
            }
            for (id, point, symbol, title) in desired {
                if let marker = endpoints[id],
                   marker.coordinate.latitude == point.latitude,
                   marker.coordinate.longitude == point.longitude { continue }
                if let marker = endpoints.removeValue(forKey: id) { map.removeAnnotation(marker) }
                let marker = TrailAnnotation(id: id, point: point, symbol: symbol, title: title)
                endpoints[id] = marker
                map.addAnnotation(marker)
            }
        }

        private func removeLine(_ id: String, from map: MKMapView) {
            guard let old = lines.removeValue(forKey: id) else { return }
            old.overlays.forEach { roles[ObjectIdentifier($0)] = nil }
            map.removeOverlays(old.overlays)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: line)
            if let (style, casing) = roles[ObjectIdentifier(line)] {
                renderer.lineWidth = casing ? 10 : 6
                renderer.strokeColor = casing ? UIColor(FTColors.background) :
                    (style == .matched ? UIColor(FTColors.primary) : UIColor(FTColors.textSecondary))
                renderer.lineCap = .round
                renderer.lineJoin = .round
                if style == .gps { renderer.lineDashPattern = [8, 7] }
            }
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let marker = annotation as? MemberAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "member") ??
                    MKAnnotationView(annotation: marker, reuseIdentifier: "member")
                view.annotation = marker
                view.canShowCallout = false
                setMemberContent(view, member: marker.member)
                return view
            }
            guard let marker = annotation as? TrailAnnotation else { return nil }
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: "trail") as? MKMarkerAnnotationView) ??
                MKMarkerAnnotationView(annotation: marker, reuseIdentifier: "trail")
            view.annotation = marker
            view.markerTintColor = UIColor(FTColors.primary)
            view.glyphImage = UIImage(systemName: marker.symbol)
            view.accessibilityLabel = marker.title
            return view
        }

        private func setMemberContent(_ view: MKAnnotationView, member: MemberLocation) {
            guard let marker = view.annotation as? MemberAnnotation else { return }
            let content = MapMemberPin(memberLocation: member, isCurrentUser: member.id == currentUserId)
            if let host = marker.host {
                host.rootView = content
                if host.view.superview !== view {
                    view.subviews.forEach { $0.removeFromSuperview() }
                    view.addSubview(host.view)
                }
                return
            }
            let host = UIHostingController(rootView: content)
            marker.host = host
            host.view.backgroundColor = .clear
            host.view.frame = CGRect(x: 0, y: 0, width: 64, height: 72)
            view.subviews.forEach { $0.removeFromSuperview() }
            view.frame = host.view.frame
            view.centerOffset = CGPoint(x: 0, y: -36)
            view.addSubview(host.view)
            view.accessibilityLabel = member.name
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let marker = view.annotation as? MemberAnnotation else { return }
            onSelectMember?(marker.member)
            mapView.deselectAnnotation(marker, animated: false)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if isMovingProgrammatically { isMovingProgrammatically = false }
            else if mapView.userTrackingMode == .follow { return }
            else { onUserMoved?() }
        }
    }
}
