import MapKit

final class RouteMapMarker: NSObject, MKAnnotation {
    enum Kind: Equatable {
        case start, end, single, stay, direction

        var symbol: String {
            switch self {
            case .start: return "circle.fill"
            case .end: return "flag.fill"
            case .single: return "mappin.circle.fill"
            case .stay: return "mappin"
            case .direction: return "arrow.up"
            }
        }
    }

    struct Spec {
        let id: String
        let point: GeoPoint
        let kind: Kind
        let entryID: String?
        let directionSymbol: String?
    }

    let id: String
    let kind: Kind
    let entryID: String?
    private(set) var directionSymbol: String?
    @objc dynamic var coordinate: CLLocationCoordinate2D

    var title: String? {
        switch kind {
        case .start: return L10n.tr("history.tag.start")
        case .end: return L10n.tr("history.tag.latest")
        case .single: return L10n.tr("Lộ trình")
        case .stay: return L10n.tr("Điểm dừng")
        case .direction: return L10n.tr("Lộ trình")
        }
    }

    init(spec: Spec) {
        id = spec.id
        kind = spec.kind
        entryID = spec.entryID
        directionSymbol = spec.directionSymbol
        coordinate = spec.point.coordinate
    }

    func update(from spec: Spec) -> Bool {
        let changed = coordinate.latitude != spec.point.latitude ||
            coordinate.longitude != spec.point.longitude || directionSymbol != spec.directionSymbol
        coordinate = spec.point.coordinate
        directionSymbol = spec.directionSymbol
        return changed
    }

    var symbol: String { directionSymbol ?? kind.symbol }

    static func specifications(for model: RouteOverlayModel) -> [Spec] {
        var specs = model.stays.map { stay in
            Spec(id: "stay:\(stay.id)", point: stay.point, kind: .stay,
                 entryID: stay.id, directionSymbol: nil)
        }
        for segment in model.segments where segment.points.count >= 2 {
            let length = zip(segment.points, segment.points.dropFirst())
                .reduce(0) { $0 + $1.0.distance(to: $1.1) }
            guard length >= 80 else { continue }
            let index = segment.points.count / 2
            let before = segment.points[index - 1]
            let after = segment.points[index]
            var longitude = after.longitude - before.longitude
            if longitude > 180 { longitude -= 360 }
            if longitude < -180 { longitude += 360 }
            var middleLongitude = before.longitude + longitude / 2
            if middleLongitude > 180 { middleLongitude -= 360 }
            if middleLongitude < -180 { middleLongitude += 360 }
            let mid = GeoPoint(latitude: (before.latitude + after.latitude) / 2,
                               longitude: middleLongitude)
            specs.append(Spec(id: "direction:\(segment.id)", point: mid,
                              kind: .direction, entryID: segment.id,
                              directionSymbol: arrow(from: before, to: after)))
        }
        if let start = model.start {
            let onePoint = model.end == start
            specs.append(Spec(id: "route:start", point: start,
                              kind: onePoint ? .single : .start,
                              entryID: nil, directionSymbol: nil))
        }
        if let end = model.end, end != model.start {
            specs.append(Spec(id: "route:end", point: end, kind: .end,
                              entryID: nil, directionSymbol: nil))
        }
        return specs
    }

    private static func arrow(from start: GeoPoint, to end: GeoPoint) -> String {
        let symbols = ["arrow.up", "arrow.up.right", "arrow.right", "arrow.down.right",
                       "arrow.down", "arrow.down.left", "arrow.left", "arrow.up.left"]
        var longitude = end.longitude - start.longitude
        if longitude > 180 { longitude -= 360 }
        if longitude < -180 { longitude += 360 }
        let east = longitude * cos((start.latitude + end.latitude) * .pi / 360)
        let north = end.latitude - start.latitude
        let angle = atan2(east, north)
        let sector = Int((angle / (.pi / 4)).rounded())
        return symbols[(sector + 8) % 8]
    }
}
