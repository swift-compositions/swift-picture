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
