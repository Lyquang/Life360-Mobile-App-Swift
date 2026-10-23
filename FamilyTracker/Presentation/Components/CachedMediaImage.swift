import SwiftUI

struct CachedMediaImage: View {
    let url: URL
    let blurhash: String?
    let loader: MediaImageLoader
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
        image = try? await loader.load(url)
    }
}
