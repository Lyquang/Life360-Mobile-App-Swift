# Plan / execution: MapKit search

Use existing AppContainer/MapCoordinator/LiveMap architecture. Add pure Domain
models, search/history ports and use cases; Core owns MKLocalSearchCompleter and
MKLocalSearch, Data maps their output and stores bounded UserDefaults query cache.
ObservableObject search VM owns debounce and request versions; Coordinator owns
sheet lifetime and selected place; renderer adds one distinct search pin.

Cache expiry/dedup/cap use an injected clock. Account ID is hashed for storage key;
JSON stores user-typed query/timestamps only. Session stop clears cache and revokes
old VM capability synchronously before logout's async work. Search close cancels
requests without clearing same-session history. App restart retains unexpired entries.

Files: Domain search entities/repositories/use cases; Core/Maps; Data repository/cache;
Places/Search VM/View; AppContainer, MapCoordinator, MainTabCoordinator.stop,
LiveMapView/LiveTrailMapView; vi/en strings; standalone search tests/script.

Meaningful checks map to AC01–07 in spec. Existing app scheme lacks runnable
XCTest target; use standalone Swift executable to run model/cache/state-machine
tests, then compile all production code with unsigned Simulator build. Do not
change app targets or install dependencies simply to run this feature's tests.

Localization: key/copy table is canonical in spec.md; both resources updated together.
Use native iOS16 UI only; preserve trail camera/member selection and attribution.
