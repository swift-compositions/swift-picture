extension Picture.Sprites {
    /// One disc of light.
    public struct Sprite: Sendable, Hashable {
        public var center: Picture.Point
        public var radius: Double
        public var color: Picture.Color

        public init(center: Picture.Point, radius: Double, color: Picture.Color) {
            self.center = center
            self.radius = radius
            self.color = color
        }
    }
}
