public import Vector

extension Picture.Glass {
    /// Where a point of a glass lies from the glass's outline as it is drawn: how far in, in picture units, and
    /// the outline's outward direction across the view, x right and y up. A pane knows it from its region's signed
    /// distance; a renderer finds it for a body from the body's silhouette.
    public struct Outline: Sendable, Hashable {
        public var inward: Double
        public var outward: Vector<2, Double>

        public init(inward: Double, outward: Vector<2, Double>) {
            self.inward = inward
            self.outward = outward
        }
    }
}
