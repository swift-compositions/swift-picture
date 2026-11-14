import Picture

extension Picture.Renderer.CPU.Traversal {
    /// A point of the raster where the picture behind glass is read.
    struct Read {
        var x: Double
        var y: Double
    }
}
