import MapKit
import SwiftUI

struct RouteCameraRequest: Equatable {
    let revision: Int
    let entryID: String?
}

struct RouteMapView: UIViewRepresentable {
    let model: RouteOverlayModel
    let cameraRequest: RouteCameraRequest
    let edgePadding: UIEdgeInsets
    let onSelectEntry: (String) -> Void
    let onUserMovedMap: () -> Void

    func makeCoordinator() -> RouteMapRenderer { RouteMapRenderer() }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.mapType = .standard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.delegate = context.coordinator
        context.coordinator.attach(to: mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.update(
            model: model, cameraRequest: cameraRequest, edgePadding: edgePadding,
            onSelectEntry: onSelectEntry, onUserMovedMap: onUserMovedMap
        )
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: RouteMapRenderer) {
        coordinator.detach()
        mapView.delegate = nil
    }
}

#if DEBUG
private struct RouteMapViewPreview: PreviewProvider {
    static var previews: some View {
        RouteMapView(
            model: sample,
            cameraRequest: RouteCameraRequest(revision: 0, entryID: nil),
            edgePadding: UIEdgeInsets(top: 40, left: 24, bottom: 100, right: 24),
            onSelectEntry: { _ in }, onUserMovedMap: {}
        )
        .previewDisplayName("Journey route map")
    }

    private static var sample: RouteOverlayModel {
        let points = [
            GeoPoint(latitude: 10.7769, longitude: 106.7009),
            GeoPoint(latitude: 10.779, longitude: 106.703),
            GeoPoint(latitude: 10.782, longitude: 106.704),
            GeoPoint(latitude: 10.784, longitude: 106.708)
        ]
        let moving = MovingSegment(
            fromLatitude: points[0].latitude, fromLongitude: points[0].longitude,
            toLatitude: points[3].latitude, toLongitude: points[3].longitude,
            startTime: "2026-10-16T08:00:00Z", endTime: "2026-10-16T08:20:00Z",
            durationMinutes: 20, durationFormatted: "20", path: points
        )
        let stay = StayPoint(
            latitude: points[3].latitude, longitude: points[3].longitude,
            arrivedAt: "2026-10-16T08:20:00Z", leftAt: "2026-10-16T08:50:00Z",
            durationMinutes: 30, durationFormatted: "30", pointCount: 5
        )
        return RouteOverlayModel.build(
            from: DayJourney(date: nil, summary: nil, entries: [.moving(moving), .stay(stay)]),
            toleranceMeters: 5
        )
    }
}
#endif
