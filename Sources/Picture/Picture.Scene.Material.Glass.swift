public import Vector

extension Picture.Scene.Material {
    /// A surface that shows what is behind it from a place its slant pushes aside, under a coat of `tint`.
    public struct Glass: Sendable, Hashable {
        public var bend: Double
        public var tint: Picture.Color

        public init(bend: Double, tint: Picture.Color = .clear) {
            self.bend = bend
            self.tint = tint
        }
    }
}

extension Picture.Scene.Material.Glass {
    /// How far from a point of the surface the picture behind is read, for the surface's unit normal
    /// in eye space there: `bend` times the normal's x, and minus its y.
    public func offset(for normal: Vector<3, Double>) -> Vector<2, Double> {
        Vector([bend * normal[0], -bend * normal[1]])
    }

    /// The glass's pixel over the pixel of the picture behind that it reads: the tint over it.
    public func pixel(over behind: Picture.Pixel) -> Picture.Pixel {
        tint.pixel.composited(over: behind)
    }
}
