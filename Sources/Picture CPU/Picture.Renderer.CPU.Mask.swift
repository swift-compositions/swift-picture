import Picture

extension Picture.Renderer.CPU {
    /// The share of each pixel a clip leaves open, over a box; 0 outside it.
    struct Mask {
        var box: Box
        var values: [Float]
    }
}

extension Picture.Renderer.CPU.Mask {
    /// The share at a pixel of raster space.
    subscript(x: Int, y: Int) -> Float {
        box.contains(x, y) ? values[box.index(x, y)] : 0
    }
}
