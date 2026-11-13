import Picture

extension Picture.Renderer {
    /// The working parts of the renderer in pure Swift.
    package enum CPU {}
}

extension Picture.Renderer.CPU {
    /// The edition of this renderer's drawing, raised by every change that can change a pixel it draws, so that
    /// a raster kept from an earlier edition is never taken for this one's.
    package static let edition = 2

    /// How far a flattened curve may stray from the true one, in pixels of the raster.
    static let tolerance: Double = 0.1

    /// The most pixels one sheet may hold: past this a layer is refused as `.unsupported`.
    static let limit: Int = 1 << 26

    /// The most pixels a renderer keeps of what it draws for images that name their picture, unless it is told
    /// otherwise: 2²⁵, half a gigabyte.
    static let keeping: Int = 1 << 25

    /// The sum of the squares of a transform's linear part: its largest stretch is at most the root of this.
    static func stretch(_ transform: Picture.Transform) -> Double {
        let a = transform[0, 0]
        let b = transform[0, 1]
        let c = transform[1, 0]
        let d = transform[1, 1]
        return (a * a + b * b + c * c + d * d).squareRoot()
    }

    /// A point of raster space taken through a transform.
    static func point(_ transform: Picture.Transform, _ x: Double, _ y: Double) -> Picture.Plane.Point<2> {
        let moved = transform.applied(to: Vector([x, y]))
        return Picture.Plane.Point<2>([moved[0], moved[1]])
    }

    /// The pixel that ends a change limited to a share `c` of a pixel: what was there plus `c` times the change.
    static func limited(_ old: Picture.Pixel, _ new: Picture.Pixel, _ share: Float?) -> Picture.Pixel {
        guard let share, share != 1 else { return new }
        return old.interpolated(to: new, at: share)
    }
}
