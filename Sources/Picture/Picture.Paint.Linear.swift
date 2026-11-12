extension Picture.Paint {
    /// A gradient along the line from one point to another, constant across it.
    public struct Linear: Sendable, Hashable {
        public var start: Picture.Plane.Point<2>
        public var end: Picture.Plane.Point<2>
        public var gradient: Picture.Gradient

        public init(from start: Picture.Plane.Point<2>, to end: Picture.Plane.Point<2>, _ gradient: Picture.Gradient) {
            self.start = start
            self.end = end
            self.gradient = gradient
        }
    }
}

extension Picture.Paint.Linear {
    /// How far along the line from `start` to `end` the point's foot lies: 0 at `start`, 1 at `end`.
    public func parameter(at point: Picture.Plane.Point<2>) -> Double {
        let across = end[0] - start[0]
        let down = end[1] - start[1]
        let length = across * across + down * down
        guard length > 0 else { return 0 }
        return ((point[0] - start[0]) * across + (point[1] - start[1]) * down) / length
    }
}
