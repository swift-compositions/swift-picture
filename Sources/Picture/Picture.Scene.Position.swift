extension Picture.Scene {
    /// A point of a scene as it is drawn: where in the picture, and how deep.
    public struct Position: Sendable, Hashable {
        public var point: Picture.Point
        public var depth: Double

        public init(point: Picture.Point, depth: Double) {
            self.point = point
            self.depth = depth
        }
    }
}
