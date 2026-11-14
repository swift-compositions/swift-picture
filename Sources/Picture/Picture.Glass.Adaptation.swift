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
    /// A pixel's lightness, 0 to 1: the Oklab L (`Color.Oklab.coordinates(red:green:blue:)` of swift-color-standard)
    /// of its linear colour over its alpha with each component held to 0…1; 0 without alpha.
    static func lightness(of pixel: Picture.Pixel) -> Float {
        guard pixel.alpha > 0 else { return 0 }
        func held(_ value: Float) -> Float { Swift.min(Swift.max(value / pixel.alpha, 0), 1) }
        return Color_Standard::Color.Oklab.coordinates(red: held(pixel.color.red), green: held(pixel.color.green), blue: held(pixel.color.blue)).l
    }

    /// A pixel with its Oklab lightness moved toward the colour's by `strength`, held to 0…1, times the difference
    /// of their lightnesses, and its a and b kept, so the backdrop's hue and chroma stay and only its lightness
    /// gives way: its linear colour over its alpha, each component held to 0…1, taken into Oklab by
    /// `Color.Oklab.coordinates(red:green:blue:)` of swift-color-standard and back by `Color.Oklab.linear(l:a:b:)`,
    /// each component held to 0…1 again. Alpha is kept, and a share of 0 gives the pixel bit for bit.
    public func pixel(_ pixel: Picture.Pixel) -> Picture.Pixel {
        self.pixel(pixel, target: Self.lightness(of: color.pixel))
    }

    /// `pixel(_:)` with the colour's lightness, `lightness(of: color.pixel)`, worked out once by the caller.
    func pixel(_ pixel: Picture.Pixel, target: Float) -> Picture.Pixel {
        var place = (l: Float(0), a: Float(0), b: Float(0))
        if pixel.alpha > 0 {
            func held(_ value: Float) -> Float { Swift.min(Swift.max(value / pixel.alpha, 0), 1) }
            let found = Color_Standard::Color.Oklab.coordinates(red: held(pixel.color.red), green: held(pixel.color.green), blue: held(pixel.color.blue))
            place = (found.l, found.a, found.b)
        }
        let share = Float(Swift.min(Swift.max(strength, 0), 1)) * abs(target - place.l)
        guard share > 0 else { return pixel }
        let linear = Color_Standard::Color.Oklab.linear(l: place.l + (target - place.l) * share, a: place.a, b: place.b)
        func held(_ value: Float) -> Float { Swift.min(Swift.max(value, 0), 1) }
        return Picture.Pixel(
            color: .init(red: held(linear.red) * pixel.alpha, green: held(linear.green) * pixel.alpha, blue: held(linear.blue) * pixel.alpha),
            alpha: pixel.alpha
        )
    }
}
