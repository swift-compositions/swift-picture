public import Color_Standard
import IEC_61966

extension Picture.Color {
    /// The colour's place in Oklab, where equal steps look about equally large. Alpha is left out, and each of
    /// red, green and blue is held to 0…1 first.
    public var oklab: Color_Standard::Color.Oklab {
        .init(IEC_61966.`2`.`1`.SRGB(r: Double(red), g: Double(green), b: Double(blue)).canonical())
    }

    /// The colour written in sRGB for a place in Oklab, with an alpha. A place outside sRGB gives the colour
    /// with each of red, green and blue held to 0…1.
    public init(_ oklab: Color_Standard::Color.Oklab, alpha: Float = 1) {
        let written = IEC_61966.`2`.`1`.SRGB(oklab.canonical())
        self.init(red: Float(written.r), green: Float(written.g), blue: Float(written.b), alpha: alpha)
    }

    /// This colour part of the way to another along the straight line between their places in Oklab, with
    /// alpha going the same part of the way. `share` is not held to 0…1.
    public func mixed(inOklabTo other: Self, at share: Double) -> Self {
        let (from, to) = (oklab, other.oklab)
        let place = Color_Standard::Color.Oklab(
            l: from.l + (to.l - from.l) * share,
            a: from.a + (to.a - from.a) * share,
            b: from.b + (to.b - from.b) * share
        )
        return Self(place, alpha: alpha + (other.alpha - alpha) * Float(share))
    }
}
