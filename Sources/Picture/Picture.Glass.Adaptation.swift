import Numeric

extension Picture.Glass {
    /// How a glass keeps what is on it legible: it moves the lightness of what it shows toward `color`'s by
    /// `strength` times how far apart they are, keeping its hue and chroma, so a dark backdrop is lifted toward a
    /// light colour much and keeps its colour, a light one little, and one as light as the colour not at all. Toward white, black labels on
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
    /// A pixel's place in Oklab (Ottosson 2020), lightness L and the opponent axes a and b, from its linear colour
    /// over its alpha with each component held to 0…1; the origin without alpha.
    public static func oklab(of pixel: Picture.Pixel) -> (L: Float, a: Float, b: Float) {
        guard pixel.alpha > 0 else { return (0, 0, 0) }
        func held(_ value: Float) -> Float { Swift.min(Swift.max(value / pixel.alpha, 0), 1) }
        let (r, g, b) = (held(pixel.color.red), held(pixel.color.green), held(pixel.color.blue))
        func root(_ value: Float) -> Float { value > 0 ? Float(Double.exp(Double.log(Double(value)) / 3)) : 0 }
        let l = root(0.412_221_470_8 * r + 0.536_332_536_3 * g + 0.051_445_992_9 * b)
        let m = root(0.211_903_498_2 * r + 0.680_699_545_1 * g + 0.107_396_956_6 * b)
        let s = root(0.088_302_461_9 * r + 0.281_718_837_6 * g + 0.629_978_700_5 * b)
        return (
            0.210_454_255_3 * l + 0.793_617_785_0 * m - 0.004_072_046_8 * s,
            1.977_998_495_1 * l - 2.428_592_205_0 * m + 0.450_593_709_9 * s,
            0.025_904_037_1 * l + 0.782_771_766_2 * m - 0.808_675_766_0 * s
        )
    }

    /// The linear colour at a place in Oklab, each component held to 0…1.
    public static func color(L: Float, a: Float, b: Float) -> (red: Float, green: Float, blue: Float) {
        let l = L + 0.396_337_777_4 * a + 0.215_803_757_3 * b
        let m = L - 0.105_561_345_8 * a - 0.063_854_172_8 * b
        let s = L - 0.089_484_177_5 * a - 1.291_485_548_0 * b
        let (l3, m3, s3) = (l * l * l, m * m * m, s * s * s)
        func held(_ value: Float) -> Float { Swift.min(Swift.max(value, 0), 1) }
        return (
            held(4.076_741_662_1 * l3 - 3.307_711_591_3 * m3 + 0.230_969_929_2 * s3),
            held(-1.268_438_004_6 * l3 + 2.609_757_401_1 * m3 - 0.341_319_396_5 * s3),
            held(-0.004_196_086_3 * l3 - 0.703_418_614_7 * m3 + 1.707_638_127_4 * s3)
        )
    }

    /// A pixel's lightness, 0 to 1: its Oklab L.
    public static func lightness(of pixel: Picture.Pixel) -> Float {
        oklab(of: pixel).L
    }

    /// The share by which a pixel's lightness is moved toward the colour's: `strength`, held to 0…1, times the
    /// difference of their lightnesses.
    public func share(for pixel: Picture.Pixel) -> Float {
        let strength = Float(Swift.min(Swift.max(self.strength, 0), 1))
        return strength * abs(Self.lightness(of: color.pixel) - Self.lightness(of: pixel))
    }

    /// A pixel with its Oklab lightness moved toward the colour's by its share and its a and b kept, so the
    /// backdrop's hue and chroma stay and only its lightness gives way; alpha is kept. A share of 0 gives the
    /// pixel bit for bit.
    public func pixel(_ pixel: Picture.Pixel) -> Picture.Pixel {
        self.pixel(pixel, target: Self.lightness(of: color.pixel))
    }

    /// `pixel(_:)` with the colour's lightness, `lightness(of: color.pixel)`, worked out once by the caller.
    func pixel(_ pixel: Picture.Pixel, target: Float) -> Picture.Pixel {
        let place = Self.oklab(of: pixel)
        let share = Float(Swift.min(Swift.max(strength, 0), 1)) * abs(target - place.L)
        guard share > 0 else { return pixel }
        let moved = Self.color(L: place.L + (target - place.L) * share, a: place.a, b: place.b)
        return Picture.Pixel(color: .init(red: moved.red * pixel.alpha, green: moved.green * pixel.alpha, blue: moved.blue * pixel.alpha), alpha: pixel.alpha)
    }
}
