import Picture

extension Picture.Renderer.CPU {
    /// A transform's six entries as plain numbers, so that a point taken through it many times builds no vectors.
    /// Each coordinate is summed as swift-matrix's `applied(to:)` sums it, from zero and in the order of the
    /// columns, so the result is that of `applied(to:)` bit for bit.
    struct Affine: Sendable {
        let xx: Double
        let xy: Double
        let x0: Double
        let yx: Double
        let yy: Double
        let y0: Double
    }
}

extension Picture.Renderer.CPU.Affine {
    init(_ transform: Picture.Transform) {
        self.init(
            xx: transform[0, 0],
            xy: transform[0, 1],
            x0: transform[0, 2],
            yx: transform[1, 0],
            yy: transform[1, 1],
            y0: transform[1, 2]
        )
    }

    /// The first coordinate of a point taken through the transform.
    @inline(__always)
    func x(_ x: Double, _ y: Double) -> Double {
        0 + xx * x + xy * y + x0
    }

    /// The second coordinate of a point taken through the transform.
    @inline(__always)
    func y(_ x: Double, _ y: Double) -> Double {
        0 + yx * x + yy * y + y0
    }

    /// A point taken through the transform.
    @inline(__always)
    func point(_ x: Double, _ y: Double) -> Picture.Plane.Point<2> {
        Picture.Plane.Point<2>([self.x(x, y), self.y(x, y)])
    }
}
