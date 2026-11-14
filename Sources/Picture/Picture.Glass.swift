import Color_Standard
public import Vector

extension Picture {
    /// A glass: what it does to the picture behind it, wherever it stands. The same value is the material of a
    /// mesh in a scene (`Picture.Scene.Material.glass`) and of a flat pane over a picture (`Picture.Glass.Pane`),
    /// and each reads the picture behind through the same laws: bent by its surface, frosted, adapted, under a
    /// coat of its tint and with the light it reflects on top.
    public struct Glass: Sendable, Hashable {
        /// What bends what the glass reads: a skin's `bend`, or a body's medium.
        public var surface: Surface

        /// The coat over what the glass shows; clear changes nothing. On a skin it lies over what is read; through
        /// a body it is taken on along the way: its alpha is the share taken on across the glass's own thickness,
        /// so a pane's level middle and the thickest path through a ball take the same coat.
        public var tint: Picture.Color

        /// A light the glass reflects, or none.
        public var light: Light?

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

        public init(
            _ surface: Surface = .skin(bend: 0),
            tint: Picture.Color = .clear,
            light: Light? = nil,
            frost: Double = 0,
            gain: Double = 1,
            saturation: Double = 1,
            adaptation: Adaptation? = nil
        ) {
            self.surface = surface
            self.tint = tint
            self.light = light
            self.frost = frost
            self.gain = gain
            self.saturation = saturation
            self.adaptation = adaptation
        }
    }
}

extension Picture.Glass {
    /// The glass's body, or nil for a skin.
    public var body: Body? {
        guard case .body(let body) = surface else { return nil }
        return body
    }

    /// How far from a point of the surface the picture behind is read, for the surface's unit normal
    /// in eye space there: a skin's `bend` times the normal's x, and minus its y; zero for a body, which bends
    /// by Snell's law instead.
    public func offset(for normal: Vector<3, Double>) -> Vector<2, Double> {
        guard case .skin(let bend) = surface else { return .zero }
        return Vector([bend * normal[0], -bend * normal[1]])
    }
}

extension Picture.Glass {
    /// A pixel brightened by a gain and with each of red, green and blue moved away from its luminance
    /// (`Color.luminance(red:green:blue:)` of swift-color-standard: 0.2126 red, 0.7152 green and 0.0722 blue, in
    /// linear light) by a factor: each becomes
    /// gain × (luminance + (component − luminance) × factor), held to 0 up to the pixel's alpha. Alpha is kept, and
    /// a gain and a factor of 1 give the pixel bit for bit.
    public static func saturated(_ pixel: Picture.Pixel, by factor: Float, gain: Float = 1) -> Picture.Pixel {
        guard factor != 1 || gain != 1 else { return pixel }
        let c = pixel.color
        let luminance = Color_Standard::Color.luminance(red: c.red, green: c.green, blue: c.blue)
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
