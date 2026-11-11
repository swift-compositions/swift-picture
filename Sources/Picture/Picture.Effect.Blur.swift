extension Picture.Effect {
    /// A Gaussian blur with one standard deviation in both directions, in the layer's units.
    public struct Blur: Sendable, Hashable {
        public var deviation: Double

        public init(deviation: Double) {
            self.deviation = deviation
        }
    }
}

extension Picture.Effect.Blur {
    /// This blur followed by another, as one blur: the deviations add as squares.
    public func followed(by other: Self) -> Self {
        Self(deviation: (deviation * deviation + other.deviation * other.deviation).squareRoot())
    }
}
