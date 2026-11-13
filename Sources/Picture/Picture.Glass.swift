public import Vector

extension Picture {
    /// A glass: what it does to the picture behind it, wherever it stands. The same value is the material of a
    /// mesh in a scene (`Picture.Scene.Material.glass`) and of a flat pane over a picture (`Picture.Glass.Pane`),
    /// and each reads the picture behind through the same laws: bent by its surface, frosted, adapted, under a
    /// coat of its tint and with the light it reflects on top.
    public struct Glass: Sendable, Hashable {
        /// How far a skin without a body pushes what it reads aside: see `offset(for:)`. Not used with a body.
        public var bend: Double

        /// The coat over what the glass shows; clear changes nothing.
        public var tint: Picture.Color

        /// A light the glass reflects, or none.
        public var light: Light?

        /// The glass's body, or none: then the glass is a skin that reads the picture behind at `offset(for:)`
        /// under a coat of `tint`. With a body `bend` is not used, and the tint is taken on along the way
        /// through it: its alpha is the share after one unit of length.
        public var refraction: Refraction?

        /// How much the glass blurs what is behind it: the deviation of a Gaussian over the picture behind, in
        /// units of the picture the glass is drawn in. Zero is clear. Where the surface turns away from the eye
        /// the frost thins, by `frosting(facing:)`.
        public var frost: Double

        /// How much brighter the glass makes what it shows: red, green and blue are multiplied by it in linear
        /// light, held to the pixel's alpha; 1 changes nothing.
        public var gain: Double

        /// How vivid the glass makes what it shows: each colour's distance from its own luminance is multiplied
        /// by this, so 1 changes nothing, more is more vivid and 0 is grey.
        public var saturation: Double

        /// How the glass moves what it shows toward a colour, the more the further the backdrop is from it, so
        /// that content on the glass stays legible; none changes nothing.
        public var adaptation: Adaptation?

        /// The soft shadows the glass casts on the picture around it, drawn in order before it.
        public var shadows: [Shadow]

        public init(
            bend: Double = 0,
            tint: Picture.Color = .clear,
            light: Light? = nil,
            refraction: Refraction? = nil,
            frost: Double = 0,
            gain: Double = 1,
            saturation: Double = 1,
            adaptation: Adaptation? = nil,
            shadows: [Shadow] = []
        ) {
            self.bend = bend
            self.tint = tint
            self.light = light
            self.refraction = refraction
            self.frost = frost
            self.gain = gain
            self.saturation = saturation
            self.adaptation = adaptation
            self.shadows = shadows
        }
    }
}

extension Picture.Glass {
    /// How far from a point of the surface the picture behind is read, for the surface's unit normal
    /// in eye space there: `bend` times the normal's x, and minus its y.
    public func offset(for normal: Vector<3, Double>) -> Vector<2, Double> {
        Vector([bend * normal[0], -bend * normal[1]])
    }

    /// The glass's pixel over the pixel of the picture behind that it reads: adapted, then the tint over it.
    public func pixel(over behind: Picture.Pixel) -> Picture.Pixel {
        shading.coat(behind)
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
        facing normal: Vector<3, Double>,
        outline: Outline? = nil,
        tilts: InlineArray<3, Double> = [1, 1, 1]
    ) -> Picture.Pixel {
        shading.pixel(
            over: behind, through: length, leaving: leaving, beyond: beyond, mirroring: mirrored, by: share,
            facing: normal, outline: outline, tilts: tilts
        )
    }

    /// The glass with its colours taken into working pixels once, for drawing many points of it.
    public var shading: Shading {
        Shading(
            tint: tint.pixel,
            light: light,
            shine: light?.color.pixel ?? .transparent,
            above: refraction?.surroundings?.above.pixel,
            below: refraction?.surroundings?.below.pixel,
            gain: Float(gain),
            saturation: Float(saturation),
            adaptation: adaptation
        )
    }
}

extension Picture.Glass {
    /// A pixel brightened by a gain and with each of red, green and blue moved away from its luminance (0.2126
    /// red, 0.7152 green and 0.0722 blue, in linear light) by a factor: each becomes
    /// gain × (luminance + (component − luminance) × factor), held to 0 up to the pixel's alpha. Alpha is kept, and
    /// a gain and a factor of 1 give the pixel bit for bit.
    public static func saturated(_ pixel: Picture.Pixel, by factor: Float, gain: Float = 1) -> Picture.Pixel {
        guard factor != 1 || gain != 1 else { return pixel }
        let c = pixel.color
        let luminance = 0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue
        func moved(_ value: Float) -> Float { Swift.min(Swift.max(gain * (luminance + (value - luminance) * factor), 0), Swift.max(pixel.alpha, 0)) }
        return Picture.Pixel(color: .init(red: moved(c.red), green: moved(c.green), blue: moved(c.blue)), alpha: pixel.alpha)
    }
}

extension Picture.Glass {
    /// How much of the frost a surface keeps where its unit normal in eye space is `normal`: the square root of
    /// the normal's z, held to 0…1. What the glass reads is the clear picture mixed toward the frosted one by this
    /// share, so a surface facing the eye is frosted fully and a rim seen edge-on shows the picture lensed but
    /// clear, as a polished edge does.
    public static func frosting(facing normal: Vector<3, Double>) -> Double {
        let z = Swift.min(Swift.max(abs(normal[2]), 0), 1)
        return z.squareRoot()
    }
}
