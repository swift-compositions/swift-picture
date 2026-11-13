import Picture

extension Picture.Renderer.CPU.Store {
    /// What a kept raster is found by: the source it was drawn from, hashed once however often it is looked up.
    struct Key: Sendable, Hashable {
        let source: Picture.Image.Source
        let hash: Int

        init(_ source: Picture.Image.Source) {
            self.source = source
            self.hash = source.hashValue
        }

        static func == (first: Self, second: Self) -> Bool {
            first.hash == second.hash && first.source == second.source
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(hash)
        }
    }
}
