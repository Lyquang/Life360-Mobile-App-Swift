# UI state

AppearancePreference enum system/light/dark; local raw-string persistence key
app.appearance, invalid fallback system. AppearanceSettings sở hữu preference duy nhất.
Không Backend field mới. Map member selection/expanded local UI giữ View ownership;
query/search/modal thuộc MapCoordinator/PlaceSearchViewModel như cũ. Timestamp parse
fail → localized unknown; nil presence chỉ ẩn badge, không mang nghĩa offline.
