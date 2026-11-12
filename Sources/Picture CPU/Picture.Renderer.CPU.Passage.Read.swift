import Picture

extension Picture.Renderer.CPU.Passage {
    /// A point of the raster where the picture behind glass is read.
    struct Read {
        var x: Double
        var y: Double
    }
}
