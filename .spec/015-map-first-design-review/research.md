# Research / implementation decisions

- Dùng @StateObject AppearanceSettings ở root và preferredColorScheme; init sync
  từ UserDefaults trước content; system trả nil. Giữ state/session identity.
- Native Picker/List/NavigationStack iOS16, environment preference cho modal tree.
- MapKit MKMapView/annotation hosting theo effective trait, không thay renderer/SDK.
- Header/member panels adaptive; native search sheet giữ coordinator/usecase và
  partial map bằng medium/large detents, large khi keyboard/XXXL cần diện tích đọc.
- DebugOverlay bỏ visible floating control, giữ hidden keyboard shortcut/launch
  presentation; Profile Developer link tới đầy đủ console+monitoring.
- Skill research/HIG đã ghi trong audit/design; không dùng web CSS/mockup để suy
  native semantics. Native tokens/labels và measurements có test riêng.
