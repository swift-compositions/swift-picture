import Picture

extension Picture.Renderer.CPU {
    /// The nearest triangle at one sample point of a scene: its number in the stage's list, the point's
    /// weights on its corners in the raster's plane, and its depth; a number below zero where none is.
    struct Hit {
        var triangle: Int
        var weights: InlineArray<3, Double>
        var depth: Double
    }
}

extension Picture.Renderer.CPU.Hit {
    /// No triangle.
    static var none: Self { Self(triangle: -1, weights: [0, 0, 0], depth: .infinity) }
}
