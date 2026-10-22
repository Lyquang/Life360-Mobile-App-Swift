import MapKit
import SwiftUI

@MainActor
final class RouteMapRenderer: NSObject, MKMapViewDelegate {
    private enum LineRole { case casing, stroke }
    private struct LineRecord {
        let points: [GeoPoint]
        let casing: MKPolyline
        let stroke: MKPolyline
    }

    private weak var mapView: MKMapView?
    private var lines = [String: LineRecord]()
    private var roles = [ObjectIdentifier: (id: String, role: LineRole)]()
    private var markers = [String: RouteMapMarker]()
    private var lastGeometryID: UInt64?
    private var selectedEntryID: String?
    private var lastCameraRequest: RouteCameraRequest?
    private var lastEdgePadding: UIEdgeInsets?
    private var isProgrammaticCamera = false
    private var tapRecognizer: UITapGestureRecognizer?
    private var onSelectEntry: ((String) -> Void)?
    private var onUserMovedMap: (() -> Void)?

    func attach(to mapView: MKMapView) {
        self.mapView = mapView
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapMap(_:)))
        tap.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tap)
        tapRecognizer = tap
    }

    func update(model: RouteOverlayModel, cameraRequest: RouteCameraRequest,
                edgePadding: UIEdgeInsets, onSelectEntry: @escaping (String) -> Void,
                onUserMovedMap: @escaping () -> Void) {
        guard let mapView else { return }
        self.onSelectEntry = onSelectEntry
        self.onUserMovedMap = onUserMovedMap
        let geometryChanged = lastGeometryID != model.geometryID
        var markersChanged = false
        if geometryChanged {
            _ = syncLines(model.segments, in: mapView)
            markersChanged = syncMarkers(model, in: mapView)
            lastGeometryID = model.geometryID
        }

        if selectedEntryID != model.selectedEntryID {
            selectedEntryID = model.selectedEntryID
            restyleLines(in: mapView)
            restyleMarkers(in: mapView)
        }
        if markersChanged { restyleMarkers(in: mapView) }
        if geometryChanged || lastCameraRequest != cameraRequest || lastEdgePadding != edgePadding {
            lastCameraRequest = cameraRequest
            lastEdgePadding = edgePadding
            fit(model: model, entryID: cameraRequest.entryID,
                edgePadding: edgePadding, in: mapView)
        }
    }

    func detach() {
        if let mapView {
            if let tapRecognizer { mapView.removeGestureRecognizer(tapRecognizer) }
            mapView.removeOverlays(Array(mapView.overlays))
            mapView.removeAnnotations(Array(markers.values))
        }
        mapView = nil
        tapRecognizer = nil
        lines.removeAll()
        roles.removeAll()
        markers.removeAll()
        lastGeometryID = nil
        onSelectEntry = nil
        onUserMovedMap = nil
        lastEdgePadding = nil
    }

    private func syncLines(_ segments: [RouteOverlayModel.Segment], in mapView: MKMapView) -> Bool {
        var changed = false
        let desiredIDs = Set(segments.map(\.id))
        for id in lines.keys.filter({ !desiredIDs.contains($0) }) {
            removeLine(id, from: mapView)
            changed = true
        }
        for segment in segments {
            if let previous = lines[segment.id], previous.points == segment.points { continue }
            if lines[segment.id] != nil { removeLine(segment.id, from: mapView) }
            var coordinates = segment.points.map(\.coordinate)
            let casing = MKPolyline(coordinates: &coordinates, count: coordinates.count)
            let stroke = MKPolyline(coordinates: &coordinates, count: coordinates.count)
            lines[segment.id] = LineRecord(points: segment.points, casing: casing, stroke: stroke)
            roles[ObjectIdentifier(casing)] = (segment.id, .casing)
            roles[ObjectIdentifier(stroke)] = (segment.id, .stroke)
            mapView.addOverlay(casing, level: .aboveRoads)
            mapView.addOverlay(stroke, level: .aboveRoads)
            changed = true
        }
        return changed
    }

    private func removeLine(_ id: String, from mapView: MKMapView) {
        guard let previous = lines.removeValue(forKey: id) else { return }
        roles[ObjectIdentifier(previous.casing)] = nil
        roles[ObjectIdentifier(previous.stroke)] = nil
        mapView.removeOverlays([previous.casing, previous.stroke])
    }

    private func syncMarkers(_ model: RouteOverlayModel, in mapView: MKMapView) -> Bool {
        let specs = RouteMapMarker.specifications(for: model)
        let desiredIDs = Set(specs.map(\.id))
        var changed = false
        for id in markers.keys.filter({ !desiredIDs.contains($0) }) {
            if let marker = markers.removeValue(forKey: id) { mapView.removeAnnotation(marker) }
            changed = true
        }
        for spec in specs {
            if let existing = markers[spec.id] {
                if existing.kind != spec.kind || existing.entryID != spec.entryID {
                    mapView.removeAnnotation(existing)
                    let replacement = RouteMapMarker(spec: spec)
                    markers[spec.id] = replacement
                    mapView.addAnnotation(replacement)
                    changed = true
                } else if existing.update(from: spec) {
                    changed = true
                }
            } else {
                let marker = RouteMapMarker(spec: spec)
                markers[spec.id] = marker
                mapView.addAnnotation(marker)
                changed = true
            }
        }
        return changed
    }

    private func fit(model: RouteOverlayModel, entryID: String?, edgePadding: UIEdgeInsets,
                     in mapView: MKMapView) {
        let points: [GeoPoint]
        if let entryID, let segment = model.segments.first(where: { $0.id == entryID }) {
            points = segment.points
        } else if let entryID, let stay = model.stays.first(where: { $0.id == entryID }) {
            points = [stay.point]
        } else {
            points = model.segments.flatMap(\.points) + model.stays.map(\.point)
                + [model.start, model.end].compactMap { $0 }
        }
        guard let bounds = RouteBounds(points: points) else { return }
        isProgrammaticCamera = true
        mapView.setVisibleMapRect(RouteMapGeometry.visibleRect(for: bounds),
                                  edgePadding: edgePadding, animated: false)
    }

    private func restyleLines(in mapView: MKMapView) {
        for record in lines.values {
            for overlay in [record.casing, record.stroke] {
                guard let renderer = mapView.renderer(for: overlay) as? MKPolylineRenderer,
                      let info = roles[ObjectIdentifier(overlay)] else { continue }
                configure(renderer, id: info.id, role: info.role)
                renderer.setNeedsDisplay()
            }
        }
    }

    private func configure(_ renderer: MKPolylineRenderer, id: String, role: LineRole) {
        let selected = selectedEntryID == nil || selectedEntryID == id
        let isFocus = selectedEntryID == id
        renderer.lineWidth = role == .casing ? (isFocus ? 13 : 10) : (isFocus ? 8 : 6)
        renderer.strokeColor = role == .casing
            ? UIColor(FTColors.background).withAlphaComponent(selected ? 0.96 : 0.4)
            : UIColor(FTColors.primary).withAlphaComponent(selected ? 1 : 0.3)
        renderer.lineCap = .round
        renderer.lineJoin = .round
    }

    private func restyleMarkers(in mapView: MKMapView) {
        for marker in markers.values {
            guard let view = mapView.view(for: marker) as? MKMarkerAnnotationView else { continue }
            style(view, for: marker)
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
        let renderer = MKPolylineRenderer(polyline: polyline)
        if let info = roles[ObjectIdentifier(polyline)] {
            configure(renderer, id: info.id, role: info.role)
        }
        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let marker = annotation as? RouteMapMarker else { return nil }
        let reuseID = "route-marker"
        let view = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: marker, reuseIdentifier: reuseID)
        view.annotation = marker
        view.canShowCallout = false
        style(view, for: marker)
        return view
    }

    private func style(_ view: MKMarkerAnnotationView, for marker: RouteMapMarker) {
        let selected = selectedEntryID == nil || selectedEntryID == marker.entryID
        view.alpha = selected ? 1 : 0.5
        view.markerTintColor = marker.kind == .stay ? UIColor(FTColors.accent) : UIColor(FTColors.primary)
        view.glyphImage = UIImage(systemName: marker.symbol)
        view.displayPriority = marker.kind == .direction ? .defaultLow : .required
        view.accessibilityLabel = marker.title
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let marker = view.annotation as? RouteMapMarker, let id = marker.entryID else { return }
        onSelectEntry?(id)
        mapView.deselectAnnotation(marker, animated: false)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if isProgrammaticCamera {
            isProgrammaticCamera = false
        } else {
            onUserMovedMap?()
        }
    }

    @objc private func didTapMap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let mapView else { return }
        let point = recognizer.location(in: mapView)
        let paths = lines.map { id, record in
            (id, record.points.map { mapView.convert($0.coordinate, toPointTo: mapView) })
        }
        guard let id = RouteMapGeometry.nearestSegment(to: point, paths: paths) else { return }
        onSelectEntry?(id)
    }
}
