public import Vector

extension Picture.Scene.Material {
    /// A surface that shows what is behind it from a place its slant pushes aside, under a coat of `tint`.
    public struct Glass: Sendable, Hashable {
        public var bend: Double
        public var tint: Picture.Color

        /// A light the glass reflects, or none.
        public var light: Light?

        public init(bend: Double, tint: Picture.Color = .clear, light: Light? = nil) {
            self.bend = bend
            self.tint = tint
            self.light = light
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

    /// The glass's pixel where its unit normal in eye space is `normal`: the tint over what it reads, and on
    /// top the light it reflects there, added.
    public func pixel(over behind: Picture.Pixel, facing normal: Vector<3, Double>) -> Picture.Pixel {
        let coated = pixel(over: behind)
        guard let light else { return coated }
        let share = Float(light.reflection(for: normal))
        guard share > 0 else { return coated }
        return light.color.pixel.composited(over: coated, operator: .lighter, coverage: share)
    }
}
