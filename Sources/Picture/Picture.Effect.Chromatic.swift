public import Vector

extension Picture.Effect {
    /// Red, green and blue each moved by its own offset.
    public struct Chromatic: Sendable, Hashable {
        public var red: Vector<2, Double>
        public var green: Vector<2, Double>
        public var blue: Vector<2, Double>

        public init(red: Vector<2, Double>, green: Vector<2, Double> = .zero, blue: Vector<2, Double>) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }
}

extension Picture.Effect.Chromatic {
    /// The pixel made from the sheet's pixels at `point − red`, `point − green` and `point − blue`.
    public func pixel(red: Picture.Pixel, green: Picture.Pixel, blue: Picture.Pixel) -> Picture.Pixel {
        Picture.Pixel(
            color: .init(red: red.color.red, green: green.color.green, blue: blue.color.blue),
            alpha: Swift.max(red.alpha, green.alpha, blue.alpha)
        )
    }
}
