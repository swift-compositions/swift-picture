import Numeric

extension Picture.Glass {
    /// How a glass keeps what is on it legible: it moves what it shows toward `color` by `strength` times how
    /// far the backdrop's lightness is from the colour's, so a dark backdrop is lifted toward a light colour much
    /// and a light one little, and a backdrop as light as the colour is left alone. Toward white, black labels on
    /// the glass stay legible; toward black, white ones do; toward a grey, the glass lifts what is dark and dims
    /// what is bright.
    public struct Adaptation: Sendable, Hashable {
        public var color: Picture.Color

        /// How strongly, 0 to 1.
        public var strength: Double

        public init(toward color: Picture.Color, strength: Double) {
            self.color = color
            self.strength = strength
        }
    }
}

extension Picture.Glass.Adaptation {
    /// A pixel's lightness, 0 to 1: the cube root of its relative luminance (0.2126 red, 0.7152 green and 0.0722
    /// blue of its linear colour over its alpha), as CIE and Oklab take lightness to grow; 0 without alpha.
    public static func lightness(of pixel: Picture.Pixel) -> Float {
        guard pixel.alpha > 0 else { return 0 }
        let luminance = (0.2126 * pixel.color.red + 0.7152 * pixel.color.green + 0.0722 * pixel.color.blue) / pixel.alpha
        let held = Swift.min(Swift.max(luminance, 0), 1)
        return held > 0 ? Float(Double.exp(Double.log(Double(held)) / 3)) : 0
    }

    /// The share by which a pixel is moved toward the colour: `strength` times the difference of their
    /// lightnesses, each held to 0…1.
    public func share(for pixel: Picture.Pixel) -> Float {
        let strength = Float(Swift.min(Swift.max(self.strength, 0), 1))
        return strength * abs(Self.lightness(of: color.pixel) - Self.lightness(of: pixel))
    }

    /// A pixel moved toward the colour by its share, colour and alpha together.
    public func pixel(_ pixel: Picture.Pixel) -> Picture.Pixel {
        let share = share(for: pixel)
        guard share > 0 else { return pixel }
        return pixel.interpolated(to: color.pixel, at: share)
    }
}
