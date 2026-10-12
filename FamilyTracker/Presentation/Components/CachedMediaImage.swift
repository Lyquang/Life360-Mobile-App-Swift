import SwiftUI

struct CachedMediaImage: View {
    let url: URL
    let blurhash: String?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable() }
            else { placeholder.overlay(ProgressView()) }
        }
        .task(id: url) { await load() }
    }

    private var placeholder: some View {
        Group {
            if let blurhash, let image = BlurHashDecoder.image(from: blurhash) {
                Image(uiImage: image).resizable()
            } else { Color.gray.opacity(0.18) }
        }
    }

    private func load() async {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        if let cached = URLCache.shared.cachedResponse(for: request), let value = UIImage(data: cached.data) {
            image = value; return
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let value = UIImage(data: data) else { return }
        URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
        image = value
    }
}
