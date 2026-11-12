public import Vector

extension Picture.Scene.Material {
    /// A surface that shows what is behind it from a place its slant pushes aside, under a coat of `tint`.
    public struct Glass: Sendable, Hashable {
        public var bend: Double
        public var tint: Picture.Color

        /// A light the glass reflects, or none.
        public var light: Light?

        /// The glass's body, or none: then the glass is a skin that reads the picture behind at `offset(for:)`
        /// under a coat of `tint`. With a body `bend` is not used, and the tint is taken on along the way
        /// through it: its alpha is the share after one unit of the scene.
        public var refraction: Refraction?

        public init(bend: Double, tint: Picture.Color = .clear, light: Light? = nil, refraction: Refraction? = nil) {
            self.bend = bend
            self.tint = tint
            self.light = light
            self.refraction = refraction
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
        shading.pixel(over: behind, facing: normal)
    }

    /// The pixel of glass with a body: `shading`'s, which says what each part does.
    public func pixel(
        over behind: InlineArray<3, Picture.Pixel>,
        through length: Double,
        leaving: Vector<3, Double>,
        beyond: Double,
        mirroring mirrored: Vector<3, Double>,
        by share: Double,
        facing normal: Vector<3, Double>
    ) -> Picture.Pixel {
        shading.pixel(over: behind, through: length, leaving: leaving, beyond: beyond, mirroring: mirrored, by: share, facing: normal)
    }

    /// The glass with its colours taken into working pixels once, for drawing many points of it.
    public var shading: Shading {
        Shading(
            tint: tint.pixel,
            light: light,
            shine: light?.color.pixel ?? .transparent,
            above: refraction?.surroundings?.above.pixel,
            below: refraction?.surroundings?.below.pixel
        )
    }
}
