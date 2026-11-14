import Numeric
public import Vector

extension Picture.Glass {
    /// A soft shadow a glass casts, kept by where the glass stands (a pane's `shadows`, a scene's `shadows`) on the picture around it: its outline as drawn, a pane's region or a body's
    /// silhouette, moved by an offset and blurred by a softness, in a colour whose alpha is its strength. It falls
    /// only outside the glass, which shows the picture without it. A thin dark one hugging the outline is the
    /// glass's dark edge.
    public struct Shadow: Sendable, Hashable {
        public var color: Picture.Color

        /// How soft the edge is, in picture units: about the deviation of a Gaussian blur of the region.
        public var softness: Double

        /// How far the shadow is moved from the glass, in picture units.
        public var offset: Vector<2, Double>

        public init(
            color: Picture.Color = Picture.Color(red: 0, green: 0, blue: 0, alpha: 0.2),
            softness: Double = 16,
            offset: Vector<2, Double> = Vector([0, 6])
        ) {
            self.color = color
            self.softness = softness
            self.offset = offset
        }
    }
}

extension Picture.Glass.Shadow {
    /// The share of the colour at a signed distance from the moved region's boundary: 1 / (1 + e^(1.7·d / softness)),
    /// the logistic curve that stands within 0.01 of a Gaussian-blurred edge: a half on the boundary, toward 1
    /// inside and 0 outside, falling evenly; a hard edge for a softness that is not positive.
    public func share(at distance: Double) -> Double {
        guard softness > 0 else { return distance <= 0 ? 1 : 0 }
        let x = 1.7 * distance / softness
        guard x < 700 else { return 0 }
        return 1 / (1 + Double.exp(x))
    }
}

extension Picture.Glass.Shadow {
    /// The shadow with its colour at another alpha, which is its strength.
    public func with(alpha: Float) -> Self {
        var shadow = self
        shadow.color = color.with(alpha: alpha)
        return shadow
    }
}
