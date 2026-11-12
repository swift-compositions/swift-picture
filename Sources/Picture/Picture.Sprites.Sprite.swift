extension Picture.Sprites {
    /// One disc of light.
    public struct Sprite: Sendable, Hashable {
        public var center: Picture.Plane.Point<2>
        public var radius: Double
        public var color: Picture.Color

        public init(center: Picture.Plane.Point<2>, radius: Double, color: Picture.Color) {
            self.center = center
            self.radius = radius
            self.color = color
        }
    }
}
