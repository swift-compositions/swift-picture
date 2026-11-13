extension Picture.Scene.Camera {
    /// A point of the world as a camera sees it: where a scene through the camera draws it and how deep, how far
    /// ahead of the eye it lies, and whether it lies at or beyond the near plane, where a scene draws it.
    public struct Sight: Sendable, Hashable {
        public var position: Picture.Scene.Position
        public var distance: Double
        public var ahead: Bool

        public init(position: Picture.Scene.Position, distance: Double, ahead: Bool) {
            self.position = position
            self.distance = distance
            self.ahead = ahead
        }
    }
}
