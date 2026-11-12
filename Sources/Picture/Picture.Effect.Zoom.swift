extension Picture.Effect {
    /// A radial blur: each point becomes the mean of the sheet along the stretch of the line from
    /// the point toward the centre that `amount` covers, from the point itself (`amount` 0) to the centre (1).
    public struct Zoom: Sendable, Hashable {
        public var center: Picture.Plane.Point<2>
        public var amount: Double

        public init(center: Picture.Plane.Point<2>, amount: Double) {
            self.center = center
            self.amount = amount
        }
    }
}

extension Picture.Effect.Zoom {
    /// The point of the sheet read for `point` at `fraction` of the way along its stretch, 0 to 1.
    public func source(of point: Picture.Plane.Point<2>, at fraction: Double) -> Picture.Plane.Point<2> {
        let scale = 1 - amount * fraction
        return Picture.Plane.Point<2>([
            center[0] + (point[0] - center[0]) * scale,
            center[1] + (point[1] - center[1]) * scale,
        ])
    }
}
