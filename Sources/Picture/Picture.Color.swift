public import Color_Standard
import IEC_61966
public import W3C_CSS_Compositing

extension Picture {
    /// A colour as it is written: sRGB-encoded red, green and blue with straight alpha.
    public struct Color: Sendable, Hashable {
        public var red: Float
        public var green: Float
        public var blue: Float
        public var alpha: Float

        public init(red: Float, green: Float, blue: Float, alpha: Float = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }
}

extension Picture.Color {
    public static var black: Self { Self(red: 0, green: 0, blue: 0) }

    public static var white: Self { Self(red: 1, green: 1, blue: 1) }

    public static var clear: Self { Self(red: 0, green: 0, blue: 0, alpha: 0) }

    public init(gray: Float, alpha: Float = 1) {
        self.init(red: gray, green: gray, blue: gray, alpha: alpha)
    }

    /// The colour in linear light with straight alpha: each component through the sRGB transfer function.
    public var linear: Compositing.Straight<Float> {
        Compositing.Straight(
            color: Compositing.Color(
                red: IEC_61966.SRGB.TransferFunction.linear(red),
                green: IEC_61966.SRGB.TransferFunction.linear(green),
                blue: IEC_61966.SRGB.TransferFunction.linear(blue)
            ),
            alpha: alpha
        )
    }

    /// The colour as a working pixel: linear light, multiplied by alpha.
    public var pixel: Picture.Pixel {
        Compositing.Premultiplied(linear)
    }
}

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
