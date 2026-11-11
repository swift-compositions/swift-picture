extension Picture.Paint {
    /// A gradient outward from a centre, constant on every circle around it.
    public struct Radial: Sendable, Hashable {
        public var center: Picture.Point
        public var radius: Double
        public var gradient: Picture.Gradient

        public init(center: Picture.Point, radius: Double, _ gradient: Picture.Gradient) {
            self.center = center
            self.radius = radius
            self.gradient = gradient
        }
    }
}

extension Picture.Paint.Radial {
    /// The point's distance from the centre in radii: 0 at the centre, 1 on the circle.
    public func parameter(at point: Picture.Point) -> Double {
        guard radius > 0 else { return 0 }
        let across = point[0] - center[0]
        let down = point[1] - center[1]
        return (across * across + down * down).squareRoot() / radius
    }
}
