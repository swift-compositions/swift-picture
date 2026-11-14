import Color_Standard

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
    /// over its alpha with each component held to 0…1: `Color.Oklab.coordinates(red:green:blue:)` of
    /// swift-color-standard. The origin without alpha.
    public static func oklab(of pixel: Picture.Pixel) -> (L: Float, a: Float, b: Float) {
        guard pixel.alpha > 0 else { return (0, 0, 0) }
        func held(_ value: Float) -> Float { Swift.min(Swift.max(value / pixel.alpha, 0), 1) }
        let place = Color_Standard::Color.Oklab.coordinates(
            red: held(pixel.color.red),
            green: held(pixel.color.green),
            blue: held(pixel.color.blue)
        )
        return (place.l, place.a, place.b)
    }

    /// The linear colour at a place in Oklab, `Color.Oklab.linear(l:a:b:)` of swift-color-standard, each
    /// component held to 0…1.
    public static func color(L: Float, a: Float, b: Float) -> (red: Float, green: Float, blue: Float) {
        let linear = Color_Standard::Color.Oklab.linear(l: L, a: a, b: b)
        func held(_ value: Float) -> Float { Swift.min(Swift.max(value, 0), 1) }
        return (held(linear.red), held(linear.green), held(linear.blue))
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
